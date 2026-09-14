import XCTest

/// Regression coverage for control semantics, scroll boundaries, and every secondary Study route.
final class ShelfStudyInteractionUITests: ShelfUITestCase {
    func test48ProgressReopensAfterScrollingAndBothTabsWork() {
        guard openStudyTab() else { return }
        for _ in 0..<2 {
            // Start from farther down the real scroll view; the helper must scroll back up when needed.
            dragStudyViewport(studyViewport(element("learn-screen-frame")), upward: true)
            tapStudyButton("learning-progress")
            expectProgressOpen()
            XCTAssertEqual(app.buttons["progress-tab-now"].value as? String, "Selected")
            app.buttons["progress-tab-history"].tap()
            XCTAssertTrue(app.staticTexts["UNDERSTANDING TIME MACHINE"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons["progress-tab-history"].value as? String, "Selected")
            app.buttons["progress-tab-now"].tap()
            XCTAssertTrue(app.staticTexts["What you are strengthening"].waitForExistence(timeout: 5))
            closeProgress()
        }
    }

    func test49StudySecondaryButtonsOpenRealDestinationsAndCollapse() {
        guard openStudyTab() else { return }
        expectStudyToolsRemoved()
        for (identifier, title, contentID) in [
            ("learning-mode-active-recall", "Active Recall", "Begin recall"),
            ("learning-mode-interview", "Interview Mode", "Start interview")
        ] {
            tapStudyButton(identifier)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 6))
            XCTAssertTrue(app.buttons[contentID].exists)
            XCTAssertTrue(app.buttons[contentID].isHittable,
                          "The setup action must be reachable when its sheet opens.")
            closeStudySheet(title)
        }
        revealStudyTools()
        for (identifier, title) in [
            ("learning-connections", "Connections"),
            ("learning-document-topics", "Document Topics"),
            ("learning-search-ideas", "Search ideas")
        ] {
            tapStudyButton(identifier)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 6))
            if identifier == "learning-search-ideas" {
                XCTAssertTrue(app.textFields["knowledge-search-field"].exists)
            }
            closeStudySheet(title)
        }
        tapStudyButton("learning-more")
        XCTAssertEqual(app.buttons["learning-more"].value as? String, "Collapsed")
        expectStudyToolsRemoved()
        XCTAssertFalse(app.buttons["learning-connections"].isHittable,
                       "Collapsed tools must not remain interactive behind other content.")
        // A structural removal must still support repeated insertion and real navigation.
        for identifier in ["learning-connections", "learning-document-topics", "learning-search-ideas"] {
            revealStudyTools()
            for tool in studyToolIDs {
                XCTAssertEqual(app.buttons.matching(identifier: tool).count, 1,
                               "Reopening More must restore exactly one native button per tool.")
            }
            tapStudyButton("learning-more")
            expectStudyToolsRemoved()
            XCTAssertFalse(app.buttons[identifier].isHittable)
        }
        revealStudyTools()
        tapStudyButton("learning-connections")
        XCTAssertTrue(app.navigationBars["Connections"].waitForExistence(timeout: 6))
        closeStudySheet("Connections")
        tapStudyButton("learning-more")
        expectStudyToolsRemoved()
    }

    private var studyToolIDs: [String] {
        ["learning-connections", "learning-document-topics", "learning-search-ideas"]
    }

    private func expectStudyToolsRemoved(file: StaticString = #filePath, line: UInt = #line) {
        // Wait for the real hierarchy update, never for an arbitrary sleep or a second tap.
        let removed = NSPredicate { _, _ in
            self.app.buttons["learning-more"].value as? String == "Collapsed" &&
                self.studyToolIDs.allSatisfy {
                    self.app.descendants(matching: .any).matching(identifier: $0).count == 0
                }
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: removed, object: nil)], timeout: 4)
        guard result == .completed else {
            attachAccessibilityTree(name: "collapsed-study-tools-remain")
            XCTFail("Collapsed tools must be absent from the accessibility hierarchy, not merely transparent or disabled.",
                    file: file, line: line)
            return
        }
        for identifier in studyToolIDs {
            XCTAssertFalse(app.buttons[identifier].exists, file: file, line: line)
            XCTAssertFalse(app.buttons[identifier].isHittable, file: file, line: line)
        }
    }

    private func closeStudySheet(_ title: String) {
        let done = app.navigationBars[title].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 6))
    }
}
