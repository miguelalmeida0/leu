import XCTest
@testable import ShelfCore

final class PDFTextCleanerTests: XCTestCase {
    func testPaginationHyphenAndPageArtifactsAreCleaned() {
        let raw = "Java-\nScript executes on a single\nthread.\n42\nCHAPTER 3"
        let output = PDFTextCleaner().clean(raw)
        XCTAssertTrue(output.contains("JavaScript executes on a single thread."))
        XCTAssertFalse(output.contains("\n42\n"))
        XCTAssertFalse(output.lowercased().contains("chapter 3"))
    }

    func testLegitimateTechnicalHyphenIsNotDestroyed() {
        let output = PDFTextCleaner().clean("CSS-in-JS is one\napproach.")
        XCTAssertTrue(output.contains("CSS-in-JS"))
    }
}
