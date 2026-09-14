import XCTest
@testable import ShelfCore

final class KnowledgeRepositoryTests: XCTestCase {
    func testManualCrossBookConnectionAndBacklinkPersist() async throws {
        let root = temporaryDirectory()
        let store = FileKnowledgeSnapshotStore(root: root)
        let repository = KnowledgeRepository(persistence: store)
        let (a, bundleA) = bundle(documentID: UUID(), fingerprint: "a", text: "React reconciliation preserves component identity when stable keys remain consistent.")
        let (b, bundleB) = bundle(documentID: UUID(), fingerprint: "b", text: "Stable keys tell React which component identity corresponds between renders.")
        try await repository.replaceDocumentIndex(bundleA)
        try await repository.replaceDocumentIndex(bundleB)
        let connection = try await repository.confirmConnection(source: a, destination: b, type: .sameIdea)
        XCTAssertEqual(connection.origin, .user)

        let reopened = KnowledgeRepository(persistence: FileKnowledgeSnapshotStore(root: root))
        let backlinks = try await reopened.connections(for: b)
        XCTAssertEqual(backlinks.count, 1)
        XCTAssertEqual(backlinks.first?.sourcePassageID, a)
    }

    func testReindexKeepsManualConnectionAndReanchorsChangedPassage() async throws {
        let root = temporaryDirectory(); let repository = KnowledgeRepository(persistence: FileKnowledgeSnapshotStore(root: root))
        let docA = UUID(), docB = UUID()
        let oldA = customBundle(doc: docA, fingerprint: "old", text: "React reconciliation compares a new tree with the previous tree and preserves component identity.", page: 4)
        let other = customBundle(doc: docB, fingerprint: "b", text: "Stable keys preserve component identity between React renders.", page: 2)
        try await repository.replaceDocumentIndex(oldA.bundle); try await repository.replaceDocumentIndex(other.bundle)
        try await repository.confirmConnection(source: oldA.passageID, destination: other.passageID)

        let newA = customBundle(doc: docA, fingerprint: "new", text: "React reconciliation compares the new tree to the previous tree while preserving component identity.", page: 5)
        try await repository.replaceDocumentIndex(newA.bundle)
        let snapshot = try await repository.snapshot()
        let connection = try XCTUnwrap(snapshot.confirmedConnections.first)
        XCTAssertFalse(connection.requiresRecovery)
        XCTAssertEqual(connection.sourcePassageID, newA.passageID)
    }

    func testTopicChainCreateSaveReopen() async throws {
        let root = temporaryDirectory(); let repository = KnowledgeRepository(persistence: FileKnowledgeSnapshotStore(root: root))
        let (passageID, bundle) = bundle(documentID: UUID(), fingerprint: "chain", text: "The event loop drains the microtask queue before the next task.")
        try await repository.replaceDocumentIndex(bundle)
        var chain = try await repository.createChain(title: "Event Loop")
        chain.items = [TopicChainItem(chainID: chain.id, kind: .passage, passageID: passageID, position: 0)]
        try await repository.saveChain(chain)
        let reopened = KnowledgeRepository(persistence: FileKnowledgeSnapshotStore(root: root))
        let snapshot = try await reopened.snapshot()
        XCTAssertEqual(snapshot.topicChains.first?.items.first?.passageID, passageID)
    }

    func testClearingDerivedIndexPreservesUserKnowledge() async throws {
        let root = temporaryDirectory(); let repository = KnowledgeRepository(persistence: FileKnowledgeSnapshotStore(root: root))
        let a = customBundle(doc: UUID(), fingerprint: "a", text: "React reconciliation preserves identity through keys.", page: 0)
        let b = customBundle(doc: UUID(), fingerprint: "b", text: "Keys keep component identity stable between renders.", page: 0)
        try await repository.replaceDocumentIndex(a.bundle); try await repository.replaceDocumentIndex(b.bundle)
        _ = try await repository.confirmConnection(source: a.passageID, destination: b.passageID)
        let concept = try await repository.createConcept(name: "Identity Preservation")
        try await repository.bind(passageID: a.passageID, conceptID: concept.id)
        try await repository.clearDerivedIndex()
        let snapshot = try await repository.snapshot()
        XCTAssertEqual(snapshot.confirmedConnections.count, 1)
        XCTAssertEqual(snapshot.userBindings.count, 1)
        XCTAssertTrue(snapshot.passages.allSatisfy { !$0.isAvailable })
    }

    private func bundle(documentID: UUID, fingerprint: String, text: String) -> (UUID, KnowledgeDocumentBundle) {
        let custom = customBundle(doc: documentID, fingerprint: fingerprint, text: text, page: 0)
        return (custom.passageID, custom.bundle)
    }

    private func customBundle(doc: UUID, fingerprint: String, text: String, page: Int) -> (passageID: UUID, bundle: KnowledgeDocumentBundle) {
        let analysis = DocumentAnalysis(documentID: doc, fingerprint: fingerprint, algorithmVersion: 1,
            pages: [AnalyzedPage(pageIndex: page, normalizedText: text,
                segments: [SourceSegment(id: StableIdentity.uuid("seg|\(text)"), pageIndex: page, kind: .paragraph, text: text, importance: 0.8)])])
        let seeded = ConceptCatalog.seeded(); let bundle = KnowledgePipeline().index(analysis: analysis, concepts: seeded.concepts, aliases: seeded.aliases)
        return (bundle.assembly.passages[0].id, bundle)
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
