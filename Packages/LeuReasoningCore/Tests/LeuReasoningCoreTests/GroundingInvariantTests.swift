import XCTest
@testable import LeuReasoningCore

/// The invariants that make this engine safe to put in front of a learner.
/// If any of these fail, nothing downstream can be trusted.
final class GroundingInvariantTests: XCTestCase {

    func testZeroUnsupportedStatementsAcrossTheCorpus() async throws {
        let corpus = try CorpusFixture.load()
        let report = await EvaluationHarness(corpus: corpus).run()
        XCTAssertEqual(report.unsupportedStatements, 0)
        XCTAssertEqual(report.chains.unsupportedBridges, 0)
        XCTAssertEqual(report.counterfactuals.inventedConsequences, 0)
        XCTAssertEqual(report.relationships.falsePositives, 0)
        XCTAssertEqual(report.synthesis.manufacturedContrasts, 0)
    }

    func testSourceSupportedAndInferredAreNeverFlattened() throws {
        let graph = try CorpusFixture.graph()
        for relation in graph.relations {
            switch relation.provenance.admissibility {
            case .sourceSupported:
                XCTAssertFalse(relation.supportingAtoms.isEmpty)
            case .inferredValidated:
                XCTAssertFalse(relation.provenance.derivedFrom.isEmpty)
                XCTAssertNotEqual(relation.provenance.rule, .none)
            }
        }
    }

    func testAttributionTextDistinguishesQuotingFromConnecting() throws {
        let graph = try CorpusFixture.graph()
        let atom = try XCTUnwrap(graph.atoms.first)
        XCTAssertTrue(atom.provenance.attribution.hasPrefix("From "))
        let answer = MechanismEngine().answer(.why("a stable key"), in: graph)
        if let inferred = answer.paths.first(where: { $0.admissibility == .inferredValidated }) {
            XCTAssertTrue(inferred.provenance.attribution.hasPrefix("Leu connected "))
        }
    }

    func testValidatorRejectsUngroundedArtifacts() {
        let orphan = KnowledgeAtom(claimType: .mechanism,
                                   subject: "x", relation: RelationKind.enables.rawValue, object: "y",
                                   provenance: Provenance(admissibility: .sourceSupported, spans: []))
        let report = GraphValidator().validate(atoms: [orphan], relations: [])
        XCTAssertTrue(report.admittedAtoms.isEmpty)
        XCTAssertEqual(report.rejections.first?.reason, .missingProvenance)
    }

    func testProposalGateRejectsAClaimThatIsNotInTheSource() {
        let block = SourceBlock(documentID: "d", page: 1, indexOnPage: 0,
                                text: "An index enables row lookup without a full scan.")
        let assignment = SourceRoleAssignment(block: block, role: .explanation, confidence: 1, evidence: [])
        let hallucinated = AtomProposal(claimType: .mechanism,
                                        subject: "an index",
                                        relation: RelationKind.causes.rawValue,
                                        object: "automatic query rewriting",
                                        claimedSpan: "An index rewrites your queries automatically.")
        let result = ProposalAdmissionGate().admit([hallucinated], from: assignment)
        XCTAssertTrue(result.atoms.isEmpty)
        XCTAssertEqual(result.rejections.first?.reason, .spanNotFoundInSource)
    }

    func testProposalGateRejectsAnObjectThatIsNotInTheSpan() {
        let text = "An index enables row lookup without a full scan."
        let block = SourceBlock(documentID: "d", page: 1, indexOnPage: 0, text: text)
        let assignment = SourceRoleAssignment(block: block, role: .explanation, confidence: 1, evidence: [])
        let proposal = AtomProposal(claimType: .mechanism,
                                    subject: "an index",
                                    relation: RelationKind.enables.rawValue,
                                    object: "constant time writes",
                                    claimedSpan: text)
        let result = ProposalAdmissionGate().admit([proposal], from: assignment)
        XCTAssertTrue(result.atoms.isEmpty)
        XCTAssertEqual(result.rejections.first?.reason, .objectNotInSpan)
    }

    func testIdsAreStableAcrossProcessRuns() {
        let first = StableID(namespace: "atom", components: ["a", "b"])
        let second = StableID(namespace: "atom", components: ["a", "b"])
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.rawValue, "atom.\(StableID.digest("a\u{1F}b"))")
    }

    func testPersistedStructuresAreVersionedAndBoundToExtraction() throws {
        let corpus = try CorpusFixture.load()
        let state = UnderstandingState()
        XCTAssertEqual(state.extractionVersion, corpus.extractionVersion)
        let graph = corpus.buildGraph()
        for atom in graph.atoms {
            XCTAssertEqual(atom.provenance.spans.first?.extractionVersion, corpus.extractionVersion)
        }
    }
}
