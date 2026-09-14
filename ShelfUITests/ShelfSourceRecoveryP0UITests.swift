import XCTest

/// Deliberately keeps the existing UI-test library. Never delete/reimport the
/// PDFs to make the extraction-version migration appear successful.
final class ShelfSourceRecoveryP0UITests: ShelfUITestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["LEU_UI_DIAGNOSTICS"] = "1"
        app.launchEnvironment["LEU_PDF_DIAGNOSTICS"] = "1"
        app.launch()
        openExistingLibraryAfterRestoration()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 25))
    }

    func test59ExistingReactPagesOneToThreeRetainTextAndCode() {
        assertReactPagesOneToThree()
    }

    private func assertReactPagesOneToThree() {
        openReactNotes()
        let read = app.segmentedControls.buttons["Read"]
        if read.exists && !read.isSelected { read.tap() }
        // Existing reading position may be anywhere in this same four-page PDF.
        for _ in 0..<3 {
            let previous = readerButton(identifier: "previous-page", label: "Previous page")
            if previous.isEnabled { previous.tap() }
        }
        let expected = [
            ["React Notes", "A clearer model for React", "A component describes the interface for a particular set of props, state and context.",
             "Keep rendering pure: do not change unrelated objects, start requests or subscribe to events while calculating the interface."],
            ["State is a snapshot", "Setting state requests another render. It does not change the state variable inside the event handler that is already running.", "setCount(previous => previous + 1);"],
            ["Keys describe identity", "A stable key helps React match an item to its previous instance within a list of siblings.", "<Row key={item.id} item={item} />"]
        ]
        for (index, phrases) in expected.enumerated() {
            expectPage("Page \(index + 1) of 4", on: pageControl())
            for phrase in phrases {
                let text = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", phrase)).firstMatch
                XCTAssertTrue(text.waitForExistence(timeout: 10), phrase)
                XCTAssertTrue(text.isHittable, "The acceptance text must be visible, not merely present offscreen: \(phrase)")
            }
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "SHELF SAMPLES /")).firstMatch.exists)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "SHELF / ORIGINAL SAMPLE NOTES")).firstMatch.exists)
            capture("v26-react-page-\(index + 1)-intact")
            attachAccessibilityTree(name: "v26-react-page-\(index + 1)-visible-text")
            if index < 2 { readerButton(identifier: "next-page", label: "Next page").tap() }
        }
    }

    func test60ExistingLibraryActiveRecallRevealsAndReturns() {
        openStudyLandingAfterRestoration()
        revealStudyTools()
        tapStudyButton("learning-mode-active-recall")
        let begin = app.buttons["Begin recall"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: begin)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 60), .completed)
        begin.tap()
        XCTAssertTrue(element("recall-card").waitForExistence(timeout: 10))
        XCTAssertFalse(element("question-card").exists)
        capture("v26-recall-question")
        tapStudyButton("recall-reveal-source", scrollID: "study-activity")
        capture("v26-recall-answer")
        tapStudyButton("recall-view-source", scrollID: "study-activity")
        XCTAssertTrue(element("reader-screen").waitForExistence(timeout: 10))
        capture("v26-recall-source")
        let back = identifiedControl("reader-context-return")
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
        XCTAssertTrue(element("recall-card").waitForExistence(timeout: 10))
        capture("v26-recall-return")
    }

    func test61ExistingReactQuestionChoicesExplanationSourceReturn() {
        assertModelQuestionJourney()
    }

    private func assertModelQuestionJourney() {
        prepareAcceptedReactQuestions()
        openStudyAndStart(minutes: "10 minutes")
        advanceToAcceptedQuestion()
        let prompt = app.staticTexts["question-prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 60), "No MCQ from the real React PDF; do not replace it with a fixture.")
        XCTAssertTrue(element("study-model-question-page-3").exists,
            "The visible question must itself be a persisted model result from page 3.")
        let originalPrompt = prompt.label
        let choices = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "question-option-"))
        XCTAssertGreaterThanOrEqual(choices.count, 3)
        capture("v26-react-question-choices")
        attachAccessibilityTree(name: "v26-react-question-choices")
        identifiedControl("question-option-0").tap()
        tapStudyButton("commit-answer", scrollID: "study-activity")
        let quote = app.staticTexts["question-supporting-quote"]
        XCTAssertTrue(quote.waitForExistence(timeout: 10))
        XCTAssertFalse(quote.label.isEmpty)
        capture("v26-react-answer-explanation")
        attachAccessibilityTree(name: "v26-react-answer-explanation")
        tapStudyButton("view-question-source", scrollID: "study-activity")
        XCTAssertTrue(element("reader-screen").waitForExistence(timeout: 10))
        capture("v26-react-exact-source")
        attachAccessibilityTree(name: "v26-react-exact-source")
        let back = identifiedControl("reader-context-return")
        XCTAssertTrue(back.waitForExistence(timeout: 5)); back.tap()
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        XCTAssertEqual(prompt.label, originalPrompt)
        XCTAssertTrue(app.staticTexts["question-supporting-quote"].exists)
        capture("v26-react-return-to-answer")
    }

    func test62UninterruptedExistingLibraryReadLensStudySourceReturn() {
        // One launch, one installed candidate, no reset, reimport, fixture output,
        // or manual generation-cache seeding between these screens.
        assertReactPagesOneToThree()
        readerTool(identifier: "reader-tool-learn", label: "Study").tap()
        let understand = app.buttons["learning-action-understand"]
        XCTAssertTrue(understand.waitForExistence(timeout: 8)); understand.tap()
        let origin = app.staticTexts["lens-origin-passage"]
        XCTAssertTrue(origin.waitForExistence(timeout: 10))
        XCTAssertTrue(origin.label.contains("Keys describe identity"))
        let explanation = app.staticTexts["lens-model-explanation"]
        let explained = explanation.waitForExistence(timeout: 100)
        capture("v26-page3-lens")
        attachAccessibilityTree(name: "v26-page3-lens")
        XCTAssertTrue(explained, "A template or empty Lens cannot satisfy the model-backed page 3 gate.")
        XCTAssertTrue(explanation.label.localizedCaseInsensitiveContains("key"))
        XCTAssertTrue(explanation.label.localizedCaseInsensitiveContains("instance") ||
            explanation.label.localizedCaseInsensitiveContains("state"))
        identifiedControl("lens-view-source").tap()
        expectPage("Page 3 of 4", on: pageControl())
        capture("v26-page3-lens-source")
        identifiedControl("reader-context-return").tap()
        XCTAssertTrue(origin.waitForExistence(timeout: 10))
        app.navigationBars["Understanding Lens"].buttons["Done"].tap()
        identifiedControl("reader-context-return").tap()
        assertModelQuestionJourney()
        tapStudyButton("view-question-source", scrollID: "study-activity")
        expectPage("Page 3 of 4", on: pageControl())
        identifiedControl("reader-context-return").tap()
        XCTAssertTrue(app.staticTexts["question-supporting-quote"].waitForExistence(timeout: 10))
    }
}
