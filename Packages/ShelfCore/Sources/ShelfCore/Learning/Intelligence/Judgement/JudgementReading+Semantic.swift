import Foundation

/// What the semantic reader adds to the facts the judge weighs. Each is evidence, never a verdict:
/// credit read in other words is asked about before anything is recorded and never raises credit
/// the wording already earns; every semantic doubt leads to a question. The decision boundary
/// stays in `UnderstandingJudge`.
extension JudgementReading {
    /// The reading the answer supports once what it says in other words counts too (nil when the
    /// semantic reading raised no claim).
    var semanticState: UnderstandingState? {
        guard let level = signals.semanticLevel, !signals.semanticCoverage.isEmpty else { return nil }
        let state = UnderstandingJudge.state(of: level)
        return state == .misconception || state == .insufficientEvidence ? nil : state
    }

    /// Credit that rests only on what the answer says in other words, on its key claim (the
    /// definition when it is so read).
    var semanticCredit: UnderstandingHypothesis? {
        guard let state = semanticState else { return nil }
        let raised = signals.semanticCoverage
        let key = target.rubric.first { $0.kind == .definition && raised[$0.id] != nil }?.id
            ?? target.rubric.first { raised[$0.id] != nil }?.id ?? raised.keys.sorted().first
        return UnderstandingHypothesis(state, support: 0.5, cue: .semanticCoverage, claimID: key)
    }

    /// Reasons the answer gives that the source does not say, in its words or in others.
    var unsettledReasons: [ReasonReading] {
        signals.clauses.compactMap(\.reason).filter { !$0.supported }
    }

    /// The claim that says why or how (purpose, mechanism, cause, consequence): what a question about
    /// a learner's reasoning asks for.
    var reasonClaimID: String? {
        target.rubric.first { [.purpose, .mechanism, .cause, .consequence].contains($0.kind) }?.id
    }

    /// Clauses that another concept's wording explains clearly better than the target's, read in
    /// other words: a confusion the lexical reader cannot see. Where the target's own words explain
    /// the clause well, meaning never overrides them (the lexical reader's rule).
    var semanticConfusions: [UnderstandingHypothesis] {
        guard target.concept != nil, !diagnosis.has(.confusedConcept) else { return [] }
        return signals.clauses.compactMap { clause in
            guard let reading = clause.semantic, reading.blocks.contains(.rival), clause.ownPrecision < Self.ownShare,
                  !(clause.verdict == .supports && clause.recall >= Self.strongRecall) else { return nil }
            return UnderstandingHypothesis(.misconception, support: 0.5, cue: .possibleConfusion, relatedConcept: reading.rival)
        }
    }

    /// A clause that says a claim with its sense reversed, where the lexical reader saw no
    /// contradiction: an opposite word ("slower" where the source says "faster") or the opposite
    /// polarity on the proposition it carries ("nobody can read them"). A doubt, asked about.
    var opposites: [UnderstandingHypothesis] {
        signals.clauses.compactMap { clause in
            guard let reading = clause.semantic, reading.reversesSense, let claim = reading.closest,
                  clause.verdict != .contradicts else { return nil }
            return UnderstandingHypothesis(.misconception, support: 0.5, cue: .opposite, claimID: claim)
        }
    }
}
