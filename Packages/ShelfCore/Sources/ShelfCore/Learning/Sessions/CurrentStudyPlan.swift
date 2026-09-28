import Foundation

/// A session plan together with the snapshot it was made from.
public struct CurrentStudyPlan: Sendable {
    public let session: StudySession
    public let source: RevisionedLearningSnapshot

    /// Plans against the repository's latest snapshot, away from the caller's actor, and keeps
    /// the plan only if nothing was written while it was being made. Indexing, an upsert or any
    /// saved answer during planning invalidates it and planning starts again from the new
    /// snapshot. Nil when the repository kept changing: an outdated plan is never returned.
    public static func make(from repository: LearningRepository, attempts: Int = 3,
                            _ plan: @Sendable (LearningSnapshot) async -> StudySession) async throws -> CurrentStudyPlan? {
        for _ in 0..<max(1, attempts) {
            let source = try await repository.revisionedSnapshot()
            let session = await plan(source.snapshot)
            if await repository.revision == source.revision { return CurrentStudyPlan(session: session, source: source) }
        }
        return nil
    }
}
