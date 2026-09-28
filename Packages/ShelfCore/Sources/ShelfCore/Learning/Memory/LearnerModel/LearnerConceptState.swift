import Foundation

/// What Leu can say about one concept, read from the learner model at a moment in time.
///
/// Derived, never stored: every state is a function of the persisted evidence (per-operation
/// success and failure weights, spaced successes, misconception records) and of the date, so it
/// follows forgetting and fading misconceptions without migrations and can never go stale. A
/// stored label would duplicate that evidence and drift from it.
public enum LearnerConceptState: String, Sendable, CaseIterable {
    /// Reliable at connecting or transferring the idea (contrast, examples), nothing below failing.
    case mastered
    /// Explains the idea reliably; not yet shown at the connect or transfer level.
    case mostlyUnderstood
    /// Some success, not yet reliable — or a misconception on its way out.
    case fragile
    /// A live misconception.
    case misconception
    /// Recognises or picks the right answer, but explanations of it keep falling short.
    case weakReasoning
    /// Too little evidence to say anything: one answer, or only the learner's own ratings.
    case insufficientEvidence
    /// Never seen.
    case unknown

    /// Evidence below this weight is one answer's worth: never enough for a verdict.
    static let minimumEvidence = 1.5

    public static func of(_ concept: LearnerConceptID, in state: LearnerModelState, at date: Date) -> LearnerConceptState {
        let records = state.misconceptions(for: concept)
        if records.contains(where: { $0.status == .active && $0.salience(at: date) >= 0.2 }) { return .misconception }
        guard let mastery = state.mastery(concept), !mastery.operations.isEmpty else { return records.isEmpty ? .unknown : .fragile }
        let weight = mastery.operations.reduce(0) { $0 + $1.evidenceWeight }
        if weight < minimumEvidence { return .insufficientEvidence }
        let level = mastery.level(at: date)
        if level >= 3 { return .mastered }
        if level == 2 { return records.contains { $0.status == .resolving } ? .fragile : .mostlyUnderstood }
        // Right when recognising, short when explaining: the answer is there without the reasons.
        let explaining = mastery.operations.filter { $0.operation.level == 2 && $0.evidenceWeight >= 1 }
        if level == 1, !explaining.isEmpty, explaining.allSatisfy({ $0.estimate < 0.55 }) { return .weakReasoning }
        return .fragile
    }
}
