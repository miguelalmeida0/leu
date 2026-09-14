import XCTest
@testable import ShelfCore

/// Reproduces the study-material defects reported from the mid-level interview PDF:
/// tracked section labels leaking into answer options, mnemonics becoming definition
/// questions, front matter becoming recall prompts, and unbounded option length.
final class TrackedLabelAndInstructionTests: XCTestCase {
    private let analyzer = DocumentAnalyzer()
    private let documentID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func evidence(_ text: String, page: Int = 193) -> SemanticEvidenceSpan {
        SemanticEvidenceSpan(documentID: documentID, pageIndex: page, sectionTitle: nil, sourceText: text)
    }

    // MARK: Tracked labels

    func testLetterSpacedLabelStillCountsAsOneWordPerRun() {
        XCTAssertEqual(DocumentAnalyzer.spokenWordCount("M A K E I T S T I C K"), 1)
        XCTAssertEqual(DocumentAnalyzer.spokenWordCount("R E A L E X A M P L E"), 1)
        XCTAssertEqual(DocumentAnalyzer.spokenWordCount("I N O N E B R E AT H"), 1)
        XCTAssertEqual(DocumentAnalyzer.spokenWordCount("MAKE IT STICK"), 3)
        XCTAssertEqual(DocumentAnalyzer.spokenWordCount("The event loop is a scheduler"), 6)
    }

    /// Before the fix "R E A L E X A M P L E" counted as eleven words, missed the
    /// ten-word heading limit, and was merged into the preceding paragraph, which is
    /// how a section label ended up inside a multiple-choice option.
    func testTrackedLabelIsClassifiedAsHeadingNotParagraphTail() {
        let page = SourcePageInput(pageIndex: 193, text: """
        Reference identity is whether two references point to the same object.

        R E A L E X A M P L E

        Two objects with identical contents are still separate references.
        """)
        let result = analyzer.analyze(documentID: documentID, fingerprint: "x", pages: [page])
        let segments = result.pages[0].segments
        XCTAssertTrue(segments.contains { $0.kind == .heading && $0.text.contains("E X A M P L E") })
        XCTAssertFalse(segments.contains { $0.kind == .paragraph && $0.text.contains("E X A M P L E") },
                       "A tracked label must never survive inside a paragraph body")
    }

    // MARK: Memory hooks

    func testMemoryHookDoesNotBecomeADefinitionClaim() {
        let sentence = "One person viewed through two windows is still the same person."
        let claims = GeneralClaimExtractor().extract(sentence, evidence: evidence(sentence))
        XCTAssertTrue(claims.isEmpty, "A mnemonic has no recoverable answer and cannot be quiz truth")
    }

    func testOrdinaryDefinitionIsStillExtracted() {
        let sentence = "An origin is the browser security identity formed by scheme, host and port."
        let claims = GeneralClaimExtractor().extract(sentence, evidence: evidence(sentence))
        XCTAssertFalse(claims.isEmpty, "Real definitions must keep working")
        XCTAssertEqual(claims.first?.intent, .define)
    }

    // MARK: Reader instructions

    func testFrontMatterInstructionIsRejected() {
        XCTAssertTrue(InstructionalText.isReaderInstruction("Do not memorize it word-for-word. Keep the structure:"))
        XCTAssertTrue(InstructionalText.isReaderInstruction("Reconstruct the idea in your own words before you look."))
        XCTAssertTrue(InstructionalText.isReaderInstruction("If you cannot explain the definition in one breath, reread it."))
        XCTAssertFalse(InstructionalText.isReaderInstruction("An origin is scheme plus host plus port."))
    }

    func testInstructionSentenceProducesNoClaim() {
        let sentence = "Do not memorize it word-for-word."
        XCTAssertTrue(GeneralClaimExtractor().extract(sentence, evidence: evidence(sentence, page: 1)).isEmpty)
    }

    // MARK: Option length

    func testRunawayObjectIsRejectedBeforeItBecomesAnOption() {
        let long = "Reference identity is "
            + Array(repeating: "preserved across renders and memoization boundaries", count: 6).joined(separator: " and ")
            + "."
        let claims = GeneralClaimExtractor().extract(long, evidence: evidence(long))
        XCTAssertTrue(claims.isEmpty, "An object past the length cap cannot reach the option set")
    }

    func testOptionSetRejectsLengthMismatch() {
        XCTAssertNotNil(QuestionOptionQuality.rejectionReason(
            prompt: "What does reference identity mean in this source?",
            answer: "the same person",
            alternatives: ["a labeled cupboard built into the house",
                           Array(repeating: "preserved across renders", count: 12).joined(separator: " ")]))
    }
}
