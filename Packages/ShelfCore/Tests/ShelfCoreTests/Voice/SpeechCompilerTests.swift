import XCTest
@testable import ShelfCore

final class SpeechCompilerTests: XCTestCase {
    func testSourceAndSpokenTextStaySeparateAndMapped() throws {
        let source = "useEffect runs after React commits the rendered output to the DOM."
        let block = SpeechInputBlock(documentID: UUID(), pageIndex: 8, kind: .prose,
                                     text: source, sourceRange: SourceTextRange(location: 100, length: (source as NSString).length))
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: [block]))
        let segment = try XCTUnwrap(plan.segments.first)
        XCTAssertEqual(segment.source.sourceText, source)
        XCTAssertNotEqual(segment.spokenText, source)
        XCTAssertTrue(segment.spokenText.contains("use effect"))
        XCTAssertEqual(segment.source.sourceRange?.location, 100)
        XCTAssertEqual(segment.source.pageIndex, 8)
    }

    func testHeadingCodeAndProseGetDifferentProsody() {
        let compiler = SpeechCompiler()
        let plan = compiler.compile(document: SpeechDocument(blocks: [
            SpeechInputBlock(pageIndex: 0, kind: .heading, text: "EVENT LOOP"),
            SpeechInputBlock(pageIndex: 0, kind: .prose, text: "The event loop coordinates tasks."),
            SpeechInputBlock(pageIndex: 0, kind: .code, text: "const [count, setCount] = useState(0)")
        ]), rate: SpeechRateProfile(userMultiplier: 1.5))
        XCTAssertEqual(plan.segments.count, 3)
        XCTAssertLessThan(plan.segments[0].prosody.rateMultiplier, plan.segments[1].prosody.rateMultiplier)
        XCTAssertLessThan(plan.segments[2].prosody.rateMultiplier, plan.segments[1].prosody.rateMultiplier)
        XCTAssertGreaterThan(plan.segments[0].prosody.postPause, plan.segments[1].prosody.postPause)
    }

    func testUserPronunciationOverrideWins() {
        var dictionary = PronunciationDictionary()
        dictionary.setUserOverride(display: "PostgreSQL", spoken: "Post grass")
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: [
            SpeechInputBlock(pageIndex: 0, kind: .prose, text: "PostgreSQL uses MVCC.")
        ]), dictionary: dictionary)
        XCTAssertTrue(plan.segments[0].spokenText.contains("Post grass"))
        XCTAssertFalse(plan.segments[0].spokenText.contains("Postgres Q L"))
    }

    func testLargeTechnicalSpeechCompilationStaysInteractive() {
        let sentence = "useEffect runs after rendering. Promise.all resolves work in O(log n). HTTPS uses TLS."
        let blocks = (0..<1_000).map { SpeechInputBlock(pageIndex: $0 / 20, kind: .prose, text: sentence) }
        let clock = ContinuousClock(); let start = clock.now
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: blocks))
        let elapsed = start.duration(to: clock.now)
        XCTAssertEqual(plan.segments.count, 3_000)
        XCTAssertLessThan(elapsed, .seconds(3))
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        print("VOICE_BENCHMARK 1000_blocks_3000_segments_seconds=\(seconds)")
    }

    func testBenchmarkCorpusCompilesWithoutEmptySegments() {
        let inputs = [
            "useEffect runs after React commits the rendered output to the DOM.",
            "The === operator performs strict equality, while == allows coercion.",
            "Binary search runs in O(log n), while linear search runs in O(n).",
            "HTTPS encrypts HTTP communication using TLS.",
            "Promise.all resolves when every promise resolves.",
            "Promise<User[]> represents a promise containing an array of User objects.",
            "PostgreSQL uses MVCC to manage concurrent transactions.",
            "HTML, CSS, HTTP, DOM, API, JSON, SQL, OAuth and JWT."
        ]
        let blocks = inputs.enumerated().map { SpeechInputBlock(pageIndex: $0.offset, kind: .prose, text: $0.element) }
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: blocks))
        XCTAssertEqual(plan.segments.count, inputs.count)
        XCTAssertTrue(plan.segments.allSatisfy { !$0.spokenText.isEmpty && !$0.source.sourceText.isEmpty })
    }
}
