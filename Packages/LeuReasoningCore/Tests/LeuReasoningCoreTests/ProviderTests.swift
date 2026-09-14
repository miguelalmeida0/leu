import XCTest
@testable import LeuReasoningCore

final class ProviderTests: XCTestCase {

    func testEngineRunsEndToEndWithNoModelAtAll() async {
        let blocks = [
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 0, text: "IN ONE BREATH",
                        fontSize: 16, isBold: true, isAllCaps: true),
            SourceBlock(documentID: "mobile-mastery", page: 12, indexOnPage: 1,
                        text: "A stable key enables identity matching across renders. Identity matching across renders enables state preservation during reorder.",
                        fontSize: 11)
        ]
        let core = ReasoningCore(provider: DeterministicReasoningProposalProvider())
        let result = await core.build(from: blocks)
        XCTAssertEqual(result.providerIdentifier, "deterministic")
        XCTAssertFalse(result.graph.atoms.isEmpty)
        let answer = core.why("a stable key", in: result.graph)
        XCTAssertTrue(answer.isAnswered)
        XCTAssertTrue(result.admission.isClean)
    }

    func testAppleProviderCompilesAndDegradesToDeterministic() async {
        let provider = AppleFoundationReasoningProposalProvider()
        let block = SourceBlock(documentID: "d", page: 1, indexOnPage: 0,
                                text: "An index enables row lookup without a full scan.")
        let assignment = SourceRoleAssignment(block: block, role: .explanation, confidence: 1, evidence: [])
        let proposals = await provider.proposeAtoms(for: assignment)
        // With or without Foundation Models, the deterministic proposal is present.
        XCTAssertTrue(proposals.contains { $0.relation == RelationKind.enables.rawValue })
    }

    func testBuildIsDeterministicAcrossRuns() async {
        let blocks = [
            SourceBlock(documentID: "d", page: 1, indexOnPage: 0,
                        text: "Caching enables lower latency on repeat requests. If the underlying data changes, caching causes stale data.",
                        fontSize: 11)
        ]
        let core = ReasoningCore()
        let first = await core.build(from: blocks)
        let second = await core.build(from: blocks)
        XCTAssertEqual(first.graph.atoms.map(\.id), second.graph.atoms.map(\.id))
        XCTAssertEqual(first.graph.relations.map(\.id), second.graph.relations.map(\.id))
    }

    func testCrossSourceProposalsAreOnlyMadeAcrossDocuments() async throws {
        let corpus = try CorpusFixture.load()
        let atoms = corpus.buildAtoms().atoms
        let proposals = await DeterministicReasoningProposalProvider().proposeRelations(among: atoms)
        XCTAssertFalse(proposals.isEmpty)
        let byID = Dictionary(atoms.map { ($0.id.rawValue, $0) }, uniquingKeysWith: { first, _ in first })
        for proposal in proposals {
            let documents = Set(proposal.supportingAtomIDs.compactMap { byID[$0.rawValue]?.sourceDocumentID })
            XCTAssertGreaterThan(documents.count, 1)
        }
    }
}
