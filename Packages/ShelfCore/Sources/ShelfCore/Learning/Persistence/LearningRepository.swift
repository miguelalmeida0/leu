import Foundation

public actor LearningRepository {
    private let persistence: any LearningSnapshotPersistence
    private var state: LearningSnapshot?
    private let scheduler: any ReviewScheduling
    let reducer = LearnerModelReducer()
    /// Increments with every committed transaction.
    public private(set) var revision = 0

    public init(persistence: any LearningSnapshotPersistence,
                scheduler: any ReviewScheduling = ShelfReviewScheduler()) {
        self.persistence = persistence; self.scheduler = scheduler
    }

    @discardableResult
    public func open() throws -> LearningSnapshot {
        if let state { return state }
        var loaded = try persistence.load()
        let seeded = loaded.topics.isEmpty
        if seeded { loaded.topics = TopicClassifier.defaultSeeds.map(\.topic) }
        let migrated = DerivedExtractionMigration.apply(to: &loaded)
        if migrated { try persistence.save(loaded) }
        else if seeded { try? persistence.save(loaded) }
        self.state = loaded
        return loaded
    }

    public func snapshot() throws -> LearningSnapshot { try open() }

    public func revisionedSnapshot() throws -> RevisionedLearningSnapshot {
        RevisionedLearningSnapshot(snapshot: try open(), revision: revision)
    }

    public func upsertAnalysis(_ analysis: DocumentAnalysis, topics: [TopicClassification],
                               questions: [LearningQuestion], semanticIndex: SemanticIndex? = nil) throws {
        try transaction { snapshot in
            let old = snapshot.analyses[analysis.documentID]
            if old?.extractionVersion != analysis.extractionVersion || old?.fingerprint != analysis.fingerprint {
                for index in snapshot.learningObjects.indices where
                    snapshot.learningObjects[index].source.documentID == analysis.documentID &&
                    snapshot.learningObjects[index].origin == .documentAnalysis {
                    snapshot.learningObjects[index].sourceIsStale = true
                }
            }
            snapshot.analyses[analysis.documentID] = analysis
            if let semanticIndex { snapshot.semanticIndexes[analysis.documentID] = semanticIndex }
            mergeTopics(topics.map(\.topic), into: &snapshot)
            let automaticTopicIDs = Set(topics.filter { $0.score >= 0.18 }.map(\.topic.id))
            let topicIDs = snapshot.manualDocumentTopics[analysis.documentID] ?? automaticTopicIDs
            var enriched = analysis
            enriched.topicScores = Dictionary(uniqueKeysWithValues: topics.map { ($0.topic.id, $0.score) })
            snapshot.analyses[analysis.documentID] = enriched
            snapshot.questions.removeAll { $0.source.documentID == analysis.documentID }
            snapshot.questions.append(contentsOf: questions.filter { FinalMCQAdmission.rejectionReason($0, analysis: enriched) == nil }.map { question in
                var q = question; q.topicIDs = topicIDs; return q
            })
            ensureObjects(for: enriched, topicIDs: topicIDs, in: &snapshot)
        }
    }

    public func setManualTopics(documentID: UUID, topicIDs: Set<UUID>) throws {
        try transaction { snapshot in
            snapshot.manualDocumentTopics[documentID] = topicIDs
            for index in snapshot.learningObjects.indices
            where snapshot.learningObjects[index].source.documentID == documentID {
                snapshot.learningObjects[index].topicIDs = topicIDs
            }
            for index in snapshot.questions.indices
            where snapshot.questions[index].source.documentID == documentID {
                snapshot.questions[index].topicIDs = topicIDs
            }
        }
    }

    @discardableResult
    public func addTopic(name: String) throws -> LearningTopic {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw ShelfError.emptyTitle }
        return try transaction { snapshot in
            if let existing = snapshot.topics.first(where: { $0.name.compare(clean, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                return existing
            }
            let topic = LearningTopic(id: StableIdentity.uuid("manual-topic|" + clean.lowercased()), name: String(clean.prefix(64)), isManual: true)
            snapshot.topics.append(topic)
            return topic
        }
    }

    @discardableResult
    public func capture(type: LearningObjectType, source: LearningSource, title: String,
                        prompt: String? = nil, topicIDs: Set<UUID> = [], importance: Double = 0.6,
                        origin: LearningObjectOrigin = .userSelection) throws -> LearningObject {
        try transaction { snapshot in
            let object = LearningObject(type: type, source: source, topicIDs: topicIDs,
                                        title: title, prompt: prompt, importance: importance, origin: origin)
            snapshot.learningObjects.append(object)
            snapshot.reviewStates[object.id] = ReviewState(learningObjectID: object.id, importance: importance)
            snapshot.timeline.append(LearningTimelineEvent(kind: .encountered, title: title,
                                                           learningObjectID: object.id, source: source))
            return object
        }
    }

    /// Records a review and, in the same transaction, what it shows about the learner.
    public func review(objectID: UUID, questionID: UUID? = nil, rating: RecallRating,
                       correct: Bool? = nil, confidence: ConfidenceLevel? = nil,
                       responseTime: TimeInterval? = nil, hintCount: Int = 0,
                       at date: Date = Date(), evidence: [LearningEvidence] = []) throws {
        try transaction { snapshot in
            apply(evidence, to: &snapshot)
            guard let object = snapshot.learningObjects.first(where: { $0.id == objectID }) else { throw ShelfError.notFound }
            let current = snapshot.reviewStates[objectID] ?? ReviewState(learningObjectID: objectID, importance: object.importance)
            snapshot.reviewStates[objectID] = scheduler.reviewed(current, rating: rating, hintCount: hintCount, at: date)
            snapshot.attempts.append(LearningAttempt(learningObjectID: objectID, questionID: questionID,
                                                     occurredAt: date, rating: rating, wasCorrect: correct,
                                                     confidence: confidence, responseTime: responseTime,
                                                     hintCount: hintCount))
            if let questionID, let confidence, let correct {
                let propositionID = snapshot.questions.first(where: { $0.id == questionID })?.propositionID
                snapshot.confidenceRecords.append(ConfidenceRecord(questionID: questionID, propositionID: propositionID,
                                                                  confidence: confidence, wasCorrect: correct, occurredAt: date))
            }
            let kind: TimelineEventKind = rating == .forgot ? .forgot : (rating == .difficult ? .difficult : .recalled)
            snapshot.timeline.append(LearningTimelineEvent(occurredAt: date, kind: kind, title: object.title,
                                                           learningObjectID: object.id, source: object.source))
        }
    }

    public func connect(_ sourceID: UUID, to targetID: UUID, kind: RelationshipKind,
                        customLabel: String? = nil) throws {
        try transaction { snapshot in
            guard sourceID != targetID,
                  snapshot.learningObjects.contains(where: { $0.id == sourceID }),
                  snapshot.learningObjects.contains(where: { $0.id == targetID }) else { throw ShelfError.corruptLibrary("Invalid learning relationship or object reference.") }
            if !snapshot.relationships.contains(where: { $0.sourceObjectID == sourceID && $0.targetObjectID == targetID && $0.kind == kind }) {
                snapshot.relationships.append(LearningRelationship(sourceObjectID: sourceID, targetObjectID: targetID,
                                                                   kind: kind, customLabel: customLabel))
                let title = snapshot.learningObjects.first(where: { $0.id == sourceID })?.title ?? "Connection"
                snapshot.timeline.append(LearningTimelineEvent(kind: .connected, title: title, learningObjectID: sourceID))
            }
        }
    }

    @discardableResult
    public func saveTrail(_ trail: LearningTrail) throws -> LearningTrail {
        try transaction { snapshot in
            if let index = snapshot.trails.firstIndex(where: { $0.id == trail.id }) { snapshot.trails[index] = trail }
            else { snapshot.trails.append(trail) }
            return trail
        }
    }

    public func deleteTrail(id: UUID) throws { try transaction { $0.trails.removeAll { $0.id == id } } }

    public func recordLensUse(_ source: LearningSource) throws {
        let key = "\(source.documentID)|\(source.pageIndex)"
        try transaction { $0.lensUsage[key] = min(100, ($0.lensUsage[key] ?? 0) + 1) }
    }

    public func saveMask(_ mask: DiagramMask) throws {
        try transaction { snapshot in
            guard snapshot.learningObjects.contains(where: { $0.id == mask.learningObjectID }) else { throw ShelfError.notFound }
            if let index = snapshot.masks.firstIndex(where: { $0.id == mask.id }) { snapshot.masks[index] = mask }
            else { snapshot.masks.append(mask) }
            snapshot.timeline.append(LearningTimelineEvent(kind: .masked, title: mask.label ?? "Diagram recall",
                                                           learningObjectID: mask.learningObjectID, source: mask.source))
        }
    }

    public func saveRecording(_ recording: ExplanationRecording) throws {
        try transaction { snapshot in
            guard snapshot.learningObjects.contains(where: { $0.id == recording.learningObjectID }) else { throw ShelfError.notFound }
            if let index = snapshot.recordings.firstIndex(where: { $0.id == recording.id }) { snapshot.recordings[index] = recording }
            else { snapshot.recordings.append(recording) }
            snapshot.timeline.append(LearningTimelineEvent(kind: .recorded, title: "Self explanation",
                                                           learningObjectID: recording.learningObjectID))
        }
    }


    public func recordEmotionalCheckIn(_ checkIn: EmotionalCheckIn) throws {
        try transaction { snapshot in
            snapshot.emotionalCheckIns.append(checkIn)
            if snapshot.emotionalCheckIns.count > 120 { snapshot.emotionalCheckIns.removeFirst(snapshot.emotionalCheckIns.count - 120) }
        }
    }

    public func deleteEmotionalCheckIns() throws {
        try transaction { $0.emotionalCheckIns.removeAll() }
    }

    public func setEmotionalCheckInPreference(_ preference: EmotionalCheckInPreference) throws {
        try transaction { $0.emotionalCheckInPreference = preference }
    }

    public func saveResumeStudyContext(_ context: ResumeStudyContext?) throws {
        try transaction { $0.resumeStudyContext = context }
    }

    public func saveSession(_ session: StudySession) throws {
        try transaction { StudyCheckpointMutation.storeSession(session, in: &$0) }
    }

    public func saveStudyCheckpoint(session: StudySession?, context: ResumeStudyContext?) throws {
        try transaction { try StudyCheckpointMutation.apply(session: session, context: context, to: &$0) }
    }

    func transaction<T>(_ mutation: (inout LearningSnapshot) throws -> T) throws -> T {
        var next = try open()
        let result = try mutation(&next)
        try validate(next)
        try persistence.save(next)
        state = next
        revision += 1
        return result
    }

    private func validate(_ snapshot: LearningSnapshot) throws {
        guard snapshot.schemaVersion == 1 else { throw ShelfError.unsupportedVersion(snapshot.schemaVersion) }
        let objectIDs = Set(snapshot.learningObjects.map(\.id))
        guard objectIDs.count == snapshot.learningObjects.count else { throw ShelfError.corruptLibrary("Invalid learning relationship or object reference.") }
        guard snapshot.relationships.allSatisfy({ objectIDs.contains($0.sourceObjectID) && objectIDs.contains($0.targetObjectID) }) else {
            throw ShelfError.corruptLibrary("Invalid learning relationship or object reference.")
        }
        guard snapshot.masks.allSatisfy({ objectIDs.contains($0.learningObjectID) }) else { throw ShelfError.corruptLibrary("Invalid learning relationship or object reference.") }
    }

    private func mergeTopics(_ topics: [LearningTopic], into snapshot: inout LearningSnapshot) {
        for topic in topics where !snapshot.topics.contains(where: { $0.id == topic.id }) { snapshot.topics.append(topic) }
    }
}
