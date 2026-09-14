import XCTest
import ShelfCore
@testable import Shelf

final class KnowledgeIntegrationTests: XCTestCase {
    func testLearningAnalysisBecomesStableConnectedPassages() throws {
        let documentID = UUID()
        let analysis = DocumentAnalysis(documentID: documentID, fingerprint: "abc", algorithmVersion: DocumentAnalyzer.algorithmVersion,
            pages: [
                AnalyzedPage(pageIndex: 0, normalizedText: "React reconciliation preserves component identity. Stable keys matter.",
                    segments: [SourceSegment(pageIndex: 0, kind: .heading, text: "Reconciliation"),
                               SourceSegment(pageIndex: 0, kind: .paragraph, text: "React reconciliation preserves component identity. Stable keys matter.")]),
                AnalyzedPage(pageIndex: 1, normalizedText: "State is preserved when component identity remains stable.",
                    segments: [SourceSegment(pageIndex: 1, kind: .paragraph, text: "State is preserved when component identity remains stable.")])
            ])
        let seeded = ConceptCatalog.seeded()
        let bundle = KnowledgePipeline().index(analysis: analysis, concepts: seeded.concepts, aliases: seeded.aliases)
        XCTAssertFalse(bundle.assembly.passages.isEmpty)
        XCTAssertEqual(Set(bundle.assembly.passages.map(\.documentID)), Set([documentID]))
        XCTAssertEqual(Set(bundle.index.records.map(\.passageID)), Set(bundle.assembly.passages.map(\.id)))
        XCTAssertTrue(bundle.index.records.contains { !$0.conceptIDs.isEmpty })
    }

    func testKnowledgePersistenceIsSeparateFromDerivedIndex() async throws {
        let root = temporaryDirectory()
        let repository = KnowledgeRepository(persistence: FileKnowledgeSnapshotStore(root: root))
        _ = try await repository.open()
        let concept = try await repository.createConcept(name: "Referential Equality")
        try await repository.clearDerivedIndex()
        let reopened = KnowledgeRepository(persistence: FileKnowledgeSnapshotStore(root: root))
        let snapshot = try await reopened.open()
        XCTAssertTrue(snapshot.concepts.contains { $0.id == concept.id })
        XCTAssertTrue(snapshot.indexRecords.isEmpty)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
