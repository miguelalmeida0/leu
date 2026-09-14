import XCTest
@testable import ShelfCore

final class ReviewSchedulerTests: XCTestCase {
    private let scheduler = ShelfReviewScheduler()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testForgotSchedulesEarlierThanDifficultAndKnewIt() {
        let state = ReviewState(learningObjectID: UUID(), stability: 3)
        let forgot = scheduler.reviewed(state, rating: .forgot, at: now)
        let difficult = scheduler.reviewed(state, rating: .difficult, at: now)
        let knew = scheduler.reviewed(state, rating: .knewIt, at: now)
        XCTAssertLessThan(forgot.nextReviewAt!, difficult.nextReviewAt!)
        XCTAssertLessThan(difficult.nextReviewAt!, knew.nextReviewAt!)
    }

    func testRepeatedSuccessIncreasesStability() {
        var state = ReviewState(learningObjectID: UUID())
        let first = scheduler.reviewed(state, rating: .knewIt, at: now)
        state = first
        let second = scheduler.reviewed(state, rating: .knewIt, at: now.addingTimeInterval(86_400))
        XCTAssertGreaterThan(second.stability, first.stability)
    }

    func testFailureWeakensStabilityAndRaisesDifficulty() {
        let state = ReviewState(learningObjectID: UUID(), difficulty: 0.4, stability: 8)
        let failed = scheduler.reviewed(state, rating: .forgot, at: now)
        XCTAssertLessThan(failed.stability, state.stability)
        XCTAssertGreaterThan(failed.difficulty, state.difficulty)
    }

    func testHintSupportShortensOtherwiseSuccessfulRecallInterval() {
        let scheduler = ShelfReviewScheduler()
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let state = ReviewState(learningObjectID: UUID(), stability: 3, importance: 0.7)
        let unsupported = scheduler.reviewed(state, rating: .knewIt, hintCount: 0, at: now)
        let supported = scheduler.reviewed(state, rating: .knewIt, hintCount: 3, at: now)
        XCTAssertLessThan(try! XCTUnwrap(supported.nextReviewAt), try! XCTUnwrap(unsupported.nextReviewAt))
        XCTAssertLessThan(supported.stability, unsupported.stability)
    }

    func testCalculationIsDeterministic() {
        let state = ReviewState(learningObjectID: UUID(), difficulty: 0.4, stability: 2.2, importance: 0.8)
        XCTAssertEqual(scheduler.reviewed(state, rating: .difficult, at: now),
                       scheduler.reviewed(state, rating: .difficult, at: now))
    }
}
