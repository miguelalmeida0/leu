import XCTest

/// Real reader navigation and real provider only. No library reset or seeded answer.
final class ShelfExplainLikeTenUITests: ShelfUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["LEU_EXPLANATION_TRACE"] = "1"
        app.launchEnvironment["LEU_EXPLANATION_TRACE_FINGERPRINT"] = "7d42381fcbb2e1c6252457bced1a3970015142adbac4a556fb35d7ab4e318640"
        app.launchEnvironment["LEU_EXPLANATION_TRACE_PAGE"] = "3"
        app.launchEnvironment["LEU_EXPLANATION_FORCE_GENERATION"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 25))
    }

    func testExplainActionUsesTheCurrentCanonicalPassageAndClosesCleanly() {
        openReactNotes()
        let read = app.segmentedControls.buttons["Read"]
        if read.exists && !read.isSelected { read.tap() }
        for _ in 0..<3 {
            let previous = readerButton(identifier: "previous-page", label: "Previous page")
            if previous.isEnabled { previous.tap() }
        }
        for _ in 0..<2 { readerButton(identifier: "next-page", label: "Next page").tap() }
        expectPage("Page 3 of 4", on: pageControl())
        readerTool(identifier: "reader-tool-learn", label: "Study").tap()
        let action = app.buttons["learning-action-explain-like-ten"]
        XCTAssertTrue(action.waitForExistence(timeout: 10)); action.tap()
        XCTAssertTrue(element("explain-like-ten").waitForExistence(timeout: 10))
        app.buttons["explain-toggle-passage"].tap()
        let passage = app.staticTexts["explain-original-passage"]
        XCTAssertTrue(passage.waitForExistence(timeout: 10))
        XCTAssertTrue(passage.label.contains("Keys describe identity"))
        XCTAssertTrue(passage.label.contains("<Row key={item.id} item={item} />"))
        XCTAssertFalse(passage.label.contains("Key describ identit"))
        capture("explain-page3-original-passage")
        app.navigationBars["Explain like I'm 10"].buttons["Done"].tap()
        XCTAssertFalse(element("explain-like-ten").exists)
        expectPage("Page 3 of 4", on: pageControl())
    }

    func testRealExplanationAndRefinementsStayOnPageThree() {
        openReactNotes()
        let read = app.segmentedControls.buttons["Read"]
        if read.exists && !read.isSelected { read.tap() }
        for _ in 0..<3 {
            let previous = readerButton(identifier: "previous-page", label: "Previous page")
            if previous.isEnabled { previous.tap() }
        }
        for _ in 0..<2 { readerButton(identifier: "next-page", label: "Next page").tap() }
        expectPage("Page 3 of 4", on: pageControl())
        // Select the real paragraph used by the Mac probe, through the existing reader gesture.
        let paragraph = element("read-block-2-1")
        XCTAssertTrue(paragraph.waitForExistence(timeout: 10))
        XCTAssertEqual(normalize(paragraph.label), normalize(originalPassage))
        capture("explain-page3-before-generation")
        paragraph.press(forDuration: 0.6)
        let studySheet = app.navigationBars["Learn from this"]
        XCTAssertTrue(studySheet.waitForExistence(timeout: 10))
        studySheet.buttons["Done"].tap()
        readerTool(identifier: "reader-tool-learn", label: "Study").tap()
        let action = app.buttons["learning-action-explain-like-ten"]
        XCTAssertTrue(action.waitForExistence(timeout: 10)); action.tap()
        let first = app.staticTexts["explain-block-0"]
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { [self] _, _ in
            first.exists || element("explain-failed").exists || element("explain-unavailable").exists || element("explain-needs-context").exists
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 90), .completed)
        capture("explain-real-result-or-blocker")
        captureAttemptTrace("standard")
        attachAccessibilityTree(name: "explain-real-result-or-blocker")
        XCTAssertTrue(first.exists, "A failed/unavailable model or refusal cannot satisfy the supported-passage quality gate.")
        XCTAssertFalse(first.label.isEmpty)
        assertOriginalPassage()
        capture("explain-page3-real-standard-passing")
        revealAndTap("explain-even-simpler")
        let refinement = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "evenSimpler"),
            object: app.staticTexts["explain-provenance"])
        let simplerResult = XCTWaiter.wait(for: [refinement], timeout: 90)
        captureAttemptTrace("evenSimpler")
        XCTAssertEqual(simplerResult, .completed)
        assertOriginalPassage()
        capture("explain-page3-even-simpler-passing")
        revealAndTap("explain-show-example")
        let example = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "withExample"),
            object: app.staticTexts["explain-provenance"])
        let exampleResult = XCTWaiter.wait(for: [example], timeout: 90)
        captureAttemptTrace("withExample")
        XCTAssertEqual(exampleResult, .completed)
        XCTAssertTrue(app.staticTexts["Illustration"].exists)
        assertOriginalPassage()
        capture("explain-page3-illustration")
        app.navigationBars["Explain like I'm 10"].buttons["Done"].tap()
        XCTAssertFalse(element("explain-like-ten").exists)
        expectPage("Page 3 of 4", on: pageControl())
        capture("explain-page3-return-passing")
    }

    private let originalPassage = """
    A stable key helps React match an item to its previous
    instance within a list of siblings. Reordering should
    not make one item inherit the local state of another.
    """

    private func normalize(_ text: String) -> String { text.split(whereSeparator: \.isWhitespace).joined(separator: " ") }

    private func assertOriginalPassage() {
        revealAndTap("explain-toggle-passage")
        XCTAssertEqual(normalize(app.staticTexts["explain-original-passage"].label), normalize(originalPassage))
        XCTAssertEqual(app.staticTexts["explain-source-label"].label, "React Notes · p. 3")
        revealAndTap("explain-toggle-passage")
    }

    private func revealAndTap(_ identifier: String) {
        let button = app.buttons[identifier]
        if !button.isHittable {
            for _ in 0..<5 where !button.isHittable { app.scrollViews.firstMatch.swipeDown() }
            for _ in 0..<8 where !button.isHittable { app.scrollViews.firstMatch.swipeUp() }
        }
        XCTAssertTrue(button.isHittable, "Cannot reach \(identifier)"); button.tap()
    }

    private func captureAttemptTrace(_ mode: String) {
        revealAndTap("Development diagnostics")
        let trace = app.staticTexts["explain-attempt-trace"]
        XCTAssertTrue(trace.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(string: trace.label)
        attachment.name = "explanation-production-attempts-\(mode)"
        attachment.lifetime = .keepAlways; add(attachment)
        // Attach the bytes authored and flushed by the production controller. XCTest
        // never synthesizes a generation artifact, including when workspace mirroring fails.
        let prefix = "Artifact flushed: "
        let paths = trace.label.components(separatedBy: "\n").filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
        var attached = 0
        for path in paths where FileManager.default.fileExists(atPath: path) {
            let file = XCTAttachment(contentsOfFile: URL(fileURLWithPath: path))
            file.name = "explanation-production-request-\(mode)-copy-\(attached).json"
            file.lifetime = .keepAlways; add(file)
            attached += 1
        }
        capture("explain-development-diagnostics-\(mode)")
        XCTAssertGreaterThan(attached, 0, "Production trace was not readable; inspect Development diagnostics write status.")
        // Collapse before taking the visible explanation screenshot.
        revealAndTap("Development diagnostics")
    }
}
