import XCTest
@testable import LeuReasoningCore

final class PlanningAndStateTests: XCTestCase {

    func testPlannerTargetsTheConditionTheLearnerDropped() throws {
        let graph = try CorpusFixture.graph()
        let alignment = ExplanationAligner().align(explanation: "Retries fix failed requests.",
                                                   concept: "retrying",
                                                   in: graph)
        let plans = QuestionPlanner().plan(concept: "retrying", in: graph, alignment: alignment)
        let top = try XCTUnwrap(plans.first)
        XCTAssertEqual(top.operation, .identifyMissingCondition)
        XCTAssertEqual(top.reason.cause, .yourExplanation)
        XCTAssertTrue(top.target.contains("transient"))
    }

    func testPlansCarryAGroundedAnswerRequirement() throws {
        let graph = try CorpusFixture.graph()
        for plan in QuestionPlanner().plan(concept: "an index", in: graph) {
            XCTAssertFalse(plan.reason.text.isEmpty)
            for line in plan.answerMustInclude {
                XCTAssertTrue(line.provenance.isComplete)
            }
        }
    }

    func testPlannerNeverWritesQuestionText() throws {
        let graph = try CorpusFixture.graph()
        let plans = QuestionPlanner().plan(concept: "caching", in: graph)
        XCTAssertFalse(plans.isEmpty)
        for plan in plans {
            XCTAssertFalse(plan.target.hasSuffix("?"), "a plan must not contain realised question text")
        }
    }

    func testStrategySelectorPrefersMechanismAfterAReversal() throws {
        let graph = try CorpusFixture.graph()
        let alignment = ExplanationAligner().align(explanation: "A cascading failure causes thread pool exhaustion.",
                                                   concept: "thread pool exhaustion",
                                                   in: graph)
        let moves = ExplanationStrategySelector().select(concept: "thread pool exhaustion",
                                                         in: graph,
                                                         alignment: alignment)
        XCTAssertTrue(moves.contains { $0.strategy == .causalChain || $0.strategy == .mechanismFirst })
        for move in moves {
            XCTAssertFalse(move.material.isEmpty, "a strategy was selected with no source material")
        }
    }

    func testAnalogyIsOnlyOfferedWhenASourceDrawsIt() throws {
        let graph = try CorpusFixture.graph()
        let moves = ExplanationStrategySelector().select(concept: "hoisting", in: graph, limit: 10)
        XCTAssertFalse(moves.contains { $0.strategy == .analogyFromSource })
    }

    func testStrategiesAreNotRepeated() throws {
        let graph = try CorpusFixture.graph()
        let first = ExplanationStrategySelector().select(concept: "caching", in: graph)
        let used = first.map(\.strategy)
        let second = ExplanationStrategySelector().select(concept: "caching", in: graph, alreadyUsed: used)
        XCTAssertTrue(Set(second.map(\.strategy)).isDisjoint(with: Set(used)) || second.isEmpty)
    }

    func testUnderstandingStateIsBuiltFromExplicitEventsOnly() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let events: [LearningEvent] = [
            .requestedExplanation(concept: "caching", at: now),
            .askedQuestion(text: "why do index keys break state?", concept: "a stable key", at: now.addingTimeInterval(60)),
            .openedPrerequisite(concept: "identity matching across renders", at: now.addingTimeInterval(120)),
            .attemptedExplanation(concept: "retrying", text: "Retries fix failed requests.", verdict: .partiallySupported, at: now.addingTimeInterval(180)),
            .openedRelatedSource(documentID: "react-notes", concept: "a stable key", at: now.addingTimeInterval(240)),
            .markedResolved(concept: "caching", at: now.addingTimeInterval(300))
        ]
        let state = UnderstandingStateProjector().project(events: events)
        XCTAssertEqual(state.focusConcept, "caching")
        XCTAssertTrue(state.isResolved("caching"))
        XCTAssertEqual(state.unresolvedQuestions.count, 1)
        XCTAssertEqual(state.visitedDependencies, ["identity matching across renders"])
        XCTAssertEqual(state.relatedSourcesSeen, ["react-notes"])
        XCTAssertEqual(state.attemptedExplanations.count, 1)
        XCTAssertEqual(state.version, UnderstandingState.schemaVersion)
    }

    func testProjectionIsDeterministicRegardlessOfEventOrder() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let events: [LearningEvent] = [
            .requestedExplanation(concept: "caching", at: now),
            .openedPrerequisite(concept: "a cache lookup before the request", at: now.addingTimeInterval(30)),
            .markedResolved(concept: "caching", at: now.addingTimeInterval(90))
        ]
        let forward = UnderstandingStateProjector().project(events: events)
        let backward = UnderstandingStateProjector().project(events: events.reversed())
        XCTAssertEqual(forward, backward)
    }

    func testEverySuggestionCarriesAReason() throws {
        let graph = try CorpusFixture.graph()
        for plan in QuestionPlanner().plan(concept: "retrying", in: graph) {
            XCTAssertFalse(plan.reason.text.isEmpty)
            XCTAssertFalse(plan.reason.evidence.isEmpty)
        }
        for move in ExplanationStrategySelector().select(concept: "retrying", in: graph) {
            XCTAssertFalse(move.reason.text.isEmpty)
            XCTAssertFalse(move.reason.evidence.isEmpty)
        }
    }
}
