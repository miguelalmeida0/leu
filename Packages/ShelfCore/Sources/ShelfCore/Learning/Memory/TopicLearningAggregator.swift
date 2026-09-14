import Foundation

public struct TopicLearningAggregator: Sendable {
    private let scheduler: any ReviewScheduling
    public init(scheduler: any ReviewScheduling = ShelfReviewScheduler()) { self.scheduler = scheduler }

    public func state(topicID: UUID, snapshot: LearningSnapshot, now: Date = Date()) -> TopicLearningState {
        let objectIDs = Set(snapshot.learningObjects.filter { $0.topicIDs.contains(topicID) }.map(\.id))
        let attempts = snapshot.attempts.filter { objectIDs.contains($0.learningObjectID) }
        let reviewStates = objectIDs.compactMap { snapshot.reviewStates[$0] }
        let confidences = attempts.compactMap { $0.confidence?.numericValue }
        let correctness = attempts.compactMap(\.wasCorrect)
        let averageConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Double(confidences.count)
        let accuracy = correctness.isEmpty ? 0 : Double(correctness.filter { $0 }.count) / Double(correctness.count)
        let nextDue = reviewStates.compactMap(\.nextReviewAt).min()
        let states = reviewStates.map { scheduler.mastery(for: $0, at: now) }
        let mastery: MasteryState
        if states.contains(.fading) { mastery = .fading }
        else if states.contains(.due) { mastery = .due }
        else if states.contains(.learning) { mastery = .learning }
        else if states.contains(.strengthening) { mastery = .strengthening }
        else if !states.isEmpty && states.allSatisfy({ $0 == .durable }) { mastery = .durable }
        else { mastery = .new }
        let successful = attempts.filter { attempt in
            attempt.wasCorrect ?? (attempt.rating != .forgot)
        }.count
        let failed = attempts.filter { attempt in
            !(attempt.wasCorrect ?? (attempt.rating != .forgot))
        }.count
        return TopicLearningState(topicID: topicID, encounters: objectIDs.count, attempts: attempts.count,
                                  successfulRecalls: successful,
                                  failedRecalls: failed,
                                  averageConfidence: averageConfidence,
                                  calibrationDelta: averageConfidence - accuracy,
                                  nextReviewAt: nextDue, state: mastery)
    }
}
