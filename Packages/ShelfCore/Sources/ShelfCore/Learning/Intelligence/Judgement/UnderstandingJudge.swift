import Foundation

/// Weighs the readings an answer allows and decides whether the learner model may learn from
/// it now or should first ask one discriminating question. Deterministic: the same diagnosis,
/// signals and prior always give the same judgement. It never raises credit above what the
/// diagnosis found; it only decides how far that finding can be trusted.
///
/// The order of the checks is the decision boundary:
/// 1. nothing comparable → insufficient evidence;
/// 2. a clearly stated wrong idea → misconception;
/// 3. a doubtful wrong idea, a possible confusion, or a live earlier misconception this answer
///    does not clearly correct → ask the question that separates misconception from credit;
/// 4. source wording copied, credit resting on thin wording (one distinctive word, most of the
///    idea missing), or credit from a learner who says they are unsure → ask before counting it;
/// 5. otherwise the diagnosis stands (understood, mostly, fragile), except that a right
///    conclusion given with a reason the source does not settle is weak reasoning.
struct UnderstandingJudge: Sendable {
    /// How often each kind of verdict matched an independent teacher's reading on the V35
    /// development split (histogram calibration, rounded; weak reasoning had a single committed
    /// dev case and sits at even odds). Partial credit is usually a correct paraphrase the lexical
    /// reader only half recognised, hence its low value: it under-credits, it does not over-credit.
    enum Confidence {
        static let nothingComparable = 0.5, misconception = 0.75, strongCredit = 0.8, partialCredit = 0.2, weakReasoning = 0.5
        /// The leading reading of a judgement that asks first: right about four times in ten until answered.
        static let undecided = 0.4
        /// A reading that rests only on what the answer says in other words, asked about first.
        static let semanticOnly = 0.5
    }

    func judge(_ diagnosis: UnderstandingDiagnosis, signals: DiagnosisSignals, target: DiagnosisTarget, prior: LearnerPrior) -> UnderstandingJudgement {
        let reading = JudgementReading(diagnosis: diagnosis, signals: signals, target: target)
        // 1. Nothing comparable: learn nothing, ask for the idea itself.
        if reading.nothingComparable {
            return decide(.insufficientEvidence, Confidence.nothingComparable, [UnderstandingHypothesis(.insufficientEvidence, support: 0.8, cue: .nothingComparable)],
                          ask: DiscriminatingQuestion(between: [.insufficientEvidence, .fragile], claimIDs: reading.definitionID.map { [$0] } ?? [],
                                                      operation: .define, relatedConcept: nil))
        }
        var hypotheses = reading.misconceptions + reading.possibleConfusions + reading.omittedNegations + reading.lingering(prior)
            + reading.semanticConfusions + reading.opposites
        let credit = reading.credit
        hypotheses.append(credit)
        // Credit only the semantic space can see, when the wording itself earns none. It is asked
        // about before anything is recorded; it never raises credit the wording already earns.
        let semantic = credit.state == .insufficientEvidence ? reading.semanticCredit : nil
        if let semantic { hypotheses.append(semantic) }
        let leading = semantic?.state ?? credit.state
        hypotheses.sort { ($0.support, Self.rank($0.state)) > ($1.support, Self.rank($1.state)) }

        // 2. A clearly stated wrong idea.
        if let wrong = reading.misconceptions.first(where: { $0.support >= 0.7 }) {
            return decide(.misconception, Confidence.misconception, hypotheses, ask: nil, focus: wrong)
        }
        // 3. A wrong idea that is possible but not established. The most specific doubt decides what
        // to ask: a claim the answer seems to misread before a concept it may be mixing up.
        let specificity: [UnderstandingCue] = [.contradiction, .omittedNegation, .opposite, .priorMisconception, .possibleConfusion]
        if let doubtful = hypotheses.filter({ $0.state == .misconception })
            .min(by: { (specificity.firstIndex(of: $0.cue) ?? 9) < (specificity.firstIndex(of: $1.cue) ?? 9) }) {
            let claims = doubtful.claimID.map { [$0] } ?? reading.definitionID.map { [$0] } ?? []
            // A wrong idea stated (in this answer or an earlier one) is re-tested as such; a claim the
            // answer may only misread is asked in its own terms, so a right answer counts at that
            // claim's level, not as a connect-level check.
            let operation: ProbeOperation
            if doubtful.relatedConcept != nil && doubtful.claimID == nil { operation = .contrast }
            else if [.contradiction, .opposite, .priorMisconception].contains(doubtful.cue) { operation = .misconceptionCheck }
            else { operation = claims.first.map(reading.operation(for:)) ?? .define }
            return decide(leading, Confidence.undecided, hypotheses,
                          ask: DiscriminatingQuestion(between: [.misconception, leading], claimIDs: claims, operation: operation,
                                                      relatedConcept: doubtful.relatedConcept))
        }
        // Source wording copied: memory of the text, not yet understanding — ask for own words.
        if diagnosis.level == .surface {
            return decide(.fragile, Confidence.undecided, hypotheses,
                          ask: DiscriminatingQuestion(between: [.fragile, .understood], claimIDs: credit.claimID.map { [$0] } ?? [],
                                                      operation: .purpose, relatedConcept: nil))
        }
        // 4. Credit resting on thin wording, or given by a learner who says they are unsure.
        if credit.cue == .thinCoverage || (credit.state.credits && reading.selfDoubt), let claim = credit.claimID {
            if credit.cue != .thinCoverage { hypotheses.insert(UnderstandingHypothesis(.fragile, support: credit.support, cue: .selfDoubt, claimID: claim), at: 0) }
            // Credit that may be less than it looks is weighed against fragile understanding;
            // thin partial credit, against a misreading that shares its words ("only once").
            let alternative: UnderstandingState = credit.state.credits ? .fragile : .misconception
            return decide(leading, Confidence.undecided, hypotheses,
                          ask: DiscriminatingQuestion(between: [leading, alternative], claimIDs: [claim],
                                                      operation: reading.operation(for: claim), relatedConcept: nil))
        }
        // Said only in other words: a reading the semantic space gives, asked about before anything
        // is recorded. A right conclusion with a reason the source does not settle is weak reasoning,
        // and the question asks for the reason.
        if let semantic, let claim = semantic.claimID {
            let weak = !reading.unsettledReasons.isEmpty
            let asked = weak ? reading.reasonClaimID ?? claim : claim
            return decide(weak ? .weakReasoning : semantic.state, Confidence.semanticOnly, hypotheses,
                          ask: DiscriminatingQuestion(between: weak ? [.weakReasoning, semantic.state] : [semantic.state, .fragile],
                                                      claimIDs: [asked], operation: reading.operation(for: asked), relatedConcept: nil))
        }
        if credit.cue == .nothingComparable {
            return decide(.insufficientEvidence, Confidence.nothingComparable, hypotheses,
                          ask: DiscriminatingQuestion(between: [.insufficientEvidence, .fragile], claimIDs: reading.definitionID.map { [$0] } ?? [],
                                                      operation: .define, relatedConcept: nil))
        }
        // 5. The diagnosis stands; a right conclusion with an unsettled reason is weak reasoning.
        if credit.state != .insufficientEvidence, reading.unsupportedReason {
            let weak = UnderstandingHypothesis(.weakReasoning, support: 0.6, cue: .unsupportedReason, claimID: credit.claimID)
            return decide(.weakReasoning, Confidence.weakReasoning, [weak] + hypotheses, ask: nil)
        }
        // A reason the source does not give, in its words or in others, beside a credited conclusion:
        // the reasoning may be the learner's own. Asked about before the credit counts.
        if credit.state != .insufficientEvidence, !reading.unsettledReasons.isEmpty {
            let asked = reading.reasonClaimID ?? credit.claimID
            let weak = UnderstandingHypothesis(.weakReasoning, support: 0.5, cue: .unsupportedReason, claimID: asked)
            return decide(.weakReasoning, Confidence.undecided, [weak] + hypotheses,
                          ask: DiscriminatingQuestion(between: [.weakReasoning, credit.state], claimIDs: asked.map { [$0] } ?? [],
                                                      operation: asked.map(reading.operation(for:)) ?? .purpose, relatedConcept: nil))
        }
        return decide(credit.state, credit.state == .fragile ? Confidence.partialCredit : Confidence.strongCredit, hypotheses, ask: nil)
    }

    private func decide(_ state: UnderstandingState, _ confidence: Double, _ hypotheses: [UnderstandingHypothesis],
                        ask question: DiscriminatingQuestion?, focus: UnderstandingHypothesis? = nil) -> UnderstandingJudgement {
        let ordered = focus.map { focus in [focus] + hypotheses.filter { $0 != focus } } ?? hypotheses
        return UnderstandingJudgement(state: state, confidence: confidence, hypotheses: ordered, question: question)
    }

    /// Ties go to the more cautious reading.
    static func rank(_ state: UnderstandingState) -> Int {
        switch state {
        case .misconception: return 5
        case .insufficientEvidence: return 4
        case .weakReasoning: return 3
        case .fragile: return 2
        case .mostlyUnderstood: return 1
        case .understood: return 0
        }
    }

    /// The reading a diagnosis level stands for when nothing else is weighed.
    static func state(of level: UnderstandingLevel) -> UnderstandingState {
        switch level {
        case .solid: return .understood
        case .mostly: return .mostlyUnderstood
        case .partial, .surface: return .fragile
        case .misconceived: return .misconception
        case .circular, .unrelated, .insufficient: return .insufficientEvidence
        }
    }
}
