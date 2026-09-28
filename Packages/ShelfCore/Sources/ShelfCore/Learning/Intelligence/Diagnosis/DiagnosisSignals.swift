import Foundation

/// How strongly one clause's verdict is supported — what the judge weighs. Transient: the
/// persisted diagnosis keeps the verdicts, not the numbers behind them.
struct ClauseSignal: Sendable {
    let text: String
    let verdict: StatementVerdict
    let claimID: String?
    /// The claim alignment behind the verdict: how much of the claim the clause expresses, how
    /// much of the clause the claim explains, and how many distinctive claim words carry that.
    let recall: Double
    let precision: Double
    let distinctive: Int
    /// The other concept whose grounded wording explains the clause best, how much of the clause
    /// it explains (share and weight), beside the target's own share. Concept targets only.
    let rival: ConceptKey?
    let rivalPrecision: Double
    let rivalMatched: Double
    let ownPrecision: Double
    /// For a contradiction: how much of the opposed proposition the clause restates.
    let conflictOverlap: Double
    /// A negated claim that the clause matches without expressing any negation.
    let unexpressedNegation: Bool
    let words: Int
    /// Every claim the clause credits (not only the verdict's), with the recall and distinctive words behind it.
    var credited: [String: (recall: Double, distinctive: Int)] = [:]
}

/// Everything the judge weighs beyond the diagnosis itself, one entry per statement.
struct DiagnosisSignals: Sendable {
    var clauses: [ClauseSignal] = []

    static let none = DiagnosisSignals()
}

extension UnderstandingDiagnoser {
    /// The target's own share of a clause and its strongest rival concept (same tie-break as a confusion).
    static func rivalry(_ clause: LearnerClause, context: AlignmentContext) -> (rival: ConceptKey?, precision: Double, matched: Double, own: Double) {
        guard let own = context.target.concept else { return (nil, 0, 0, 0) }
        let ownPrecision = context.precision(clause, against: own)
        let best = context.conceptProfiles.keys.filter { $0 != own }.map { ($0, context.evidence(clause, against: $0)) }
            .max { ($0.1.precision, $1.0.value) < ($1.1.precision, $0.0.value) }
        return (best?.0, best?.1.precision ?? 0, best?.1.matched ?? 0, ownPrecision)
    }

    static func signal(_ statement: StatementDiagnosis, clause: LearnerClause, alignment: Alignment?, context: AlignmentContext) -> ClauseSignal {
        let rivalry = rivalry(clause, context: context)
        return ClauseSignal(text: statement.learnerText, verdict: statement.verdict, claimID: statement.claimID ?? alignment?.rubric.claim.id,
                            recall: alignment?.recall ?? 0, precision: alignment?.precision ?? 0, distinctive: alignment?.distinctive ?? 0,
                            rival: rivalry.rival, rivalPrecision: rivalry.precision, rivalMatched: rivalry.matched, ownPrecision: rivalry.own,
                            conflictOverlap: alignment?.conflictOverlap ?? 0, unexpressedNegation: alignment?.unexpressedNegation ?? false,
                            words: clause.profile.words.count)
    }
}
