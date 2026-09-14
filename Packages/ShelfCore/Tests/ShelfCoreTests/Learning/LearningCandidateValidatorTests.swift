import XCTest
import ShelfCore

final class LearningCandidateValidatorTests: XCTestCase {
    func testFabricatedQuoteRejected() throws { try rejected(.fabricatedQuote) { $0.supportingQuote = "An entirely invented explanation absent from this page." } }
    func testDuplicateChoicesRejected() throws { try rejected(.duplicateOrInvalidChoices) { $0.choices[1] = $0.choices[0] } }
    func testUnsupportedExplanationRejected() throws { try rejected(.unsupportedExplanation) { $0.explanation = "An outside fact." } }
    func testWrongDocumentRejected() throws { try rejected(.wrongSource, wrongDocument: true) { _ in } }
    func testTwoSupportedChoicesRejected() throws {
        try rejected(.ambiguousAnswer) { $0.choices[1] = "A cache is a reusable store." }
    }
    func testQuotePresenceAloneCannotValidateQuestionMeaning() throws {
        try rejected(.semanticReviewRequired) { _ in }
    }

    private func rejected(_ expected: LearningCandidateValidator.Rejection,
                          wrongDocument: Bool = false,
                          mutate: (inout LearningModelCandidate) -> Void) throws {
        let text = "A cache is a reusable store. A queue is an ordered buffer. A stack is a last-in-first-out buffer."
        var page = AnalyzedPage(pageIndex: 0, normalizedText: text, segments: [])
        page.canonicalText = text
        var analysis = DocumentAnalysis(documentID: UUID(), fingerprint: "file", algorithmVersion: 2, pages: [page])
        analysis.extractionVersion = SourceExtractionVersion.current
        let packet = try XCTUnwrap(LearningSourcePacket(analysis: analysis, page: page))
        if wrongDocument { analysis.documentID = UUID() }
        var candidate = LearningModelCandidate(prompt: "Which storage behavior does a cache provide?",
            choices: ["a reusable store", "an ordered buffer", "a last-in-first-out buffer"], correctChoice: 0,
            explanation: "A cache is a reusable store.", supportingQuote: "A cache is a reusable store. ", concept: "cache", skill: "mechanism")
        // At least 30 characters are required for source evidence.
        candidate.supportingQuote = "A cache is a reusable store. A queue"
        mutate(&candidate)
        switch LearningCandidateValidator().validate(candidate, packet: packet, analysis: analysis, existing: []) {
        case .success: XCTFail("Expected \(expected)")
        case .failure(let reason): XCTAssertEqual(reason, expected)
        }
    }
}
