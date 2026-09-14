import XCTest

/// Screen-by-screen native QA for Shelf. Tests use isolated seeded storage.
final class ShelfUITests: ShelfUITestCase {
    func test00AccessibilityContract() {
        XCTAssertTrue(element("library-screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("library-search").exists)
        XCTAssertTrue(element("import-pdf").exists)
        XCTAssertTrue(element("book-React Notes").exists)
        openReactNotes()
        XCTAssertTrue(readerButton(identifier: "next-page", label: "Next page").exists)
        XCTAssertTrue(pageControl().exists)
        XCTAssertTrue(readerButton(identifier: "speech-control", label: "Read page aloud").exists)
        XCTAssertTrue(scrubberControl().exists)
        capture("00-accessibility-contract")
    }

    func test01LibraryBaselineAndPrimaryTabs() {
        capture("01-library")
        XCTAssertTrue(element("library-screen").exists)
        XCTAssertTrue(app.textFields["library-search"].exists)
        XCTAssertTrue(app.buttons["import-pdf"].exists)
        app.buttons["library-filter-favorites"].tap(); capture("02-favorites")
        app.buttons["library-filter-recents"].tap(); capture("03-recents")
        app.buttons["library-filter-tags"].tap(); capture("04-tags")
        identifiedControl("library-tags-back", label: "Library").tap()
        openLibrarySettings(); capture("05-settings")
    }

    func test02ReaderBaselineReadAndOriginalModes() {
        openReactNotes(); capture("06-reader-read")
        XCTAssertTrue(app.segmentedControls.buttons["Read"].isSelected)
        app.segmentedControls.buttons["Original"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Original"].isSelected); capture("07-reader-original")
        app.segmentedControls.buttons["Read"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Read"].isSelected)
    }

    func test03ArrowPagingAndPositionPersistence() {
        openReactNotes()
        let page = pageControl()
        readerButton(identifier: "next-page", label: "Next page").tap()
        expectPage("Page 2 of 4", on: page); capture("08-reader-page-2")
        readerButton(identifier: "close-reader", label: "Back to library").tap()
        openReactNotes(); expectPage("Page 2 of 4", on: pageControl())
    }

    func test04ReaderContentsSectionsPagesBookmarks() {
        openReactNotes(); app.buttons["Contents"].tap()
        XCTAssertTrue(app.staticTexts["Find your place"].waitForExistence(timeout: 5)); capture("09-contents-sections")
        app.segmentedControls.buttons["Pages"].tap()
        XCTAssertTrue(app.buttons["Current page 1"].waitForExistence(timeout: 10)); capture("10-contents-pages")
        app.segmentedControls.buttons["Bookmarks"].tap(); capture("11-contents-bookmarks-empty")
    }

    func test05BookmarkAppearsInContents() {
        openReactNotes(); readerButton(identifier: "bookmark-page", label: "Bookmark").tap()
        app.buttons["Contents"].tap(); app.segmentedControls.buttons["Bookmarks"].tap()
        XCTAssertTrue(app.staticTexts["Page 1"].waitForExistence(timeout: 5)); capture("12-bookmark-saved")
    }

    func test06ReaderSearchFindsAndNavigates() {
        openReactNotes(); app.buttons["Search"].tap()
        let search = app.textFields["pdf-search-input"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("functional updater")
        let result = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "functional updater")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8)); capture("13-reader-search"); result.tap()
        expectPage("Page 2 of 4", on: pageControl())
        XCTAssertTrue(element("reader-search-return").waitForExistence(timeout: 5))
    }

    func test07PageStudyMarksAndDrawerFilters() {
        openReactNotes(); app.buttons["Mark important parts"].tap(); app.buttons["Important"].tap(); app.buttons["Mark important parts"].tap(); app.buttons["Your Marks"].tap()
        XCTAssertTrue(app.staticTexts["Your Marks"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "React")).firstMatch.exists); capture("14-study-important")
    }

    func test08AddNoteSurvivesReopen() {
        openReactNotes(); app.buttons["Mark important parts"].tap(); app.buttons["Add page note"].tap()
        let editor = app.textViews["note-text-input"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5)); editor.tap(); editor.typeText("Remember the state snapshot.")
        app.buttons["save-note"].tap(); readerButton(identifier: "close-reader", label: "Back to library").tap(); openReactNotes()
        app.buttons["Mark important parts"].tap(); app.buttons["Add page note"].tap()
        XCTAssertTrue(app.textViews["note-text-input"].waitForExistence(timeout: 5)); capture("15-note-reopen")
    }

    func test09TextControlsAreReachableInBothModes() {
        openReactNotes(); openAppearance()
        XCTAssertTrue(app.sliders["settings-read-text-slider"].waitForExistence(timeout: 5)); capture("16-text-read"); app.buttons["Done"].tap()
        app.segmentedControls.buttons["Original"].tap(); openAppearance()
        XCTAssertTrue(element("settings-surround-warm").waitForExistence(timeout: 5)); capture("17-text-original")
    }

    func test10SpeechControlChangesState() {
        openReactNotes(); let play = app.buttons["Read page aloud"]
        XCTAssertTrue(play.waitForExistence(timeout: 5)); play.tap()
        XCTAssertTrue(app.buttons["Pause reading"].waitForExistence(timeout: 5)); capture("18-speech-active")
        app.buttons["Pause reading"].tap()
    }

    func test11LibrarySearchAndFavorites() {
        let search = app.textFields["library-search"]
        search.tap(); search.typeText("closure")
        XCTAssertTrue(app.staticTexts["Inside your PDFs"].waitForExistence(timeout: 10)); capture("19-library-search")
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 15))
        app.buttons["actions-React Notes"].tap(); app.buttons["Add to favorites"].tap(); app.buttons["library-filter-favorites"].tap()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 5)); capture("20-favorites-populated")
    }

    func test12SettingsAndBackupEntryPoint() {
        openLibrarySettings(); app.swipeUp()
        XCTAssertTrue(app.buttons["export-backup"].waitForExistence(timeout: 5)); capture("21-settings-backup")
    }

    func test13HorizontalGestureSmokeTestInReadMode() {
        openReactNotes(); swipeReaderContentLeft()
        expectPage("Page 2 of 4", on: pageControl()); swipeReaderContentRight(); expectPage("Page 1 of 4", on: pageControl())
        capture("22-read-gesture-roundtrip")
    }

    func test14HorizontalGestureSmokeTestInOriginalMode() {
        openReactNotes(); app.segmentedControls.buttons["Original"].tap(); XCTAssertTrue(app.segmentedControls.buttons["Original"].isSelected)
        swipeReaderContentLeft()
        expectPage("Page 2 of 4", on: pageControl()); swipeReaderContentRight(); expectPage("Page 1 of 4", on: pageControl())
        capture("23-original-gesture-roundtrip")
    }
}
