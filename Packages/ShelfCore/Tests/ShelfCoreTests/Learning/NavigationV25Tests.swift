import XCTest
@testable import ShelfCore

final class NavigationV25Tests: XCTestCase {
    func testContentsRestorationFollowsNaturalProgress() {
        let entries = (1...30).map { (id: "section-\($0)", page: ($0 - 1) * 3) }
        XCTAssertEqual(ContentsLocation.activeEntryID(entries: entries, pageIndex: 51), "section-18")
        XCTAssertEqual(ContentsLocation.activeEntryID(entries: entries, pageIndex: 53), "section-18")
        XCTAssertEqual(ContentsLocation.activeEntryID(entries: entries, pageIndex: 69), "section-24")
        XCTAssertNil(ContentsLocation.activeEntryID(entries: [], pageIndex: 0))
        XCTAssertEqual(ContentsLocation.activeEntryID(entries: [("a", 0), ("b", 0)], pageIndex: 0), "b")
    }

    func testSourceMatcherRestoresCompletePassageAcrossPDFRunBoundaries() throws {
        let raw = "Other text. A microtask\nruns after the current script completes. More text."
        let range = try XCTUnwrap(SourcePassageMatcher.range(of: "A microtask runs after the current script completes.", in: raw))
        XCTAssertEqual((raw as NSString).substring(with: range), "A microtask\nruns after the current script completes.")
        XCTAssertNil(SourcePassageMatcher.range(of: "A microtask runs before the current script completes.", in: raw))
    }

    func testSourceMatcherNeverChoosesAnAmbiguousPassageOrTruncatesToAPrefix() {
        XCTAssertNil(SourcePassageMatcher.range(of: "A repeated sentence.", in: "A repeated sentence. A repeated sentence."))
        XCTAssertNil(SourcePassageMatcher.range(of: "The complete passage has an unavailable ending.", in: "The complete passage has another ending."))
    }

    func testTrailContinueKeepsCurrentStopAndSkipsDeletedSources() throws {
        let first = TrailNode(kind: .document, documentID: UUID(), title: "First")
        let second = TrailNode(kind: .pageRange, documentID: UUID(), pageRange: 18...24, title: "Second")
        let third = TrailNode(kind: .document, documentID: UUID(), title: "Third")
        let trail = LearningTrail(title: "Route", nodes: [first, second, third], currentNodeID: second.id)
        let restored = try JSONDecoder().decode(LearningTrail.self, from: JSONEncoder().encode(trail))
        XCTAssertEqual(TrailNavigation.resumeNode(in: restored, availableIDs: [first.id, second.id, third.id])?.id, second.id)
        XCTAssertEqual(TrailNavigation.resumeNode(in: restored, availableIDs: [first.id, third.id])?.id, third.id)
        XCTAssertEqual(TrailNavigation.source(for: second, snapshot: LearningSnapshot())?.pageIndex, 18)
    }

    func testTrailQuestionResolvesItsExactSource() {
        let source = LearningSource(documentID: UUID(), pageIndex: 24, sourceText: "A source passage.")
        let option = QuestionOption(text: "Answer")
        let question = LearningQuestion(stableKey: "trail", kind: .definition, prompt: "What is the answer?", options: [option], correctOptionID: option.id, source: source, qualityScore: 0.8)
        let node = TrailNode(kind: .question, referenceID: question.id, title: "Question")
        XCTAssertEqual(TrailNavigation.source(for: node, snapshot: LearningSnapshot(questions: [question])), source)
        XCTAssertNil(TrailNavigation.source(for: node, snapshot: LearningSnapshot()))
    }

    func testOriginalPagingPolicyMatrix() {
        for sign in [-1.0, 1.0] {
            var policy = PageTurnPolicy()
            XCTAssertEqual(policy.lock(dx: sign * 80, dy: 65), .horizontal)
            XCTAssertEqual(policy.targetDelta(dx: sign * 60, velocityX: sign * 500, width: 390, page: 2, count: 5), sign < 0 ? 1 : -1)
            XCTAssertNil(policy.targetDelta(dx: sign * 60, velocityX: sign * 100, width: 390, page: 2, count: 5))
            XCTAssertEqual(policy.targetDelta(dx: sign * 180, velocityX: sign * 80, width: 390, page: 2, count: 5), sign < 0 ? 1 : -1)
            XCTAssertNil(policy.targetDelta(dx: sign * 10, velocityX: sign * 900, width: 390, page: 2, count: 5))
            XCTAssertNil(policy.targetDelta(dx: sign * 80, velocityX: -sign * 500, width: 390, page: 2, count: 5))
            XCTAssertNil(policy.targetDelta(dx: sign * 180, velocityX: sign * 500, width: 390, page: sign > 0 ? 0 : 4, count: 5))
        }
    }

    func testLegacyTrailAndSnapshotDecodeWithoutProgressOrLensFields() throws {
        let trail = LearningTrail(title: "Old")
        var raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(trail)) as! [String: Any]
        raw.removeValue(forKey: "currentNodeID")
        XCTAssertNil(try JSONDecoder().decode(LearningTrail.self, from: JSONSerialization.data(withJSONObject: raw)).currentNodeID)
        let snapshot = try JSONDecoder().decode(LearningSnapshot.self, from: Data("{}".utf8))
        XCTAssertTrue(snapshot.lensUsage.isEmpty)
    }
}
