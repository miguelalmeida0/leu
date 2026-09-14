import Foundation

/// How one learner proposition stands against the sources.
public enum AlignmentVerdict: String, Codable, CaseIterable, Sendable {
    case supported
    case partiallySupported
    case contradicted
    case notAddressed
    case ambiguous
}

public struct PropositionAlignment: Codable, Equatable, Sendable {
    public var proposition: LearnerProposition
    public var verdict: AlignmentVerdict
    public var matchedAtomID: StableID?
    public var matchScore: Double
    public var findings: [MisconceptionFinding]
    /// The single line Leu should say about this proposition.
    public var feedback: GroundedLine?

    public init(proposition: LearnerProposition,
                verdict: AlignmentVerdict,
                matchedAtomID: StableID?,
                matchScore: Double,
                findings: [MisconceptionFinding],
                feedback: GroundedLine?) {
        self.proposition = proposition
        self.verdict = verdict
        self.matchedAtomID = matchedAtomID
        self.matchScore = matchScore
        self.findings = findings
        self.feedback = feedback
    }
}

public struct ExplanationAlignmentReport: Codable, Equatable, Sendable {
    public var alignments: [PropositionAlignment]
    /// Source claims about the concept that the learner never touched.
    public var unaddressedAtomIDs: [StableID]
    public var concept: String?

    public init(alignments: [PropositionAlignment], unaddressedAtomIDs: [StableID], concept: String?) {
        self.alignments = alignments
        self.unaddressedAtomIDs = unaddressedAtomIDs
        self.concept = concept
    }

    public var verdict: AlignmentVerdict {
        if alignments.contains(where: { $0.verdict == .contradicted }) { return .contradicted }
        if alignments.contains(where: { $0.verdict == .partiallySupported }) { return .partiallySupported }
        if alignments.isEmpty { return .notAddressed }
        if alignments.allSatisfy({ $0.verdict == .supported }) { return .supported }
        if alignments.contains(where: { $0.verdict == .ambiguous }) { return .ambiguous }
        return .partiallySupported
    }

    public var findings: [MisconceptionFinding] { alignments.flatMap(\.findings) }

    /// Fraction of the learner's own claims that the sources back.
    public var supportedShare: Double {
        guard !alignments.isEmpty else { return 0 }
        let supported = alignments.filter { $0.verdict == .supported }.count
        return Double(supported) / Double(alignments.count)
    }
}

/// Compares a learner explanation against the grounded knowledge model.
///
/// The comparison is structural, not lexical: a different wording of the same
/// claim is accepted, while the same wording with a dropped condition is not.
public struct ExplanationAligner: Sendable {
    public var matchFloor: Double
    public var supportCeiling: Double

    public init(matchFloor: Double = 0.30, supportCeiling: Double = 0.58) {
        self.matchFloor = matchFloor
        self.supportCeiling = supportCeiling
    }

    public func align(explanation: String,
                      concept: String?,
                      in graph: KnowledgeGraph) -> ExplanationAlignmentReport {
        let propositions = PropositionSplitter().split(explanation)
        let candidateAtoms: [KnowledgeAtom]
        if let concept {
            let relevant = ConceptCompressor().relevantAtoms(for: concept, in: graph)
            candidateAtoms = relevant.isEmpty ? graph.atoms : relevant
        } else {
            candidateAtoms = graph.atoms
        }

        var alignments: [PropositionAlignment] = []
        var touched: Set<String> = []
        for proposition in propositions {
            let alignment = align(proposition: proposition, against: candidateAtoms, in: graph)
            if let matched = alignment.matchedAtomID { touched.insert(matched.rawValue) }
            alignments.append(alignment)
        }
        let unaddressed = candidateAtoms
            .filter { !touched.contains($0.id.rawValue) && $0.carriesMechanism }
            .map(\.id)
        return ExplanationAlignmentReport(alignments: alignments,
                                          unaddressedAtomIDs: unaddressed,
                                          concept: concept)
    }

    // MARK: - One proposition

    public func align(proposition: LearnerProposition,
                      against atoms: [KnowledgeAtom],
                      in graph: KnowledgeGraph) -> PropositionAlignment {
        let scored = atoms.map { (atom: $0, score: score(proposition, against: $0)) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.atom.id.rawValue < rhs.atom.id.rawValue
            }
        guard let best = scored.first, best.score >= matchFloor else {
            return PropositionAlignment(proposition: proposition,
                                        verdict: .notAddressed,
                                        matchedAtomID: nil,
                                        matchScore: scored.first?.score ?? 0,
                                        findings: [],
                                        feedback: nil)
        }

        var findings: [MisconceptionFinding] = []
        let atom = best.atom

        // Conflation: two unrelated claims match equally well.
        if let runnerUp = scored.dropFirst().first,
           abs(runnerUp.score - best.score) < 0.05,
           TextScanning.overlap(runnerUp.atom.subject, atom.subject) < 0.4 {
            findings.append(finding(.conflatedConcepts,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: "matches both \"\(atom.subject)\" and \"\(runnerUp.atom.subject)\"",
                                    feedback: "Your sources treat \"\(atom.subject)\" and \"\(runnerUp.atom.subject)\" as separate ideas — which one do you mean?"))
        }

        if isReversed(proposition, atom) {
            findings.append(finding(.reversedCauseEffect,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: "learner has \(proposition.subject) → \(proposition.object); source has \(atom.subject) → \(atom.object)",
                                    feedback: "Your source runs the other way: \(atom.subject) \(atom.relation) \(atom.object), not the reverse."))
        } else if !proposition.isUnparsed, proposition.isNegated != atom.isNegated {
            findings.append(finding(.incorrectNegation,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: "polarity differs from the source",
                                    feedback: atom.isNegated
                                        ? "Your source states the opposite: \(atom.statement)."
                                        : "Your source does state this: \(atom.statement)."))
        } else if !proposition.isUnparsed,
                  let propositionKind = RelationKind(rawValue: proposition.relation),
                  let atomKind = RelationKind(rawValue: atom.relation),
                  family(propositionKind) != family(atomKind) {
            findings.append(finding(.wrongDependency,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: "learner says \(proposition.relation), source says \(atom.relation)",
                                    feedback: "Your source states a different link: \(atom.subject) \(atom.relation) \(atom.object)."))
        }

        if let mismatch = numericMismatch(proposition, atom) {
            findings.append(finding(.numericalMismatch,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: mismatch,
                                    feedback: "Your source gives a different number: \(mismatch)."))
        }
        if let identifier = identifierMismatch(proposition, atoms: atoms) {
            findings.append(finding(.identifierMismatch,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: "\(identifier) does not appear in your sources for this idea",
                                    feedback: "No source in your library mentions \(identifier) here."))
        }

        // Over- and under-generalisation.
        let restricting = restrictions(of: atom)
        if proposition.quantifier == .universal, !restricting.isEmpty {
            findings.append(finding(.scopeTooBroad,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: "learner states it universally; source restricts it to \(restricting.joined(separator: ", "))",
                                    feedback: "Careful — your source does not state this for every case: it holds \(restricting.joined(separator: ", "))."))
        } else if let missing = missingCondition(proposition, atom) {
            findings.append(finding(.missingCondition,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: missing,
                                    feedback: "Almost — your explanation is missing the condition that \(missing)."))
        }
        if let narrow = extraCondition(proposition, atom) {
            findings.append(finding(.scopeTooNarrow,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: narrow,
                                    feedback: "Your source is broader than that: it does not limit the claim to \(narrow)."))
        }
        if let addition = unsupportedAddition(proposition, atoms: atoms) {
            findings.append(finding(.unsupportedAddition,
                                    proposition: proposition,
                                    atom: atom,
                                    detail: addition,
                                    feedback: "Nothing in your sources says \(addition) — where did that come from?"))
        }

        let verdict = resolve(findings: findings, score: best.score)
        let feedback = findings.first.map { finding in
            GroundedLine(text: finding.feedback,
                         atomIDs: [atom.id],
                         admissibility: .inferredValidated,
                         provenance: finding.provenance)
        } ?? (verdict == .supported
              ? GroundedLine(text: "That matches your source: \(atom.statement).",
                             atomIDs: [atom.id],
                             admissibility: .sourceSupported,
                             provenance: atom.provenance)
              : nil)

        return PropositionAlignment(proposition: proposition,
                                    verdict: verdict,
                                    matchedAtomID: atom.id,
                                    matchScore: best.score,
                                    findings: findings,
                                    feedback: feedback)
    }

    // MARK: - Scoring and checks

    func score(_ proposition: LearnerProposition, against atom: KnowledgeAtom) -> Double {
        if proposition.isUnparsed {
            let combined = "\(atom.subject) \(atom.object)"
            return 0.85 * TextScanning.overlap(proposition.text, combined)
        }
        let subject = TextScanning.overlap(proposition.subject, atom.subject)
        let object = TextScanning.overlap(proposition.object, atom.object)
        var score = 0.55 * subject + 0.45 * object
        if let propositionKind = RelationKind(rawValue: proposition.relation),
           let atomKind = RelationKind(rawValue: atom.relation),
           family(propositionKind) == family(atomKind) {
            score += 0.08
        }
        // Reversed statements must still match their atom so the reversal can
        // be reported rather than silently missed.
        let reversed = 0.55 * TextScanning.overlap(proposition.subject, atom.object)
            + 0.45 * TextScanning.overlap(proposition.object, atom.subject)
        return min(1.0, max(score, reversed * 0.95))
    }

    enum RelationFamily: String {
        case enablement, causation, prevention, dependency, definition, contrast, instantiation, other
    }

    func family(_ kind: RelationKind) -> RelationFamily {
        switch kind {
        case .enables, .supports: return .enablement
        case .causes, .consequenceOf, .failureOf: return .causation
        case .prevents: return .prevention
        case .requires, .prerequisiteOf: return .dependency
        case .explains, .refines, .qualifies, .scopes: return .definition
        case .contrastsWith: return .contrast
        case .exampleOf, .implementationOf, .samePrincipleAs: return .instantiation
        }
    }

    func isReversed(_ proposition: LearnerProposition, _ atom: KnowledgeAtom) -> Bool {
        guard !proposition.isUnparsed else { return false }
        guard let kind = RelationKind(rawValue: proposition.relation),
              let atomKind = RelationKind(rawValue: atom.relation),
              family(kind) == family(atomKind),
              [RelationFamily.causation, .enablement, .dependency].contains(family(atomKind)) else { return false }
        let forward = min(TextScanning.overlap(proposition.subject, atom.subject),
                          TextScanning.overlap(proposition.object, atom.object))
        let backward = min(TextScanning.overlap(proposition.subject, atom.object),
                           TextScanning.overlap(proposition.object, atom.subject))
        return backward >= 0.6 && backward > forward + 0.2
    }

    /// Everything the source uses to narrow the claim.
    func restrictions(of atom: KnowledgeAtom) -> [String] {
        var values = atom.conditions.map { $0.isPositive ? "when \($0.text)" : "unless \($0.text)" }
        values.append(contentsOf: atom.qualifiers.filter { $0.kind == .scope }.map { "for \($0.text)" })
        values.append(contentsOf: atom.qualifiers.filter { $0.kind == .frequency && $0.text != "always" }.map { "\($0.text)" })
        return values
    }

    func missingCondition(_ proposition: LearnerProposition, _ atom: KnowledgeAtom) -> String? {
        for condition in atom.conditions {
            let covered = TextScanning.coverage(of: condition.text, in: proposition.text) >= 0.5
                || proposition.conditions.contains { TextScanning.overlap($0.text, condition.text) >= 0.5 }
            if !covered { return condition.text }
        }
        for qualifier in atom.qualifiers where qualifier.kind == .scope {
            if TextScanning.coverage(of: qualifier.text, in: proposition.text) < 0.5 {
                return "this applies \(qualifier.text)"
            }
        }
        return nil
    }

    func extraCondition(_ proposition: LearnerProposition, _ atom: KnowledgeAtom) -> String? {
        for condition in proposition.conditions {
            let matched = atom.conditions.contains { TextScanning.overlap($0.text, condition.text) >= 0.5 }
            if !matched { return condition.text }
        }
        return nil
    }

    func numericMismatch(_ proposition: LearnerProposition, _ atom: KnowledgeAtom) -> String? {
        guard !proposition.numbers.isEmpty, !atom.numbers.isEmpty else { return nil }
        for learnerNumber in proposition.numbers {
            let matched = atom.numbers.contains { $0.value == learnerNumber.value && $0.comparator == learnerNumber.comparator }
            if !matched, let sourceNumber = atom.numbers.first {
                return "you said \(learnerNumber.rawText), your source says \(sourceNumber.rawText)"
            }
        }
        return nil
    }

    func identifierMismatch(_ proposition: LearnerProposition, atoms: [KnowledgeAtom]) -> String? {
        let known = Set(atoms.flatMap { $0.identifiers.map { $0.text.lowercased() } })
        for identifier in proposition.identifiers where identifier.kind != .other {
            if !known.contains(identifier.text.lowercased()), !known.isEmpty {
                return identifier.text
            }
        }
        return nil
    }

    func unsupportedAddition(_ proposition: LearnerProposition, atoms: [KnowledgeAtom]) -> String? {
        guard !proposition.isUnparsed, !proposition.object.isEmpty else { return nil }
        let corpus = atoms.map { "\($0.subject) \($0.relation) \($0.object)" }.joined(separator: " ")
        let coverage = TextScanning.coverage(of: proposition.object, in: corpus)
        guard coverage < 0.34 else { return nil }
        return "\"\(proposition.object)\""
    }

    func resolve(findings: [MisconceptionFinding], score: Double) -> AlignmentVerdict {
        if findings.contains(where: { $0.type.isContradiction }) { return .contradicted }
        if findings.contains(where: { $0.type == .conflatedConcepts }) { return .ambiguous }
        if !findings.isEmpty { return .partiallySupported }
        return score >= supportCeiling ? .supported : .ambiguous
    }

    func finding(_ type: MisconceptionType,
                 proposition: LearnerProposition,
                 atom: KnowledgeAtom,
                 detail: String,
                 feedback: String) -> MisconceptionFinding {
        MisconceptionFinding(type: type,
                             propositionID: proposition.id,
                             atomID: atom.id,
                             detail: detail,
                             feedback: feedback,
                             provenance: Provenance.inferred(from: [atom.provenance],
                                                             ids: [atom.id],
                                                             rule: .conditionPropagation))
    }
}
