import XCTest

/// Regression journeys added after the V17 UX audit. These focus on navigation contracts
/// that can look correct in screenshots while still behaving incorrectly under gestures.
final class ShelfReaderRegressionUITests: ShelfUITestCase {

    func test15OriginalZoomPansWithoutTurningPageAndArrowStillTurns() {
        openReactNotes()
        app.segmentedControls.buttons["Original"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Original"].isSelected)
        let page = pageControl()
        expectPage("Page 1 of 4", on: page)

        let viewport = element("original-viewport-frame")
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))
        viewport.pinch(withScale: 2.0, velocity: 1.0)
        swipeReaderContentLeft()
        expectPage("Page 1 of 4", on: page)

        readerButton(identifier: "next-page", label: "Next page").tap()
        expectPage("Page 2 of 4", on: page)
        capture("24-original-zoom-pan-contract")
    }

    func test16SearchResultNavigatesThroughReaderLocation() {
        openReactNotes()
        app.buttons["Search"].tap()
        let search = app.textFields["pdf-search-input"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("functional updater")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "functional updater")).firstMatch.waitForExistence(timeout: 8))
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "functional updater")).firstMatch.tap()
        expectPage("Page 2 of 4", on: pageControl())
        XCTAssertTrue(element("reader-search-return").waitForExistence(timeout: 5))
        capture("25-search-navigation-page-2")
    }

    func test17PagesNavigatorOpensAroundCurrentPage() {
        openReactNotes()
        readerButton(identifier: "next-page", label: "Next page").tap()
        readerButton(identifier: "next-page", label: "Next page").tap()
        expectPage("Page 3 of 4", on: pageControl())
        app.buttons["Contents"].tap()
        app.segmentedControls.buttons["Pages"].tap()
        XCTAssertTrue(app.buttons["Current page 3"].waitForExistence(timeout: 8))
        capture("26-pages-current-page-3")
    }

    func test18EmptyBookmarksCanBookmarkCurrentPage() {
        openReactNotes()
        app.buttons["Contents"].tap()
        app.segmentedControls.buttons["Bookmarks"].tap()
        XCTAssertTrue(app.buttons["Bookmark current page"].waitForExistence(timeout: 5))
        app.buttons["Bookmark current page"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Page 1")).firstMatch.waitForExistence(timeout: 5))
        capture("27-bookmark-empty-state-action")
    }

    func test19ReadModeStudyMarkIsExplicitlyWholePage() {
        openReactNotes()
        readerButton(identifier: "next-page", label: "Next page").tap()
        app.buttons["Mark important parts"].tap()
        app.buttons["Important"].tap()
        app.buttons["Mark important parts"].tap(); app.buttons["Your Marks"].tap()
        XCTAssertTrue(app.staticTexts["Your Marks"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["p. 2"].exists)
        capture("28-study-whole-page-context")
    }

    func test20FocusModeKeepsExplicitLibraryExit() {
        openReactNotes()
        enterFocusMode()
        XCTAssertTrue(app.buttons["Back to library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Show reading controls"].exists)
        capture("29-focus-safe-exit")
    }

    func test21EmptyFavoritesHasBrowseLibraryRecovery() {
        app.buttons["library-filter-favorites"].tap()
        XCTAssertTrue(app.buttons["Browse library"].waitForExistence(timeout: 5))
        app.buttons["Browse library"].tap()
        XCTAssertTrue(app.buttons["book-React Notes"].waitForExistence(timeout: 5))
        capture("30-empty-favorites-recovery")
    }

}
