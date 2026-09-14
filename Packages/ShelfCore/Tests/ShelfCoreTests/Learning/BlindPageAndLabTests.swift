import XCTest
@testable import ShelfCore

final class BlindPageAndLabTests: XCTestCase {
    func testBlindPageRequiresMeaningfulProgress() {
        let policy = BlindPagePolicy()
        XCTAssertFalse(policy.shouldPrompt(BlindPageContext(pagesSincePrompt: 2, secondsSincePrompt: 500, atSectionBoundary: true, consecutiveSkips: 0)))
        XCTAssertTrue(policy.shouldPrompt(BlindPageContext(pagesSincePrompt: 5, secondsSincePrompt: 500, atSectionBoundary: true, consecutiveSkips: 0)))
    }

    func testSkippingMakesPromptsLessFrequent() {
        let policy = BlindPagePolicy()
        XCTAssertFalse(policy.shouldPrompt(BlindPageContext(pagesSincePrompt: 6, secondsSincePrompt: 500, atSectionBoundary: true, consecutiveSkips: 2)))
    }

    func testAllInitialLabsHaveDeterministicCorrectOrder() {
        let labs = LabCatalog.all()
        XCTAssertEqual(Set(labs.map(\.kind)).count, 5)
        for lab in labs {
            XCTAssertFalse(lab.elements.isEmpty)
            XCTAssertEqual(Set(lab.elements.map(\.id)), Set(lab.correctOrder))
            XCTAssertGreaterThanOrEqual(lab.scenario.choices.count, 3)
            XCTAssertEqual(Set(lab.scenario.choices.map(\.id)).count, lab.scenario.choices.count)
            XCTAssertTrue(lab.scenario.choices.contains { $0.id == lab.scenario.correctChoiceID })
            XCTAssertFalse(lab.scenario.explanation.isEmpty)
        }
    }
}
