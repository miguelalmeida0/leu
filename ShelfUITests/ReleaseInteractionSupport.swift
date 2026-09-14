import XCTest

extension ShelfUITestCase {
    func assertReleaseControlsVisible(beforeRelease: Bool,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let ids = ["release-continue", "release-done"] + (beforeRelease ? ["release-accessible-action"] : [])
        for id in ids { assertPinnedReleaseButton(id, file: file, line: line) }
    }

    func tapPinnedReleaseButton(_ identifier: String,
                                file: StaticString = #filePath, line: UInt = #line) {
        assertPinnedReleaseButton(identifier, file: file, line: line)
        app.buttons[identifier].tap()
    }

    private func assertPinnedReleaseButton(_ identifier: String,
                                          file: StaticString, line: UInt) {
        let query = app.buttons.matching(identifier: identifier)
        let button = query.firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        let probe = element("session-summary-frame")
        let dock = element("release-controls-frame")
        XCTAssertTrue(dock.waitForExistence(timeout: 5), file: file, line: line)
        let visible = NSPredicate { _, _ in
            query.count == 1 && button.isEnabled && button.isHittable
                && self.studyViewport(probe).contains(button.frame)
                && dock.frame.insetBy(dx: -1, dy: -1).contains(button.frame)
        }
        let expectation = XCTNSPredicateExpectation(predicate: visible, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                       "Pinned Release controls must be fully visible without scrolling or drawing: " + identifier,
                       file: file, line: line)
        XCTAssertGreaterThanOrEqual(button.frame.height, 44, file: file, line: line)
    }

    func finishRoundForEmotionalFlow() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-library", "--force-emotional-checkin"]
        app.launch()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 25))
        app.buttons["primary-learn"].tap()
        revealStudySessionOptions()
        XCTAssertTrue(app.buttons["learn-topic-react"].waitForExistence(timeout: 25))
        tapStudyButton("learn-topic-react")
        tapStudyButton("5 minutes")
        let start = app.buttons["start-learning-session"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: start)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 35), .completed)
        tapStudyButton("start-learning-session")
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 12))
        completeStudySessionForEmotionalAcceptance()
        XCTAssertTrue(element("session-complete-screen").waitForExistence(timeout: 10))
        XCTAssertTrue(element("emotional-check-in").waitForExistence(timeout: 5))
    }
}
