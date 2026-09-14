import XCTest
@testable import ShelfCore

final class SpeechParagraphV25Tests: XCTestCase {
    func testParagraphRetainsSentenceRangesAfterTechnicalNormalization() throws {
        let source = "useEffect updates the DOM. HTTPS uses TLS."
        let block = SpeechInputBlock(documentID: UUID(), pageIndex: 18, kind: .prose, text: source,
                                    sourceRange: SourceTextRange(location: 120, length: (source as NSString).length))
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: [block]))
        let paragraph = try XCTUnwrap(SpeechParagraphBuilder().paragraph(from: plan.segments, startingAt: 0))
        XCTAssertEqual(paragraph.sentences.count, 2)
        for sentence in paragraph.sentences {
            let mapped = paragraph.sentence(atUTF16: NSRange(location: sentence.spokenRange.location, length: 1))
            XCTAssertEqual(mapped, sentence)
            let range = try XCTUnwrap(sentence.segment.source.sourceRange)
            XCTAssertEqual((source as NSString).substring(with: NSRange(location: range.location - 120, length: range.length)), sentence.segment.source.sourceText)
            XCTAssertEqual(sentence.segment.source.pageIndex, 18)
        }
        XCTAssertNil(paragraph.sentence(atUTF16: NSRange(location: NSNotFound, length: 0)))
    }

    func testBlockCodeAndPageBoundariesNeverMerge() throws {
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: [
            SpeechInputBlock(pageIndex: 0, kind: .prose, text: "First sentence. Second sentence."),
            SpeechInputBlock(pageIndex: 0, kind: .code, text: "const answer = 42;"),
            SpeechInputBlock(pageIndex: 1, kind: .prose, text: "A new page.")
        ]))
        let first = try XCTUnwrap(SpeechParagraphBuilder().paragraph(from: plan.segments, startingAt: 0))
        XCTAssertEqual(first.sentences.count, 2)
        XCTAssertEqual(SpeechParagraphBuilder().paragraph(from: plan.segments, startingAt: 2)?.sentences.count, 1)
        XCTAssertEqual(SpeechParagraphBuilder().paragraph(from: plan.segments, startingAt: 3)?.sentences.count, 1)
    }

    func testResumeAtSecondSentenceDoesNotReplayTheFirst() throws {
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: [SpeechInputBlock(pageIndex: 0, kind: .prose, text: "First sentence. Second sentence. Third sentence.")]))
        let resumed = try XCTUnwrap(SpeechParagraphBuilder().paragraph(from: plan.segments, startingAt: 1))
        XCTAssertEqual(resumed.sentences.map(\.queueIndex), [1, 2])
        XCTAssertFalse(resumed.spokenText.contains("First sentence"))
    }

    func testUTF16OffsetsSurviveEmojiAndNormalization() throws {
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: [SpeechInputBlock(pageIndex: 0, kind: .prose, text: "A smile 🙂 starts the example. JSON encodes the result.")]))
        let paragraph = try XCTUnwrap(SpeechParagraphBuilder().paragraph(from: plan.segments, startingAt: 0))
        let second = try XCTUnwrap(paragraph.sentences.last)
        XCTAssertEqual(second.spokenRange.location, (plan.segments[0].spokenText as NSString).length + 1)
        XCTAssertEqual(paragraph.sentence(atUTF16: NSRange(location: second.spokenRange.location, length: 4))?.queueIndex, 1)
    }

    func testBackendWithoutTimingKeepsSentenceGranularity() {
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: [SpeechInputBlock(pageIndex: 0, kind: .prose, text: "First sentence. Second sentence.")]))
        XCTAssertEqual(SpeechParagraphBuilder().paragraph(from: plan.segments, startingAt: 0, mergeProse: false)?.sentences.count, 1)
    }
}
