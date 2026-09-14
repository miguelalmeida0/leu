import XCTest
@testable import LeuReasoningCore

final class CounterfactualTests: XCTestCase {

    func testLosingKeyStabilityPropagatesOnlyStatedConsequences() throws {
        let graph = try CorpusFixture.graph()
        let result = CounterfactualEngine().evaluate(.propertyLost(subject: "a stable key", property: "stable"), in: graph)
        XCTAssertFalse(result.consequences.isEmpty)
        let labels = result.consequences.map { KnowledgeNode.key(for: $0.label) }
        XCTAssertTrue(labels.contains(KnowledgeNode.key(for: "identity matching across renders")))
        for consequence in result.consequences {
            XCTAssertEqual(consequence.admissibility, .inferredValidated)
            XCTAssertTrue(consequence.provenance.isComplete)
            XCTAssertFalse(consequence.justification.isEmpty)
        }
    }

    func testEveryConsequenceIsBackedByAnExistingEdge() throws {
        let graph = try CorpusFixture.graph()
        let engine = CounterfactualEngine()
        for change in [KnowledgeChange.removed("an index"),
                       .removed("a timeout"),
                       .removed("caching"),
                       .removed("a circuit breaker")] {
            let result = engine.evaluate(change, in: graph)
            for consequence in result.consequences {
                for link in consequence.viaChain.links.dropFirst() {
                    let id = try XCTUnwrap(link.viaRelation)
                    XCTAssertTrue(graph.relation(id) != nil || graph.atom(id) != nil,
                                  "consequence used a relation that is not in the graph")
                }
            }
        }
    }

    func testFalsifyingAConditionOnlyRetractsConditionedClaims() throws {
        let graph = try CorpusFixture.graph()
        let result = CounterfactualEngine().evaluate(.conditionFalse("the failure is transient"), in: graph)
        XCTAssertFalse(result.consequences.isEmpty)
        for consequence in result.consequences {
            XCTAssertEqual(consequence.polarity, .ruleNoLongerApplies)
        }
        // The engine must not claim to know what happens instead.
        XCTAssertTrue(result.openQuestions.contains { $0.contains("what happens instead") })
    }

    func testUnknownSubjectProducesNoSpeculation() throws {
        let graph = try CorpusFixture.graph()
        let result = CounterfactualEngine().evaluate(.removed("blockchain consensus"), in: graph)
        XCTAssertTrue(result.consequences.isEmpty)
        XCTAssertNotNil(result.unansweredReason)
    }

    func testDepthIsBoundedAndDeclared() throws {
        let graph = try CorpusFixture.graph()
        let engine = CounterfactualEngine(maxDepth: 2)
        let result = engine.evaluate(.removed("an unbounded wait"), in: graph)
        for consequence in result.consequences {
            XCTAssertLessThanOrEqual(consequence.viaChain.length, 3)
        }
    }
}
