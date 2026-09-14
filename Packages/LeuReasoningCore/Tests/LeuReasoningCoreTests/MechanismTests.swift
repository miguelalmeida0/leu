import XCTest
@testable import LeuReasoningCore

final class MechanismTests: XCTestCase {

    func testWhyProducesTheStatedEnablementChain() throws {
        let graph = try CorpusFixture.graph()
        let answer = MechanismEngine().answer(.why("a stable key"), in: graph)
        XCTAssertTrue(answer.isAnswered)
        let labels = try XCTUnwrap(answer.paths.first).steps.map(\.toLabel)
        XCTAssertTrue(labels.contains { KnowledgeNode.key(for: $0) == KnowledgeNode.key(for: "identity matching across renders") })
        XCTAssertTrue(labels.contains { KnowledgeNode.key(for: $0) == KnowledgeNode.key(for: "state preservation during reorder") })
    }

    func testMultiStepPathsAreMarkedInferredNotSourceStated() throws {
        let graph = try CorpusFixture.graph()
        let answer = MechanismEngine().answer(.why("a stable key"), in: graph)
        for path in answer.paths where path.steps.count > 1 {
            XCTAssertEqual(path.admissibility, .inferredValidated)
            XCTAssertFalse(path.provenance.derivedFrom.isEmpty)
        }
        for path in answer.paths where path.steps.count == 1 {
            XCTAssertEqual(path.admissibility, .sourceSupported)
        }
    }

    func testWhatDependsOnThisUsesStatedRequirements() throws {
        let graph = try CorpusFixture.graph()
        let answer = MechanismEngine().answer(.whatDependsOnThis("an idempotent operation"), in: graph)
        XCTAssertTrue(answer.isAnswered)
        let labels = answer.paths.flatMap { $0.steps.map(\.fromLabel) + $0.steps.map(\.toLabel) }
        XCTAssertTrue(labels.contains { $0.contains("retrying") || $0.contains("delivery") })
    }

    func testUnknownSubjectIsAnsweredHonestly() throws {
        let graph = try CorpusFixture.graph()
        let answer = MechanismEngine().answer(.why("quantum entanglement"), in: graph)
        XCTAssertFalse(answer.isAnswered)
        XCTAssertNotNil(answer.unansweredReason)
    }

    func testNegatedClaimsNeverBecomeTraversableEdges() throws {
        let corpus = try CorpusFixture.load()
        let graph = corpus.buildGraph()
        let negated = corpus.atoms.filter(\.isNegated)
        XCTAssertFalse(negated.isEmpty)
        for spec in negated {
            let subject = KnowledgeNode.key(for: spec.subject)
            let object = KnowledgeNode.key(for: spec.object)
            let hasEdge = graph.relations.contains { relation in
                graph.node(relation.subject.id)?.key == subject && graph.node(relation.object.id)?.key == object
            }
            XCTAssertFalse(hasEdge, "negated claim \(spec.key) leaked into the graph as an edge")
        }
    }

    func testEveryGoldenChainIsReproducedWithoutUnsupportedBridges() throws {
        let corpus = try CorpusFixture.load()
        let graph = corpus.buildGraph()
        let engine = CausalChainEngine()
        var missing: [String] = []
        var bridges: [String] = []
        for spec in corpus.chains {
            let chains = engine.chains(from: spec.start, in: graph)
            let expected = spec.labels.map { KnowledgeNode.key(for: $0) }
            let reproduced = chains.contains { chain in
                let labels = chain.links.map { KnowledgeNode.key(for: $0.label) }
                return labels.count >= expected.count && Array(labels.prefix(expected.count)) == expected
            }
            if !reproduced { missing.append(spec.key) }
            for chain in chains {
                let problems = engine.problems(in: chain, graph: graph).filter { $0.kind == .unsupportedBridge }
                if !problems.isEmpty { bridges.append("\(spec.key): \(problems.map(\.detail).joined(separator: "; "))") }
            }
        }
        XCTAssertTrue(bridges.isEmpty, "unsupported bridges: \(bridges.joined(separator: " | "))")
        XCTAssertTrue(missing.isEmpty, "chains not reproduced: \(missing.joined(separator: ", "))")
    }

    func testChainProvenanceIsAlwaysComplete() throws {
        let graph = try CorpusFixture.graph()
        let engine = CausalChainEngine()
        for chain in engine.chains(from: "an index key", in: graph) {
            XCTAssertTrue(chain.provenance.isComplete)
            for link in chain.links.dropFirst() {
                XCTAssertTrue(link.provenance.isComplete)
            }
        }
    }
}
