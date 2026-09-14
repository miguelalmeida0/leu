import Foundation
import ShelfCore

@main struct RecoveryHarness {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("leu-model-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = QuestionOption(text: "A"), b = QuestionOption(text: "B")
        let question = LearningQuestion(stableKey: "recovery-fixture", kind: .semanticRelationship,
            prompt: "What does the source establish?", options: [a, b], correctOptionID: b.id,
            source: LearningSource(documentID: UUID(), pageIndex: 2, sourceText: "Explicit source."), qualityScore: 1)
        let activities = [0, 1].map { _ in StudyActivity(kind: .question, questionID: question.id, title: "Q", estimatedSeconds: 60) }
        let session = StudySession(requestedMinutes: 5, activities: activities)
        var seed = LearningSnapshot()
        seed.questions = [question]; seed.sessions = [session]
        seed.resumeStudyContext = ResumeStudyContext(sessionID: session.id, questionID: question.id,
            selectedAnswerID: a.id, selectedConfidence: .certain, answerCommitted: true, revealedHintCount: 1)
        try FileLearningSnapshotStore(root: root).save(seed)
        let model = LearningModel(repository: LearningRepository(persistence: FileLearningSnapshotStore(root: root)),
            library: LibraryModel(), recordingsDirectory: root)
        await model.bootstrap()
        try require(model.activeSession?.id == session.id, "bootstrap restores the exact session")
        try require(model.selectedAnswerID == a.id && model.answerCommitted && model.selectedConfidence == .certain,
                    "bootstrap restores answer, confidence and committed state")
        model.selectAnswer(b.id)
        try require(model.selectedAnswerID == a.id, "committed answers cannot be silently changed")
        model.resetActivityState()
        model.selectAnswer(a.id); model.selectConfidence(.unsure)
        model.selectAnswer(b.id); model.selectConfidence(.certain); model.commitAnswer()
        await model.studySaveTask?.value
        let restored = try FileLearningSnapshotStore(root: root).load()
        try require(restored.resumeStudyContext?.selectedAnswerID == b.id && restored.resumeStudyContext?.selectedConfidence == .certain,
                    "rapid ordered writes persist the latest values")
        try require(restored.resumeStudyContext?.answerCommitted == true && !model.isSavingStudyState && model.studySaveError == nil,
                    "Saved is acknowledged after the complete checkpoint")
        model.advance()
        await model.studySaveTask?.value
        let advanced = try FileLearningSnapshotStore(root: root).load()
        try require(advanced.resumeStudyContext?.activityIndex == 1 && advanced.resumeStudyContext?.selectedAnswerID == nil,
                    "next activity persists a reset answer state")
        model.completeSession()
        await model.studySaveTask?.value
        try require(model.snapshot.sessions.first?.completedAt != nil && model.snapshot.timeline.filter { $0.kind == .session }.count == 1,
                    "completion updates the observable history as well as disk")
        model.selectAnswer(a.id); model.endSession()
        await model.studySaveTask?.value
        let ended = try FileLearningSnapshotStore(root: root).load()
        try require(ended.resumeStudyContext == nil && ended.sessions.count == 1,
                    "end after a queued edit clears resume without deleting history")
        let failure = LearningModel(repository: LearningRepository(persistence: RejectWrites()),
            library: LibraryModel(), recordingsDirectory: root)
        await failure.bootstrap()
        failure.snapshot.questions = [question]; failure.activeSession = session
        failure.selectAnswer(a.id)
        await failure.studySaveTask?.value
        try require(failure.studySaveError != nil && failure.notice != nil && !failure.isSavingStudyState,
                    "failed writes surface a real error instead of claiming Saved")
        print("PASS: 9 LearningModel recovery-logic checks (Observation/PDF/UI adapters excluded; not iOS certification)")
    }

    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw HarnessError.failed(message) }
        print("PASS: " + message)
    }
}
private enum HarnessError: Error { case failed(String) }
private struct RejectWrites: LearningSnapshotPersistence {
    func load() throws -> LearningSnapshot { LearningSnapshot() }
    func save(_ snapshot: LearningSnapshot) throws { throw HarnessError.failed("Injected disk error") }
}
