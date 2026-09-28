import Foundation

public protocol StudySessionPlanning: Sendable {
    func plan(snapshot: LearningSnapshot, topicID: UUID?, minutes: Int, mode: StudySessionMode, now: Date) -> StudySession
}

public struct ShelfStudySessionPlanner: StudySessionPlanning, Sendable {
    private let scheduler: any ReviewScheduling
    public init(scheduler: any ReviewScheduling = ShelfReviewScheduler()) { self.scheduler = scheduler }

    public func plan(snapshot: LearningSnapshot, topicID: UUID?, minutes: Int,
                     mode: StudySessionMode = .learn, now: Date = Date()) -> StudySession {
        plan(snapshot: snapshot, knowledge: .empty, topicID: topicID, minutes: minutes, mode: mode, now: now)
    }

    /// With compiled knowledge, what the learner model knows reorders the session (live
    /// misconceptions, weak and confidently-wrong concepts first) and each activity carries the
    /// grounded question the adaptive selector chose. Without knowledge, planning is unchanged.
    public func plan(snapshot: LearningSnapshot, knowledge: ConceptKnowledgeBase, topicID: UUID?, minutes: Int,
                     mode: StudySessionMode = .learn, now: Date = Date()) -> StudySession {
        let safeMinutes = [5, 10, 20, 30].contains(minutes) ? minutes : min(30, max(5, minutes))
        // Concept names repeat across documents: every lookup stays inside the passage's document.
        var scoped: [UUID: (mapper: LearnerEvidenceMapper, selector: AdaptiveProbeSelector)] = [:]
        func tools(_ documentID: UUID) -> (mapper: LearnerEvidenceMapper, selector: AdaptiveProbeSelector) {
            if let known = scoped[documentID] { return known }
            let local = knowledge.restricted(to: documentID)
            let made = (mapper: LearnerEvidenceMapper(knowledge: local), selector: AdaptiveProbeSelector(knowledge: local))
            scoped[documentID] = made
            return made
        }
        let priority = RetrievalPriority()
        var plannedProbes = Set<String>()
        let target = safeMinutes * 60
        let objects = snapshot.studyObjects.filter { object in
            topicID.map { object.topicIDs.contains($0) } ?? true
        }
        var candidates: [(Double, StudyActivity)] = []
        var pendingProbes: [Int: (LearnerConceptID, AdaptiveProbeSelector.Preference)] = [:]
        // The first passage that teaches each concept, so a detour can show its own source.
        var passages: [LearnerConceptID: LearningObject] = [:]

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
            let concepts = knowledge.isEmpty ? [] : tools(object.source.documentID).mapper.concepts(in: object.source)
            for concept in concepts where passages[concept.id] == nil { passages[concept.id] = object }
            let learner = concepts.map { priority.score(for: $0.id, in: snapshot.learnerModel, at: now) }.max() ?? 0
            let base = dueScore * 0.48 + weakness * 0.26 + object.importance * 0.16 + novelty * 0.10 + learner * 0.3
            let rankedQuestions = ConceptImportanceModel().ranked(snapshot.questions.filter { $0.source.documentID == object.source.documentID && $0.source.pageIndex == object.source.pageIndex }, snapshot: snapshot)
            if let question = rankedQuestions.first {
                candidates.append((base + question.qualityScore * 0.18,
                                   StudyActivity(kind: .question, learningObjectID: object.id, questionID: question.id,
                                                 title: object.title, estimatedSeconds: mode == .interview ? 55 : 75)))
            } else if let concept = concepts.first {
                // No admitted question on this page: a grounded recognition question about its
                // concept, chosen only if this activity makes it into the session.
                candidates.append((base + 0.8 * 0.18,
                                   StudyActivity(kind: .question, learningObjectID: object.id,
                                                 title: object.title, estimatedSeconds: mode == .interview ? 55 : 75)))
                pendingProbes[candidates.count - 1] = (concept.id, .choice)
            }
            if mode != .interview {
                candidates.append((base * 0.94, StudyActivity(kind: .recall, learningObjectID: object.id,
                                                              title: object.title, estimatedSeconds: 70)))
                if let concept = concepts.first { pendingProbes[candidates.count - 1] = (concept.id, .open) }
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

        // Ties keep the source order, so the same library and history always plan the same session.
        var remaining = candidates.indices.sorted { a, b in candidates[a].0 == candidates[b].0 ? a < b : candidates[a].0 > candidates[b].0 }
        var activities: [StudyActivity] = []
        var usedObjects = Set<UUID>()
        var elapsed = 0
        var lastKind: StudyActivityKind?
        var resolved: [Int: StudyActivity?] = [:]
        // A candidate's grounded question is chosen only when it could enter the session.
        func resolve(_ index: Int) -> StudyActivity? {
            if let known = resolved[index] { return known }
            var activity = candidates[index].1
            if let (concept, preference) = pendingProbes[index] {
                var decision = tools(concept.documentID).selector.next(for: concept, state: snapshot.learnerModel, preferring: preference, now: now)
                    .flatMap { plannedProbes.contains($0.probe.id) ? nil : $0 }
                // A detour asks about a prerequisite: it belongs with that concept's own passage.
                if let detour = decision, detour.probe.concept != concept {
                    if let passage = passages[detour.probe.concept] {
                        activity.learningObjectID = passage.id
                        activity.title = passage.title
                    } else { decision = nil }
                }
                if preference == .choice {
                    guard let decision, let question = decision.probe.question else { resolved[index] = .some(nil); return nil }
                    activity.questionID = question.id
                }
                activity.probe = decision?.probe
                activity.remediation = decision?.startsObjective
            }
            resolved[index] = activity
            return activity
        }
        // Kinds alternate while another kind is available; a library with a single kind of activity
        // still fills the session, never with the same passage twice.
        while elapsed < target - 30 {
            var chosen: (position: Int, activity: StudyActivity)?
            for allowRepeatKind in [false, true] where chosen == nil {
                if allowRepeatKind && (mode == .interview || lastKind == nil) { break }
                for (position, index) in remaining.enumerated() {
                    let candidate = candidates[index].1
                    if let objectID = candidate.learningObjectID, usedObjects.contains(objectID) && (candidate.kind == lastKind || allowRepeatKind) { continue }
                    if candidate.kind == lastKind && mode != .interview && !allowRepeatKind { continue }
                    if elapsed + candidate.estimatedSeconds > target + 45 && !activities.isEmpty { continue }
                    guard let activity = resolve(index) else { continue }
                    if let moved = activity.learningObjectID, moved != candidate.learningObjectID, usedObjects.contains(moved) { continue }
                    if let probe = activity.probe, plannedProbes.contains(probe.id) { resolved[index] = nil; continue }
                    chosen = (position, activity)
                    break
                }
            }
            guard let (position, activity) = chosen else { break }
            remaining.remove(at: position)
            if let probe = activity.probe { plannedProbes.insert(probe.id) }
            activities.append(activity)
            elapsed += activity.estimatedSeconds
            if let objectID = activity.learningObjectID { usedObjects.insert(objectID) }
            lastKind = activity.kind
        }
        if elapsed < target / 2, mode != .interview {
            activities.append(StudyActivity(kind: .continueReading, title: "Continue reading", estimatedSeconds: max(60, target - elapsed)))
        }
        return StudySession(topicID: topicID, requestedMinutes: safeMinutes, mode: mode, activities: activities)
    }
}
