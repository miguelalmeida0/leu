import XCTest
@testable import ShelfCore

final class StudyPlannerTests: XCTestCase {
    private let planner = ShelfStudySessionPlanner()
    private let topic = LearningTopic(name: "React")
    private let documentID = UUID()

    func testPlannerRespectsTopicAndIncludesVariety() {
        let snapshot = makeSnapshot(count: 6)
        let session = planner.plan(snapshot: snapshot, topicID: topic.id, minutes: 10, mode: .learn,
                                   now: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertFalse(session.activities.isEmpty)
        XCTAssertGreaterThan(Set(session.activities.map(\.kind)).count, 1)
        for activity in session.activities {
            if let id = activity.learningObjectID,
               let object = snapshot.learningObjects.first(where: { $0.id == id }) {
                XCTAssertTrue(object.topicIDs.contains(topic.id))
            }
        }
    }

    func testInterviewModeDoesNotRevealNonQuestionActivityTypes() {
        let session = planner.plan(snapshot: makeSnapshot(count: 6), topicID: topic.id, minutes: 10,
                                   mode: .interview, now: Date())
        XCTAssertTrue(session.activities.allSatisfy { $0.kind == .question })
    }

    func testRequestedDurationIsBounded() {
        let session = planner.plan(snapshot: makeSnapshot(count: 10), topicID: topic.id, minutes: 10, mode: .learn, now: Date())
        let seconds = session.activities.reduce(0) { $0 + $1.estimatedSeconds }
        XCTAssertGreaterThan(seconds, 180)
        XCTAssertLessThanOrEqual(seconds, 690)
    }


    func testOverdueWeakItemIsPrioritizedAheadOfFreshItem() {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let overdueSource = LearningSource(documentID: documentID, pageIndex: 0, sourceText: "React key preserves identity.")
        let freshSource = LearningSource(documentID: documentID, pageIndex: 1, sourceText: "React prop carries input.")
        let overdue = LearningObject(type: .recall, source: overdueSource, topicIDs: [topic.id], title: "Keys", importance: 0.9)
        let fresh = LearningObject(type: .recall, source: freshSource, topicIDs: [topic.id], title: "Props", importance: 0.5)
        var snapshot = LearningSnapshot(topics: [topic], learningObjects: [overdue, fresh])
        snapshot.reviewStates[overdue.id] = ReviewState(learningObjectID: overdue.id, nextReviewAt: now.addingTimeInterval(-86_400 * 7), reviewCount: 3, difficulty: 0.9, stability: 1)
        snapshot.reviewStates[fresh.id] = ReviewState(learningObjectID: fresh.id, reviewCount: 0, difficulty: 0.2, stability: 1)

        let session = planner.plan(snapshot: snapshot, topicID: topic.id, minutes: 5, mode: .learn, now: now)
        XCTAssertEqual(session.activities.first?.learningObjectID, overdue.id)
    }

    private func makeSnapshot(count: Int) -> LearningSnapshot {
        var snapshot = LearningSnapshot(topics: [topic])
        for index in 0..<count {
            let source = LearningSource(documentID: documentID, pageIndex: index,
                                        sourceText: "React concept \(index) is a stable source definition.")
            let object = LearningObject(type: .definition, source: source, topicIDs: [topic.id],
                                        title: "React concept \(index)", importance: 0.7)
            snapshot.learningObjects.append(object)
            snapshot.reviewStates[object.id] = ReviewState(learningObjectID: object.id,
                nextReviewAt: Date(timeIntervalSince1970: 1_700_000_000), reviewCount: 1,
                difficulty: Double(index % 3) / 3, stability: 2)
            let a = QuestionOption(text: "Stable source definition")
            let b = QuestionOption(text: "Another source term")
            let c = QuestionOption(text: "Third source term")
            snapshot.questions.append(LearningQuestion(stableKey: "q\(index)", kind: .definition,
                prompt: "What is concept \(index)?", options: [a,b,c], correctOptionID: a.id,
                source: source, topicIDs: [topic.id], qualityScore: 0.8))
        }
        return snapshot
    }
}
