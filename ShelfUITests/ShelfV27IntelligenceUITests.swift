import XCTest

/// New V27 journeys only. Uses bundled PDFs and production admission/providers.
/// No seeded learner result, model answer, or connection substitutes.
final class ShelfV27IntelligenceUITests: ShelfUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--uitesting"]
        app.launchEnvironment["LEU_UI_DIAGNOSTICS"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 25))
    }
    /// Teach Leu lives inside the collapsed "Passage tools" DisclosureGroup,
    /// so it must be expanded before its row becomes hittable.
    private func openTeachLeu() {
        let tools = identifiedControl("learning-passage-tools", label: "Passage tools")
        XCTAssertTrue(tools.waitForExistence(timeout: 10) && tools.isHittable); tools.tap()
        // The expanded row already fits on screen; tapReady's blind swipe-on-retry
        // logic can scroll straight past it once the disclosure animation settles.
        let teach = app.buttons["learning-action-teach-leu"]
        XCTAssertTrue(teach.waitForExistence(timeout: 5), "Teach Leu row never appeared after expanding Passage tools")
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: teach)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed, "Teach Leu row did not become hittable after expanding Passage tools")
        teach.tap()
    }
    func testTeachReactSourceRoundTripAndResumeActualThought() {
        pageThree("React Notes")
        openTeachLeu()
        let editor = app.textViews["teach-leu-explanation"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10)); editor.tap()
        // Clear only the thought being edited in this isolated V27 test app.
        if let value = editor.value as? String, !value.isEmpty { editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)) }
        editor.typeText("Keys tell React which item is which when a list changes.")
        app.swipeUp()
        tapReady("teach-leu-compare")
        XCTAssertTrue(element("teach-leu-result").waitForExistence(timeout: 40))
        XCTAssertTrue(app.staticTexts["YOU CAPTURED"].exists)
        XCTAssertTrue(app.staticTexts["WORTH ADDING"].exists)
        capture("v27-teach-react-comparison")
        tapReady("teach-leu-view-source")
        expectPage("Page 3 of 4", on: pageControl())
        capture("v27-teach-exact-source")
        tapReady("reader-context-return")
        XCTAssertTrue(element("teach-leu-screen").waitForExistence(timeout: 10))
        app.navigationBars["Teach Leu"].buttons["Done"].tap()
        app.navigationBars["Learn from this"].buttons["Done"].tap()
        tapReady("resume-understanding-thought")
        XCTAssertEqual(app.textViews["teach-leu-explanation"].value as? String,
            "Keys tell React which item is which when a list changes.")
        capture("v27-resumed-thought")
    }
    func testV291TeachSupportedSubsetMixedClauseEditAndReopen() {
        pageThree("React Notes"); openTeachLeu()
        let concise = "Keys tell React which item is which when a list changes."
        let unsupported = "A stable key prevents server outages."
        func replaceDraft(_ text: String) {
            for _ in 0..<8 {
                let editor = app.textViews["teach-leu-explanation"]
                if editor.exists && editor.isHittable {
                    editor.tap()
                    if let old = editor.value as? String, !old.isEmpty {
                        editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
                    }
                    editor.typeText(text); app.swipeUp(); return
                }
                app.scrollViews.firstMatch.swipeDown()
            }
            XCTFail("The editable thought must remain reachable.")
        }
        replaceDraft(concise); tapReady("teach-leu-compare")
        XCTAssertTrue(element("teach-leu-result").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["YOU CAPTURED"].exists)
        XCTAssertTrue(app.staticTexts["WORTH ADDING"].exists)
        XCTAssertFalse(app.staticTexts["NOT ESTABLISHED HERE"].exists)
        capture("v291-teach-supported-subset")
        replaceDraft(concise + " " + unsupported); tapReady("teach-leu-compare")
        XCTAssertTrue(app.staticTexts["NOT ESTABLISHED HERE"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["YOU CAPTURED"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "“" + unsupported + "”")).firstMatch.exists)
        capture("v291-teach-mixed-clauses")
        tapReady("teach-leu-view-source"); expectPage("Page 3 of 4", on: pageControl())
        capture("v291-teach-exact-source"); tapReady("reader-context-return")
        XCTAssertTrue(element("teach-leu-screen").waitForExistence(timeout: 10))
        replaceDraft(concise); tapReady("teach-leu-compare")
        XCTAssertTrue(element("teach-leu-result").waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["NOT ESTABLISHED HERE"].exists)
        app.navigationBars["Teach Leu"].buttons["Done"].tap()
        app.navigationBars["Learn from this"].buttons["Done"].tap()
        tapReady("resume-understanding-thought")
        XCTAssertEqual(app.textViews["teach-leu-explanation"].value as? String, concise)
        capture("v291-teach-reopened-edited-draft")
    }
    func testReactKeysLabChangesIdentityWithExactSourceReturn() {
        pageThree("React Notes"); tapReady("learning-action-try-it")
        tapReady("try-it-reorder")
        XCTAssertEqual(app.staticTexts["try-it-outcome"].label, "The state moved with the same item.")
        capture("v27-keys-stable-identities")
        let index = app.segmentedControls.buttons["Index keys"]
        XCTAssertTrue(index.exists && index.isHittable); index.tap()
        tapReady("try-it-reorder")
        XCTAssertEqual(app.staticTexts["try-it-outcome"].label, "The position kept the state; another item now occupies it.")
        capture("v27-keys-position-state")
        tapReady("try-it-view-source")
        expectPage("Page 3 of 4", on: pageControl()); capture("v27-keys-source")
        tapReady("reader-context-return")
        XCTAssertTrue(element("try-it-screen").waitForExistence(timeout: 10))
    }
    func testCacheLabReuseStalenessAndRecompute() {
        pageThree("System Design"); tapReady("learning-action-try-it")
        tapReady("try-it-reuse")
        XCTAssertEqual(app.staticTexts["try-it-copy"].label, "Stored copy: 1")
        tapReady("try-it-change-original"); tapReady("try-it-reuse")
        XCTAssertEqual(app.staticTexts["try-it-original"].label, "Original: 2")
        XCTAssertEqual(app.staticTexts["try-it-copy"].label, "Stored copy: 1")
        capture("v27-cache-stale-copy")
        tapReady("try-it-recompute")
        XCTAssertEqual(app.staticTexts["try-it-copy"].label, "Stored copy: 2")
        capture("v27-cache-recomputed-copy")
        tapReady("try-it-view-source"); expectPage("Page 3 of 4", on: pageControl())
        capture("v27-cache-exact-source")
    }
    func testV3AdmittedQuestionStudyFeedbackAndSourceRoundTrip() {
        pageThree("React Notes")
        let tools = identifiedControl("learning-passage-tools", label: "Passage tools")
        XCTAssertTrue(tools.exists && tools.isHittable); tools.tap()
        tapReady("learning-action-understand")
        XCTAssertTrue(element("lens-v3-explanation").waitForExistence(timeout: 100),
            "A persisted V3 question is required. Availability or a raw response cannot satisfy this gate.")
        capture("v27-question-admission-at-source")
        app.navigationBars["Understanding Lens"].buttons["Done"].tap()
        tapReady("close-reader"); openStudyLandingAfterRestoration()
        revealStudySessionOptions(); tapStudyButton("learn-topic-react"); tapStudyButton("30 minutes")
        let start = app.buttons["start-learning-session"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: start)], timeout: 30), .completed)
        tapStudyButton("start-learning-session")
        for _ in 0..<20 {
            if element("study-v3-question-page-3").exists { break }
            if element("session-complete-screen").exists { break }
            completeCurrentStudyActivity()
        }
        XCTAssertTrue(element("study-v3-question-page-3").exists, "The actual plan must include the admitted V3 React p.3 question.")
        let prompt = app.staticTexts["question-prompt"].label
        XCTAssertFalse(prompt.hasPrefix("What is ")); XCTAssertFalse(prompt.hasPrefix("What does "))
        tapStudyButton("question-option-0", scrollID: "study-activity")
        tapStudyButton("commit-answer", scrollID: "study-activity")
        XCTAssertTrue(app.staticTexts["question-supporting-quote"].waitForExistence(timeout: 8))
        let quote = app.staticTexts["question-supporting-quote"].label
        XCTAssertFalse(quote.isEmpty); capture("v27-question-feedback")
        tapStudyButton("view-question-source", scrollID: "study-activity")
        expectPage("Page 3 of 4", on: pageControl()); capture("v27-question-exact-source")
        tapReady("reader-context-return")
        XCTAssertEqual(app.staticTexts["question-prompt"].label, prompt)
        XCTAssertEqual(app.staticTexts["question-supporting-quote"].label, quote)
        capture("v27-question-return"); app.buttons["End study session"].tap()
    }
    /// Physical-device acceptance probe for the embedded Qwen 2B runtime. Not part of
    /// the standing regression suite: requires the offline model already staged in the
    /// app container. Prints raw metrics for the certification report; asserts only
    /// that a real on-device generation actually completed.
    func testPhysicalDeviceOfflineQwenRealInference() {
        pageThree("React Notes"); openTeachLeu()
        let installedToggle = app.switches["Offline model"]
        guard installedToggle.waitForExistence(timeout: 10) else {
            capture("qwen-physical-no-toggle"); attachAccessibilityTree(name: "qwen-physical-no-toggle")
            XCTFail("Offline model toggle not present — model file is not staged in the app container"); return
        }
        if let value = installedToggle.value as? String, value == "0" { installedToggle.tap() }
        let editor = app.textViews["teach-leu-explanation"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10)); editor.tap()
        if let value = editor.value as? String, !value.isEmpty {
            editor.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        editor.typeText("Keys tell React which item is which when a list changes.")
        app.swipeUp()
        let start = Date()
        tapReady("teach-leu-compare")
        let resultAppeared = element("teach-leu-offline-result").waitForExistence(timeout: 180)
        let elapsed = Date().timeIntervalSince(start)
        print("[qwen-physical] wall_seconds=\(elapsed)")
        capture("qwen-physical-after-compare")
        attachAccessibilityTree(name: "qwen-physical-after-compare")
        if let provider = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Offline model")).firstMatch.label as String? {
            print("[qwen-physical] provider_label=\(provider)")
        }
        if let message = app.staticTexts.allElementsBoundByIndex.map(\.label).first(where: { $0.contains("offline") || $0.contains("Offline") || $0.contains("memory") || $0.contains("cool") || $0.contains("budget") }) {
            print("[qwen-physical] message=\(message)")
        }
        XCTAssertTrue(resultAppeared, "No real on-device Qwen generation was observed within 180s")
    }
    private func pageThree(_ book: String) {
        let tile = app.buttons["book-" + book]
        XCTAssertTrue(tile.waitForExistence(timeout: 25)); tile.tap()
        XCTAssertTrue(element("reader-screen").waitForExistence(timeout: 10))
        let read = app.segmentedControls.buttons["Read"]
        if read.exists && !read.isSelected { read.tap() }
        for _ in 0..<3 { let previous = readerButton(identifier: "previous-page", label: "Previous page"); if previous.isEnabled { previous.tap() } }
        for _ in 0..<2 { readerButton(identifier: "next-page", label: "Next page").tap() }
        expectPage("Page 3 of 4", on: pageControl())
        readerTool(identifier: "reader-tool-learn", label: "Study").tap()
        XCTAssertTrue(app.navigationBars["Learn from this"].waitForExistence(timeout: 10))
    }
    private func tapReady(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<7 {
            let target = app.buttons[id]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate { [weak self] _, _ in
                guard let self else { return false }
                let fresh = app.buttons[id]; return fresh.exists && fresh.isHittable
            }, object: nil)
            if XCTWaiter.wait(for: [ready], timeout: 1) == .completed {
                let fresh = app.buttons[id]; XCTAssertTrue(fresh.exists && fresh.isHittable, file: file, line: line); fresh.tap(); return
            }
            if !target.exists { _ = target.waitForExistence(timeout: 2) }
            app.scrollViews.firstMatch.swipeUp()
        }
        capture("v27-unreachable-" + id); attachAccessibilityTree(name: "v27-unreachable-" + id)
        XCTFail("Control never became reachable: " + id, file: file, line: line)
    }
}
