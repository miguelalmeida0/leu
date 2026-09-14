import XCTest
@testable import ShelfCore

final class KnowledgeRankingTests: XCTestCase {
    func testStrongTechnicalRelationshipBeatsGenericOverlap() {
        let docA = UUID(), docB = UUID(), docC = UUID()
        let passages = [
            passage(docA, 0, "React reconciliation compares rendered trees and stable keys preserve component identity between renders.", "Reconciliation"),
            passage(docB, 4, "Stable keys help React reconciliation preserve component identity and state between renders.", "Preserving State"),
            passage(docC, 2, "A system component can process user data and return a value from a function.", "General Concepts")
        ]
        let seeded = ConceptCatalog.seeded()
        let build = KnowledgeIndexBuilder().build(passages: passages, concepts: seeded.concepts, aliases: seeded.aliases)
        var snapshot = KnowledgeSnapshot(passages: passages, indexRecords: build.records,
                                         detectedBindings: build.bindings, concepts: seeded.concepts, aliases: seeded.aliases)
        let ranked = ConnectionRanker().related(to: passages[0], snapshot: snapshot, limit: 5, minimumScore: 0)
        XCTAssertEqual(ranked.first?.passage.id, passages[1].id)
        XCTAssertTrue((ranked.first?.reason.explanation ?? "").contains("concept") || (ranked.first?.reason.explanation ?? "").contains("Related"))
        XCTAssertFalse(ranked.prefix(1).contains(where: { $0.passage.id == passages[2].id }))
        snapshot.indexRecords = []
        XCTAssertTrue(ConnectionRanker().related(to: passages[0], snapshot: snapshot).isEmpty)
    }

    func testQualityFloorCanReturnNothing() {
        let a = passage(UUID(), 0, "This system stores data and returns a value.", nil)
        let b = passage(UUID(), 0, "The application process accepts user information.", nil)
        let seeded = ConceptCatalog.seeded()
        let build = KnowledgeIndexBuilder().build(passages: [a,b], concepts: seeded.concepts, aliases: seeded.aliases)
        let snapshot = KnowledgeSnapshot(passages: [a,b], indexRecords: build.records,
                                         detectedBindings: build.bindings, concepts: seeded.concepts, aliases: seeded.aliases)
        XCTAssertTrue(ConnectionRanker().related(to: a, snapshot: snapshot, minimumScore: 2.4).isEmpty)
    }

    private func passage(_ doc: UUID, _ page: Int, _ text: String, _ section: String?) -> KnowledgePassage {
        let clean = text.lowercased()
        return KnowledgePassage(id: StableIdentity.uuid("test|\(doc)|\(page)|\(text)"), documentID: doc,
                                pageIndex: page, sectionTitle: section, text: text, normalizedText: clean,
                                contentFingerprint: String(StableIdentity.hash64(clean)), indexVersion: 1)
    }
}
