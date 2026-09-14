import XCTest

/// End-to-end acceptance for Shelf Learning OS. These tests intentionally drive
/// the same sample PDFs used by the existing native reader suite so the analysis
/// pipeline, source links, and study UI are exercised together.
final class ShelfLearningOSUITests: ShelfUITestCase {
    func test32LearnTodayCreatesLocalStudySession() throws {
        openLearn()
        revealStudySessionOptions()
        let react = app.buttons["learn-topic-react"]
        if react.waitForExistence(timeout: 20) { tapStudyButton("learn-topic-react") }
        tapStudyButton("10 minutes")
        let start = app.buttons["start-learning-session"]
        XCTAssertTrue(waitForEnabled(start, timeout: 30), "Study material should become available after local indexing.")
        tapStudyButton("start-learning-session")
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 12))
        capture("32-learn-session")
    }

    func test33QuestionCommitAndSourceRoundTrip() throws {
        openLearnAndStart()
        guard element("question-card").waitForExistence(timeout: 12) else {
            XCTFail("The seeded study plan must include the question required by this round-trip test.")
            return
        }
        var option = identifiedControl("question-option-0")
        if !option.waitForExistence(timeout: 3) {
            option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Option A.")).firstMatch
        }
        XCTAssertTrue(option.waitForExistence(timeout: 5), "The first answer option must be accessible and addressable.")
        option.tap()
        let commit = identifiedControl("commit-answer", label: "Commit answer")
        XCTAssertTrue(waitForEnabled(commit, timeout: 5), "Selecting an answer must enable the commit control.")
        commit.tap()
        let source = identifiedControl("view-question-source", label: "View source")
        XCTAssertTrue(source.waitForExistence(timeout: 5), "Committed answers must expose their source control.")
        source.tap()
        XCTAssertTrue(element("reader-screen").waitForExistence(timeout: 10))
        let returnControl = identifiedControl("reader-context-return", label: "Back to question")
        XCTAssertTrue(returnControl.waitForExistence(timeout: 5), "Source inspection must expose a visible return-to-question control.")
        capture("33-source-roundtrip-reader")
        returnControl.tap()
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 8))
    }

    func test34ActiveRecallEntryPoint() {
        openLearn()
        tapStudyButton("learning-mode-active-recall")
        XCTAssertTrue(app.navigationBars["Active Recall"].waitForExistence(timeout: 5) || app.staticTexts["Active Recall"].exists)
        XCTAssertTrue(app.buttons["Begin recall"].exists)
        capture("34-active-recall-setup")
    }

    func test35InterviewModeEntryPoint() {
        openLearn()
        tapStudyButton("learning-mode-interview")
        XCTAssertTrue(app.navigationBars["Interview Mode"].waitForExistence(timeout: 5) || app.staticTexts["Interview Mode"].exists)
        XCTAssertTrue(app.buttons["Start interview"].exists)
        capture("35-interview-setup")
    }

    func test36LearningTimelineAndConnectionsOpen() {
        openLearn()
        tapStudyButton("learning-progress")
        let history = app.buttons["progress-tab-history"]
        XCTAssertTrue(app.staticTexts["Your understanding"].waitForExistence(timeout: 6), "Progress must visibly replace the Study root.")
        XCTAssertTrue(history.waitForExistence(timeout: 6), "Progress must expose a History tab."); history.tap()
        XCTAssertTrue(app.staticTexts["UNDERSTANDING TIME MACHINE"].waitForExistence(timeout: 5), "History must render the visible Understanding Time Machine content.")
        closeProgress()
        openLearn()
        revealStudyTools()
        tapStudyButton("learning-connections")
        XCTAssertTrue(app.navigationBars["Connections"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["YOUR LIBRARY, BETWEEN THE BOOKS"].exists)
        capture("36-connections")
    }

    func test37TrailsCanCreatePersistentLearningPath() {
        app.buttons["primary-trails"].tap()
        XCTAssertTrue(element("trails-screen").waitForExistence(timeout: 6))
        app.buttons["new-learning-trail"].tap()
        let field = app.textFields["Frontend interview"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("Frontend Interview")
        app.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Frontend Interview"].waitForExistence(timeout: 6))
        capture("37-trail-created")
    }

    func test38ReaderExposesLearningObjectActions() {
        openReactNotes()
        let learn = readerTool(identifier: "reader-tool-learn", label: "Study")
        XCTAssertTrue(learn.exists); learn.tap()
        XCTAssertTrue(element("learning-object-actions").waitForExistence(timeout: 5))
        XCTAssertTrue(identifiedControl("learning-action-remember", label: "Remember").exists)
        XCTAssertTrue(identifiedControl("learning-action-test", label: "Test").exists)
        XCTAssertTrue(identifiedControl("learning-action-connect", label: "Connect").exists)
        XCTAssertTrue(identifiedControl("learning-action-mask", label: "Mask").exists)
        XCTAssertTrue(identifiedControl("learning-action-explain", label: "Explain").exists)
        capture("38-learning-actions")
    }

    func test39LearningObjectSurvivesRelaunch() {
        openReactNotes()
        let learn = readerTool(identifier: "reader-tool-learn", label: "Study")
        XCTAssertTrue(learn.exists); learn.tap()
        XCTAssertTrue(element("learning-object-actions").waitForExistence(timeout: 5))
        let remember = identifiedControl("learning-action-remember", label: "Remember")
        XCTAssertTrue(remember.waitForExistence(timeout: 5)); remember.tap()
        XCTAssertTrue(app.buttons["Back to library"].waitForExistence(timeout: 8))
        app.buttons["Back to library"].tap()

        openLearn()
        tapStudyButton("learning-progress")
        let historyBeforeRelaunch = app.buttons["progress-tab-history"]
        XCTAssertTrue(app.staticTexts["Your understanding"].waitForExistence(timeout: 6), "Progress must be visibly open before relaunch.")
        XCTAssertTrue(historyBeforeRelaunch.waitForExistence(timeout: 6), "Progress must expose History before relaunch."); historyBeforeRelaunch.tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 6))
        let savedEvent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "progress-event-encountered-")).firstMatch
        XCTAssertTrue(savedEvent.waitForExistence(timeout: 5), "Remember must create a source-bound history event.")
        let savedEventID = savedEvent.identifier
        closeProgress()

        // Relaunch without --reset-library so this test actually verifies persisted Learning OS state.
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 20))
        app.buttons["primary-learn"].tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 8))
        tapStudyButton("learning-progress")
        let historyAfterRelaunch = app.buttons["progress-tab-history"]
        XCTAssertTrue(app.staticTexts["Your understanding"].waitForExistence(timeout: 6), "Progress must be visibly open after relaunch.")
        XCTAssertTrue(historyAfterRelaunch.waitForExistence(timeout: 6), "Progress must expose History after relaunch."); historyAfterRelaunch.tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons[savedEventID].waitForExistence(timeout: 6), "The exact captured event must survive relaunch, not just the Today heading.")
        capture("39-learning-persists")
    }


    func test40LearningStateIsARealRecallEntryPoint() {
        openLearn()
        tapStudyButton("learning-progress")
        let nowTab = app.buttons["progress-tab-now"]
        XCTAssertTrue(app.staticTexts["Your understanding"].waitForExistence(timeout: 6), "Progress must visibly replace the Study root immediately.")
        XCTAssertTrue(nowTab.waitForExistence(timeout: 6), "Progress must open directly to its Now view.")
        XCTAssertTrue(app.staticTexts["What you are strengthening"].waitForExistence(timeout: 5), "Progress must open directly to the visible Now content.")
        let react = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "progress-topic-", "React,")).firstMatch
        XCTAssertTrue(waitForEnabled(react, timeout: 30), "React recall must have real indexed learning objects.")
        tapStudyButton(react.identifier, scrollID: "progress-now-scroll")
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 8), "Starting recall from Progress must reveal the actual study session.")
        XCTAssertTrue(element("question-card").waitForExistence(timeout: 5) || element("recall-card").exists,
                      "A recall entry point must expose an actual activity, not an empty session.")
        XCTAssertTrue(app.buttons["End study session"].exists)
        capture("40-progress-starts-real-recall")
    }

    func test41ReaderTestActionOpensSourceBoundPromptEditor() {
        openReactNotes()
        let learn = readerTool(identifier: "reader-tool-learn", label: "Study")
        XCTAssertTrue(learn.exists); learn.tap()
        XCTAssertTrue(element("learning-object-actions").waitForExistence(timeout: 5))
        let testAction = identifiedControl("learning-action-test", label: "Test")
        XCTAssertTrue(testAction.waitForExistence(timeout: 5)); testAction.tap()
        XCTAssertTrue(element("recall-prompt-editor").waitForExistence(timeout: 6))
        XCTAssertTrue(element("manual-recall-prompt").exists)
        XCTAssertTrue(app.buttons["save-recall-prompt"].exists)
        capture("41-source-bound-test-editor")
    }

    private func openLearn() {
        let learn = app.buttons["primary-learn"]
        XCTAssertTrue(learn.waitForExistence(timeout: 8)); learn.tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 10))
    }

    private func openLearnAndStart() {
        openLearn()
        revealStudySessionOptions()
        if app.buttons["learn-topic-react"].waitForExistence(timeout: 20) { tapStudyButton("learn-topic-react") }
        tapStudyButton("10 minutes")
        let start = app.buttons["start-learning-session"]
        XCTAssertTrue(waitForEnabled(start, timeout: 30), "Study material should become available after local indexing.")
        tapStudyButton("start-learning-session")
        XCTAssertTrue(element("study-session-screen").waitForExistence(timeout: 12))
    }

    private func waitForEnabled(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        let predicate = NSPredicate(format: "enabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
