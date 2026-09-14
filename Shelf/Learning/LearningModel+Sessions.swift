import Foundation
import ShelfCore

@MainActor
extension LearningModel {
    func startPassageQuestion(_ source: IntelligenceSource) -> Bool {
        guard activeSession == nil, source.isCurrent(in: snapshot.analyses),
              let question = ConceptImportanceModel().ranked(snapshot.questions, snapshot: snapshot).first(where: {
                  $0.source.documentID == source.packet.documentID && $0.source.pageIndex == source.packet.pageIndex &&
                  CanonicalWhitespaceResolver.normalize(source.passage.sourceText).contains(CanonicalWhitespaceResolver.normalize($0.source.sourceText)) &&
                  ($0.v4 != nil || $0.modelProvenance?.schemaVersion == 3)
              }), let object = snapshot.studyObjects.first(where: { sourceKey($0.source) == sourceKey(question.source) }) else { return false }
        begin(StudySession(topicID: object.topicIDs.first, requestedMinutes: 1, mode: .learn,
            activities: [.init(kind: .question, learningObjectID: object.id, questionID: question.id,
                title: object.title, estimatedSeconds: 55)]))
        return true
    }
    func startInterview(topicID: UUID?, questionCount: Int?) {
        let allowedObjects = snapshot.studyObjects.filter { object in
            topicID.map { object.topicIDs.contains($0) } ?? true
        }
        let pageKeys = Set(allowedObjects.map { sourceKey($0.source) })
        let dueIDs = Set(dueObjects.map(\.id))
        var questions = snapshot.questions.filter { question in
            guard pageKeys.contains(sourceKey(question.source)) else { return false }
            guard questionCount == nil else { return true }
            return allowedObjects.contains { object in
                dueIDs.contains(object.id) && sourceKey(object.source) == sourceKey(question.source)
            }
        }
        questions = ConceptImportanceModel().ranked(questions, snapshot: snapshot, annotations: library.snapshot.annotations)

        if let questionCount { questions = Array(questions.prefix(questionCount)) }
        let activities = questions.compactMap { question -> StudyActivity? in
            guard let object = allowedObjects.first(where: { sourceKey($0.source) == sourceKey(question.source) }) else { return nil }
            return StudyActivity(kind: .question, learningObjectID: object.id, questionID: question.id,
                                 title: object.title, estimatedSeconds: 55)
        }
        begin(StudySession(topicID: topicID,
                           requestedMinutes: estimatedMinutes(for: activities, secondsEach: 55),
                           mode: .interview, activities: activities))
    }

    func startActiveRecall(topicID: UUID? = nil, documentID: UUID? = nil,
                           trailID: UUID? = nil, dueOnly: Bool = false) {
        var objects = snapshot.studyObjects.filter { object in
            if let topicID, !object.topicIDs.contains(topicID) { return false }
            if let documentID, object.source.documentID != documentID { return false }
            return true
        }
        if let trailID, let trail = snapshot.trails.first(where: { $0.id == trailID }) {
            let objectIDs = Set(trail.nodes.filter { $0.kind == .learningObject }.compactMap(\.referenceID))
            let documentIDs = Set(trail.nodes.filter { $0.kind == .document }.compactMap(\.documentID))
            objects = objects.filter { objectIDs.contains($0.id) || documentIDs.contains($0.source.documentID) }
        }
        if dueOnly {
            let ids = Set(dueObjects.map(\.id))
            objects = objects.filter { ids.contains($0.id) }
        }
        let activities = objects.prefix(12).map { StudyActivity(kind: .recall, learningObjectID: $0.id, title: $0.title, estimatedSeconds: 70) }
        guard !activities.isEmpty else { notice = "No passages are ready in this selection."; return }
        begin(StudySession(topicID: topicID,
                           requestedMinutes: estimatedMinutes(for: activities, secondsEach: 70),
                           mode: .activeRecall, activities: activities))
    }

    func startReview(objectID: UUID) {
        guard let object = snapshot.studyObjects.first(where: { $0.id == objectID }) else { return }
        begin(StudySession(topicID: object.topicIDs.first, requestedMinutes: 5,
                           mode: .activeRecall, activities: [activity(for: object)]))
    }

    func startReview(objectIDs: [UUID]) {
        let ids = Set(objectIDs)
        let objects = snapshot.studyObjects.filter { ids.contains($0.id) }
        guard !objects.isEmpty else { return }
        let activities = objects.prefix(8).map { activity(for: $0) }
        begin(StudySession(topicID: nil, requestedMinutes: estimatedMinutes(for: activities, secondsEach: 70),
                           mode: .activeRecall, activities: activities))
    }

    func startSession(topicID: UUID?, minutes: Int, mode: StudySessionMode = .learn) {
        Task {
            await prepareV4Questions()
            guard activeSession == nil else { return }
            begin(planner.plan(snapshot: snapshot, topicID: topicID, minutes: minutes, mode: mode, now: Date()))
        }
    }

    func selectAnswer(_ id: UUID) {
        guard !answerCommitted else { return }
        selectedAnswerID = id
        play(.selectionChanged)
        persistStudyState()
    }

    func commitAnswer() {
        guard selectedAnswerID != nil, !answerCommitted else { return }
        answerCommitted = true
        persistStudyState()
        play(.answerCommitted)
        if let question = currentQuestion {
            play(selectedAnswerID == question.correctOptionID ? .answerCorrect : .answerIncorrect)
            if let analysis = snapshot.analyses[question.source.documentID],
               let source = IntelligenceSource(source: question.source, analysis: analysis) {
                Task {
                    do { try await repository.storeUnderstandingEvent(.init(kind: .answeredQuestion, source: source))
                        snapshot = try await repository.snapshot()
                    } catch { errorMessage = "Could not save this learning event." }
                }
            }
        }
    }

    func rateCurrent(_ rating: RecallRating) async {
        guard !isRecordingAttempt else { return }
        isRecordingAttempt = true
        defer { isRecordingAttempt = false }
        await studySaveTask?.value
        guard studySaveError == nil else { return }
        guard let object = currentObject else { advance(); return }
        let correct = currentQuestion.map { $0.correctOptionID == selectedAnswerID }
        let responseTime = activityStartedAt.map { Date().timeIntervalSince($0) }
        do {
            try await repository.review(objectID: object.id, questionID: currentQuestion?.id,
                                        rating: rating, correct: correct, confidence: selectedConfidence,
                                        responseTime: responseTime, hintCount: revealedHintCount)
            snapshot = try await repository.snapshot()
            let mastery = snapshot.reviewStates[object.id].map { scheduler.mastery(for: $0, at: Date()) }
            if mastery == .strengthening || mastery == .durable { play(.memoryStrengthened) }
            advance()
        } catch { errorMessage = error.localizedDescription }
    }

    func revealNextHint() {
        let total = currentQuestion.map { hints.hints(for: $0, topicName: topicName(for: $0)).count } ?? 0
        guard revealedHintCount < total else { return }
        revealedHintCount += 1
        persistStudyState()
        play(.sourceRevealed)
    }

    func progressiveHints() -> [ProgressiveHint] {
        guard let question = currentQuestion else { return [] }
        return Array(hints.hints(for: question, topicName: topicName(for: question)).prefix(revealedHintCount))
    }

    func advance() {
        guard let session = activeSession else { return }
        if activityIndex + 1 < session.activities.count {
            activityIndex += 1
            resetActivityState()
            persistStudyState()
        } else { completeSession() }
    }

    func completeSession() {
        guard var session = activeSession else { return }
        session.completedAt = Date()
        activeSession = session
        sessionSummaryPresented = true
        play(.studySessionCompleted)
        persistStudyState()
    }

    func endSession() {
        activeSession = nil
        recallDraft = ""
        recallMarkedUnknown = false
        sessionSummaryPresented = false
        activityIndex = 0
        selectedFeeling = nil
        releasePresented = false
        persistStudyState()
    }

    private func begin(_ session: StudySession) {
        #if DEBUG
        let objects = snapshot.studyObjects.filter { object in
            session.topicID.map { object.topicIDs.contains($0) } ?? true
        }
        let candidates = objects.filter { object in
            snapshot.questions.contains { $0.source.documentID == object.source.documentID && $0.source.pageIndex == object.source.pageIndex }
        }
        StudyInteractionTrace.record("study.plan objects=\(objects.count) questionCandidates=\(candidates.count) plannedQuestions=\(session.activities.filter { $0.questionID != nil }.count)")
        #endif
        activeSession = session
        StudyInteractionTrace.record("study.active session=\(session.id) questionIDs=\(session.activities.compactMap(\.questionID))")
        activityIndex = 0
        sessionStartedAt = Date()
        sessionSummaryPresented = false
        selectedFeeling = nil; releasePresented = false
        resetActivityState()
        play(.studySessionStarted)
        persistStudyState()
    }

    private func activity(for object: LearningObject) -> StudyActivity {
        let question = ConceptImportanceModel().ranked(snapshot.questions.filter { sourceKey($0.source) == sourceKey(object.source) },
            snapshot: snapshot, annotations: library.snapshot.annotations).first
        let kind: StudyActivityKind
        if snapshot.masks.contains(where: { $0.learningObjectID == object.id }) { kind = .mask }
        else { kind = question == nil ? .recall : .question }
        return StudyActivity(kind: kind, learningObjectID: object.id, questionID: question?.id,
                             title: object.title, estimatedSeconds: 70)
    }

    private func estimatedMinutes(for activities: [StudyActivity], secondsEach: Int) -> Int {
        max(5, Int(ceil(Double(activities.count * secondsEach) / 60.0)))
    }

    private func topicName(for question: LearningQuestion) -> String? {
        question.topicIDs.compactMap { id in snapshot.topics.first(where: { $0.id == id })?.name }.first
    }

    private func sourceKey(_ source: LearningSource) -> String {
        "\(source.documentID.uuidString)|\(source.pageIndex)"
    }

    func resetActivityState() {
        recallDraft = ""
        recallMarkedUnknown = false
        selectedAnswerID = nil
        answerCommitted = false
        selectedConfidence = nil
        revealedHintCount = 0
        activityStartedAt = Date()
    }
}

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
            snapshot = try await repository.snapshot()
            selectedFeeling = feeling
            play(.selectionChanged)
        } catch { errorMessage = error.localizedDescription }
    }

    func setEmotionalCheckInPreference(_ preference: EmotionalCheckInPreference) async {
        do {
            try await repository.setEmotionalCheckInPreference(preference)
            snapshot = try await repository.snapshot()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteEmotionalCheckIns() async {
        do {
            try await repository.deleteEmotionalCheckIns()
            snapshot = try await repository.snapshot()
        } catch { errorMessage = error.localizedDescription }
    }
}
