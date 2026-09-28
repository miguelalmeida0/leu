import Foundation

/// A Teach It Back explanation that still needs one more answer.
public struct PendingVerification: Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// Leu could not tell two readings apart and learned nothing yet: ask the question the
        /// comparison ended with.
        case discriminate
        /// The explanation was understood: check it transfers (an example, a contrast) before
        /// calling the concept mastered.
        case transfer
    }
    public let concept: LearnerConceptID
    public let kind: Kind
    /// The discriminating question (for `.discriminate`).
    public let question: FollowUpQuestion?
    public let since: Date
}

/// What Teach It Back leaves for the study session to follow up — derived from stored attempts
/// and the learner model, so nothing new is stored: an attempt that taught the model nothing
/// still carries the question its comparison asked, and an understood one is followed by one
/// transfer check (or whatever the concept is asked next) before anything else is promoted.
public enum TeachBackFollowThrough {
    /// Older explanations are not followed up: the session planner has fresher evidence by then.
    public static let window: TimeInterval = 14 * 86_400

    /// Only attempts whose passage is unchanged in `analyses` count: a question worded from an
    /// older version of the page is never asked.
    public static func pending(attempts: [UnderstandingAttempt], model: LearnerModelState, analyses: [UUID: DocumentAnalysis],
                               now: Date) -> [PendingVerification] {
        var found: [LearnerConceptID: PendingVerification] = [:]
        for attempt in attempts.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard !attempt.resolved, now.timeIntervalSince(attempt.createdAt) <= window, now >= attempt.createdAt,
                  attempt.source.isCurrent(in: analyses),
                  let result = attempt.result, result.backend == TeachBack.backend, let diagnosis = result.diagnosis else { continue }
            let documentID = attempt.source.packet.documentID
            if attempt.evidenceRecordedAt == nil, let question = diagnosis.intervention.followUp, let key = question.concept ?? diagnosis.concept {
                let concept = LearnerConceptID(documentID: documentID, concept: key)
                // Answered since, one way or another: nothing is pending.
                if let seen = model.mastery(concept)?.lastSeenAt, seen >= attempt.createdAt { found[concept] = nil; continue }
                found[concept] = PendingVerification(concept: concept, kind: .discriminate, question: question, since: attempt.createdAt)
            } else if let recorded = attempt.evidenceRecordedAt, [.solid, .mostly].contains(diagnosis.level), let key = diagnosis.concept,
                      !diagnosis.hasMisconception {
                let concept = LearnerConceptID(documentID: documentID, concept: key)
                // One check: the next answer about the concept settles it, whatever was asked — a
                // concept without a contrast or example question must not stay promoted for weeks.
                let answered = model.mastery(concept).map { $0.lastSeenAt > recorded } ?? false
                guard !answered, LearnerConceptState.of(concept, in: model, at: now) != .mastered else { found[concept] = nil; continue }
                found[concept] = PendingVerification(concept: concept, kind: .transfer, question: nil, since: recorded)
            }
        }
        return found.values.sorted { ($0.since, $0.concept) < ($1.since, $1.concept) }
    }
}
