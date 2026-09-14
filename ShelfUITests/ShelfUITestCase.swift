import XCTest

class ShelfUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-library"]
        app.launchEnvironment["LEU_UI_DIAGNOSTICS"] = "1"
        app.launchEnvironment["LEU_PDF_DIAGNOSTICS"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 25))
    }

    override func tearDownWithError() throws {
        if (testRun?.totalFailureCount ?? 0) > 0 {
            capture("failed-journey")
            attachAccessibilityTree(name: "failed-journey")
        }
    }

    func openReactNotes() {
        app.buttons["book-React Notes"].tap()
        assertExists("reader-screen", timeout: 10)
        assertReaderButton(identifier: "next-page", label: "Next page", timeout: 10)
        let page = pageControl()
        guard page.waitForExistence(timeout: 10) else {
            attachAccessibilityTree(name: "missing-reader-page-control")
            XCTFail("Missing reader page control")
            return
        }
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func readerButton(identifier: String, label: String) -> XCUIElement {
        let byID = app.buttons[identifier]
        if byID.exists { return byID }
        return firstHittableButton(label: label)
    }

    func readerTool(identifier: String, label: String) -> XCUIElement {
        let byID = app.buttons[identifier]
        if byID.exists { return byID }
        return firstHittableButton(label: label)
    }

    /// Stable control lookup for SwiftUI surfaces whose accessibility identifier may
    /// be exported on the semantic element rather than XCUI's concrete Button query.
    func identifiedControl(_ identifier: String, label: String? = nil) -> XCUIElement {
        let button = app.buttons[identifier]
        if button.exists { return button }
        let any = element(identifier)
        if any.exists { return any }
        if let label { return firstHittableButton(label: label) }
        return any
    }

    func readerTextControl() -> XCUIElement {
        let text = app.buttons["reader-tool-text"]
        if text.exists { return text }
        let zoom = app.buttons["reader-tool-zoom"]
        if zoom.exists { return zoom }
        let textLabel = app.buttons["Text size"]
        if textLabel.exists { return textLabel }
        return app.buttons["PDF zoom"]
    }

    func openReaderOptions() {
        let menu = app.buttons["Reader options"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5)); menu.tap()
    }

    func openAppearance() {
        openReaderOptions()
        XCTAssertTrue(app.buttons["Reading appearance"].waitForExistence(timeout: 5))
        app.buttons["Reading appearance"].tap()
    }

    func enterFocusMode() {
        openReaderOptions()
        XCTAssertTrue(app.buttons["Focus mode"].waitForExistence(timeout: 5))
        app.buttons["Focus mode"].tap()
    }

    func openLibrarySettings() {
        let options = app.buttons["library-options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5)); options.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5)); app.buttons["Settings"].tap()
    }

    func pageControl() -> XCUIElement {
        let byID = app.descendants(matching: .any)["reader-page-count"]
        if byID.exists { return byID }
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "Page ")
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    func scrubberControl() -> XCUIElement {
        let byID = app.sliders["reader-scrubber"]
        if byID.exists { return byID }
        return app.sliders["Page scrubber"]
    }

    /// Gesture tests intentionally use a stable coordinate inside the reading viewport instead
    /// of depending on a synthetic accessibility element. This drives the same hit-tested surface
    /// a finger reaches on-device and works for both SwiftUI Read mode and PDFKit Original mode.
    func swipeReaderContentLeft() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func swipeReaderContentRight() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.82, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    func expectPage(_ expected: String, on element: XCUIElement) {
        print("[leu-gesture-ui] expected=\(expected) labelBefore=\(element.label) valueBefore=\(String(describing: element.value))")
        let predicate = NSPredicate(format: "label == %@ OR value == %@", expected, expected)
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: 6)
        print("[leu-gesture-ui] labelAfter=\(element.label) valueAfter=\(String(describing: element.value))")
    }

    func assertExists(_ identifier: String, timeout: TimeInterval = 10,
                      file: StaticString = #filePath, line: UInt = #line) {
        guard element(identifier).waitForExistence(timeout: timeout) else {
            attachAccessibilityTree(name: "missing-\(identifier)")
            XCTFail("Missing accessibility identifier: \(identifier)", file: file, line: line)
            return
        }
    }

    func assertReaderButton(identifier: String, label: String, timeout: TimeInterval = 10,
                            file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        var candidate = readerButton(identifier: identifier, label: label)
        while !candidate.exists && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            candidate = readerButton(identifier: identifier, label: label)
        }
        guard candidate.exists else {
            attachAccessibilityTree(name: "missing-\(identifier)-reader-control")
            XCTFail("Missing reader control: \(identifier) / \(label)", file: file, line: line)
            return
        }
    }

    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func attachAccessibilityTree(name: String) {
        let tree = app.debugDescription
        print("LEU_UI_TREE_BEGIN: \(name)")
        print(tree)
        print("LEU_UI_TREE_END: \(name)")
        let attachment = XCTAttachment(string: tree)
        attachment.name = "\(name)-accessibility-tree"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func firstHittableButton(label: String) -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "label == %@", label))
        for candidate in query.allElementsBoundByIndex where candidate.isHittable {
            return candidate
        }
        return query.firstMatch
    }
}

// Shared study journey for all UI regression subclasses.
extension ShelfUITestCase {
    func openStudyAndStart(minutes: String) {
        let study = app.buttons["primary-learn"]
        XCTAssertTrue(study.waitForExistence(timeout: 8)); study.tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 10))
        revealStudySessionOptions()
        if app.buttons["learn-topic-react"].waitForExistence(timeout: 20) { tapStudyButton("learn-topic-react") }
        // LazyVGrid does not realize the duration buttons until scrolled onscreen.
        let duration = revealStudyButton(minutes)
        XCTAssertTrue(duration.exists && duration.isHittable)
        tapStudyButton(minutes)
        let start = app.buttons["start-learning-session"]
        XCTAssertTrue(waitUntilEnabled(start, timeout: 35)); tapStudyButton("start-learning-session")
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 12))
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

}
