import XCTest
@testable import ShelfCore

final class LearningRepositoryTests: XCTestCase {
    func testLearningStateSurvivesRepositoryReopen() async throws {
        let root = temporaryDirectory()
        let source = LearningSource(documentID: UUID(), pageIndex: 2, sourceText: "A closure is a function with lexical context.")
        let first = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        _ = try await first.open()
        let object = try await first.capture(type: .recall, source: source, title: "Closure")
        try await first.review(objectID: object.id, rating: .difficult, correct: true, confidence: .certain)
        let second = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let restored = try await second.open()
        XCTAssertEqual(restored.learningObjects.first?.id, object.id)
        XCTAssertEqual(restored.attempts.count, 1)
        XCTAssertEqual(restored.reviewStates[object.id]?.reviewCount, 1)
    }

    func testConnectionsMasksTrailsAndRecordingsPersist() async throws {
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: temporaryDirectory()))
        _ = try await repo.open()
        let doc = UUID()
        let first = try await repo.capture(type: .passage, source: LearningSource(documentID: doc, pageIndex: 0, sourceText: "One"), title: "One")
        let second = try await repo.capture(type: .passage, source: LearningSource(documentID: doc, pageIndex: 1, sourceText: "Two"), title: "Two")
        try await repo.connect(first.id, to: second.id, kind: .prerequisite)
        try await repo.saveMask(DiagramMask(learningObjectID: first.id, source: first.source,
                                            regions: [SourceBounds(x: 0.1, y: 0.2, width: 0.3, height: 0.2)]))
        _ = try await repo.saveTrail(LearningTrail(title: "Path", nodes: [TrailNode(kind: .learningObject, referenceID: first.id, title: "One")]))
        try await repo.saveRecording(ExplanationRecording(learningObjectID: first.id, filename: "one.m4a", duration: 3))
        let snapshot = try await repo.snapshot()
        XCTAssertEqual(snapshot.relationships.count, 1)
        XCTAssertEqual(snapshot.masks.count, 1)
        XCTAssertEqual(snapshot.trails.count, 1)
        XCTAssertEqual(snapshot.recordings.count, 1)
    }


    func testCustomRelationshipLabelPersistsAcrossReopen() async throws {
        let root = temporaryDirectory()
        let firstRepo = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        _ = try await firstRepo.open()
        let doc = UUID()
        let a = try await firstRepo.capture(type: .passage, source: LearningSource(documentID: doc, pageIndex: 0, sourceText: "Client cache"), title: "Client cache")
        let b = try await firstRepo.capture(type: .passage, source: LearningSource(documentID: doc, pageIndex: 1, sourceText: "Revalidation"), title: "Revalidation")
        try await firstRepo.connect(a.id, to: b.id, kind: .custom, customLabel: "invalidates when stale")

        let reopened = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let snapshot = try await reopened.open()
        XCTAssertEqual(snapshot.relationships.count, 1)
        XCTAssertEqual(snapshot.relationships[0].kind, .custom)
        XCTAssertEqual(snapshot.relationships[0].customLabel, "invalidates when stale")
    }

    func testManualClassificationOverridesDocumentLearningObjects() async throws {
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: temporaryDirectory()))
        let opened = try await repo.open()
        let automatic = try XCTUnwrap(opened.topics.first(where: { $0.name == "Frontend" }))
        let manual = try await repo.addTopic(name: "GraphQL")
        let document = UUID()
        let object = try await repo.capture(
            type: .passage,
            source: LearningSource(documentID: document, pageIndex: 0, sourceText: "GraphQL schemas describe typed API data."),
            title: "Schema",
            topicIDs: [automatic.id]
        )

        try await repo.setManualTopics(documentID: document, topicIDs: [manual.id])
        let snapshot = try await repo.snapshot()

        XCTAssertEqual(snapshot.manualDocumentTopics[document], [manual.id])
        XCTAssertEqual(snapshot.learningObjects.first(where: { $0.id == object.id })?.topicIDs, [manual.id])
    }

    func testManualClassificationSurvivesAnalysisRefreshAndReplacesAutomaticTopics() async throws {
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: temporaryDirectory()))
        let opened = try await repo.open()
        let automatic = try XCTUnwrap(opened.topics.first(where: { $0.name == "Frontend" }))
        let manual = try await repo.addTopic(name: "GraphQL")
        let document = UUID()
        try await repo.setManualTopics(documentID: document, topicIDs: [manual.id])

        let pages = [
            SourcePageInput(pageIndex: 0, text: "Closure is a function with lexical context. Render is the browser process that produces pixels. Layout is the process that calculates geometry."),
            SourcePageInput(pageIndex: 1, text: "Component is a reusable interface unit. Browser is software that retrieves and renders web resources. Event is a signal dispatched to listeners.")
        ]
        let analysis = DocumentAnalyzer().analyze(documentID: document, fingerprint: String(repeating: "a", count: 64), pages: pages)
        let questions = DeterministicQuestionEngine().generate(from: analysis, topicIDs: [automatic.id])
        try await repo.upsertAnalysis(analysis, topics: [TopicClassification(topic: automatic, score: 1)], questions: questions)

        let refreshed = try await repo.snapshot()
        XCTAssertFalse(refreshed.learningObjects.filter { $0.source.documentID == document }.isEmpty)
        XCTAssertTrue(refreshed.learningObjects.filter { $0.source.documentID == document }.allSatisfy { $0.topicIDs == [manual.id] })
        XCTAssertTrue(refreshed.questions.filter { $0.source.documentID == document }.allSatisfy { $0.topicIDs == [manual.id] })
    }

    private func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
