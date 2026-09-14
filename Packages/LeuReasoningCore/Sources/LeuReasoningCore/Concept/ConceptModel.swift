import Foundation

/// A single rendered line that can always be traced back to sources.
/// Every user-visible sentence the engine produces is one of these; there is no
/// path from the engine to the screen that bypasses provenance.
public struct GroundedLine: Codable, Equatable, Sendable {
    public var text: String
    public var atomIDs: [StableID]
    public var admissibility: Admissibility
    public var provenance: Provenance

    public init(text: String,
                atomIDs: [StableID],
                admissibility: Admissibility,
                provenance: Provenance) {
        self.text = text
        self.atomIDs = atomIDs
        self.admissibility = admissibility
        self.provenance = provenance
    }

    public static func fromAtom(_ atom: KnowledgeAtom, text: String? = nil) -> GroundedLine {
        GroundedLine(text: text ?? atom.statement,
                     atomIDs: [atom.id],
                     admissibility: .sourceSupported,
                     provenance: atom.provenance)
    }
}

/// A concept understood at five levels of compression, each level grounded.
public struct ConceptModel: Codable, Equatable, Sendable {
    public var concept: String
    /// Level 1 — one sentence.
    public var oneSentence: GroundedLine?
    /// Level 2 — the mental model: what to picture.
    public var mentalModel: [GroundedLine]
    /// Level 3 — the mechanism: how it actually works, step by step.
    public var mechanism: [GroundedLine]
    /// Level 4 — where it bites: trade-offs and failure modes.
    public var tradeOffsAndFailures: [GroundedLine]
    /// Level 5 — connected ideas, including other documents.
    public var connectedIdeas: [GroundedLine]
    /// Levels the sources cannot fill. Named, never faked.
    public var gaps: [String]

    public init(concept: String,
                oneSentence: GroundedLine?,
                mentalModel: [GroundedLine],
                mechanism: [GroundedLine],
                tradeOffsAndFailures: [GroundedLine],
                connectedIdeas: [GroundedLine],
                gaps: [String]) {
        self.concept = concept
        self.oneSentence = oneSentence
        self.mentalModel = mentalModel
        self.mechanism = mechanism
        self.tradeOffsAndFailures = tradeOffsAndFailures
        self.connectedIdeas = connectedIdeas
        self.gaps = gaps
    }

    public var allLines: [GroundedLine] {
        var lines: [GroundedLine] = []
        if let oneSentence { lines.append(oneSentence) }
        lines.append(contentsOf: mentalModel)
        lines.append(contentsOf: mechanism)
        lines.append(contentsOf: tradeOffsAndFailures)
        lines.append(contentsOf: connectedIdeas)
        return lines
    }

    /// The level a learner should be shown next, given what they have seen.
    public func nextLevel(after seen: Int) -> Int? {
        let filled = [oneSentence != nil,
                      !mentalModel.isEmpty,
                      !mechanism.isEmpty,
                      !tradeOffsAndFailures.isEmpty,
                      !connectedIdeas.isEmpty]
        guard seen < 5 else { return nil }
        for level in (max(seen, 0) + 1)...5 where filled[level - 1] { return level }
        return nil
    }
}

/// Compresses a concept out of the graph at five levels.
///
/// Compression is selection, not generation: each level picks the atoms that
/// best serve that level and renders them with fixed templates. Nothing is
/// paraphrased into existence.
public struct ConceptCompressor: Sendable {
    public init() {}

    public func compress(concept: String, in graph: KnowledgeGraph) -> ConceptModel {
        let atoms = relevantAtoms(for: concept, in: graph)
        guard !atoms.isEmpty else {
            return ConceptModel(concept: concept,
                                oneSentence: nil,
                                mentalModel: [],
                                mechanism: [],
                                tradeOffsAndFailures: [],
                                connectedIdeas: [],
                                gaps: ["No source in this library defines or explains \"\(concept)\"."])
        }

        var gaps: [String] = []

        // Level 1 — the shortest definitional claim from the most factual role.
        let definitionCandidates = atoms.filter { $0.claimType == .definition && !$0.isNegated }
            .sorted { lhs, rhs in
                let lw = lhs.sourceRole.mechanismWeight, rw = rhs.sourceRole.mechanismWeight
                if lw != rw { return lw > rw }
                let ll = TextScanning.words(lhs.object).count, rl = TextScanning.words(rhs.object).count
                if ll != rl { return ll < rl }
                return lhs.id.rawValue < rhs.id.rawValue
            }
        let oneSentence = definitionCandidates.first.map { GroundedLine.fromAtom($0) }
        if oneSentence == nil { gaps.append("No source gives a one-sentence definition of \"\(concept)\".") }

        // Level 2 — the mental model: what it is plus what it buys you.
        var mentalModel: [GroundedLine] = []
        for atom in atoms.filter({ $0.claimType == .mechanism && $0.relation == RelationKind.enables.rawValue }).prefix(2) {
            mentalModel.append(GroundedLine.fromAtom(atom, text: "Picture it as: \(atom.subject) gives you \(atom.object)."))
        }
        if mentalModel.isEmpty, let definition = definitionCandidates.dropFirst().first {
            mentalModel.append(GroundedLine.fromAtom(definition))
        }
        if mentalModel.isEmpty { gaps.append("No source states what \"\(concept)\" is for, only what it is.") }

        // Level 3 — the mechanism: sequences and grounded causal chains.
        var mechanism: [GroundedLine] = []
        for atom in atoms.filter({ $0.claimType == .sequence }).prefix(3) {
            mechanism.append(GroundedLine.fromAtom(atom))
        }
        let chainEngine = CausalChainEngine()
        for atom in atoms.prefix(4) {
            for chain in chainEngine.chains(from: atom.subject, in: graph).prefix(1) where chain.length >= 3 {
                mechanism.append(GroundedLine(text: chain.rendered,
                                              atomIDs: chain.links.compactMap(\.viaRelation),
                                              admissibility: chain.admissibility,
                                              provenance: chain.provenance))
            }
        }
        if mechanism.isEmpty { gaps.append("No source walks through how \"\(concept)\" works step by step.") }

        // Level 4 — trade-offs and failure modes.
        var tradeOffs: [GroundedLine] = []
        for atom in atoms.filter({ $0.claimType == .tradeoff || $0.claimType == .failureMode || $0.claimType == .constraint }).prefix(4) {
            tradeOffs.append(GroundedLine.fromAtom(atom))
        }
        if tradeOffs.isEmpty { gaps.append("No source states a failure mode or trade-off for \"\(concept)\".") }

        // Level 5 — connected ideas, preferring other documents.
        var connected: [GroundedLine] = []
        let homeDocuments = Set(atoms.compactMap(\.sourceDocumentID))
        for relation in graph.relations where [.exampleOf, .samePrincipleAs, .implementationOf, .contrastsWith, .refines].contains(relation.kind) {
            guard let subject = graph.node(relation.subject.id), let object = graph.node(relation.object.id) else { continue }
            let touches = TextScanning.coverage(of: concept, in: subject.label) >= 0.5
                || TextScanning.coverage(of: concept, in: object.label) >= 0.5
            guard touches else { continue }
            let elsewhere = relation.provenance.spans.contains { !homeDocuments.contains($0.documentID) }
            connected.append(GroundedLine(text: "\(subject.label) \(readable(relation.kind)) \(object.label)\(elsewhere ? " (from another source in your library)" : "")",
                                          atomIDs: relation.supportingAtoms,
                                          admissibility: relation.provenance.admissibility,
                                          provenance: relation.provenance))
        }
        if connected.isEmpty { gaps.append("No other idea in your library is linked to \"\(concept)\" yet.") }

        return ConceptModel(concept: concept,
                            oneSentence: oneSentence,
                            mentalModel: mentalModel,
                            mechanism: Array(mechanism.prefix(4)),
                            tradeOffsAndFailures: tradeOffs,
                            connectedIdeas: Array(connected.prefix(5)),
                            gaps: gaps)
    }

    func readable(_ kind: RelationKind) -> String {
        switch kind {
        case .exampleOf: return "is an example of"
        case .samePrincipleAs: return "uses the same principle as"
        case .implementationOf: return "implements"
        case .contrastsWith: return "contrasts with"
        case .refines: return "refines"
        default: return kind.rawValue
        }
    }

    /// Atoms about a concept: exact concept-slug hits first, then phrase
    /// coverage, so "cache" finds "cache lookup" without matching "cash flow".
    func relevantAtoms(for concept: String, in graph: KnowledgeGraph) -> [KnowledgeAtom] {
        let slug = TextScanning.conceptSlug(concept)
        var result = graph.atoms(forConcept: slug)
        if result.count < 3 {
            let extra = graph.atoms.filter { atom in
                atom.concepts.contains(where: { TextScanning.overlap($0, slug) >= 0.5 })
                    || TextScanning.coverage(of: concept, in: atom.subject) >= 0.75
                    || TextScanning.coverage(of: concept, in: atom.object) >= 0.75
            }
            for atom in extra where !result.contains(atom) { result.append(atom) }
        }
        return result.sorted { $0.id.rawValue < $1.id.rawValue }
    }
}
