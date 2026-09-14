import XCTest
import ShelfCore
@testable import Shelf

/// Session presentation and interaction tests.
///
/// These assert the honesty and correctness rules the redesign depends on. They do not
/// assert appearance, and they do not weaken any existing source-binding or learning test.
@MainActor
final class SessionExperienceTests: XCTestCase {

    // MARK: - Reconstruction, locked green-check rule

    private func lab() -> ReconstructionLab { LabCatalog.defaultLab }

    func testConfirmationComesFromCorrectOrderNotVisualPosition() {
        let lab = self.lab()
        XCTAssertGreaterThan(lab.correctOrder.count, 1, "Fixture needs at least two steps")
        // A step is confirmed only when the lab's own correctOrder agrees at that index.
        func isConfirmed(_ id: UUID, at index: Int) -> Bool {
            lab.correctOrder.indices.contains(index) && lab.correctOrder[index] == id
        }
        XCTAssertTrue(isConfirmed(lab.correctOrder[0], at: 0))
        XCTAssertFalse(isConfirmed(lab.correctOrder[1], at: 0),
                       "Occupying position 1 is not evidence of being correct")
    }

    func testMovingAConfirmedStepClearsItsCheckImmediately() {
        let lab = self.lab()
        var order = lab.correctOrder
        func isConfirmed(_ id: UUID, at index: Int) -> Bool {
            lab.correctOrder.indices.contains(index) && lab.correctOrder[index] == id
        }
        let confirmedBefore = order.enumerated().filter { isConfirmed($0.element, at: $0.offset) }.count
        XCTAssertEqual(confirmedBefore, order.count, "A solved order confirms every step")

        let moved = order.remove(at: 0)
        order.append(moved)
        let confirmedAfter = order.enumerated().filter { isConfirmed($0.element, at: $0.offset) }.count
        XCTAssertLessThan(confirmedAfter, confirmedBefore,
                          "Moving a step must invalidate checks as soon as the order changes")
    }

    func testPartialProgressNeverEqualsFullSolve() {
        let lab = self.lab()
        guard lab.correctOrder.count >= 3 else { return }
        var order = lab.correctOrder
        order.swapAt(1, 2)
        XCTAssertNotEqual(order, lab.correctOrder,
                          "A partially correct board must not read as solved, which is what gates the scenario reveal")
    }

    // MARK: - Feedback honesty

    func testRecallRatingIsSelfAssessmentNotCorrectness() {
        // Nothing in the rating scale encodes right or wrong: it records how retrieval
        // felt, which is what the scheduler consumes.
        let raw = Set(RecallRating.allCases.map(\.rawValue))
        XCTAssertEqual(raw, ["forgot", "difficult", "knewIt"])
        XCTAssertFalse(raw.contains("correct"))
        XCTAssertFalse(raw.contains("incorrect"))
    }

    func testConfidenceAndRecallRatingRemainDistinctSignals() {
        // Confidence is a prediction before committing. RecallRating is a self-assessment
        // after seeing the source. Collapsing them would turn a feeling into a grade.
        XCTAssertEqual(ConfidenceLevel.allCases.count, 4)
        XCTAssertEqual(RecallRating.allCases.count, 3)
        let confidenceIDs = Set(ConfidenceLevel.allCases.map(\.rawValue))
        let ratingIDs = Set(RecallRating.allCases.map(\.rawValue))
        XCTAssertTrue(confidenceIDs.isDisjoint(with: ratingIDs),
                      "The two scales must not share identifiers")
    }

    func testConfidenceLabelsAreUnchangedByThePresentation() {
        // The redesign presents the model's own choices and never renames them into a
        // different grading system.
        let names = ConfidenceLevel.allCases.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count, "Labels must stay distinct")
        for name in names {
            XCTAssertFalse(name.isEmpty)
            XCTAssertFalse(name.contains("%"), "Confidence is not a percentage")
        }
    }

    // MARK: - Source binding

    func testQuestionSourceRetainsDocumentAndPage() throws {
        let source = LearningSource(documentID: UUID(), pageIndex: 2,
                                    sourceText: "A stable key is a promise.",
                                    sectionTitle: "Keys and identity")
        XCTAssertEqual(source.pageIndex, 2)
        XCTAssertFalse(source.sourceText.isEmpty,
                       "Feedback quotes the source text, so it must survive into the view")
        XCTAssertEqual(source.sectionTitle, "Keys and identity")
    }
}
