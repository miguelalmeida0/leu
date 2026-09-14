import XCTest

/// Study actions must be native Buttons, fully inside the unobscured scroll viewport.
/// A generic accessibility element with the right string is not an actionable control contract.
extension ShelfUITestCase {
    /// Synchronize the real tab action with app/chrome readiness. At most one
    /// retry is allowed, and only while the originating Library tab remains selected.
    @discardableResult
    func openStudyTab(file: StaticString = #filePath, line: UInt = #line) -> Bool {
        guard waitForStudyNavigationCondition(timeout: 8, { self.studyTabIsReady }) else {
            return failStudyNavigation("not-ready", file: file, line: line)
        }
        if !studyNavigationArrived {
            app.buttons["primary-learn"].tap()
            if !waitForStudyNavigationCondition(timeout: 3, { self.studyNavigationArrived }) {
                // Re-query after the bounded wait; do not reuse the pre-tap element.
                let library = app.buttons["primary-shelf"]
                let study = app.buttons["primary-learn"]
                let retryReady = studyTabIsReady && library.exists && library.isSelected &&
                    study.exists && study.isHittable && study.isEnabled
                // A late transition can finish during the readiness queries.
                if !studyNavigationArrived {
                    guard retryReady else {
                        return failStudyNavigation("no-transition-retry-not-safe", file: file, line: line)
                    }
                    study.tap()
                    guard waitForStudyNavigationCondition(timeout: 4, { self.studyNavigationArrived }) else {
                        return failStudyNavigation("no-transition-after-one-retry", file: file, line: line)
                    }
                }
            }
        }
        // Selected is only a navigation acknowledgement, not proof of working content.
        guard element("learn-screen").waitForExistence(timeout: 8) else {
            return failStudyNavigation("selected-without-study-content", file: file, line: line)
        }
        return true
    }

    private var studyTabIsReady: Bool {
        let study = app.buttons["primary-learn"]
        return app.state == .runningForeground && element("root-bottom-chrome-frame").exists &&
            study.exists && study.isHittable && study.isEnabled
    }

    private var studyNavigationArrived: Bool {
        let study = app.buttons["primary-learn"]
        return element("learn-screen").exists || (study.exists && study.isSelected)
    }

    private func waitForStudyNavigationCondition(timeout: TimeInterval, _ condition: @escaping () -> Bool) -> Bool {
        let predicate = NSPredicate { _, _ in condition() }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout) == .completed
    }

    private func failStudyNavigation(_ reason: String, file: StaticString, line: UInt) -> Bool {
        var state = "Study navigation failure: \(reason); appState=\(app.state.rawValue)"
        if app.state == .runningForeground {
            for id in ["root-bottom-chrome-frame", "primary-shelf", "primary-learn", "learn-screen"] {
                let node = element(id)
                state += "\n\(id): exists=\(node.exists)"
                if node.exists { state += " selected=\(node.isSelected) hittable=\(node.isHittable) enabled=\(node.isEnabled) frame=\(node.frame)" }
            }
            attachAccessibilityTree(name: "study-navigation-" + reason)
        }
        print(state)
        let detail = XCTAttachment(string: state)
        detail.name = "study-navigation-state"; detail.lifetime = .keepAlways; add(detail)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "study-navigation-" + reason; screenshot.lifetime = .keepAlways; add(screenshot)
        XCTFail(state, file: file, line: line)
        return false
    }

    func tapStudyButton(_ identifier: String, scrollID: String = "learn-screen",
                        file: StaticString = #filePath, line: UInt = #line) {
        let button = revealStudyButton(identifier, scrollID: scrollID, file: file, line: line)
        guard button.exists else { return }
        studyCheckpoint("before-\(identifier)", identifier: identifier, scrollID: scrollID)
        button.tap() // Exactly one real tap; no synthetic action, alternate route, or success retry.
        studyCheckpoint("after-\(identifier)", identifier: identifier, scrollID: scrollID)
    }

    @discardableResult
    func revealStudyButton(_ identifier: String, scrollID: String = "learn-screen",
                           file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let query = app.buttons.matching(identifier: identifier)
        let button = query.firstMatch
        let scroll = element(scrollID + "-frame")
        guard scroll.waitForExistence(timeout: 5) else {
            attachAccessibilityTree(name: "missing-\(scrollID)")
            XCTFail("Missing measured Study viewport: \(scrollID)", file: file, line: line)
            return button
        }
        guard element("root-bottom-chrome-frame").waitForExistence(timeout: 5) else {
            XCTFail("Missing geometry for bottom navigation and notices.", file: file, line: line)
            return button
        }
        for _ in 0..<8 {
            let viewport = studyViewport(scroll)
            if query.count == 1, fullyVisible(button, in: viewport) {
                // Indexing may change the layout. Require two consecutive equal frames.
                var previous: CGRect?
                let stable = NSPredicate { _, _ in
                    guard self.fullyVisible(button, in: self.studyViewport(scroll)) else { return false }
                    let current = button.frame
                    defer { previous = current }
                    return previous == current
                }
                if XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: stable, object: nil)], timeout: 3) == .completed {
                    XCTAssertTrue(button.isEnabled, "Study button is disabled: \(identifier)", file: file, line: line)
                    return button
                }
            }
            // Never treat an offscreen/overlapping 'Other' node as an actionable button.
            // Gesture coordinates are derived from the current scroll viewport, not the phone model.
            let upward = !button.exists || button.frame.midY >= viewport.midY
            dragStudyViewport(viewport, upward: upward)
        }
        studyCheckpoint("unreachable-\(identifier)", identifier: identifier, scrollID: scrollID)
        attachAccessibilityTree(name: "unreachable-\(identifier)")
        XCTFail("Expected exactly one native Button fully inside the Study viewport: \(identifier); found \(query.count).",
                file: file, line: line)
        return button
    }

    func revealStudySessionOptions(file: StaticString = #filePath, line: UInt = #line) {
        let options = revealStudyButton("study-session-options", file: file, line: line)
        if options.value as? String != "Expanded" {
            tapStudyButton("study-session-options", file: file, line: line)
        }
        XCTAssertEqual(options.value as? String, "Expanded", file: file, line: line)
        XCTAssertTrue(app.buttons["start-learning-session"].exists, file: file, line: line)
    }

    func revealStudyTools(file: StaticString = #filePath, line: UInt = #line) {
        let more = revealStudyButton("learning-more", file: file, line: line)
        if more.value as? String != "Expanded" { tapStudyButton("learning-more", file: file, line: line) }
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Expanded"), object: more)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 4), .completed,
                       "More must expose Expanded state after activation.", file: file, line: line)
    }

    func expectProgressOpen(file: StaticString = #filePath, line: UInt = #line) {
        guard app.staticTexts["Your understanding"].waitForExistence(timeout: 6) else {
            attachAccessibilityTree(name: "progress-did-not-open")
            XCTFail("Progress did not appear after a verified native-button tap.", file: file, line: line)
            return
        }
        XCTAssertEqual(app.buttons.matching(identifier: "progress-tab-now").count, 1, file: file, line: line)
        XCTAssertEqual(app.buttons.matching(identifier: "progress-tab-history").count, 1, file: file, line: line)
        XCTAssertTrue(app.buttons["progress-done"].isHittable, file: file, line: line)
    }

    func closeProgress(file: StaticString = #filePath, line: UInt = #line) {
        let done = app.buttons["progress-done"]
        XCTAssertTrue(done.waitForExistence(timeout: 4), file: file, line: line)
        XCTAssertTrue(done.isHittable, file: file, line: line)
        done.tap()
        XCTAssertTrue(element("learn-screen").waitForExistence(timeout: 6), file: file, line: line)
    }

    func studyViewport(_ scroll: XCUIElement) -> CGRect {
        guard scroll.exists else { return .zero }
        let intersection = scroll.frame.intersection(app.frame)
        let content = element("root-content-viewport")
        let safeIntersection = content.exists ? intersection.intersection(content.frame) : intersection
        let navigation = app.buttons["primary-learn"]
        let chrome = element("root-bottom-chrome-frame")
        let chromeTop = chrome.exists ? chrome.frame.minY : (navigation.exists ? navigation.frame.minY : intersection.maxY)
        let bottom = min(safeIntersection.maxY, chromeTop)
        return CGRect(x: safeIntersection.minX, y: safeIntersection.minY, width: safeIntersection.width,
                      height: max(0, bottom - safeIntersection.minY)).insetBy(dx: 2, dy: 8)
    }

    func dragStudyViewport(_ viewport: CGRect, upward: Bool) {
        guard viewport.width > 0, viewport.height > 20 else { return }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX,
            dy: viewport.minY - app.frame.minY + viewport.height * (upward ? 0.8 : 0.25)))
        let end = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX,
            dy: viewport.minY - app.frame.minY + viewport.height * (upward ? 0.25 : 0.8)))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func fullyVisible(_ button: XCUIElement, in viewport: CGRect) -> Bool {
        guard button.exists, button.isHittable else { return false }
        let frame = button.frame
        return frame.width > 0 && frame.height > 0 && viewport.contains(frame)
    }

    private func studyCheckpoint(_ name: String, identifier: String, scrollID: String) {
        let buttons = app.buttons.matching(identifier: identifier)
        let nodes = app.descendants(matching: .any).matching(identifier: identifier) // Diagnostics only.
        let descriptions = nodes.allElementsBoundByIndex.prefix(4).map {
            "type=\($0.elementType.rawValue) frame=\($0.frame) enabled=\($0.isEnabled) hittable=\($0.isHittable)"
        }.joined(separator: "; ")
        let message = "LEU_UI_CHECKPOINT: \(name) nativeButtons=\(buttons.count) viewport=\(studyViewport(element(scrollID + "-frame"))) \(descriptions)"
        print(message)
        let attachment = XCTAttachment(string: message)
        attachment.name = name + "-geometry"; attachment.lifetime = .keepAlways; add(attachment)
        capture(name)
    }
}
