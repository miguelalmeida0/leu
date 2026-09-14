import XCTest
@testable import ShelfCore

final class SpeechNormalizationCacheTests: XCTestCase {
    func testRepeatedNormalizationRunsOnceButKeepsBothSources() {
        var cache = SpeechNormalizationCache()
        var calls = 0
        for _ in 0..<1_000 {
            let value = cache.value(for: "useEffect", isCode: false) { calls += 1; return "use effect" }
            XCTAssertEqual(value, "use effect")
        }
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(cache.count, 1)
    }

    func testCodeAndProseDoNotShareNormalization() {
        var cache = SpeechNormalizationCache()
        XCTAssertEqual(cache.value(for: "f(x)", isCode: false) { "prose" }, "prose")
        XCTAssertEqual(cache.value(for: "f(x)", isCode: true) { "code" }, "code")
        XCTAssertEqual(cache.count, 2)
    }

    func testCacheHasEntryAndByteLimits() {
        var cache = SpeechNormalizationCache()
        for index in 0..<2_000 {
            XCTAssertEqual(cache.value(for: "source \(index)", isCode: false) { "spoken \(index)" }, "spoken \(index)")
        }
        XCTAssertEqual(cache.count, SpeechNormalizationCache.maximumEntries)
        var large = SpeechNormalizationCache()
        let long = String(repeating: "x", count: SpeechNormalizationCache.maximumEntryBytes)
        XCTAssertEqual(large.value(for: long, isCode: false) { long }, long)
        XCTAssertEqual(large.count, 0)
    }

    func testCachePreservesEverySegmentIdentityMappingKindAndProsody() {
        let id = UUID()
        let text = "useEffect runs after rendering. HTTPS uses TLS."
        let blocks = (0..<50).map { index in
            SpeechInputBlock(documentID: id, pageIndex: index, kind: index.isMultiple(of: 3) ? .quote : .prose,
                             text: text, sourceRange: SourceTextRange(location: index * 100, length: text.utf16.count))
        }
        let compiler = SpeechCompiler()
        let combined = compiler.compile(document: SpeechDocument(documentID: id, blocks: blocks)).segments
        let independentlyCompiled = blocks.flatMap {
            compiler.compile(document: SpeechDocument(documentID: id, blocks: [$0])).segments
        }
        XCTAssertEqual(combined, independentlyCompiled)
        XCTAssertEqual(Set(combined.map(\.id)).count, 100)
        XCTAssertEqual(Set(combined.map { $0.source.pageIndex }).count, 50)
    }

    func testUserDictionaryAndCodeModeCannotLeakBetweenCompileCalls() {
        let compiler = SpeechCompiler()
        let document = SpeechDocument(blocks: [SpeechInputBlock(pageIndex: 0, kind: .code, text: "PostgreSQL(x);")])
        var first = PronunciationDictionary(); first.setUserOverride(display: "PostgreSQL", spoken: "Database One")
        var second = PronunciationDictionary(); second.setUserOverride(display: "PostgreSQL", spoken: "Database Two")
        let a = compiler.compile(document: document, dictionary: first, codeMode: .natural).segments[0].spokenText
        let b = compiler.compile(document: document, dictionary: second, codeMode: .literal).segments[0].spokenText
        XCTAssertTrue(a.contains("Database One"))
        XCTAssertTrue(b.contains("Database Two"))
        XCTAssertFalse(b.contains("Database One"))
        XCTAssertTrue(b.contains("open parenthesis"))
    }

    func testRawUTF16SourceAndPerBlockDocumentIdentityArePreserved() {
        let text = "Résumé: useEffect runs after rendering."
        let blocks = [UUID(), UUID()].enumerated().map { index, id in
            SpeechInputBlock(documentID: id, pageIndex: index, kind: .prose, text: text,
                             sourceRange: SourceTextRange(location: 70 + index, length: text.utf16.count))
        }
        let plan = SpeechCompiler().compile(document: SpeechDocument(blocks: blocks))
        XCTAssertEqual(plan.segments.count, 2)
        for (index, segment) in plan.segments.enumerated() {
            XCTAssertEqual(segment.source.sourceText, text)
            XCTAssertEqual(segment.source.sourceRange?.location, 70 + index)
            XCTAssertEqual(segment.source.sourceRange?.length, text.utf16.count)
            XCTAssertEqual(segment.source.documentID, blocks[index].documentID)
        }
    }

    func testEmptyNormalizationCanBeCachedWithoutCreatingAnAudioSegment() {
        var cache = SpeechNormalizationCache()
        var calls = 0
        for _ in 0..<10 {
            XCTAssertEqual(cache.value(for: " ", isCode: false) { calls += 1; return "" }, "")
        }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(SpeechCompiler().compile(document: SpeechDocument(blocks: [
            SpeechInputBlock(pageIndex: 0, kind: .prose, text: " ")])).segments.isEmpty)
    }

    func testConcurrentCompilesHaveIndependentDictionaries() async {
        let compiler = SpeechCompiler()
        let values = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for index in 0..<16 {
                group.addTask {
                    var dictionary = PronunciationDictionary()
                    let phrase = "Database number \(index)"
                    dictionary.setUserOverride(display: "PostgreSQL", spoken: phrase)
                    let blocks = (0..<5).map { SpeechInputBlock(pageIndex: $0, kind: .prose, text: "PostgreSQL uses MVCC.") }
                    return compiler.compile(document: SpeechDocument(blocks: blocks), dictionary: dictionary)
                        .segments.allSatisfy { $0.spokenText.contains(phrase) }
                }
            }
            var results: [Bool] = []
            for await value in group { results.append(value) }
            return results
        }
        XCTAssertEqual(values.count, 16)
        XCTAssertTrue(values.allSatisfy { $0 })
    }
}
