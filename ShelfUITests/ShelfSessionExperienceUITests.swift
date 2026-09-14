import XCTest

/// Uses the existing isolated UI-test library; never resets or reseeds the simulator.
final class ShelfSessionExperienceUITests: ShelfUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["LEU_UI_DIAGNOSTICS"] = "1"
        app.launch()
        // An unfinished test-library session may restore directly into Study on launch.
        // Enter through the persistent primary navigation rather than requiring Library.
        XCTAssertTrue(app.buttons["primary-learn"].waitForExistence(timeout: 25))
        app.buttons["primary-learn"].tap()
        let ready = NSPredicate { _, _ in
            self.element("learn-screen").exists || self.element("study-session-screen").exists ||
                self.element("session-complete-screen").exists
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 25), .completed)
        if app.buttons["End study session"].waitForExistence(timeout: 5) {
            app.buttons["End study session"].tap()
        }
        if app.buttons["session-summary-done"].exists {
            tapStudyButton("session-summary-done", scrollID: "session-summary")
        }
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 10))
    }

    func testTypedRecallSurvivesExactSourceRoundTrip() {
        beginRecall()
        let draft = "I remember the idea in my own words.\nThis is my second line."
        let editor = app.textViews["recall-typed-answer"]
        XCTAssertTrue(editor.waitForExistence(timeout: 8))
        scrollTo(editor); editor.tap(); editor.typeText(draft)
        // Tapping outside the editor through the real Reveal action dismisses the keyboard.
        tapActivity("recall-reveal-source")
        let answer = app.staticTexts["recall-your-answer"]
        XCTAssertEqual(answer.label, draft)
        scrollTo(answer); capture("session-recall-answer-comparison")
        sourceRoundTrip()
        revealAfterReconstructionIfNeeded()
        XCTAssertEqual(answer.label, draft)
        scrollTo(answer); capture("session-recall-draft-after-source")
        let before = app.staticTexts["study-progress"].label
        tapActivity("recall-rating-difficult")
        expectProgressChange(from: before)
    }

    func testUnknownSurvivesSourceAndResetsOnNextObject() {
        beginRecall()
        tapActivity("recall-dont-know")
        XCTAssertTrue(app.buttons["recall-dont-know"].isSelected)
        capture("session-recall-unknown-selected")
        tapActivity("recall-reveal-source")
        XCTAssertEqual(app.staticTexts["recall-your-answer"].label, "You marked this one as not known yet.")
        sourceRoundTrip()
        if app.buttons["recall-reveal-source"].exists {
            XCTAssertTrue(app.buttons["recall-dont-know"].isSelected)
        }
        revealAfterReconstructionIfNeeded()
        XCTAssertEqual(app.staticTexts["recall-your-answer"].label, "You marked this one as not known yet.")
        scrollTo(app.staticTexts["recall-your-answer"]); capture("session-recall-unknown-after-source")
        let before = app.staticTexts["study-progress"].label
        tapActivity("recall-rating-forgot")
        expectProgressChange(from: before)
        XCTAssertFalse(app.buttons["recall-dont-know"].isSelected)
        XCTAssertEqual(app.textViews["recall-typed-answer"].value as? String, "")
        scrollTo(app.textViews["recall-typed-answer"]); capture("session-recall-next-object-reset")
    }

    func testMCQPredictionCommitFeedbackAndSourceRoundTrip() {
        prepareAcceptedReactQuestions()
        beginStudy()
        advanceToAcceptedQuestion()
        XCTAssertTrue(app.staticTexts["question-prompt"].waitForExistence(timeout: 20))
        let original = app.staticTexts["question-prompt"].label
        XCTAssertFalse(app.buttons["question-confidence-certain"].exists,
                       "Confidence follows choosing an answer.")
        tapActivity("question-option-0")
        tapActivity("question-confidence-certain")
        XCTAssertEqual(app.buttons["question-confidence-certain"].value as? String, "Selected")
        capture("session-mcq-confidence-prediction")
        tapActivity("commit-answer")
        let quote = app.staticTexts["question-supporting-quote"]
        XCTAssertTrue(quote.waitForExistence(timeout: 8)); XCTAssertFalse(quote.label.isEmpty)
        let quotedSource = quote.label
        let selectedOutcome = app.buttons["question-option-0"].value as? String
        XCTAssertTrue(selectedOutcome?.contains("Your answer") == true)
        XCTAssertFalse(app.buttons["question-option-0"].isEnabled)
        scrollTo(quote); capture("session-mcq-source-feedback")
        tapActivity("view-question-source")
        XCTAssertTrue(element("reader-screen").waitForExistence(timeout: 10))
        capture("session-mcq-exact-source")
        returnFromSource()
        XCTAssertEqual(app.staticTexts["question-prompt"].label, original)
        XCTAssertEqual(quote.label, quotedSource)
        XCTAssertEqual(app.buttons["question-option-0"].value as? String, selectedOutcome)
        XCTAssertFalse(app.buttons["question-option-0"].isEnabled)
        XCTAssertFalse(app.buttons["commit-answer"].exists)
        scrollTo(quote); capture("session-mcq-committed-return")
    }

    func testReconstructionChecksUpdateUsingAccessibleControls() {
        beginStudy()
        // A 30-minute React plan includes its real reconstruction activity. Traverse the
        // actual preceding activities; no injected session or forced completion.
        for _ in 0..<30 {
            if app.staticTexts["mini-lab-progress"].exists { break }
            finishCurrentActivity()
        }
        XCTAssertTrue(app.staticTexts["mini-lab-progress"].exists, "The real plan must reach reconstruction.")
        let expected = ["Element type", "Key", "Position among siblings", "Preserved instance"]
        // This is the catalog's React identity order, not an answer shown to the learner.
        // First create a known partial arrangement using only native move controls.
        arrange([expected[0], expected[2], expected[1], expected[3]])
        XCTAssertEqual(app.staticTexts["mini-lab-progress"].label, "2 of 4 in place")
        XCTAssertEqual(element("mini-lab-step-0").value as? String, "Confirmed correct")
        XCTAssertEqual(element("mini-lab-step-1").value as? String, "Unresolved")
        XCTAssertEqual(element("mini-lab-step-2").value as? String, "Unresolved")
        XCTAssertFalse(element("lab-scenario").exists)
        scrollTo(element("mini-lab-step-0")); capture("session-reconstruction-partial-checks")
        tapActivity("mini-lab-down-0")
        XCTAssertEqual(element("mini-lab-step-1").value as? String, "Unresolved",
                       "Moving the previously correct first step must immediately remove its check.")
        XCTAssertFalse(element("lab-scenario").exists)
        capture("session-reconstruction-check-cleared")
        arrange(expected)
        XCTAssertEqual(app.staticTexts["mini-lab-progress"].label, "4 of 4 in place")
        for i in 0..<4 { XCTAssertEqual(element("mini-lab-step-\(i)").value as? String, "Confirmed correct") }
        XCTAssertTrue(element("lab-scenario").exists)
        scrollTo(element("mini-lab-step-0")); capture("session-reconstruction-solved")
    }

    func testCompleteSessionReportsRealActivitiesAndReturnsToStudy() {
        beginRecall()
        let progress = app.staticTexts["study-progress"].label
        let total = Int(progress.components(separatedBy: " of ").last ?? "")
        XCTAssertNotNil(total)
        var completed = 0
        for _ in 0..<12 {
            if element("session-complete-screen").exists { break }
            let before = app.staticTexts["study-progress"].label
            tapActivity("recall-reveal-source")
            tapActivity("recall-rating-forgot")
            completed += 1
            expectProgressChange(from: before)
        }
        XCTAssertTrue(element("session-complete-screen").waitForExistence(timeout: 8))
        XCTAssertEqual(completed, total)
        let headline = completed == 1 ? "One activity completed." : "\(completed) activities completed."
        XCTAssertEqual(app.staticTexts["session-summary-headline"].label, headline)
        XCTAssertTrue(element("session-summary-practised").exists)
        XCTAssertTrue(element("session-summary-revisit").exists)
        XCTAssertEqual(app.buttons["session-summary-primary"].label, "Review what you marked")
        capture("session-complete-real-record")
        tapStudyButton("session-summary-primary", scrollID: "session-summary")
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 10))
        app.buttons["End study session"].tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 10))
        // Complete another real round to verify the secondary summary action as well.
        beginRecall()
        for _ in 0..<12 {
            if element("session-complete-screen").exists { break }
            let before = app.staticTexts["study-progress"].label
            tapActivity("recall-reveal-source"); tapActivity("recall-rating-knewIt")
            expectProgressChange(from: before)
        }
        XCTAssertTrue(element("session-complete-screen").waitForExistence(timeout: 8))
        XCTAssertFalse(element("session-summary-revisit").exists)
        XCTAssertEqual(app.buttons["session-summary-primary"].label, "Continue reading")
        tapStudyButton("session-summary-done", scrollID: "session-summary")
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 10))
        capture("session-complete-back-to-study")
    }

    private func beginRecall() {
        tapStudyButton("learning-mode-active-recall")
        let begin = app.buttons["Begin recall"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: begin)], timeout: 60), .completed)
        begin.tap()
        XCTAssertTrue(element("recall-card").waitForExistence(timeout: 10))
    }

    private func beginStudy() {
        revealStudySessionOptions()
        tapStudyButton("learn-topic-react")
        tapStudyButton("30 minutes")
        let start = app.buttons["start-learning-session"]
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: start)], timeout: 60), .completed)
        tapStudyButton("start-learning-session")
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 10))
    }

    private func sourceRoundTrip() {
        let source = app.staticTexts["recall-source-quote"].label
        let pageLabel = app.staticTexts["recall-source-page"].label
        let pageNumber = pageLabel.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        XCTAssertFalse(source.isEmpty); XCTAssertFalse(pageNumber.isEmpty)
        tapActivity("recall-view-source")
        XCTAssertTrue(element("reader-screen").waitForExistence(timeout: 10))
        XCTAssertTrue(pageControl().label.hasPrefix("Page \(pageNumber) of "))
        let excerpt = String(source.prefix(60))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", excerpt)).firstMatch.waitForExistence(timeout: 8), "The reader must expose the exact source excerpt.")
        capture("session-recall-exact-source")
        returnFromSource()
    }

    private func returnFromSource() {
        let back = identifiedControl("reader-context-return")
        XCTAssertTrue(back.waitForExistence(timeout: 8)); XCTAssertTrue(back.isHittable); back.tap()
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 10))
    }

    private func revealAfterReconstructionIfNeeded() {
        if app.buttons["recall-reveal-source"].exists { tapActivity("recall-reveal-source") }
    }

    private func tapActivity(_ id: String) { tapStudyButton(id, scrollID: "study-activity") }

    private func scrollTo(_ target: XCUIElement) {
        let frame = element("study-activity-frame")
        for _ in 0..<12 {
            let viewport = studyViewport(frame)
            if target.exists && target.isHittable && viewport.intersects(target.frame) { return }
            dragStudyViewport(viewport, upward: !target.exists || target.frame.midY > viewport.midY)
        }
        XCTFail("Session content is unreachable: \(target.identifier)")
    }

    private func expectProgressChange(from before: String) {
        let changed = NSPredicate { _, _ in
            self.element("session-complete-screen").exists || self.app.staticTexts["study-progress"].label != before
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: nil)], timeout: 10), .completed)
    }

    private func finishCurrentActivity() {
        let before = app.staticTexts["study-progress"].label
        if element("question-card").exists {
            tapActivity("question-option-0"); tapActivity("commit-answer"); tapActivity("recall-rating-difficult")
        } else if element("recall-card").exists {
            tapActivity("recall-reveal-source"); tapActivity("recall-rating-difficult")
        } else {
            XCTFail("Unexpected activity before reconstruction; the real React plan must include the lab.")
        }
        expectProgressChange(from: before)
    }

    private func arrange(_ titles: [String]) {
        for (target, title) in titles.enumerated() {
            for _ in 0..<titles.count {
                guard let current = (0..<titles.count).first(where: { element("mini-lab-step-\($0)").label.localizedCaseInsensitiveContains(title) }) else {
                    XCTFail("Missing catalog step: \(title)"); return
                }
                if current == target { break }
                let direction = current > target ? "up" : "down"
                tapActivity("mini-lab-\(direction)-\(current)")
            }
            XCTAssertTrue(element("mini-lab-step-\(target)").label.localizedCaseInsensitiveContains(title))
        }
    }
}
