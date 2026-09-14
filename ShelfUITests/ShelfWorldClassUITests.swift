import XCTest

/// Acceptance journeys for the connected-library and human technical-reading releases.
final class ShelfWorldClassUITests: ShelfUITestCase {
    func test42ReaderConnectOpensCrossLibraryPassageExperience() {
        openReactNotes()
        readerTool(identifier: "reader-tool-learn", label: "Study").tap()
        XCTAssertTrue(element("learning-object-actions").waitForExistence(timeout: 6))
        let connect = identifiedControl("learning-action-connect", label: "Connect")
        XCTAssertTrue(connect.waitForExistence(timeout: 5)); connect.tap()
        XCTAssertTrue(element("connected-passage-sheet").waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["RELATED IN YOUR LIBRARY"].waitForExistence(timeout: 12))
        capture("42-connected-passage")
    }

    func test43KnowledgeSearchPreservesTechnicalTerms() {
        openReactNotes()
        app.buttons["Reader options"].tap()
        app.buttons["Search ideas"].tap()
        let field = app.textFields["knowledge-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 8)); field.tap(); field.typeText("setCount")
        XCTAssertTrue(element("knowledge-search").exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "setCount")).firstMatch.waitForExistence(timeout: 12),
                      "Knowledge search should preserve and return camelCase technical tokens that exist in the seeded PDF corpus.")
        capture("43-knowledge-search")
    }

    func test44VoiceSettingsExposeQualitySpeedAndTechnicalReading() {
        openReactNotes()
        app.buttons["Reader options"].tap()
        app.buttons["Voice & listening"].tap()
        XCTAssertTrue(element("voice-settings").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["TECHNICAL READING"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Dense code")).firstMatch.exists)
        capture("44-voice-settings")
    }

    func test45SpeechStartsAndCompactTechnicalControlsAppear() {
        openReactNotes()
        app.buttons["Read page aloud"].tap()
        XCTAssertTrue(app.buttons["Pause reading"].waitForExistence(timeout: 8))
        XCTAssertTrue(element("voice-player-strip").waitForExistence(timeout: 5))
        XCTAssertTrue(element("voice-speed").exists)
        XCTAssertTrue(element("voice-picker-menu").exists)
        capture("45-voice-player")
        app.buttons["Pause reading"].tap()
    }

    func test46TrailsHaveOneCreationSurface() {
        app.buttons["primary-trails"].tap()
        XCTAssertTrue(element("trails-screen").waitForExistence(timeout: 8))
        let add = app.buttons["new-learning-trail"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        let field = app.textFields["Frontend interview"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("React Identity")
        app.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["React Identity"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["new-topic-chain"].exists, "Trails must not expose a competing Topic Chain creation flow.")
        capture("46-trail")
    }

    func test47BookMenuExposesConnectionsWithoutDashboard() {
        let actions = app.buttons["actions-React Notes"]
        XCTAssertTrue(actions.waitForExistence(timeout: 8)); actions.tap()
        XCTAssertTrue(app.buttons["Connections"].exists); app.buttons["Connections"].tap()
        XCTAssertTrue(app.staticTexts["THIS BOOK CONNECTS TO"].waitForExistence(timeout: 8))
        capture("47-book-connections")
    }

    func test50SemanticQuestionUsesFourLevelCertainty() {
        prepareAcceptedReactQuestions()
        openStudyAndStart(minutes: "10 minutes")
        advanceToAcceptedQuestion()
        XCTAssertTrue(element("question-card").waitForExistence(timeout: 15),
                      "The real React study session must expose an admitted semantic question.")
        XCTAssertFalse(app.buttons["question-confidence-certain"].exists,
                       "Prediction controls follow an answer choice, never grade it.")
        tapStudyButton("question-option-0", scrollID: "study-activity")
        for label in ["Guessing", "Unsure", "Fairly sure", "Certain"] {
            revealStudyButton(label, scrollID: "study-activity")
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 4), "Missing V24 certainty level: \(label)")
        }
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "appeared on page")).firstMatch.exists,
                       "V24 must not regress to page-presence questions.")
        capture("50-semantic-question-certainty")
    }

    func test51UnderstandingLensUsesVerifiedSourceFacts() {
        openReactNotes()
        let originPage = pageControl().label
        readerTool(identifier: "reader-tool-learn", label: "Study").tap()
        XCTAssertTrue(element("learning-object-actions").waitForExistence(timeout: 6))
        let understand = app.buttons["learning-action-understand"]
        XCTAssertTrue(understand.waitForExistence(timeout: 5)); understand.tap()
        XCTAssertTrue(element("understanding-lens").waitForExistence(timeout: 8))
        let origin = app.staticTexts["lens-origin-passage"]
        XCTAssertTrue(origin.waitForExistence(timeout: 5))
        let originalPassage = origin.label
        // Local facts are optional; this passage has a source meaning projection
        // plus verified Related facts. Both must remain grounded and inspectable.
        XCTAssertTrue(app.staticTexts["What this says"].waitForExistence(timeout: 8))
        let meaning = "committing applies the necessary changes to the screen."
        XCTAssertTrue(app.staticTexts[meaning].exists)
        XCTAssertTrue(originalPassage.split(whereSeparator: \.isWhitespace).joined(separator: " ").contains(meaning))
        let related = app.buttons["Related"]
        XCTAssertTrue(related.waitForExistence(timeout: 8)); related.tap()
        let fact = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "understanding-lens-fact-")).firstMatch
        XCTAssertTrue(fact.waitForExistence(timeout: 20))
        XCTAssertFalse(element("understanding-lens-empty").exists)
        let targetPage = fact.value as? String
        tapLensFact(fact.identifier)
        let back = app.buttons["reader-context-return"]
        XCTAssertTrue(back.waitForExistence(timeout: 12), "Source inspection must expose a real return Button.")
        XCTAssertEqual(app.buttons.matching(identifier: "reader-context-return").count, 1)
        XCTAssertEqual(back.label, "Back to Understanding Lens")
        if let targetPage { XCTAssertTrue(pageControl().label.hasPrefix(targetPage + " of ")) }
        capture("51-lens-source-with-return")
        XCTAssertTrue(back.isHittable); back.tap()
        XCTAssertTrue(app.staticTexts["lens-origin-passage"].waitForExistence(timeout: 12))
        XCTAssertEqual(app.staticTexts["lens-origin-passage"].label, originalPassage,
                       "Return must restore the selected passage in Lens, not drop the learner into Library.")
        capture("51-restored-lens")
        let done = app.navigationBars["Understanding Lens"].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap()
        expectPage(originPage, on: pageControl())
    }

    func test52V24PrivacyAndNeuralVoiceControlsAreExposed() {
        openLibrarySettings()
        let off = revealCheckInOption("Off")
        XCTAssertTrue(off.isEnabled); off.tap()
        expectCheckInSelected("Off")
        let delete = revealV24SettingsControl("settings-delete-check-ins")
        XCTAssertEqual(delete.label, "Delete emotional check-in history")
        XCTAssertFalse(delete.isEnabled, "A reset library has no emotional history to delete.")
        let install = revealV24SettingsControl("settings-install-voice")
        XCTAssertTrue(["Install neural voice (~400 MB)", "Neural voice installed"].contains(install.label))
        let voice = element("settings-voice-status")
        XCTAssertTrue(voice.exists)
        XCTAssertTrue(voice.label.contains("Supertonic 3") || voice.label.contains("Apple fallback"))
        capture("52-voice-controls")
        app.navigationBars.buttons["Library"].tap()
        openLibrarySettings()
        _ = revealCheckInOption("Off")
        expectCheckInSelected("Off")
        capture("52-check-in-preference-restored")
    }

    func test53ActiveStudyContextSurvivesInterruption() {
        prepareAcceptedReactQuestions()
        openStudyAndStart(minutes: "10 minutes")
        advanceToAcceptedQuestion()
        XCTAssertTrue(app.staticTexts["question-prompt"].waitForExistence(timeout: 12))
        let prompt = app.staticTexts["question-prompt"].label
        let progress = app.staticTexts["study-progress"].label
        tapStudyButton("question-option-0", scrollID: "study-activity")
        tapStudyButton("question-confidence-certain", scrollID: "study-activity")
        let answer = app.buttons["question-option-0"].label
        waitForStudySave()
        relaunchWithoutReset()
        XCTAssertTrue(app.staticTexts["question-prompt"].waitForExistence(timeout: 25),
                      "An unfinished session must open directly, without tapping Study.")
        XCTAssertEqual(app.staticTexts["study-progress"].label, progress)
        XCTAssertEqual(app.staticTexts["question-prompt"].label, prompt)
        XCTAssertEqual(app.buttons["question-option-0"].label, answer)
        XCTAssertEqual(app.buttons["question-option-0"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["question-confidence-certain"].value as? String, "Selected")
        tapStudyButton("commit-answer", scrollID: "study-activity")
        XCTAssertTrue(app.buttons["view-question-source"].waitForExistence(timeout: 6))
        waitForStudySave()
        relaunchWithoutReset()
        XCTAssertTrue(app.buttons["view-question-source"].waitForExistence(timeout: 25))
        XCTAssertEqual(app.staticTexts["question-prompt"].label, prompt)
        XCTAssertFalse(app.buttons["commit-answer"].exists, "A committed answer must not revert to an uncommitted question.")
        capture("53-restored-answer-and-confidence")
    }

    func test54IrritatedCheckInOffersOptionalRelease() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-library", "--force-emotional-checkin"]
        app.launch()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 25))
        openStudyAndStart(minutes: "5 minutes")
        completeStudySessionForEmotionalAcceptance()
        XCTAssertTrue(element("session-complete-screen").waitForExistence(timeout: 10))
        XCTAssertTrue(element("emotional-check-in").waitForExistence(timeout: 5))
        tapStudyButton("feeling-irritated", scrollID: "session-summary")
        XCTAssertTrue(app.staticTexts["Get it out?"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["Release"].exists)
        XCTAssertTrue(app.buttons["Continue"].exists)
        XCTAssertTrue(app.buttons["I'm done"].exists)
        tapStudyButton("check-in-open-release", scrollID: "session-summary")
        XCTAssertTrue(element("release-surface").waitForExistence(timeout: 5))
        assertReleaseControlsVisible(beforeRelease: true)
        tapPinnedReleaseButton("release-accessible-action")
        XCTAssertTrue(app.staticTexts["release-completed-message"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["release-heading"].label, "Better?")
        XCTAssertFalse(app.buttons["release-accessible-action"].exists)
        assertReleaseControlsVisible(beforeRelease: false)
        capture("54-irritated-release-accessible")
        tapPinnedReleaseButton("release-continue")
        XCTAssertFalse(element("release-surface").exists)
        XCTAssertTrue(element("session-complete-screen").exists,
                      "Continue must restore the completed round, not discard its context.")
        tapStudyButton("session-summary-done", scrollID: "session-summary")
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 8))
    }


}
