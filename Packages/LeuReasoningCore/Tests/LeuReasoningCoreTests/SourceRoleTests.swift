import XCTest
@testable import LeuReasoningCore

final class SourceRoleTests: XCTestCase {

    /// The classifier must recognise the mobile-mastery section structure from
    /// shape and vocabulary, not from a list of known heading strings.
    func testClassifiesMasteryLayoutWithoutLiteralHeadingMatches() {
        let blocks = [
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 0, text: "IN ONE BREATH",
                        fontSize: 16, isBold: true, isAllCaps: true, verticalPosition: 0.1),
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 1,
                        text: "A stable key helps React match an item to its previous instance.",
                        fontSize: 11, isBold: false, verticalPosition: 0.2),
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 2, text: "MAKE IT STICK",
                        fontSize: 16, isBold: true, isAllCaps: true, verticalPosition: 0.4),
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 3, text: "Keys keep your identity.",
                        fontSize: 11, verticalPosition: 0.45),
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 4, text: "SAY THIS IN THE INTERVIEW",
                        fontSize: 16, isBold: true, isAllCaps: true, verticalPosition: 0.6),
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 5,
                        text: "Explain that keys identify items across renders.", fontSize: 11, verticalPosition: 0.65),
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 6, text: "12", verticalPosition: 0.97)
        ]
        let assignments = SourceRoleClassifier().classify(blocks: blocks)
        XCTAssertEqual(assignments[0].role, .structure)
        XCTAssertEqual(assignments[1].role, .compactExplanation)
        XCTAssertEqual(assignments[3].role, .mnemonic)
        XCTAssertEqual(assignments[5].role, .presentationAdvice)
        XCTAssertEqual(assignments[6].role, .furniture)
    }

    /// Unseen wording for the same job must still land in the right family.
    func testGeneralisesToUnseenHeadingWording() {
        let blocks = [
            SourceBlock(documentID: "other", page: 1, indexOnPage: 0, text: "IN A NUTSHELL",
                        fontSize: 15, isBold: true, isAllCaps: true),
            SourceBlock(documentID: "other", page: 1, indexOnPage: 1, text: "Caching reuses previously fetched data.", fontSize: 11),
            SourceBlock(documentID: "other", page: 1, indexOnPage: 2, text: "COMMON TRAPS",
                        fontSize: 15, isBold: true, isAllCaps: true),
            SourceBlock(documentID: "other", page: 1, indexOnPage: 3, text: "Stale data survives past its usefulness.", fontSize: 11)
        ]
        let assignments = SourceRoleClassifier().classify(blocks: blocks)
        XCTAssertEqual(assignments[1].role, .compactExplanation)
        XCTAssertEqual(assignments[3].role, .caution)
    }

    func testMnemonicAndAdviceNeverYieldFactualClaims() {
        XCTAssertFalse(SourceRole.mnemonic.yieldsFactualClaims)
        XCTAssertFalse(SourceRole.presentationAdvice.yieldsFactualClaims)
        XCTAssertFalse(SourceRole.furniture.yieldsFactualClaims)
        XCTAssertTrue(SourceRole.compactExplanation.yieldsFactualClaims)
    }

    func testRepeatedTextAcrossPagesBecomesFurniture() {
        var blocks: [SourceBlock] = []
        for page in 1...4 {
            blocks.append(SourceBlock(documentID: "d", page: page, indexOnPage: 0,
                                      text: "Mobile Mastery Series", verticalPosition: 0.02))
            blocks.append(SourceBlock(documentID: "d", page: page, indexOnPage: 1,
                                      text: "An index enables row lookup without a full scan.", fontSize: 11))
        }
        let assignments = SourceRoleClassifier().classify(blocks: blocks)
        let header = assignments.first { $0.block.text == "Mobile Mastery Series" }
        XCTAssertEqual(header?.role, .furniture)
    }
}
