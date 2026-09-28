import XCTest
@testable import ShelfCore

/// V36 against V35 on explanations neither was written against. The same code reads each split
/// twice: words only (exactly V35) and with meaning too (V36). dev (one author) and dev2 (three
/// authors, seven documents) are development splits and are printed; sealed36 (four other authors,
/// written after the reader was frozen) was scored once and prints aggregates only on request.
final class SemanticGeneralizationTests: XCTestCase {
    private typealias Report = GeneralizationEvaluation.Report

    /// Meaning is evidence, never a verdict: it never records mastery, credit for a misconception or
    /// a misconception that V35 would not, and it commits no more wrong verdicts.
    private func assertV36IsNoLessSafe(_ v36: Report, than v35: Report, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(v36.falseMastery, v35.falseMastery, "false mastery", file: file, line: line)
        XCTAssertLessThanOrEqual(v36.misconceptionCredited, v35.misconceptionCredited, "credited misconceptions", file: file, line: line)
        XCTAssertLessThanOrEqual(v36.falseMisconception, v35.falseMisconception, "false misconceptions", file: file, line: line)
        XCTAssertLessThanOrEqual(v36.harmfulWrites, v35.harmfulWrites, "harmful writes", file: file, line: line)
        XCTAssertLessThanOrEqual(v36.wrongCommits, v35.wrongCommits, "wrong commits", file: file, line: line)
    }

    func testDevelopmentSplits() throws {
        for split in ["dev", "dev2"] {
            let fixture = try XCTUnwrap(GeneralizationEvaluation.fixture(split), split)
            let v35 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v35)
            let v36 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v36)
            print("GENERALIZATION|\(split)|v35|\(v35)")
            print("GENERALIZATION|\(split)|v36|\(v36)")
            print("GENERALIZATION|\(split)|v36|\(v36.breakdown)")
            XCTAssertEqual(v36.unavailable, 0)
            assertV36IsNoLessSafe(v36, than: v35)
            XCTAssertGreaterThanOrEqual(v36.coarseRight, v35.coarseRight, "\(split): reading meaning costs no accuracy")
            XCTAssertGreaterThanOrEqual(v36.weakReasoningDetected, v35.weakReasoningDetected)
            XCTAssertLessThan(v36.probes, v36.cases, "\(split): it still commits")
        }
    }

    /// Never prints a case. Aggregates are printed only when LEU_SEALED_REPORT=1.
    func testSealed36IsEvaluableAndReportsAggregatesOnlyOnRequest() throws {
        let fixture = try XCTUnwrap(GeneralizationEvaluation.fixture("sealed36"), "V36 sealed generalization fixture")
        let v35 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v35)
        let v36 = GeneralizationEvaluation.evaluate(fixture, GeneralizationEvaluation.v36)
        XCTAssertEqual(v36.unavailable, 0, "every sealed case has a comparable target")
        XCTAssertGreaterThanOrEqual(v36.cases, 150)
        assertV36IsNoLessSafe(v36, than: v35)
        guard ProcessInfo.processInfo.environment["LEU_SEALED_REPORT"] == "1" else { return }
        print("GENERALIZATION|sealed36|v35|\(v35)")
        print("GENERALIZATION|sealed36|v36|\(v36)")
        print("GENERALIZATION|sealed36|v35|\(v35.breakdown)")
        print("GENERALIZATION|sealed36|v36|\(v36.breakdown)")
        for author in ["s6f", "s6g", "s6h", "s6i"] {
            let part = GeneralizationEvaluation.Fixture(split: "sealed36-" + author, cases: fixture.cases.filter { $0.id.hasPrefix(author) })
            print("GENERALIZATION|sealed36-\(author)|v35|\(GeneralizationEvaluation.evaluate(part, GeneralizationEvaluation.v35, metamorphic: false))")
            print("GENERALIZATION|sealed36-\(author)|v36|\(GeneralizationEvaluation.evaluate(part, GeneralizationEvaluation.v36, metamorphic: false))")
        }
        print("TRAJECTORY|sealed36|v35|\(LearnerTrajectoryEvaluation.evaluate(fixture, GeneralizationEvaluation.v35))")
        print("TRAJECTORY|sealed36|v36|\(LearnerTrajectoryEvaluation.evaluate(fixture, GeneralizationEvaluation.v36))")
    }
}
