import XCTest
@testable import ShelfCore

final class KnowledgeSearchTests: XCTestCase {
    func testSearchGroupsConceptPassageChainAndBook() {
        let doc = UUID()
        let passage = KnowledgePassage(id: UUID(), documentID: doc, pageIndex: 2, sectionTitle: "Reconciliation",
            text: "React reconciliation preserves component identity using stable keys.",
            normalizedText: "react reconciliation preserves component identity using stable keys",
            contentFingerprint: "abc", indexVersion: 1)
        let seeded = ConceptCatalog.seeded()
        let build = KnowledgeIndexBuilder().build(passages: [passage], concepts: seeded.concepts, aliases: seeded.aliases)
        let chain = TopicChain(title: "React Reconciliation")
        let snapshot = KnowledgeSnapshot(passages: [passage], indexRecords: build.records,
                                         detectedBindings: build.bindings, concepts: seeded.concepts,
                                         aliases: seeded.aliases, topicChains: [chain])
        let result = KnowledgeSearchEngine().search("reconciliation", in: snapshot)
        XCTAssertTrue(result.concepts.contains { $0.name == "Reconciliation" })
        XCTAssertEqual(result.passages.first?.id, passage.id)
        XCTAssertEqual(result.chains.first?.id, chain.id)
        XCTAssertEqual(result.documentIDs.first, doc)
    }

    func testLargeSyntheticIndexUsesCandidateNarrowing() {
        let tokenizer = TechnicalTokenizer()
        let records = (0..<10_000).map { index in
            let text = index % 997 == 0 ? "react reconciliation stable keys component identity" : "unrelated history geography paragraph \(index)"
            return KnowledgeIndexRecord(passageID: UUID(), documentID: UUID(), termCounts: tokenizer.termCounts(in: text),
                                        phraseCounts: tokenizer.phraseCounts(in: text), tokenCount: tokenizer.tokens(in: text).count)
        }
        let clock = ContinuousClock(); let start = clock.now
        let hits = BM25Index(records: records).search(terms: ["reconciliation", "component", "identity"], limit: 20)
        let elapsed = start.duration(to: clock.now)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertLessThan(elapsed, .seconds(3))
        print("KNOWLEDGE_BENCHMARK 10000_records_query_seconds=\(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)")
    }
}
