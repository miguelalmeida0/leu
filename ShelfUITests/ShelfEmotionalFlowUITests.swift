import XCTest

final class ShelfEmotionalFlowUITests: ShelfUITestCase {
    func test55DrawingCannotHideReleaseOrExitControls() {
        finishRoundForEmotionalFlow()
        tapStudyButton("feeling-irritated", scrollID: "session-summary")
        tapStudyButton("check-in-open-release", scrollID: "session-summary")
        assertReleaseControlsVisible(beforeRelease: true)
        let canvas = element("release-canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 5))
        XCTAssertTrue(studyViewport(element("session-summary-frame")).contains(canvas.frame))
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25))
        let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.75))
        start.press(forDuration: 0.05, thenDragTo: end)
        let drawn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Drawing present"), object: canvas)
        XCTAssertEqual(XCTWaiter.wait(for: [drawn], timeout: 4), .completed)
        assertReleaseControlsVisible(beforeRelease: true)
        tapPinnedReleaseButton("release-accessible-action")
        XCTAssertTrue(app.staticTexts["release-completed-message"].waitForExistence(timeout: 5))
        XCTAssertFalse(element("release-canvas").exists, "Released drawings must leave the view hierarchy.")
        assertReleaseControlsVisible(beforeRelease: false)
        tapPinnedReleaseButton("release-done")
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 8))
        relaunchWithoutReset()
        XCTAssertTrue(app.buttons["primary-learn"].waitForExistence(timeout: 25))
        XCTAssertFalse(element("release-surface").exists, "Drawings must not persist across launches.")
        XCTAssertFalse(element("study-session-screen").exists, "A finished round must not be resurrected.")
        capture("55-release-drawing-and-exit")
    }

    func test56DrainedCanFinishWithoutLosingCompletedHistory() {
        finishRoundForEmotionalFlow()
        tapStudyButton("feeling-drained", scrollID: "session-summary")
        XCTAssertTrue(app.buttons["check-in-finish-here"].exists)
        tapStudyButton("check-in-save-place", scrollID: "session-summary")
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 8))
        tapStudyButton("learning-progress")
        expectProgressOpen()
        app.buttons["progress-tab-history"].tap()
        let event = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress-event-")).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 8))
        let savedEvent = event.identifier
        closeProgress()
        relaunchWithoutReset()
        XCTAssertTrue(app.buttons["primary-learn"].waitForExistence(timeout: 25))
        XCTAssertFalse(element("study-session-screen").exists)
        app.buttons["primary-learn"].tap()
        tapStudyButton("learning-progress")
        expectProgressOpen()
        app.buttons["progress-tab-history"].tap()
        XCTAssertTrue(app.buttons[savedEvent].waitForExistence(timeout: 8),
                      "The same real learning event must survive drained exit and relaunch.")
        capture("56-drained-durable-history")
    }
}
