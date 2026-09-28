import Foundation

/// What one answer shows, as a teacher would sum it up. Transient: judged when the answer is
/// read, used to decide what the learner model may learn from it and what to ask next, and
/// never stored — what persists is the evidence it lets through (or the question it asks).
public enum UnderstandingState: String, Sendable, CaseIterable {
    /// Every key idea, in the learner's own words, nothing wrong.
    case understood
    /// The central idea is right; a secondary element is missing.
    case mostlyUnderstood
    /// Some right pieces; the central idea is incomplete or only gestured at.
    case fragile
    /// Something the source contradicts: an opposite, a reversal, another concept's idea.
    case misconception
    /// A right conclusion without the reasoning behind it (or with reasoning the source does not support).
    case weakReasoning
    /// Too little comparable content to tell.
    case insufficientEvidence

    /// Would this reading add success to the learner model?
    var credits: Bool { self == .understood || self == .mostlyUnderstood }
}

/// Why a reading is on the table.
public enum UnderstandingCue: String, Sendable {
    /// Key ideas expressed, with strong or thin lexical evidence.
    case strongCoverage, thinCoverage
    /// The answer states the opposite of a claim, or reverses it.
    case contradiction, reversal
    /// The answer reads as another concept's idea.
    case confusion, possibleConfusion
    /// Universal wording where the source is qualified.
    case overgeneralization
    /// A live misconception from earlier answers that this answer does not clearly correct.
    case priorMisconception
    /// A negated claim's content restated without its negation.
    case omittedNegation
    /// The learner says they are unsure ("maybe", "not sure", "something to do with").
    case selfDoubt
    /// A reason the source does not settle, given for a right conclusion.
    case unsupportedReason
    /// The answer restates the source's words.
    case verbatim
    /// Nothing comparable, or only the concept's own name.
    case nothingComparable
    /// Key ideas expressed in other words, as read by the semantic space: never recorded before
    /// one more answer.
    case semanticCoverage
    /// A claim word answered by its opposite ("slower" where the source says "faster").
    case opposite
}

/// One reading of an answer and how well the answer's evidence supports it.
public struct UnderstandingHypothesis: Equatable, Sendable {
    public let state: UnderstandingState
    /// 0…1: how strongly the answer's evidence supports this reading.
    public let support: Double
    public let cue: UnderstandingCue
    /// The claim the reading turns on.
    public let claimID: String?
    /// The other concept, for a confusion.
    public let relatedConcept: ConceptKey?

    public init(_ state: UnderstandingState, support: Double, cue: UnderstandingCue, claimID: String? = nil, relatedConcept: ConceptKey? = nil) {
        self.state = state; self.support = support; self.cue = cue; self.claimID = claimID; self.relatedConcept = relatedConcept
    }
}

/// The smallest question whose answer tells the two leading readings apart. The decision (what
/// to ask about, and which kind of question) is deterministic; its wording comes from templates.
public struct DiscriminatingQuestion: Equatable, Sendable {
    /// The readings the answer will separate, leading one first.
    public let between: [UnderstandingState]
    /// The claims whose answer settles it.
    public let claimIDs: [String]
    public let operation: ProbeOperation
    /// The other concept, when the question contrasts two.
    public let relatedConcept: ConceptKey?
}

/// The verdict on one answer: the leading reading, how sure Leu is of it, the readings it was
/// weighed against, and — when the next answer would change the verdict — what to ask first.
public struct UnderstandingJudgement: Equatable, Sendable {
    public let state: UnderstandingState
    /// Estimated probability that `state` is right.
    public let confidence: Double
    /// Best first.
    public let hypotheses: [UnderstandingHypothesis]
    /// Set when the learner model should wait for one more answer before it is updated.
    public let question: DiscriminatingQuestion?

    public var needsEvidence: Bool { question != nil }
}

/// A diagnosis (stored with the answer) and the judgement behind its next step (not stored).
public struct UnderstandingAssessment: Sendable {
    public let diagnosis: UnderstandingDiagnosis
    public let judgement: UnderstandingJudgement
    /// The evidence strength the judgement weighed.
    let signals: DiagnosisSignals
}

/// What the learner model already says about the concepts an answer is about: live
/// misconceptions an ambiguous answer must not be allowed to paper over.
public struct LearnerPrior: Sendable {
    public let misconceptions: [MisconceptionRecord]
    public let at: Date

    public init(misconceptions: [MisconceptionRecord] = [], at: Date = Date()) {
        self.misconceptions = misconceptions; self.at = at
    }

    /// Salient misconceptions about the given concepts that no answer has corrected yet (active;
    /// a resolving one already had a clear correction). A faded one (salience under 0.2: five to
    /// seven weeks unrevisited) no longer colours how a new answer is read.
    public init(_ state: LearnerModelState, concepts: [LearnerConceptID], at date: Date) {
        misconceptions = concepts.flatMap { state.misconceptions(for: $0) }.filter { $0.status == .active && $0.salience(at: date) >= 0.2 }
        at = date
    }
}
