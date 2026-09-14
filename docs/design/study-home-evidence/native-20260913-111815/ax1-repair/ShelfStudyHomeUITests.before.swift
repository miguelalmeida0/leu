import XCTest

/// Real sample PDFs and ordinary reader actions; no injected learning state.
/// Run this class at default size and AX1. Attachments are evidence to inspect, not certification.
final class ShelfStudyHomeUITests: ShelfUITestCase {
    func testEmptyStudyFieldsAndExistingDestinations() {
        openStudyHome()
        XCTAssertTrue(app.buttons["study-continue-empty"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["No session yet"].exists)
        assertContentViewport()
        capture("01-study-empty-collapsed")
        capture("07-study-top")
        captureField("study-continue-field", name: "study-01-empty-continue")
        tapStudyButton("study-continue-empty")
        XCTAssertTrue(app.navigationBars["Active Recall"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Begin recall"].exists)
        app.navigationBars["Active Recall"].buttons["Done"].tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 6))

        captureField("study-fading-field", name: "study-03-fading")
        captureField("study-blind-spots-field", name: "study-04-blind-spots")
        capture("04-fading-blind-spots")
        captureField("study-labs-field", name: "study-05-labs")
        let lastLab = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "study-lab-")).allElementsBoundByIndex.last!
        let visibleLastLab = revealStudyButton(lastLab.identifier)
        assertClearance(visibleLastLab)
        capture("05-labs-last-row")
        capture("10-labs-last-row")
        let lab = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "study-lab-")).firstMatch
        XCTAssertTrue(lab.exists)
        let title = lab.label
        tapStudyButton(lab.identifier)
        XCTAssertTrue(app.buttons["Run"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Reset"].exists)
        XCTAssertFalse(title.isEmpty)
        capture("study-lab-destination")
        app.buttons["Close"].tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 6))

        revealStudySessionOptions()
        XCTAssertTrue(app.buttons["10 minutes"].exists)
        tapStudyButton("study-session-options")
        XCTAssertEqual(app.buttons["study-session-options"].value as? String, "Collapsed")
        XCTAssertFalse(app.buttons["start-learning-session"].exists)
    }

    func testContinueUsesRealRememberedSourceAndReturnsToReader() {
        openReactNotes()
        let originalPage = pageControl().label
        readerTool(identifier: "reader-tool-learn", label: "Study").tap()
        XCTAssertTrue(element("learning-object-actions").waitForExistence(timeout: 5))
        let remember = identifiedControl("learning-action-remember", label: "Remember")
        XCTAssertTrue(remember.waitForExistence(timeout: 5)); remember.tap()
        let back = app.buttons["Back to library"]
        XCTAssertTrue(back.waitForExistence(timeout: 8)); back.tap()
        openStudyHome()
        XCTAssertTrue(app.buttons["study-continue-populated"].waitForExistence(timeout: 8),
                      "Remember must supply the real source-bound timeline event.")
        XCTAssertFalse(app.buttons["study-continue-empty"].exists)
        captureField("study-continue-field", name: "02-study-populated-collapsed")
        let title = app.staticTexts["study-continue-title"]
        let excerpt = app.staticTexts["study-continue-excerpt"]
        XCTAssertTrue(title.exists); XCTAssertTrue(excerpt.exists)
        XCTAssertNotEqual(title.label, excerpt.label, "The source excerpt must not become the hero heading.")
        XCTAssertLessThanOrEqual(excerpt.label.count, 161)
        XCTAssertTrue(app.staticTexts["Continue at source"].exists)
        tapStudyButton("study-continue-populated")
        XCTAssertTrue(element("reader-screen").waitForExistence(timeout: 8))
        expectPage(originalPage, on: pageControl())
        capture("study-continue-exact-source")
    }

    func testBuilderSubjectTimeAndStartRemainAboveNavigation() {
        openStudyHome()
        revealStudySessionOptions()
        XCTAssertTrue(app.buttons["learn-topic-react"].waitForExistence(timeout: 25))
        let subject = revealStudyButton("learn-topic-react")
        assertClearance(subject)
        capture("03-builder-expanded")
        capture("08-builder-subjects")
        tapStudyButton("learn-topic-react")
        tapStudyButton("10 minutes")
        let start = app.buttons["start-learning-session"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: start)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 35), .completed)
        captureField("study-time-and-start", name: "09-builder-time-and-start")
        assertClearance(start)
        for duration in ["5 minutes", "10 minutes", "20 minutes", "30 minutes"] {
            assertClearance(app.buttons[duration])
        }
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 12))
    }

    func testProgressLastRowRemainsAboveNavigation() {
        openStudyHome()
        XCTAssertTrue(app.buttons["study-session-options"].waitForExistence(timeout: 8))
        tapStudyButton("learning-progress")
        expectProgressOpen()
        let topics = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress-topic-"))
        XCTAssertTrue(topics.firstMatch.waitForExistence(timeout: 25))
        let lastTopic = topics.allElementsBoundByIndex.last!
        let lastRow = revealStudyButton(lastTopic.identifier, scrollID: "progress-now-scroll")
        assertClearance(lastRow)
        capture("06-progress-last-row")
        closeProgress()
    }

    private func assertContentViewport() {
        let content = element("root-content-viewport")
        let chrome = element("root-bottom-chrome-frame")
        XCTAssertTrue(content.waitForExistence(timeout: 5))
        XCTAssertTrue(chrome.exists)
        XCTAssertGreaterThan(content.frame.height, 0)
        XCTAssertGreaterThan(content.frame.minY, app.frame.minY, "Study must respect the top safe area.")
        XCTAssertLessThanOrEqual(content.frame.maxY, chrome.frame.minY)
        let status = app.statusBars.firstMatch
        if status.exists { XCTAssertGreaterThanOrEqual(content.frame.minY, status.frame.maxY) }
    }

    private func assertClearance(_ control: XCUIElement) {
        assertContentViewport()
        XCTAssertTrue(control.exists)
        XCTAssertTrue(control.isHittable)
        XCTAssertTrue(element("root-content-viewport").frame.contains(control.frame),
                      "The complete control must fit in the visible content region: \(control.identifier)")
        XCTAssertLessThanOrEqual(control.frame.maxY, element("root-bottom-chrome-frame").frame.minY - 8)
    }

    private func openStudyHome() {
        XCTAssertTrue(app.buttons["primary-learn"].waitForExistence(timeout: 8))
        app.buttons["primary-learn"].tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 8))
        assertContentViewport()
    }

    private func captureField(_ identifier: String, name: String) {
        let field = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        let viewportElement = element("learn-screen-frame")
        for _ in 0..<14 {
            let viewport = studyViewport(viewportElement)
            let frame = field.frame
            // Tall AX fields need multiple real viewport captures, never a scaled composite.
            let fits = frame.height <= viewport.height
            let topVisible = frame.minY >= viewport.minY && frame.minY < viewport.minY + viewport.height * 0.55
            if (fits && viewport.contains(frame)) || (!fits && topVisible) {
                capture(name)
                if frame.maxY > viewport.maxY {
                    var lastBottom = frame.minY
                    for index in 1...8 {
                        dragStudyViewport(studyViewport(viewportElement), upward: true)
                        capture(name + "-continued-\(index)")
                        let current = field.frame
                        if current.maxY <= studyViewport(viewportElement).maxY { break }
                        if current.minY == lastBottom { break }
                        lastBottom = current.minY
                    }
                    XCTAssertLessThanOrEqual(field.frame.maxY, studyViewport(viewportElement).maxY,
                                             "All of the tall field must be reachable by scrolling.")
                }
                attachAccessibilityTree(name: name)
                return
            }
            // Position the field with a measured drag, avoiding AX1 overshoot/oscillation.
            let delta = frame.minY - (viewport.minY + 20)
            let distance = min(abs(delta), viewport.height * 0.45)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let startY = delta > 0 ? viewport.maxY - 20 : viewport.minY + 20
            let endY = startY + (delta > 0 ? -distance : distance)
            origin.withOffset(CGVector(dx: viewport.midX, dy: startY))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: viewport.midX, dy: endY)))
        }
        XCTFail("Could not place \(identifier) inside the actual Study viewport for capture.")
    }
}
