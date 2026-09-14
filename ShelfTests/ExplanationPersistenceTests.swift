import XCTest
import ShelfCore
@testable import Shelf

/// Real local file-store tests. Candidates are labelled test data, not model quality evidence.
@MainActor final class ExplanationPersistenceTests: XCTestCase {
    private func directory() throws -> URL {
        let base = ProcessInfo.processInfo.environment["LEU_EXPLANATION_TEST_ROOT"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.temporaryDirectory
        let root = base.appendingPathComponent("explanation-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    private func record(documentID: UUID = UUID(), page: Int = 0) -> ExplanationRecord {
        let text = "A stable identifier can preserve an item across updates to a collection."
        let packet = ExplanationPacketBuilder().packet(
            selection: LearningSource(documentID: documentID, pageIndex: page, sourceText: text),
            pageLabel: "Test data · p. \(page + 1)", fingerprint: "test-data", extractionVersion: SourceExtractionVersion.current, canonicalPage: text)!
        return .init(candidate: .init(blocks: [.init(kind: .plainMeaning, text: text, sourceSpanIDs: ["s1"])]),
                     packet: packet, mode: .standard, backend: "test-double", availability: .available, generatedAt: Date())
    }

    private func key(_ record: ExplanationRecord) -> String {
        record.packet.cacheKey(mode: record.mode, backend: record.backend, providerRevision: record.providerRevision)
    }

    func testFreshCacheReopensPersistedExplanationWithoutCallingUnavailableProvider() async throws {
        let root = try directory(), value = record()
        let original = ExplanationCache(persistence: LearningIntelligenceCache(root: root))
        await original.store(value, for: key(value))
        XCTAssertNil(original.lastPersistenceError)
        let reopened = ExplanationCache(persistence: LearningIntelligenceCache(root: root))
        let controller = ExplanationController(provider: OfflineExplanationProvider(), cache: reopened)
        controller.start(packet: value.packet)
        for _ in 0..<200 where controller.isBusy { try await Task.sleep(for: .milliseconds(5)) }
        guard case .ready(let saved) = controller.state else { return XCTFail("Disk cache must work with model unavailable") }
        XCTAssertTrue(saved.servedFromCache)
        XCTAssertEqual(saved.candidate, value.candidate)
        XCTAssertEqual(controller.diagnostics.attempts, 0)
    }

    func testRemovingOneDocumentPreservesOtherExplanationsAndLibraryFiles() async throws {
        let root = try directory(), first = record(), second = record()
        let sentinel = root.appendingPathComponent("learning.json")
        let pdf = root.appendingPathComponent("original.pdf")
        let originalData = Data("test sentinel for user-owned data".utf8)
        try originalData.write(to: sentinel); try originalData.write(to: pdf)
        let disk = LearningIntelligenceCache(root: root)
        try await disk.saveExplanation(first, key: key(first), limit: 24)
        try await disk.saveExplanation(second, key: key(second), limit: 24)
        // Delete through a fresh front: the other document is not in memory.
        let cache = ExplanationCache(persistence: disk)
        await cache.removeAll(documentID: first.packet.documentID)
        XCTAssertNil(cache.lastPersistenceError)
        let deleted = await disk.loadExplanation(key(first)), retained = await disk.loadExplanation(key(second))
        XCTAssertNil(deleted); XCTAssertEqual(retained, second)
        XCTAssertEqual(try Data(contentsOf: sentinel), originalData)
        XCTAssertEqual(try Data(contentsOf: pdf), originalData)
    }

    func testPersistedPageOneDoesNotAnswerPageThree() async throws {
        let root = try directory(), id = UUID()
        let first = record(documentID: id, page: 0), third = record(documentID: id, page: 2)
        let disk = LearningIntelligenceCache(root: root)
        try await disk.saveExplanation(first, key: key(first), limit: 24)
        let cache = ExplanationCache(persistence: LearningIntelligenceCache(root: root))
        let missing = await cache.value(for: key(third)), saved = await cache.value(for: key(first))
        XCTAssertNil(missing); XCTAssertEqual(saved, first)
    }

    func testPersistedCandidateIsRevalidatedBeforeDisplay() async throws {
        let root = try directory()
        var invalid = record(); invalid.candidate.blocks[0].sourceSpanIDs = ["unknown"]
        let disk = LearningIntelligenceCache(root: root)
        try await disk.saveExplanation(invalid, key: key(invalid), limit: 24)
        let value = await ExplanationCache(persistence: disk).value(for: key(invalid))
        XCTAssertNil(value)
    }

    func testDiskCacheRemainsBoundedAndCanPruneDeletedDocuments() async throws {
        let disk = LearningIntelligenceCache(root: try directory())
        let values = (0..<4).map { record(page: $0) }
        for value in values { try await disk.saveExplanation(value, key: key(value), limit: 2) }
        var loaded = 0
        for value in values { if await disk.loadExplanation(key(value)) != nil { loaded += 1 } }
        XCTAssertEqual(loaded, 2)
        try await disk.retainExplanationDocuments([])
        for value in values { let saved = await disk.loadExplanation(key(value)); XCTAssertNil(saved) }
    }

    func testVersionedPromptResourceIsPresentAndRefinementsStayOnOriginal() throws {
        let prompt = try ExplanationPrompt.text(mode: .evenSimpler)
        XCTAssertEqual(ExplanationPrompt.version, 3)
        XCTAssertTrue(prompt.hasPrefix("RUNTIME_EXPLANATION_PROMPT — version 3 "))
        XCTAssertTrue(prompt.contains("SAME passage"))
        let example = try ExplanationPrompt.text(mode: .withExample)
        XCTAssertTrue(example.hasPrefix("RUNTIME_EXPLANATION_PROMPT — version 3 "))
        XCTAssertTrue(example.contains("ACTIVE REFINEMENT: withExample."))
        XCTAssertTrue(example.contains("explanation has kind plainMeaning; illustration has kind example."),
                      "V3 must request the two required typed roles, not just an unspecified prose example")
    }
}

private struct OfflineExplanationProvider: ExplanationIntelligenceProvider {
    let backend = "test-double"
    func availability() async -> LearningModelState { .unavailable }
    func explain(_ packet: ExplanationSourcePacket, mode: ExplanationMode, repairReasons: [String]) async throws -> ExplanationCandidate {
        XCTFail("An offline cache hit must never invoke a model")
        throw LearningIntelligenceError.unavailable(.unavailable)
    }
}
