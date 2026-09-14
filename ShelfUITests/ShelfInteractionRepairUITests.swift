import XCTest

/// Real touch gestures and control interactions covering the physical-device reports after V18.2.
final class ShelfInteractionRepairUITests: ShelfUITestCase {
    func test22ReadVerticalScrollCrossesSourcePageBoundary() {
        openReactNotes()
        chooseFlow("Vertical")
        for _ in 0..<12 {
            if pageControl().label != "Page 1 of 4" { break }
            drag(from: CGVector(dx: 0.5, dy: 0.69), to: CGVector(dx: 0.5, dy: 0.28))
        }
        XCTAssertNotEqual(pageControl().label, "Page 1 of 4", "Scrolling must leave the first source page.")
        XCTAssertTrue(readerButton(identifier: "close-reader", label: "Back to library").exists)
        capture("31-read-continuous-cross-page")
    }

    func test23ReadVerticalArrowsMoveAndReopenAtThatPage() {
        openReactNotes()
        chooseFlow("Vertical")
        readerButton(identifier: "next-page", label: "Next page").tap()
        expectPage("Page 2 of 4", on: pageControl())
        readerButton(identifier: "close-reader", label: "Back to library").tap()
        openReactNotes()
        expectPage("Page 2 of 4", on: pageControl())
        readerButton(identifier: "previous-page", label: "Previous page").tap()
        expectPage("Page 1 of 4", on: pageControl())
    }

    func test24OriginalFitRejectsVerticalDriftButTurnsOnHorizontalDrag() {
        openReactNotes()
        app.segmentedControls.buttons["Original"].tap()
        drag(from: CGVector(dx: 0.55, dy: 0.4), to: CGVector(dx: 0.58, dy: 0.59))
        expectPage("Page 1 of 4", on: pageControl())
        swipeReaderContentLeft()
        expectPage("Page 2 of 4", on: pageControl())
        swipeReaderContentRight()
        expectPage("Page 1 of 4", on: pageControl())
        capture("32-original-direction-lock")
    }

    func test25OriginalFocusTurnsAndControlsDoNotCoverTheViewport() {
        openReactNotes()
        app.segmentedControls.buttons["Original"].tap()
        enterFocusMode()
        swipeReaderContentLeft()
        let count = app.descendants(matching: .any)["focus-page-count"]
        expectPage("Page 2 of 4", on: count)
        let chrome = app.descendants(matching: .any)["reader-focus-chrome-frame"].firstMatch
        let viewport = app.descendants(matching: .any)["original-viewport-frame"].firstMatch
        XCTAssertTrue(chrome.waitForExistence(timeout: 3), "Focus chrome must expose its real layout frame in QA.")
        XCTAssertTrue(viewport.waitForExistence(timeout: 3), "Original viewport must expose its real layout frame in QA.")
        XCTAssertLessThanOrEqual(chrome.frame.maxY, viewport.frame.minY + 1,
                                 "Focus controls must reserve space above the PDF instead of covering it.")
        capture("33-focus-no-occlusion")
    }

    func test26TextSizeMovesOnFirstDragAndPersistsAfterDismissal() {
        openReactNotes()
        openAppearance()
        let slider = app.sliders["settings-read-text-slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let before = app.staticTexts["settings-read-text-value"].label
        slider.adjust(toNormalizedSliderPosition: 0.9)
        XCTAssertNotEqual(app.staticTexts["settings-read-text-value"].label, before)
        let after = app.staticTexts["settings-read-text-value"].label
        app.buttons["Done"].tap()
        openAppearance()
        XCTAssertEqual(app.staticTexts["settings-read-text-value"].label, after)
        capture("34-first-drag-text-slider")
    }

    func test27BrightnessMovesOnFirstDragAndKeepAwakeTogglesOnce() {
        openReactNotes()
        openAppearance()
        let slider = app.sliders["settings-brightness-slider"]
        if !slider.isHittable { app.swipeUp() }
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        let before = String(describing: slider.value)
        let value = Double((slider.value as? String ?? "100%").replacingOccurrences(of: "%", with: "")) ?? 100
        slider.adjust(toNormalizedSliderPosition: value > 50 ? 0.2 : 0.8)
        XCTAssertNotEqual(String(describing: slider.value), before, "The very first drag must change brightness.")
        let toggle = app.switches["settings-keep-awake"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        let beforeToggle = String(describing: toggle.value)
        toggle.tap()
        let deadline = Date().addingTimeInterval(2)
        var afterToggle = String(describing: app.switches["settings-keep-awake"].value)
        while afterToggle == beforeToggle && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            afterToggle = String(describing: app.switches["settings-keep-awake"].value)
        }
        XCTAssertNotEqual(afterToggle, beforeToggle, "Keep screen awake must change on the first tap.")
        capture("35-first-drag-comfort-controls")
        slider.adjust(toNormalizedSliderPosition: 0.8)
    }

    func test28ScrubberCommitsOnReleaseWithoutMovingOtherControls() {
        openReactNotes()
        let play = readerButton(identifier: "speech-control", label: "Read page aloud")
        let before = play.frame
        let slider = scrubberControl()
        slider.adjust(toNormalizedSliderPosition: 1)
        expectPage("Page 4 of 4", on: pageControl())
        XCTAssertEqual(play.frame.minY, before.minY, accuracy: 1)
        XCTAssertEqual(play.frame.minX, before.minX, accuracy: 1)
        capture("36-stable-reader-bar-scrub")
    }

    func test29FlowRoundTripDoesNotDisableReadPaging() {
        openReactNotes()
        chooseFlow("Vertical")
        readerButton(identifier: "next-page", label: "Next page").tap()
        expectPage("Page 2 of 4", on: pageControl())
        chooseFlow("Horizontal")
        swipeReaderContentLeft()
        expectPage("Page 3 of 4", on: pageControl())
        swipeReaderContentRight()
        expectPage("Page 2 of 4", on: pageControl())
    }

    func test30PlayButtonHasBreathingRoomInsideTheBar() {
        openReactNotes()
        let bar = app.descendants(matching: .any)["reader-bottom-bar-frame"].firstMatch
        let play = readerButton(identifier: "speech-control", label: "Read page aloud")
        XCTAssertTrue(bar.waitForExistence(timeout: 3), "Bottom rail must expose its real layout frame in QA.")
        XCTAssertGreaterThanOrEqual(play.frame.minY - bar.frame.minY, 12,
                                    "Playback needs visible breathing room below the reader content.")
        XCTAssertGreaterThanOrEqual(play.frame.height, 44)
        XCTAssertGreaterThanOrEqual(scrubberControl().frame.minY - play.frame.maxY, 8,
                                    "Playback and scrubber must occupy separate touch rows.")
        capture("37-bottom-bar-spacing")
    }

    func test31ReadVerticalPositionIsNotReplacedByHiddenPDFPosition() {
        openReactNotes()
        chooseFlow("Vertical")
        readerButton(identifier: "next-page", label: "Next page").tap()
        readerButton(identifier: "next-page", label: "Next page").tap()
        expectPage("Page 3 of 4", on: pageControl())
        app.segmentedControls.buttons["Original"].tap()
        expectPage("Page 3 of 4", on: pageControl())
        app.segmentedControls.buttons["Read"].tap()
        expectPage("Page 3 of 4", on: pageControl())
    }

    private func chooseFlow(_ label: String) {
        openAppearance()
        let identified = app.segmentedControls["reader-page-flow"]
        let control = identified.waitForExistence(timeout: 3) ? identified : app.segmentedControls.firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 5), "Reading Settings must expose the page-flow segmented control.")
        let option = control.buttons[label]
        XCTAssertTrue(option.waitForExistence(timeout: 3), "Missing page-flow option: \(label)")
        option.tap()
        app.buttons["Done"].tap()
    }
    private func drag(from: CGVector, to: CGVector) {
        app.coordinate(withNormalizedOffset: from).press(forDuration: 0.03,
            thenDragTo: app.coordinate(withNormalizedOffset: to))
    }
}
