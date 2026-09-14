import Foundation

public protocol StudySessionPlanning: Sendable {
    func plan(snapshot: LearningSnapshot, topicID: UUID?, minutes: Int, mode: StudySessionMode, now: Date) -> StudySession
}

public struct ShelfStudySessionPlanner: StudySessionPlanning, Sendable {
    private let scheduler: any ReviewScheduling
    public init(scheduler: any ReviewScheduling = ShelfReviewScheduler()) { self.scheduler = scheduler }

    public func plan(snapshot: LearningSnapshot, topicID: UUID?, minutes: Int,
                     mode: StudySessionMode = .learn, now: Date = Date()) -> StudySession {
        let safeMinutes = [5, 10, 20, 30].contains(minutes) ? minutes : min(30, max(5, minutes))
        let target = safeMinutes * 60
        let objects = snapshot.studyObjects.filter { object in
            topicID.map { object.topicIDs.contains($0) } ?? true
        }
        var candidates: [(Double, StudyActivity)] = []

        for object in objects {
            let state = snapshot.reviewStates[object.id] ?? ReviewState(learningObjectID: object.id, importance: object.importance)
            let mastery = scheduler.mastery(for: state, at: now)
            let dueScore: Double = {
                guard let due = state.nextReviewAt else { return 0.45 }
                if due <= now { return mastery == .fading ? 1.0 : 0.9 }
                let hours = due.timeIntervalSince(now) / 3600
                return max(0.08, 0.6 - min(0.52, hours / 72 * 0.52))
            }()
            let weakness = 0.35 + state.difficulty * 0.65
            let novelty = state.reviewCount == 0 ? 0.72 : 0.36
            let base = dueScore * 0.48 + weakness * 0.26 + object.importance * 0.16 + novelty * 0.10
            let rankedQuestions = ConceptImportanceModel().ranked(snapshot.questions.filter { $0.source.documentID == object.source.documentID && $0.source.pageIndex == object.source.pageIndex }, snapshot: snapshot)
            if let question = rankedQuestions.first {
                candidates.append((base + question.qualityScore * 0.18 + (question.v4 == nil ? 0 : 0.3),
                                   StudyActivity(kind: .question, learningObjectID: object.id, questionID: question.id,
                                                 title: object.title, estimatedSeconds: mode == .interview ? 55 : 75)))
            }
            if mode != .interview {
                candidates.append((base * 0.94, StudyActivity(kind: .recall, learningObjectID: object.id,
                                                              title: object.title, estimatedSeconds: 70)))
                if snapshot.masks.contains(where: { $0.learningObjectID == object.id }) {
                    candidates.append((base * 0.97, StudyActivity(kind: .mask, learningObjectID: object.id,
                                                                  title: object.title, estimatedSeconds: 80)))
                }
            }
        }

        if mode != .interview {
            let labKinds: [StudyActivityKind] = [.reconstruction]
            if !objects.isEmpty, let first = objects.first, labKinds.first != nil {
                candidates.append((0.46, StudyActivity(kind: .reconstruction, learningObjectID: first.id,
                                                       title: "Reconstruction lab", estimatedSeconds: 110)))
            }
        }

        candidates.sort { lhs, rhs in lhs.0 == rhs.0 ? lhs.1.id.uuidString < rhs.1.id.uuidString : lhs.0 > rhs.0 }
        var activities: [StudyActivity] = []
        var usedObjects = Set<UUID>()
        var elapsed = 0
        var lastKind: StudyActivityKind?
        for (_, activity) in candidates {
            if let objectID = activity.learningObjectID, usedObjects.contains(objectID) && activity.kind == lastKind { continue }
            if activity.kind == lastKind && mode != .interview { continue }
            if elapsed + activity.estimatedSeconds > target + 45 && !activities.isEmpty { continue }
            activities.append(activity)
            elapsed += activity.estimatedSeconds
            if let objectID = activity.learningObjectID { usedObjects.insert(objectID) }
            lastKind = activity.kind
            if elapsed >= target - 30 { break }
        }
        if elapsed < target / 2, mode != .interview {
            activities.append(StudyActivity(kind: .continueReading, title: "Continue reading", estimatedSeconds: max(60, target - elapsed)))
        }
        return StudySession(topicID: topicID, requestedMinutes: safeMinutes, mode: mode, activities: activities)
    }
}
