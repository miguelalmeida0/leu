import Foundation

/// The facts about one answer that the judge weighs, read from its diagnosis and signals.
struct JudgementReading {
    let diagnosis: UnderstandingDiagnosis
    let signals: DiagnosisSignals
    let target: DiagnosisTarget

    init(diagnosis: UnderstandingDiagnosis, signals: DiagnosisSignals, target: DiagnosisTarget) {
        self.diagnosis = diagnosis; self.signals = signals; self.target = target
    }

    /// Lexical evidence thresholds. A credited claim is *strong* when most of it is expressed with
    /// at least two distinctive words, *thin* when most of it is missing or one word carries it.
    /// Thin is the bottom of the diagnosis's own partial-credit band (recall 0.3 to 0.62).
    static let strongRecall = 0.62, fullRecall = 0.8, thinRecall = 0.4
    /// A rival concept that explains a real share of a clause (about two distinctive words'
    /// worth), more than the target does, in a clause the target explains poorly.
    static let rivalShare = 0.3, rivalWeight = 1.8, rivalMargin = 0.1, ownShare = 0.5

    var definitionID: String? { (target.rubric.first { $0.kind == .definition } ?? target.rubric.first)?.id }

    var nothingComparable: Bool {
        diagnosis.level == .insufficient || diagnosis.statements.allSatisfy { $0.verdict == .noise }
    }

    func operation(for claimID: String) -> ProbeOperation {
        target.allClaims.first { $0.id == claimID }.map(FollowUps.operation(for:)) ?? .define
    }

    private func signal(for text: String?, verdicts: Set<StatementVerdict>) -> ClauseSignal? {
        signals.clauses.first { $0.text == text && verdicts.contains($0.verdict) }
    }

    /// Wrong ideas the diagnosis states, with how clearly the answer states them.
    var misconceptions: [UnderstandingHypothesis] {
        diagnosis.issues.compactMap { issue -> UnderstandingHypothesis? in
            switch issue.kind {
            case .contradiction:
                let evidence = signal(for: issue.learnerText, verdicts: [.contradicts])
                let clear = evidence.map { $0.conflictOverlap >= 0.75 || $0.distinctive >= 2 || $0.recall >= Self.thinRecall } ?? true
                return UnderstandingHypothesis(.misconception, support: clear ? 0.85 : 0.5, cue: .contradiction, claimID: issue.claimID)
            case .causalReversal:
                return UnderstandingHypothesis(.misconception, support: 0.8, cue: .reversal, claimID: issue.claimID)
            case .confusedConcept:
                return UnderstandingHypothesis(.misconception, support: 0.8, cue: .confusion, claimID: nil, relatedConcept: issue.relatedConcept)
            case .overgeneralization:
                return UnderstandingHypothesis(.misconception, support: 0.7, cue: .overgeneralization, claimID: issue.claimID)
            default:
                return nil
            }
        }
    }

    /// Clauses another concept's wording explains clearly better than the target's, short of a
    /// confusion the diagnosis would state.
    var possibleConfusions: [UnderstandingHypothesis] {
        guard target.concept != nil, !diagnosis.has(.confusedConcept) else { return [] }
        return signals.clauses.compactMap { clause in
            guard let rival = clause.rival, ![.contradicts, .confuses, .reverses].contains(clause.verdict),
                  clause.rivalPrecision >= Self.rivalShare, clause.rivalMatched >= Self.rivalWeight,
                  clause.rivalPrecision >= clause.ownPrecision + Self.rivalMargin, clause.ownPrecision < Self.ownShare,
                  !(clause.verdict == .supports && clause.recall >= Self.strongRecall) else { return nil }
            return UnderstandingHypothesis(.misconception, support: 0.5, cue: .possibleConfusion, relatedConcept: rival)
        }
    }

    /// Negated claims whose content a clause restates without the negation.
    var omittedNegations: [UnderstandingHypothesis] {
        signals.clauses.compactMap { clause in
            guard clause.unexpressedNegation, let claim = clause.claimID, [.unsupported, .partiallySupports].contains(clause.verdict) else { return nil }
            return UnderstandingHypothesis(.misconception, support: 0.5, cue: .omittedNegation, claimID: claim)
        }
    }

    /// The learner's own words say they are unsure. Not proof of misunderstanding, but not
    /// something to record as understanding before one more answer.
    var selfDoubt: Bool {
        diagnosis.statements.contains { statement in
            let text = statement.learnerText.lowercased().replacingOccurrences(of: "’", with: "'")
            // A question mark ending a statement is doubt; one inside it ("after the ? in a URL") is syntax.
            return text.trimmingCharacters(in: .whitespaces).hasSuffix("?")
                || Self.doubt.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
    }
    /// Hedges about one's own understanding. After a determiner, "kind of" and "sort of" name a
    /// category ("a kind of rate limit", "what kind of result"), not a doubt.
    private static let doubt = try! NSRegularExpression(pattern: #"\b(?:not sure|i guess|maybe|something about|something to do with|somehow|"#
        + #"don't fully get|don't really know|no idea|not totally sure|i'm not certain)\b"#
        + #"|(?<!\b(?:a|an|the|that|this|these|those|what|which|one|some|any|every|each|no|same|other|another) )\b(?:kind|sort) of\b"#)

    /// Earlier misconceptions about a claim this answer neither restates strongly nor contradicts again.
    func lingering(_ prior: LearnerPrior) -> [UnderstandingHypothesis] {
        prior.misconceptions.compactMap { record in
            // Stated again, it is a misconception on this answer's own evidence; here it only lingers.
            // Only a claim this answer's evidence can speak to (an assessed core claim) can be papered
            // over; a supporting claim is never part of an answer's evidence, so it cannot.
            guard record.kind != .confusion, let claim = record.claimID, target.allClaims.contains(where: { $0.id == claim }),
                  diagnosis.assessment(claim) != nil,
                  !diagnosis.issues.contains(where: { $0.claimID == claim && [.contradiction, .causalReversal, .overgeneralization].contains($0.kind) })
            else { return nil }
            if strength(of: claim) == .strong, diagnosis.assessment(claim)?.coverage == .covered { return nil }
            return UnderstandingHypothesis(.misconception, support: 0.5, cue: .priorMisconception, claimID: claim)
        }
    }

    enum Strength { case strong, moderate, thin }

    /// How firmly the answer's wording carries a credited claim.
    func strength(of claimID: String) -> Strength {
        let carrying = signals.clauses.compactMap { $0.credited[claimID] }
        guard let best = carrying.max(by: { ($0.recall, $0.distinctive) < ($1.recall, $1.distinctive) }) else {
            // Credited only across clauses (whole-answer coverage).
            return diagnosis.assessment(claimID)?.coverage == .covered ? .moderate : .thin
        }
        let restated = signals.clauses.contains { $0.verdict == .restates && $0.claimID == claimID }
        if restated || best.recall >= Self.fullRecall || (best.recall >= Self.strongRecall && best.distinctive >= 2) { return .strong }
        if best.recall < Self.thinRecall || best.distinctive <= 1 { return .thin }
        return .moderate
    }

    /// The reading the credited claims support, and how firmly.
    var credit: UnderstandingHypothesis {
        let credited = diagnosis.claims.filter { $0.coverage == .covered || $0.coverage == .partial }
        let state = diagnosis.level == .surface ? UnderstandingState.fragile : UnderstandingJudge.state(of: diagnosis.level)
        guard !credited.isEmpty, state != .insufficientEvidence, state != .misconception else {
            let consistent = diagnosis.statements.contains { $0.verdict == .partiallySupports || $0.verdict == .supports }
            return consistent ? UnderstandingHypothesis(.fragile, support: 0.45, cue: .thinCoverage, claimID: definitionID)
                : UnderstandingHypothesis(.insufficientEvidence, support: 0.6, cue: .nothingComparable)
        }
        // The idea everything else rests on: the definition when credited, else the heaviest credited claim.
        let key = credited.first { id in target.rubric.first { $0.id == id.claimID }?.kind == .definition } ?? credited[0]
        switch strength(of: key.claimID) {
        case .strong: return UnderstandingHypothesis(state, support: 0.85, cue: .strongCoverage, claimID: key.claimID)
        case .moderate: return UnderstandingHypothesis(state, support: 0.7, cue: .strongCoverage, claimID: key.claimID)
        case .thin: return UnderstandingHypothesis(state, support: 0.45, cue: .thinCoverage, claimID: key.claimID)
        }
    }

    /// A reason the source does not settle, offered for a conclusion the answer does express
    /// ("indexes make lookups faster" + "because the database saves earlier answers").
    var unsupportedReason: Bool {
        guard diagnosis.claims.contains(where: { $0.coverage == .covered || $0.coverage == .partial }) else { return false }
        return signals.clauses.contains { clause in
            clause.verdict == .unsupported && Self.reason.firstMatch(in: clause.text, range: NSRange(clause.text.startIndex..., in: clause.text)) != nil
        }
    }
    private static let reason = try! NSRegularExpression(pattern: #"(?i)\b(?:because|since|as a result|that's why|which means|due to)\b"#)
}
