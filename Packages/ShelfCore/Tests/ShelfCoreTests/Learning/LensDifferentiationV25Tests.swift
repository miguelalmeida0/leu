import XCTest
@testable import ShelfCore

final class LensDifferentiationV25Tests: XCTestCase {
    static let passages = [
        "React effects rerun when a dependency changes identity.",
        "Reconciliation is the process of comparing interface descriptions to choose updates.",
        "HTTP caching reduces origin requests by reusing fresh responses.",
        "Unlike authentication, authorization determines what an identity may access.",
        "Indexes accelerate reads but add maintenance work during writes.",
        "A transaction is a unit of work committed atomically.",
        "A microtask runs after the current script completes.",
        "Binary search requires the input array to be sorted.",
        "CSS grid works by arranging content in rows and columns.",
        "Distributed caching reduces origin load by serving shared cached responses."
    ]

    func testTenPassagesProduceDistinctSourceBackedProjections() throws {
        var ideas = Set<String>(), meanings = Set<String>(), questions = Set<String>()
        for (page, passage) in Self.passages.enumerated() {
            let source = LearningSource(documentID: UUID(), pageIndex: page, sourceText: passage)
            let projection = SourceMeaningComposer().project(source: source, index: nil)
            ideas.insert(try XCTUnwrap(projection.keyIdea, passage))
            meanings.insert(projection.sentences.map(\.text).joined())
            questions.insert(try XCTUnwrap(projection.questions.first, passage).prompt)
            XCTAssertFalse(projection.terms.isEmpty)
            XCTAssertFalse(projection.sentences.isEmpty)
            XCTAssertLessThanOrEqual(projection.sentences.count, 3)
            XCTAssertTrue(projection.sentences.allSatisfy { $0.source.documentID == source.documentID && $0.source.pageIndex == page && !$0.propositionID.isEmpty })
        }
        XCTAssertEqual(ideas.count, 10); XCTAssertEqual(meanings.count, 10); XCTAssertEqual(questions.count, 10)
    }

    func testUnrelatedSourceCannotBecomePlainMeaning() {
        let document = UUID()
        let foreign = SemanticCompiler().compile(DocumentAnalysis(documentID: UUID(), fingerprint: "foreign", algorithmVersion: 2,
            pages: [AnalyzedPage(pageIndex: 0, normalizedText: "A cache is a store of previously computed responses.", segments: [])]))
        let result = SourceMeaningComposer().project(source: LearningSource(documentID: document, pageIndex: 0, sourceText: "A cache appears in the illustration."), index: foreign)
        XCTAssertNil(result.keyIdea); XCTAssertTrue(result.sentences.isEmpty); XCTAssertTrue(result.questions.isEmpty)
    }

    func testCompositionStopsAtThreeRelatedClaims() {
        let text = "A cache is a store of computed values. A cache prevents repeated work. A cache requires a stable key. A cache allows reuse across requests."
        let result = SourceMeaningComposer().project(source: LearningSource(documentID: UUID(), pageIndex: 2, sourceText: text), index: nil)
        XCTAssertEqual(result.sentences.count, 3)
        XCTAssertEqual(Set(result.sentences.map(\.propositionID)).count, 3)
        XCTAssertTrue(result.sentences.allSatisfy { text.contains($0.source.sourceText) })
    }
    func testTradeoffMeaningComposesBothGroundedSides() throws {
        let text = "Indexes accelerate reads but add maintenance work during writes."
        let source = LearningSource(documentID: UUID(), pageIndex: 7, sourceText: text)
        let projection = SourceMeaningComposer().project(source: source, index: nil)
        let meaning = try XCTUnwrap(projection.sentences.first)
        XCTAssertTrue(meaning.text.contains("Indexes accelerate reads"))
        XCTAssertTrue(meaning.text.contains("Indexes add maintenance work during writes"))
        XCTAssertEqual(meaning.source, source)
        XCTAssertFalse(meaning.propositionID.isEmpty)
        XCTAssertFalse(meaning.text.contains("B-tree"), "No external mechanism may be inserted")
    }

}
