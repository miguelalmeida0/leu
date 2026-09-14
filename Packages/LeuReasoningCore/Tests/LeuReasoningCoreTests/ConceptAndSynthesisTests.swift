import XCTest
@testable import LeuReasoningCore

final class ConceptAndSynthesisTests: XCTestCase {

    func testCachingCompressesToFiveGroundedLevels() throws {
        let graph = try CorpusFixture.graph()
        let model = ConceptCompressor().compress(concept: "caching", in: graph)
        XCTAssertNotNil(model.oneSentence)
        XCTAssertFalse(model.tradeOffsAndFailures.isEmpty)
        for line in model.allLines {
            XCTAssertTrue(line.provenance.isComplete, "ungrounded line: \(line.text)")
        }
    }

    func testMissingLevelsAreReportedAsGapsNotInvented() throws {
        let graph = try CorpusFixture.graph()
        let model = ConceptCompressor().compress(concept: "hoisting", in: graph)
        XCTAssertNotNil(model.oneSentence)
        // Nothing in the corpus states a failure mode for hoisting.
        XCTAssertTrue(model.tradeOffsAndFailures.isEmpty)
        XCTAssertTrue(model.gaps.contains { $0.contains("failure mode") })
    }

    func testUnknownConceptProducesGapsOnly() throws {
        let graph = try CorpusFixture.graph()
        let model = ConceptCompressor().compress(concept: "monad transformers", in: graph)
        XCTAssertNil(model.oneSentence)
        XCTAssertTrue(model.allLines.isEmpty)
        XCTAssertFalse(model.gaps.isEmpty)
    }

    func testSynthesisFindsTheCommonThreadAcrossDocuments() throws {
        let graph = try CorpusFixture.graph()
        let synthesizer = MultiSourceSynthesizer()
        let plan = synthesizer.plan(concept: "caching", in: graph)
        XCTAssertFalse(plan.commonThread.isEmpty)
        XCTAssertTrue(plan.commonThread.allSatisfy { $0.documentIDs.count > 1 })
    }

    func testSynthesisReportsOnlyRealDisagreement() throws {
        let graph = try CorpusFixture.graph()
        let synthesizer = MultiSourceSynthesizer()

        // caching: one source says it causes stale data, another says it prevents it.
        let caching = synthesizer.plan(concept: "caching", in: graph)
        XCTAssertTrue(caching.disagreements.contains { $0.kind == .directionConflict })

        // closures are described by one source only: no contrast may be manufactured.
        let closures = synthesizer.plan(concept: "a closure", in: graph)
        XCTAssertTrue(closures.disagreements.isEmpty)
        let rendered = synthesizer.render(closures)
        XCTAssertFalse(rendered.sections.contains { $0.title == "WHERE THEY DIFFER" })
    }

    func testNumericDisagreementIsDetected() throws {
        let graph = try CorpusFixture.graph()
        let plan = MultiSourceSynthesizer().plan(concept: "a retry budget", in: graph)
        XCTAssertTrue(plan.disagreements.contains { $0.kind == .numericConflict })
    }

    func testEveryRenderedSynthesisLineIsGrounded() throws {
        let graph = try CorpusFixture.graph()
        let synthesizer = MultiSourceSynthesizer()
        for concept in ["caching", "retrying", "an index", "a stable key", "a timeout"] {
            let rendered = synthesizer.render(synthesizer.plan(concept: concept, in: graph))
            for section in rendered.sections where section.title != "OPEN QUESTION" {
                for line in section.lines {
                    XCTAssertTrue(line.provenance.isComplete, "ungrounded synthesis line: \(line.text)")
                    XCTAssertFalse(line.atomIDs.isEmpty, "synthesis line cites no atom: \(line.text)")
                }
            }
        }
    }
}
