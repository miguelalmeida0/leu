import Foundation
import XCTest
@testable import ShelfCore

final class StudyCheckpointTests: XCTestCase {
    func testLegacyResumeDecodesWithoutDiscardingSession() throws {
        let id = UUID()
        let data = Data("{\"sessionID\":\"\(id.uuidString)\",\"activityIndex\":2,\"updatedAt\":0}".utf8)
        let context = try JSONDecoder().decode(ResumeStudyContext.self, from: data)
        XCTAssertEqual(context.sessionID, id); XCTAssertEqual(context.activityIndex, 2)
        XCTAssertNil(context.selectedAnswerID); XCTAssertNil(context.selectedConfidence)
        XCTAssertFalse(context.answerCommitted); XCTAssertEqual(context.revealedHintCount, 0)
    }

    func testNewResumeRoundTripsEveryAnswerField() throws {
        let context = ResumeStudyContext(sessionID: UUID(), activityIndex: 3, questionID: UUID(),
            selectedAnswerID: UUID(), selectedConfidence: .certain, answerCommitted: true, revealedHintCount: 2)
        XCTAssertEqual(try JSONDecoder().decode(ResumeStudyContext.self, from: JSONEncoder().encode(context)), context)
    }

    func testAtomicSessionAndContextSurviveNewRepository() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let session = makeSession()
        let context = ResumeStudyContext(sessionID: session.id, activityIndex: 1, questionID: UUID(),
            selectedAnswerID: UUID(), selectedConfidence: .fairlySure, answerCommitted: true, revealedHintCount: 2)
        try await repo.saveStudyCheckpoint(session: session, context: context)
        let reopened = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let state = try await reopened.open()
        XCTAssertEqual(state.sessions.first?.id, session.id)
        XCTAssertEqual(state.resumeStudyContext?.activityIndex, 1)
        XCTAssertEqual(state.resumeStudyContext?.selectedAnswerID, context.selectedAnswerID)
        XCTAssertEqual(state.resumeStudyContext?.selectedConfidence, .fairlySure)
        XCTAssertEqual(state.resumeStudyContext?.answerCommitted, true)
        XCTAssertEqual(state.resumeStudyContext?.revealedHintCount, 2)
    }

    func testMismatchedSessionIsRejectedWithoutMutation() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let session = makeSession()
        do {
            try await repo.saveStudyCheckpoint(session: session, context: ResumeStudyContext(sessionID: UUID()))
            XCTFail("Mismatched checkpoint accepted")
        } catch { XCTAssertEqual(error as? StudyCheckpointError, .inconsistentSession) }
        let snapshot = try await repo.snapshot()
        XCTAssertTrue(snapshot.sessions.isEmpty); XCTAssertNil(snapshot.resumeStudyContext)
    }

    func testOutOfBoundsActivityIsRejected() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let session = makeSession()
        do {
            try await repo.saveStudyCheckpoint(session: session, context: ResumeStudyContext(sessionID: session.id, activityIndex: 99))
            XCTFail("Out-of-bounds checkpoint accepted")
        } catch { XCTAssertEqual(error as? StudyCheckpointError, .inconsistentSession) }
    }

    func testRepeatedCheckpointReplacesRatherThanDuplicatesSession() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let session = makeSession()
        for i in 0..<6 {
            try await repo.saveStudyCheckpoint(session: session, context: ResumeStudyContext(sessionID: session.id, activityIndex: i % 2))
        }
        let state = try await repo.snapshot()
        XCTAssertEqual(state.sessions.count, 1); XCTAssertEqual(state.resumeStudyContext?.activityIndex, 1)
    }

    func testCompletionClearsResumeAndRecordsOneHistoryEvent() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        var session = makeSession()
        try await repo.saveStudyCheckpoint(session: session, context: ResumeStudyContext(sessionID: session.id))
        session.completedAt = Date()
        try await repo.saveStudyCheckpoint(session: session, context: nil)
        try await repo.saveStudyCheckpoint(session: session, context: nil)
        let state = try await repo.snapshot()
        XCTAssertNil(state.resumeStudyContext)
        XCTAssertEqual(state.timeline.filter { $0.kind == .session }.count, 1)
    }

    func testLeavingClearsPointerWithoutDeletingHistory() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let repo = LearningRepository(persistence: FileLearningSnapshotStore(root: root))
        let session = makeSession()
        try await repo.saveStudyCheckpoint(session: session, context: ResumeStudyContext(sessionID: session.id))
        try await repo.saveStudyCheckpoint(session: nil, context: nil)
        let state = try await repo.snapshot()
        XCTAssertNil(state.resumeStudyContext); XCTAssertEqual(state.sessions.count, 1)
    }

    func testFailedCheckpointDoesNotPublishPartialState() async throws {
        let persistence = RejectingStudyStore()
        let repo = LearningRepository(persistence: persistence)
        let session = makeSession()
        do {
            try await repo.saveStudyCheckpoint(session: session, context: ResumeStudyContext(sessionID: session.id))
            XCTFail("A failed write was acknowledged")
        } catch { XCTAssertEqual(error as? StudyStoreFailure, .writeRejected) }
        let state = try await repo.snapshot()
        XCTAssertTrue(state.sessions.isEmpty); XCTAssertNil(state.resumeStudyContext)
    }

    private func makeSession() -> StudySession {
        StudySession(requestedMinutes: 5, activities: [
            StudyActivity(kind: .question, title: "First", estimatedSeconds: 60),
            StudyActivity(kind: .question, title: "Second", estimatedSeconds: 60)])
    }
    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("leu-checkpoint-" + UUID().uuidString)
    }
}
private enum StudyStoreFailure: Error { case writeRejected }
private struct RejectingStudyStore: LearningSnapshotPersistence {
    func load() throws -> LearningSnapshot { LearningSnapshot() }
    func save(_ snapshot: LearningSnapshot) throws { throw StudyStoreFailure.writeRejected }
}
