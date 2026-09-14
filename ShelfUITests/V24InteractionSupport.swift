import XCTest

extension ShelfUITestCase {
    func openExistingLibraryAfterRestoration() {
        let ready = NSPredicate { _, _ in
            self.app.state == .runningForeground && self.element("root-bottom-chrome-frame").exists &&
                (self.element("study-session-screen").exists || self.element("session-complete-screen").exists ||
                 self.app.buttons["book-React Notes"].exists)
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 25), .completed)
        let library = app.buttons["primary-shelf"]
        XCTAssertTrue(library.exists && library.isHittable)
        library.tap()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 10),
                      "The retained React PDF must exist; never reset or reimport to satisfy this assertion.")
        XCTAssertTrue(library.isSelected)
    }

    func openStudyLandingAfterRestoration() {
        let study = app.buttons["primary-learn"]
        XCTAssertTrue(study.waitForExistence(timeout: 10)); XCTAssertTrue(study.isHittable)
        study.tap()
        let ready = NSPredicate { _, _ in
            self.element("learn-screen").exists || self.element("study-session-screen").exists ||
                self.element("session-complete-screen").exists
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 15), .completed)
        if app.buttons["End study session"].exists { app.buttons["End study session"].tap() }
        if app.buttons["session-summary-done"].exists {
            tapStudyButton("session-summary-done", scrollID: "session-summary")
        }
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 10))
    }

    /// MCQ presentation requires admitted content before planning. Opening the
    /// real page's Lens requests source-specific inference through production UI.
    /// No fixture question, cache injection, or assumption of a seeded V24 bank.
    func prepareAcceptedReactQuestions() {
        let library = app.buttons["primary-shelf"]
        XCTAssertTrue(library.waitForExistence(timeout: 10)); XCTAssertTrue(library.isHittable); library.tap()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 10))
        openReactNotes()
        for _ in 0..<3 {
            let previous = readerButton(identifier: "previous-page", label: "Previous page")
            if previous.isEnabled { previous.tap() }
        }
        readerButton(identifier: "next-page", label: "Next page").tap()
        readerButton(identifier: "next-page", label: "Next page").tap()
        expectPage("Page 3 of 4", on: pageControl())
        readerTool(identifier: "reader-tool-learn", label: "Study").tap()
        let understand = app.buttons["learning-action-understand"]
        XCTAssertTrue(understand.waitForExistence(timeout: 8)); understand.tap()
        XCTAssertTrue(app.staticTexts["lens-origin-passage"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["lens-origin-passage"].label.contains("Keys describe identity"))
        let accepted = app.staticTexts["lens-model-explanation"]
        XCTAssertTrue(accepted.waitForExistence(timeout: 100),
                      "A real accepted, persisted React p.3 model question is required before planning an MCQ journey.")
        XCTAssertFalse(accepted.label.isEmpty)
        capture("accepted-react-page3-model-precondition")
        attachAccessibilityTree(name: "accepted-react-page3-model-precondition")
        app.navigationBars["Understanding Lens"].buttons["Done"].tap()
        closeLibraryReaderAfterLens()
        openStudyLandingAfterRestoration()
        revealStudyTools()
        tapStudyButton("learning-intelligence")
        let count = element("model-persisted-question-count")
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        let persisted = NSPredicate { _, _ in (Int(count.value as? String ?? "0") ?? 0) > 0 }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: persisted, object: nil)], timeout: 10), .completed,
                       "Availability or a raw response cannot replace accepted persisted model content.")
        capture("v26-real-model-diagnostics")
        attachAccessibilityTree(name: "v26-real-model-diagnostics")
        app.navigationBars["Learning Intelligence"].buttons["Done"].tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 10))
    }

    private func closeLibraryReaderAfterLens() {
        // This reader was opened from Library, not from a source-travel route.
        // Its close-reader control is pinned above the document's scroll view;
        // scrolling the page cannot create the conditional reader-context-return.
        // Resolve the native button anew on every poll after sheet dismissal.
        let ready = NSPredicate { _, _ in
            let buttons = self.app.buttons.matching(identifier: "close-reader")
            let button = buttons.firstMatch
            return self.app.state == .runningForeground &&
                !self.app.navigationBars["Understanding Lens"].exists &&
                self.element("reader-screen").exists && buttons.count == 1 &&
                button.exists && button.isEnabled && button.isHittable &&
                self.app.frame.contains(button.frame)
        }
        guard XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 8) == .completed else {
            capture("library-reader-close-not-ready")
            attachAccessibilityTree(name: "library-reader-close-not-ready")
            XCTFail("The Library reader must expose one visible, hittable close-reader button after Lens dismisses.")
            return
        }
        // Do not retain the element resolved while Lens was dismissing.
        let close = app.buttons.matching(identifier: "close-reader").firstMatch
        XCTAssertTrue(close.exists && close.isEnabled && close.isHittable)
        close.tap()
        let returned = NSPredicate { _, _ in
            let study = self.app.buttons["primary-learn"]
            let library = self.app.buttons["primary-shelf"]
            return !self.element("reader-screen").exists &&
                library.exists && library.isSelected &&
                self.app.buttons["book-React Notes"].exists && study.exists && study.isHittable
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: returned, object: nil)], timeout: 8), .completed,
                       "Closing the reader must restore the existing Library and actionable primary navigation.")
    }

    /// A mixed plan is allowed to start with recall. Still fail if the admitted
    /// page-3 MCQ is absent from the actual plan; never substitute recall for MCQ.
    func advanceToAcceptedQuestion() {
        for _ in 0..<20 {
            if element("question-card").exists && element("study-model-question-page-3").exists {
                XCTAssertTrue(app.staticTexts["question-prompt"].waitForExistence(timeout: 8))
                return
            }
            if element("session-complete-screen").exists || app.buttons["Finish session"].exists { break }
            completeCurrentStudyActivity()
        }
        attachAccessibilityTree(name: "missing-admitted-react-question-in-plan")
        XCTFail("The real mixed Study plan never exposed its admitted React p.3 MCQ.")
    }

    private func completeCurrentStudyActivity() {
        let progress = app.staticTexts["study-progress"].label
        if element("question-card").exists {
            tapStudyButton("question-option-0", scrollID: "study-activity")
            tapStudyButton("commit-answer", scrollID: "study-activity")
            tapStudyButton("recall-rating-forgot", scrollID: "study-activity")
        } else if element("recall-card").exists {
            tapStudyButton("recall-reveal-source", scrollID: "study-activity")
            tapStudyButton("recall-rating-forgot", scrollID: "study-activity")
        } else if app.buttons["Reveal masks"].exists {
            tapStudyButton("Reveal masks", scrollID: "study-activity")
            tapStudyButton("Forgot", scrollID: "study-activity")
        } else if app.buttons["Continue"].exists {
            tapStudyButton("Continue", scrollID: "study-activity")
        } else if app.buttons["Finish session"].exists {
            tapStudyButton("Finish session", scrollID: "study-activity")
        } else {
            attachAccessibilityTree(name: "unhandled-study-activity")
            XCTFail("Unexpected activity in the real study plan."); return
        }
        let advanced = NSPredicate { _, _ in
            self.element("session-complete-screen").exists || self.app.staticTexts["study-progress"].label != progress
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: advanced, object: nil)], timeout: 10), .completed)
    }

    @discardableResult
    func revealCheckInOption(_ label: String) -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@", "settings-check-ins", label))
        let option = query.firstMatch
        let form = element("settings-form-frame")
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        for _ in 0..<16 {
            let viewport = settingsViewport(form)
            if option.exists && option.isHittable && viewport.contains(option.frame) {
                XCTAssertEqual(query.count, 1, "Each inline option must be unique, independently of its siblings.")
                return option
            }
            dragStudyViewport(viewport, upward: !option.exists || option.frame.midY >= viewport.midY)
        }
        attachAccessibilityTree(name: "check-in-option-unreachable")
        XCTFail("Inline Check-ins option is unreachable: \(label)")
        return option
    }

    func expectCheckInSelected(_ label: String) {
        let option = revealCheckInOption(label)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: option)], timeout: 6), .completed)
        for sibling in app.buttons.matching(identifier: "settings-check-ins").allElementsBoundByIndex where sibling.label != label {
            XCTAssertFalse(sibling.isSelected, "Only one Check-ins preference may be selected.")
        }
    }

    /// Form virtualizes rows: scroll before asserting controls in later sections.
    @discardableResult
    func revealV24SettingsControl(_ identifier: String) -> XCUIElement {
        let button = app.buttons.matching(identifier: identifier).firstMatch
        let form = element("settings-form-frame")
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        for _ in 0..<14 {
            let heading = app.staticTexts["Leu"]
            let viewport = settingsViewport(form)
            if heading.exists && viewport.contains(heading.frame) { break }
            dragStudyViewport(viewport, upward: false)
        }
        for _ in 0..<14 {
            let viewport = settingsViewport(form)
            if button.exists, viewport.contains(button.frame), button.isHittable || !button.isEnabled {
                XCTAssertEqual(app.buttons.matching(identifier: identifier).count, 1)
                return button
            }
            dragStudyViewport(viewport, upward: !button.exists || button.frame.midY >= viewport.midY)
        }
        attachAccessibilityTree(name: "settings-unreachable-" + identifier)
        XCTFail("Expected a real Settings control in the visible Form viewport: " + identifier)
        return button
    }

    private func settingsViewport(_ form: XCUIElement) -> CGRect {
        let viewport = studyViewport(form)
        let top = max(viewport.minY, (app.navigationBars.firstMatch.frame.maxY) + 8)
        return CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, viewport.maxY - top))
    }

    func tapLensFact(_ identifier: String) {
        let button = app.buttons[identifier]
        let scroll = element("lens-scroll-frame")
        XCTAssertTrue(scroll.waitForExistence(timeout: 6))
        for _ in 0..<10 {
            let viewport = scroll.frame.intersection(app.frame).insetBy(dx: 2, dy: 8)
            if button.exists && button.isHittable && viewport.contains(button.frame) {
                XCTAssertEqual(app.buttons.matching(identifier: identifier).count, 1)
                XCTAssertTrue(button.isEnabled)
                capture("51-before-lens-fact")
                button.tap()
                return
            }
            dragStudyViewport(viewport, upward: !button.exists || button.frame.midY >= viewport.midY)
        }
        attachAccessibilityTree(name: "lens-fact-unreachable")
        XCTFail("A verified fact must be a real Button inside the visible Lens viewport.")
    }

    func expectControlText(_ identifier: String, contains expected: String) {
        let control = app.buttons[identifier]
        let check = NSPredicate { _, _ in
            control.exists && (control.label.contains(expected) || (control.value as? String)?.contains(expected) == true)
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: check, object: nil)], timeout: 6), .completed)
    }

    func waitForStudySave() {
        let saved = app.staticTexts["study-save-status"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        let check = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Saved"), object: saved)
        XCTAssertEqual(XCTWaiter.wait(for: [check], timeout: 8), .completed, "Study state must be durable before acknowledging recovery.")
    }

    func relaunchWithoutReset() {
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func completeStudySessionForEmotionalAcceptance() {
        for _ in 0..<20 {
            if element("session-complete-screen").exists { return }
            let progress = app.staticTexts["study-progress"].label
            if element("question-card").exists {
                tapStudyButton("question-option-0", scrollID: "study-activity")
                if app.buttons["question-confidence-certain"].exists {
                    tapStudyButton("question-confidence-certain", scrollID: "study-activity")
                }
                XCTAssertEqual(app.buttons["question-option-0"].value as? String, "Selected")
                tapStudyButton("commit-answer", scrollID: "study-activity")
                tapStudyButton("recall-rating-forgot", scrollID: "study-activity")
            } else if element("recall-card").exists {
                if app.buttons["recall-reveal-source"].exists { tapStudyButton("recall-reveal-source", scrollID: "study-activity") }
                tapStudyButton("recall-rating-forgot", scrollID: "study-activity")
            } else if app.buttons["Reveal masks"].exists {
                tapStudyButton("Reveal masks", scrollID: "study-activity")
                tapStudyButton("Forgot", scrollID: "study-activity")
            } else if app.buttons["Continue"].exists {
                tapStudyButton("Continue", scrollID: "study-activity")
            } else if app.buttons["Finish session"].exists {
                tapStudyButton("Finish session", scrollID: "study-activity")
            } else {
                attachAccessibilityTree(name: "v24-emotion-unhandled-activity")
                XCTFail("Unhandled study activity in the real emotional journey.")
                return
            }
            let advanced = NSPredicate { _, _ in
                self.element("session-complete-screen").exists || self.app.staticTexts["study-progress"].label != progress
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: advanced, object: nil)], timeout: 8), .completed)
        }
        XCTFail("The short study session did not complete within its bounded activity count.")
    }
}
