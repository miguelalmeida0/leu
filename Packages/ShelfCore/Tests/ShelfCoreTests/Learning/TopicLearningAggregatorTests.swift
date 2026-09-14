import XCTest
@testable import ShelfCore

final class TopicLearningAggregatorTests: XCTestCase {
    func testHighConfidenceMissesSurfacePositiveCalibrationDelta() {
        let topic = LearningTopic(name: "React")
        let source = LearningSource(documentID: UUID(), pageIndex: 0, sourceText: "Keys preserve sibling identity.")
        let object = LearningObject(type: .recall, source: source, topicIDs: [topic.id], title: "Keys")
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let attempts = [
            LearningAttempt(learningObjectID: object.id, occurredAt: now, rating: .knewIt, wasCorrect: true, confidence: .certain),
            LearningAttempt(learningObjectID: object.id, occurredAt: now, rating: .forgot, wasCorrect: false, confidence: .certain),
        ]
        let snapshot = LearningSnapshot(topics: [topic], learningObjects: [object],
            reviewStates: [object.id: ReviewState(learningObjectID: object.id)], attempts: attempts)

        let state = TopicLearningAggregator().state(topicID: topic.id, snapshot: snapshot, now: now)
        XCTAssertEqual(state.attempts, 2)
        XCTAssertEqual(state.averageConfidence, 0.9, accuracy: 0.0001)
        XCTAssertEqual(state.calibrationDelta, 0.4, accuracy: 0.0001)
    }

    func testNextDueAndFadingStateComeFromReviewState() {
        let topic = LearningTopic(name: "Networking")
        let object = LearningObject(type: .passage,
            source: LearningSource(documentID: UUID(), pageIndex: 1, sourceText: "TLS protects data in transit."),
            topicIDs: [topic.id], title: "TLS")
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let due = now.addingTimeInterval(-86_400 * 10)
        let review = ReviewState(learningObjectID: object.id, lastReviewedAt: due.addingTimeInterval(-86_400),
                                 nextReviewAt: due, reviewCount: 3, successfulRecalls: 2,
                                 failedRecalls: 1, difficulty: 0.6, stability: 1.2)
        let snapshot = LearningSnapshot(topics: [topic], learningObjects: [object], reviewStates: [object.id: review])

        let state = TopicLearningAggregator().state(topicID: topic.id, snapshot: snapshot, now: now)
        XCTAssertEqual(state.nextReviewAt, due)
        XCTAssertTrue([MasteryState.due, .fading].contains(state.state))
    }
}
