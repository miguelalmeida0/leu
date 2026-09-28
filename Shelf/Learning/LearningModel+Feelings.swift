import Foundation
import ShelfCore

/// Emotional check-ins after a session: when to offer one and how the answer is kept.
@MainActor
extension LearningModel {
    var currentSessionAttempts: [LearningAttempt] {
        let since = sessionStartedAt ?? .distantPast
        return snapshot.attempts.filter { $0.occurredAt >= since }
    }

    var shouldOfferEmotionalCheckIn: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--force-emotional-checkin") {
            return snapshot.emotionalCheckInPreference != .off
        }
        #endif
        return EmotionalCheckInPolicy().shouldOffer(preference: snapshot.emotionalCheckInPreference,
                                                     attempts: currentSessionAttempts,
                                                     lastCheckIn: snapshot.emotionalCheckIns.last?.occurredAt)
    }

    func recordFeeling(_ feeling: StudyFeeling) async {
        do {
            try await repository.recordEmotionalCheckIn(EmotionalCheckIn(sessionID: activeSession?.id, feeling: feeling))
            try await refreshSnapshot()
            selectedFeeling = feeling
            play(.selectionChanged)
        } catch { errorMessage = error.localizedDescription }
    }

    func setEmotionalCheckInPreference(_ preference: EmotionalCheckInPreference) async {
        do {
            try await repository.setEmotionalCheckInPreference(preference)
            try await refreshSnapshot()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteEmotionalCheckIns() async {
        do {
            try await repository.deleteEmotionalCheckIns()
            try await refreshSnapshot()
        } catch { errorMessage = error.localizedDescription }
    }
}
