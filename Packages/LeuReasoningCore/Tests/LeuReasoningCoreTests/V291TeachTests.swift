import XCTest
@testable import LeuReasoningCore

final class V291TeachTests: XCTestCase {
    func atoms(_ text: String) -> [KnowledgeAtom] {
        PacketAtomExtractor().extractProse(.init(documentID: "test", page: 1, canonicalSpan: text, characterOffset: 12, sourceRole: .explanation)).atoms
    }
    func testNounVerbAmbiguityWithAuxiliaryAndFinitePredicate() {
        let source = "Concurrent requests can both make decisions from stale state."
        let atom = atoms(source).first!
        XCTAssertEqual(atom.subject, "Concurrent requests")
        XCTAssertEqual(atom.relation, "makes")
        XCTAssertEqual(atom.object, "decisions from stale state")
        XCTAssertTrue(atom.qualifiers.contains(.init(kind: .modality, text: "can")))
        XCTAssertTrue(atom.qualifiers.contains(.init(kind: .scope, text: "both")))
        XCTAssertEqual(atom.canonicalSpan, source)
        XCTAssertEqual(atom.provenance.spans.first?.characterOffset, 12)
        XCTAssertEqual(atoms("Setting state requests another render.").first?.relation, "requests")
        XCTAssertEqual(atoms("Concurrent requests require coordination.").first?.subject, "Concurrent requests")
        XCTAssertEqual(atoms("Pending updates can create conflicts.").first?.subject, "Pending updates")
        XCTAssertTrue(atoms("Concurrent requests can frobnicate state.").isEmpty)
        XCTAssertTrue(atoms("Concurrent requests can frobnicate updates to state.").isEmpty)
        XCTAssertTrue(atoms("Concurrent requests from clients.").isEmpty)
    }
    func testFrozenChallengeSupportAndCoverageIndependently() throws {
        struct Case: Decodable { let id, source, learner: String; let support: [String]; let coverage: String }
        let url = Bundle.module.url(forResource: "v291-challenge", withExtension: "json", subdirectory: "Fixtures")!
        let cases = try JSONDecoder().decode([Case].self, from: Data(contentsOf: url))
        for item in cases {
            let report = SourceBoundExplanationAligner().align(explanation: item.learner, concept: nil, in: KnowledgeGraphBuilder().build(atoms: atoms(item.source)))
            XCTAssertEqual(report.alignments.map { $0.verdict.rawValue }, item.support, item.id + " support")
            XCTAssertEqual(report.unaddressedAtomIDs.isEmpty ? "complete" : "incomplete", item.coverage, item.id + " coverage")
        }
    }
    func testNegatedListsAndUnsupportedModifiersAreNotSubsets() {
        for (source, learner) in [
            ("Cleanup does not prevent leaks and outages.", "Cleanup prevents leaks."),
            ("Cleanup prevents leaks or outages.", "Cleanup prevents leaks."),
            ("Cleanup prevents leaks.", "Cleanup prevents server outages."),
            ("Stone is a fake diamond.", "Stone is a diamond.")
        ] {
            let report = SourceBoundExplanationAligner().align(explanation: learner, concept: nil, in: KnowledgeGraphBuilder().build(atoms: atoms(source)))
            XCTAssertEqual(report.supportedShare, 0, learner)
        }
    }
}
