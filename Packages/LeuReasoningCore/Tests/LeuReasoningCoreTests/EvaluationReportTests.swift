import XCTest
@testable import LeuReasoningCore

/// Emits the full certification report. `scripts/evaluate-super-intelligence.sh`
/// runs this test with LEU_EVAL_REPORT set and prints the resulting JSON.
final class EvaluationReportTests: XCTestCase {

    func testEmitEvaluationReport() async throws {
        let corpus = try CorpusFixture.load()
        let report = await EvaluationHarness(corpus: corpus).run()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        if let path = ProcessInfo.processInfo.environment["LEU_EVAL_REPORT"] {
            try data.write(to: URL(fileURLWithPath: path))
        }
        print(String(data: data, encoding: .utf8) ?? "")

        // Corpus size gates from the brief.
        XCTAssertGreaterThanOrEqual(corpus.atoms.count, 100)
        XCTAssertGreaterThanOrEqual(report.relationships.admitted, 50)
        XCTAssertGreaterThanOrEqual(corpus.chains.count, 30)
        XCTAssertGreaterThanOrEqual(corpus.learnerCases.count, 30)
        XCTAssertGreaterThanOrEqual(corpus.crossSourceCandidates.count, 20)
    }
}
