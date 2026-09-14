import XCTest
@testable import ShelfCore

final class PageTurnPolicyTests: XCTestCase {
    func testSmallMovementDoesNotSelectAnAxis() {
        var policy = PageTurnPolicy()
        XCTAssertEqual(policy.lock(dx: 3, dy: 3), .undecided)
    }
    func testVerticalIntentStaysVerticalEvenWhenThumbDriftsSideways() {
        var policy = PageTurnPolicy()
        XCTAssertEqual(policy.lock(dx: 4, dy: 12), .vertical)
        XCTAssertEqual(policy.lock(dx: 160, dy: 20), .vertical)
        XCTAssertNil(policy.targetDelta(dx: 160, velocityX: 900, width: 390, page: 1, count: 4))
    }
    func testHorizontalIntentStaysHorizontalEvenWithLaterVerticalJitter() {
        var policy = PageTurnPolicy()
        XCTAssertEqual(policy.lock(dx: -20, dy: 2), .horizontal)
        XCTAssertEqual(policy.lock(dx: -150, dy: 160), .horizontal)
        XCTAssertEqual(policy.targetDelta(dx: -150, velocityX: -200, width: 390, page: 1, count: 4), 1)
    }
    func testAmbiguousDiagonalBelongsToReadingScroll() {
        var policy = PageTurnPolicy()
        XCTAssertEqual(policy.lock(dx: 12, dy: 10), .vertical)
    }
    func testSlowDeliberateDragCommitsExactlyOnePage() {
        let policy = horizontal()
        XCTAssertEqual(policy.targetDelta(dx: -150, velocityX: -10, width: 390, page: 0, count: 423), 1)
    }
    func testFastShortFlickCommits() {
        let policy = horizontal()
        XCTAssertEqual(policy.targetDelta(dx: -40, velocityX: -800, width: 390, page: 0, count: 423), 1)
    }
    func testTinyVelocitySpikeDoesNotCommit() {
        let policy = horizontal()
        XCTAssertNil(policy.targetDelta(dx: -8, velocityX: -1_500, width: 390, page: 0, count: 4))
    }
    func testShortSlowDragCancels() {
        let policy = horizontal()
        XCTAssertNil(policy.targetDelta(dx: -55, velocityX: -100, width: 390, page: 0, count: 4))
    }
    func testReversingBeforeReleaseCancelsForwardTurn() {
        let policy = horizontal()
        XCTAssertNil(policy.targetDelta(dx: -180, velocityX: 350, width: 390, page: 1, count: 4))
    }
    func testReversingBeforeReleaseCancelsBackwardTurn() {
        let policy = horizontal()
        XCTAssertNil(policy.targetDelta(dx: 180, velocityX: -350, width: 390, page: 1, count: 4))
    }
    func testFirstPageCannotTurnBackward() {
        XCTAssertNil(horizontal().targetDelta(dx: 200, velocityX: 900, width: 390, page: 0, count: 4))
    }
    func testLastPageCannotTurnForward() {
        XCTAssertNil(horizontal().targetDelta(dx: -200, velocityX: -900, width: 390, page: 3, count: 4))
    }
    func testRightwardDragTurnsBackOnePage() {
        XCTAssertEqual(horizontal().targetDelta(dx: 140, velocityX: 90, width: 390, page: 2, count: 4), -1)
    }
    func testNoNavigationForInvalidGeometry() {
        let policy = horizontal()
        for width in [0.0, -1.0, Double.nan, .infinity] {
            XCTAssertNil(policy.targetDelta(dx: -200, velocityX: -800, width: width, page: 1, count: 4))
        }
    }
    func testNoNavigationForInvalidPageState() {
        let policy = horizontal()
        XCTAssertNil(policy.targetDelta(dx: -200, velocityX: -800, width: 390, page: 0, count: 0))
        XCTAssertNil(policy.targetDelta(dx: -200, velocityX: -800, width: 390, page: -1, count: 4))
    }
    func testEdgeResistanceIsBounded() {
        XCTAssertEqual(horizontal().offset(dx: 1_000, width: 390, hasNeighbor: false), 18)
        XCTAssertEqual(horizontal().offset(dx: -1_000, width: 390, hasNeighbor: false), -18)
    }
    func testPageTracksFingerWithoutOvershootingViewport() {
        XCTAssertEqual(horizontal().offset(dx: -123, width: 390, hasNeighbor: true), -123)
        XCTAssertEqual(horizontal().offset(dx: -500, width: 390, hasNeighbor: true), -390)
    }
    func testVerticalPolicyNeverMovesThePageHorizontally() {
        var policy = PageTurnPolicy()
        policy.lock(dx: 2, dy: 20)
        XCTAssertEqual(policy.offset(dx: 180, width: 390, hasNeighbor: true), 0)
    }
    func testNonFiniteInputDoesNotLockAxis() {
        var policy = PageTurnPolicy()
        XCTAssertEqual(policy.lock(dx: .nan, dy: 5), .undecided)
        XCTAssertEqual(policy.lock(dx: .infinity, dy: 5), .undecided)
    }
    func testVelocityCanEstablishIntentWithoutTurningVerticalNoiseIntoPaging() {
        var fast = PageTurnPolicy()
        XCTAssertEqual(fast.lock(dx: -7, dy: 6, velocityX: -800, velocityY: 70), .horizontal)
        XCTAssertEqual(fast.lock(dx: -20, dy: 25, velocityX: -90, velocityY: 150), .horizontal)
        var vertical = PageTurnPolicy()
        XCTAssertEqual(vertical.lock(dx: 4, dy: 18, velocityX: 600, velocityY: 900), .vertical)
        var ambiguous = PageTurnPolicy()
        XCTAssertEqual(ambiguous.lock(dx: 12, dy: 10, velocityX: 100, velocityY: 90), .vertical)
    }
    func testFastReleaseNeedsHorizontalVelocityDominance() {
        let policy = horizontal()
        XCTAssertNil(policy.targetDelta(dx: -40, velocityX: -800, velocityY: 900, width: 390, page: 1, count: 4))
        XCTAssertEqual(policy.targetDelta(dx: -40, velocityX: -800, velocityY: 90, width: 390, page: 1, count: 4), 1)
        XCTAssertEqual(policy.targetDelta(dx: -160, velocityX: -100, velocityY: 140, width: 390, page: 1, count: 4), 1)
    }
    func testInvalidVelocityDoesNotEstablishIntent() {
        var policy = PageTurnPolicy()
        XCTAssertEqual(policy.lock(dx: -20, dy: 0, velocityX: .nan, velocityY: 0), .undecided)
        XCTAssertNil(horizontal().targetDelta(dx: -40, velocityX: -800, velocityY: .infinity, width: 390, page: 1, count: 4))
    }
    private func horizontal() -> PageTurnPolicy {
        var policy = PageTurnPolicy()
        policy.lock(dx: -20, dy: 0)
        return policy
    }
}
