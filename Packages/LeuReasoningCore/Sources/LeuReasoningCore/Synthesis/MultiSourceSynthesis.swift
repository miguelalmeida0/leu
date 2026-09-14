import Foundation

/// Equivalent claims made by one or more documents.
public struct ClaimCluster: Codable, Equatable, Sendable, Identifiable {
    public var id: StableID
    public var representative: KnowledgeAtom
    public var members: [StableID]
    public var documentIDs: [String]

    public init(representative: KnowledgeAtom, members: [StableID], documentIDs: [String]) {
        self.id = StableID(namespace: "cluster", components: [representative.id.rawValue])
        self.representative = representative
        self.members = members
        self.documentIDs = documentIDs
    }

    public var isShared: Bool { documentIDs.count > 1 }
}

/// A real, textual disagreement between two sources. Never inferred from tone
/// or emphasis: only from negation, numbers, direction or scope.
public struct Disagreement: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case negationConflict
        case numericConflict
        case directionConflict
        case scopeConflict
    }

    public var kind: Kind
    public var first: StableID
    public var second: StableID
    public var explanation: String
    public var provenance: Provenance

    public init(kind: Kind, first: StableID, second: StableID, explanation: String, provenance: Provenance) {
        self.kind = kind
        self.first = first
        self.second = second
        self.explanation = explanation
        self.provenance = provenance
    }
}

/// What one document adds that the others do not.
public struct SourceContribution: Codable, Equatable, Sendable {
    public var documentID: String
    public var lines: [GroundedLine]

    public init(documentID: String, lines: [GroundedLine]) {
        self.documentID = documentID
        self.lines = lines
    }
}

/// A refinement: the same claim stated with an extra condition or qualifier.
public struct Refinement: Codable, Equatable, Sendable {
    public var broader: StableID
    public var narrower: StableID
    public var addedConditions: [ClaimCondition]
    public var addedQualifiers: [Qualifier]
    public var provenance: Provenance

    public init(broader: StableID,
                narrower: StableID,
                addedConditions: [ClaimCondition],
                addedQualifiers: [Qualifier],
                provenance: Provenance) {
        self.broader = broader
        self.narrower = narrower
        self.addedConditions = addedConditions
        self.addedQualifiers = addedQualifiers
        self.provenance = provenance
    }
}

/// The plan is separated from the rendering on purpose: the plan is what the
/// engine decided, the rendering is one possible surface for it.
public struct SynthesisPlan: Codable, Equatable, Sendable {
    public var concept: String
    public var commonThread: [ClaimCluster]
    public var contributions: [SourceContribution]
    public var refinements: [Refinement]
    public var disagreements: [Disagreement]
    public var examples: [GroundedLine]
    public var openQuestions: [String]

    public init(concept: String,
                commonThread: [ClaimCluster],
                contributions: [SourceContribution],
                refinements: [Refinement],
                disagreements: [Disagreement],
                examples: [GroundedLine],
                openQuestions: [String]) {
        self.concept = concept
        self.commonThread = commonThread
        self.contributions = contributions
        self.refinements = refinements
        self.disagreements = disagreements
        self.examples = examples
        self.openQuestions = openQuestions
    }
}

/// The rendered synthesis: a list of sections, each of which is a list of
/// grounded lines. There is no free-text field anywhere in this structure.
public struct GroundedSynthesis: Codable, Equatable, Sendable {
    public struct Section: Codable, Equatable, Sendable {
        public var title: String
        public var lines: [GroundedLine]

        public init(title: String, lines: [GroundedLine]) {
            self.title = title
            self.lines = lines
        }
    }

    public var concept: String
    public var sections: [Section]
    /// Unresolved questions are not admitted statements or model inferences.
    public var openQuestions: [String]

    public init(concept: String, sections: [Section], openQuestions: [String] = []) {
        self.concept = concept
        self.sections = sections
        self.openQuestions = openQuestions
    }

    public var allLines: [GroundedLine] { sections.flatMap(\.lines) }
}

/// Plans and renders "what do my documents collectively say about X".
public struct MultiSourceSynthesizer: Sendable {
    public var equivalenceThreshold: Double

    public init(equivalenceThreshold: Double = 0.6) {
        self.equivalenceThreshold = equivalenceThreshold
    }

    public struct Comparison: Codable, Sendable {
        public enum Kind: String, Codable, Sendable {
            case sameIdea, refinement, differentCondition, disagreement, definitionContext, relatedDistinctClaims, unresolved
        }
        public var first: KnowledgeAtom
        public var second: KnowledgeAtom
        public var kind: Kind
        public var statements: [GroundedLine]
        public var bridge: KnowledgeRelation?
        public var openQuestions: [String]
    }

    public func compare(_ first: KnowledgeAtom, _ second: KnowledgeAtom, in index: CertifiedReasoningIndex) -> Comparison {
        let bridge = index.crossDocument.first { Set($0.supportingAtoms) == Set([first.id, second.id]) }
        let clusters = [ClaimCluster(representative: first, members: [first.id], documentIDs: [first.sourceDocumentID ?? ""]),
                        ClaimCluster(representative: second, members: [second.id], documentIDs: [second.sourceDocumentID ?? ""])]
        let kind: Comparison.Kind
        if equivalent(first, second) { kind = .sameIdea }
        else if !detectDisagreements(in: clusters).isEmpty { kind = .disagreement }
        else if sameCore(first, second) {
            kind = !detectRefinements(in: clusters).isEmpty ? .refinement : .differentCondition
        } else if bridge != nil { kind = .definitionContext }
        else if SemanticIdentity.phrase(first.subject) == SemanticIdentity.phrase(second.subject) { kind = .relatedDistinctClaims }
        else { kind = .unresolved }
        return Comparison(first: first, second: second, kind: kind,
                          statements: [GroundedLine.fromAtom(first), GroundedLine.fromAtom(second)], bridge: bridge,
                          openQuestions: kind == .unresolved ? ["These sources do not establish equivalence, contradiction or a bridge between the claims."] : [])
    }

    public func plan(concept: String, in graph: KnowledgeGraph) -> SynthesisPlan {
        let compressor = ConceptCompressor()
        let atoms = compressor.relevantAtoms(for: concept, in: graph)
        guard !atoms.isEmpty else {
            return SynthesisPlan(concept: concept,
                                 commonThread: [],
                                 contributions: [],
                                 refinements: [],
                                 disagreements: [],
                                 examples: [],
                                 openQuestions: ["No source in your library discusses \"\(concept)\"."])
        }

        let clusters = cluster(atoms)
        let shared = clusters.filter(\.isShared)
        let unique = clusters.filter { !$0.isShared }

        var contributions: [String: [GroundedLine]] = [:]
        for cluster in unique {
            guard let document = cluster.documentIDs.first else { continue }
            guard cluster.representative.claimType != .example else { continue }
            contributions[document, default: []].append(GroundedLine.fromAtom(cluster.representative))
        }

        let examples = atoms.filter { $0.claimType == .example || $0.sourceRole == .example }
            .prefix(3)
            .map { GroundedLine.fromAtom($0) }

        let refinements = detectRefinements(in: clusters)
        let disagreements = detectDisagreements(in: clusters)

        var openQuestions: [String] = []
        if shared.isEmpty && clusters.count > 1 {
            openQuestions.append("Your sources talk about \"\(concept)\" without overlapping on any single claim.")
        }
        if examples.isEmpty {
            openQuestions.append("No source gives a concrete example of \"\(concept)\".")
        }

        return SynthesisPlan(concept: concept,
                             commonThread: shared,
                             contributions: contributions.keys.sorted().map {
                                 SourceContribution(documentID: $0, lines: contributions[$0] ?? [])
                             },
                             refinements: refinements,
                             disagreements: disagreements,
                             examples: Array(examples),
                             openQuestions: openQuestions)
    }

    public func render(_ plan: SynthesisPlan) -> GroundedSynthesis {
        var sections: [GroundedSynthesis.Section] = []

        if !plan.commonThread.isEmpty {
            sections.append(.init(title: "COMMON THREAD",
                                  lines: plan.commonThread.map { cluster in
                                      GroundedLine(text: cluster.representative.statement,
                                                   atomIDs: cluster.members,
                                                   admissibility: .sourceSupported,
                                                   provenance: cluster.representative.provenance)
                                  }))
        }
        for contribution in plan.contributions where !contribution.lines.isEmpty {
            sections.append(.init(title: "\(contribution.documentID.uppercased()) ADDS", lines: contribution.lines))
        }
        if !plan.refinements.isEmpty {
            sections.append(.init(title: "WHERE ONE SOURCE IS MORE PRECISE",
                                  lines: plan.refinements.map { refinement in
                                      let conditions = refinement.addedConditions.map(\.text).joined(separator: ", ")
                                      let qualifiers = refinement.addedQualifiers.map(\.text).joined(separator: ", ")
                                      let added = [conditions, qualifiers].filter { !$0.isEmpty }.joined(separator: "; ")
                                      return GroundedLine(text: "The same claim is stated with an added restriction: \(added).",
                                                          atomIDs: [refinement.broader, refinement.narrower],
                                                          admissibility: .inferredValidated,
                                                          provenance: refinement.provenance)
                                  }))
        }
        // Only present when a real conflict exists: contrast is never manufactured.
        if !plan.disagreements.isEmpty {
            sections.append(.init(title: "WHERE THEY DIFFER",
                                  lines: plan.disagreements.map { disagreement in
                                      GroundedLine(text: disagreement.explanation,
                                                   atomIDs: [disagreement.first, disagreement.second],
                                                   admissibility: .inferredValidated,
                                                   provenance: disagreement.provenance)
                                  }))
        }
        if !plan.examples.isEmpty {
            sections.append(.init(title: "EXAMPLES", lines: plan.examples))
        }
        return GroundedSynthesis(concept: plan.concept, sections: sections, openQuestions: plan.openQuestions)
    }

    // MARK: - Clustering

    func cluster(_ atoms: [KnowledgeAtom]) -> [ClaimCluster] {
        var clusters: [(representative: KnowledgeAtom, members: [KnowledgeAtom])] = []
        for atom in atoms.sorted(by: { $0.id.rawValue < $1.id.rawValue }) {
            if let index = clusters.firstIndex(where: { equivalent($0.representative, atom) }) {
                clusters[index].members.append(atom)
                // The representative is the one with the most structure kept.
                if structureScore(atom) > structureScore(clusters[index].representative) {
                    clusters[index].representative = atom
                }
            } else {
                clusters.append((atom, [atom]))
            }
        }
        return clusters.map { entry in
            var documents: [String] = []
            for member in entry.members {
                if let document = member.sourceDocumentID, !documents.contains(document) { documents.append(document) }
            }
            return ClaimCluster(representative: entry.representative,
                                members: entry.members.map(\.id),
                                documentIDs: documents.sorted())
        }
    }

    /// Two claims are equivalent when they assert the same relation between the
    /// same things, with the same polarity. Wording may differ freely.
    func equivalent(_ lhs: KnowledgeAtom, _ rhs: KnowledgeAtom) -> Bool {
        guard lhs.isNegated == rhs.isNegated else { return false }
        guard lhs.relation == rhs.relation, lhs.conditions == rhs.conditions,
              lhs.qualifiers == rhs.qualifiers, lhs.numbers == rhs.numbers, lhs.identifiers == rhs.identifiers else { return false }
        return SemanticIdentity.phrase(lhs.subject) == SemanticIdentity.phrase(rhs.subject)
            && SemanticIdentity.phrase(lhs.object) == SemanticIdentity.phrase(rhs.object)
    }

    func structureScore(_ atom: KnowledgeAtom) -> Int {
        atom.conditions.count * 2 + atom.qualifiers.count + atom.numbers.count + atom.identifiers.count
    }

    // MARK: - Refinement and disagreement

    func detectRefinements(in clusters: [ClaimCluster]) -> [Refinement] {
        var refinements: [Refinement] = []
        for (index, cluster) in clusters.enumerated() {
            for other in clusters.dropFirst(index + 1) {
                guard equivalent(cluster.representative, other.representative) == false else { continue }
                guard sameCore(cluster.representative, other.representative) else { continue }
                let lhs = cluster.representative, rhs = other.representative
                let lhsRestrictions = lhs.conditions.count + lhs.qualifiers.filter { $0.kind == .scope }.count
                let rhsRestrictions = rhs.conditions.count + rhs.qualifiers.filter { $0.kind == .scope }.count
                guard lhsRestrictions != rhsRestrictions else { continue }
                let broader = lhsRestrictions < rhsRestrictions ? lhs : rhs
                let narrower = lhsRestrictions < rhsRestrictions ? rhs : lhs
                let addedConditions = narrower.conditions.filter { condition in
                    !broader.conditions.contains(condition)
                }
                let addedQualifiers = narrower.qualifiers.filter { qualifier in
                    qualifier.kind == .scope && !broader.qualifiers.contains(qualifier)
                }
                guard !addedConditions.isEmpty || !addedQualifiers.isEmpty else { continue }
                refinements.append(Refinement(broader: broader.id,
                                              narrower: narrower.id,
                                              addedConditions: addedConditions,
                                              addedQualifiers: addedQualifiers,
                                              provenance: Provenance.inferred(from: [broader.provenance, narrower.provenance],
                                                                              ids: [broader.id, narrower.id],
                                                                              rule: .sharedSubjectRefinement)))
            }
        }
        return refinements
    }

    /// Same subject and object, ignoring restrictions.
    func sameCore(_ lhs: KnowledgeAtom, _ rhs: KnowledgeAtom) -> Bool {
        lhs.relation == rhs.relation
            && lhs.isNegated == rhs.isNegated
            && SemanticIdentity.phrase(lhs.subject) == SemanticIdentity.phrase(rhs.subject)
            && SemanticIdentity.phrase(lhs.object) == SemanticIdentity.phrase(rhs.object)
            && lhs.numbers == rhs.numbers && lhs.identifiers == rhs.identifiers
    }

    func detectDisagreements(in clusters: [ClaimCluster]) -> [Disagreement] {
        var disagreements: [Disagreement] = []
        let atoms = clusters.map(\.representative)
        for (index, lhs) in atoms.enumerated() {
            for rhs in atoms.dropFirst(index + 1) {
                guard lhs.sourceDocumentID != rhs.sourceDocumentID else { continue }
                guard (lhs.conditions == rhs.conditions || lhs.conditions.isEmpty || rhs.conditions.isEmpty),
                      lhs.qualifiers == rhs.qualifiers else { continue }
                let sameSubject = SemanticIdentity.phrase(lhs.subject) == SemanticIdentity.phrase(rhs.subject)
                let sameObject = SemanticIdentity.phrase(lhs.object) == SemanticIdentity.phrase(rhs.object)
                let provenance = Provenance.inferred(from: [lhs.provenance, rhs.provenance],
                                                     ids: [lhs.id, rhs.id],
                                                     rule: .crossSourceEquivalence)

                if sameSubject, sameObject, lhs.isNegated != rhs.isNegated {
                    let negative = lhs.isNegated ? lhs : rhs
                    let positive = lhs.isNegated ? rhs : lhs
                    disagreements.append(Disagreement(kind: .negationConflict,
                                                      first: positive.id,
                                                      second: negative.id,
                                                      explanation: "\(positive.sourceDocumentID ?? "one source") states \"\(positive.statement)\", while \(negative.sourceDocumentID ?? "another") states it does not.",
                                                      provenance: provenance))
                    continue
                }
                if sameSubject, sameObject, opposed(lhs.relation, rhs.relation) {
                    disagreements.append(Disagreement(kind: .directionConflict,
                                                      first: lhs.id,
                                                      second: rhs.id,
                                                      explanation: "\(lhs.sourceDocumentID ?? "one source") says \(lhs.subject) \(lhs.relation) \(lhs.object); \(rhs.sourceDocumentID ?? "another") says it \(rhs.relation) it.",
                                                      provenance: provenance))
                    continue
                }
                if sameSubject, lhs.relation == rhs.relation, let conflict = numericConflict(lhs, rhs) {
                    disagreements.append(Disagreement(kind: .numericConflict,
                                                      first: lhs.id,
                                                      second: rhs.id,
                                                      explanation: conflict,
                                                      provenance: provenance))
                }
            }
        }
        return disagreements
    }

    func opposed(_ lhs: String, _ rhs: String) -> Bool {
        let pairs: [Set<String>] = [
            [RelationKind.enables.rawValue, RelationKind.prevents.rawValue],
            [RelationKind.causes.rawValue, RelationKind.prevents.rawValue]
        ]
        return pairs.contains(Set([lhs, rhs])) && lhs != rhs
    }

    func numericConflict(_ lhs: KnowledgeAtom, _ rhs: KnowledgeAtom) -> String? {
        func shape(_ atom: KnowledgeAtom) -> String {
            var text = atom.object
            for n in atom.numbers { text = text.replacingOccurrences(of: n.rawText, with: "NUMBER") }
            for marker in ["at most ", "at least ", "exactly "] { text = text.replacingOccurrences(of: marker, with: "") }
            return SemanticIdentity.phrase(text)
        }
        guard shape(lhs) == shape(rhs) else { return nil }
        func bounds(_ n: NumericFact) -> (Double, Double)? {
            switch n.comparator {
            case .exactly: return (n.value, n.value)
            case .atLeast: return (n.value, .infinity)
            case .atMost: return (-.infinity, n.value)
            case .range: return n.upperValue.map { (n.value, $0) }
            case .approximately: return nil
            }
        }
        for left in lhs.numbers {
            for right in rhs.numbers where left.unit == right.unit {
                if let a = bounds(left), let b = bounds(right), a.1 < b.0 || b.1 < a.0 {
                    return "\(lhs.sourceDocumentID ?? "one source") gives \(left.rawText)\(left.unit.map { " \($0)" } ?? ""), \(rhs.sourceDocumentID ?? "another") gives \(right.rawText)\(right.unit.map { " \($0)" } ?? "")."
                }
            }
        }
        return nil
    }
}
