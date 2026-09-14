import Foundation

/// Pure snapshot mutation; the repository performs its single durable commit.
enum StudyCheckpointMutation {
    static func apply(session: StudySession?, context: ResumeStudyContext?, to snapshot: inout LearningSnapshot) throws {
        if let context {
            guard let session, session.completedAt == nil, context.sessionID == session.id,
                  session.activities.indices.contains(context.activityIndex) else {
                throw StudyCheckpointError.inconsistentSession
            }
        }
        if let session { storeSession(session, in: &snapshot) }
        snapshot.resumeStudyContext = context
    }

    static func storeSession(_ session: StudySession, in snapshot: inout LearningSnapshot) {
        let existing = snapshot.sessions.firstIndex(where: { $0.id == session.id })
        let wasComplete = existing.map { snapshot.sessions[$0].completedAt != nil } ?? false
        if let existing { snapshot.sessions[existing] = session }
        else { snapshot.sessions.append(session) }
        if session.completedAt != nil && !wasComplete {
            snapshot.timeline.append(LearningTimelineEvent(kind: .session,
                title: "Study session · \(session.requestedMinutes) min"))
        }
    }
}
