import Foundation
import ShelfCore

@MainActor
extension LearningModel {
    func selectConfidence(_ level: ConfidenceLevel) {
        guard !answerCommitted else { return }
        selectedConfidence = level
        play(.selectionChanged)
        persistStudyState()
    }

    func restoreActivityState(_ context: ResumeStudyContext) {
        StudyInteractionTrace.record("study.restore expectedQuestion=\(String(describing: context.questionID)) boundQuestion=\(String(describing: currentQuestion?.id))")
        resetActivityState()
        guard let question = currentQuestion, context.questionID == question.id else { return }
        selectedAnswerID = question.options.first(where: { $0.id == context.selectedAnswerID })?.id
        selectedConfidence = context.selectedConfidence
        answerCommitted = context.answerCommitted && selectedAnswerID != nil
        revealedHintCount = min(context.revealedHintCount, hints.hints(for: question, topicName: nil).count)
    }

    /// Capture values before suspension and serialize writes in UI-event order.
    /// No swallowed write errors; "Saved" is shown only after durable persistence succeeds.
    func persistStudyState() {
        let session = activeSession
        let context = session.flatMap { session -> ResumeStudyContext? in
            guard session.completedAt == nil, session.activities.indices.contains(activityIndex) else { return nil }
            return ResumeStudyContext(sessionID: session.id, activityIndex: activityIndex,
                questionID: currentQuestion?.id, selectedAnswerID: selectedAnswerID,
                selectedConfidence: selectedConfidence, answerCommitted: answerCommitted,
                revealedHintCount: revealedHintCount)
        }
        let previous = studySaveTask
        let revision = UUID()
        studySaveRevision = revision
        isSavingStudyState = true
        studySaveError = nil
        studySaveTask = Task { [weak self, repository] in
            await previous?.value
            do {
                try await repository.saveStudyCheckpoint(session: session, context: context)
                let saved = try await repository.snapshot()
                guard let self, studySaveRevision == revision else { return }
                snapshot = saved
                isSavingStudyState = false
                StudyInteractionTrace.record("study.checkpoint.saved")
                StudyInteractionTrace.record("study.checkpoint question=\(String(describing: context?.questionID)) bank=\(saved.questions.count)")
            } catch {
                guard let self, studySaveRevision == revision else { return }
                isSavingStudyState = false
                studySaveError = error.localizedDescription
                notice = "Your latest study changes could not be saved. Keep Leu open and try again."
                errorMessage = error.localizedDescription
                StudyInteractionTrace.record("study.checkpoint.failed")
            }
        }
    }
}
