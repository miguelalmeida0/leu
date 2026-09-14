import Foundation
import Observation
import ShelfCore

@MainActor @Observable
final class LearningModel {
    let repository: LearningRepository
    let library: LibraryModel
    let indexer: PDFLearningIndexer
    let planner = ShelfStudySessionPlanner()
    let scheduler = ShelfReviewScheduler()
    let hints = ProgressiveHintBuilder()
    let topicAggregator = TopicLearningAggregator()
    let recordingsDirectory: URL

    var snapshot = LearningSnapshot()
    var isReady = false
    var isIndexing = false
    var indexingLabel: String?
    var indexingProgress: Double = 0
    var notice: String?
    var errorMessage: String?
    var activeSession: StudySession?
    var activityIndex = 0
    var selectedAnswerID: UUID?
    var answerCommitted = false
    var selectedConfidence: ConfidenceLevel?
    // Transient recall input belongs to the session, never to its durable checkpoint.
    var recallDraft = ""
    var recallMarkedUnknown = false
    var revealedHintCount = 0
    var sessionStartedAt: Date?
    var activityStartedAt: Date?
    var sessionSummaryPresented = false
    var activeLab: ReconstructionLab?
    var timelinePresented = false
    var connectionsOverviewPresented = false
    var interviewSetupPresented = false
    var activeRecallSetupPresented = false
    var documentTopicsPresented = false
    var moreLearningExpanded = false
    var selectedFeeling: StudyFeeling?
    var releasePresented = false
    var isSavingStudyState = false
    var studySaveError: String?
    var isRecordingAttempt = false
    @ObservationIgnored var studySaveTask: Task<Void, Never>?
    @ObservationIgnored var studySaveRevision = UUID()
    @ObservationIgnored var indexingTask: Task<Void, Never>?
    @ObservationIgnored var intelligenceTask: Task<Void, Never>?
    @ObservationIgnored var pendingIntelligenceSource: LearningSource?
    let intelligenceProvider: any LearningIntelligenceProvider & LearningExplanationCapable = AppleLearningIntelligenceProvider()
    let explanationCache: ExplanationCache
    var modelState: LearningModelState = .unavailable
    var modelAvailability: LearningModelState = .unavailable
    var modelInferenceAttempts = 0
    var modelGenerated = 0
    var modelAccepted = 0
    var modelRejections: [String: Int] = [:]
    var lastModelGeneration: Date?
    var lastModelError: String?
    var lastModelPacket: LearningSourcePacket?
    var modelGenerations: [LearningGenerationRecord] = []
    var migrationDiagnostics: [String] = []

    init(repository: LearningRepository, library: LibraryModel, recordingsDirectory: URL,
         indexer: PDFLearningIndexer = PDFLearningIndexer()) {
        self.repository = repository
        self.library = library
        self.recordingsDirectory = recordingsDirectory
        self.indexer = indexer
        self.explanationCache = ExplanationCache(persistence: LearningIntelligenceCache(root: recordingsDirectory.deletingLastPathComponent()))
    }

    var visibleTopics: [LearningTopic] {
        let automatic = snapshot.analyses.flatMap { documentID, analysis -> [UUID] in
            guard snapshot.manualDocumentTopics[documentID] == nil else { return [] }
            return analysis.topicScores.filter { $0.value >= 0.18 }.map(\.key)
        }
        let manual = snapshot.manualDocumentTopics.values.flatMap { Array($0) }
        let used = Set(automatic).union(manual)
        let preferred = ["Frontend", "Backend", "React", "TypeScript"]
        return snapshot.topics.filter { used.contains($0.id) || preferred.contains($0.name) }
            .sorted { a, b in
                let ai = preferred.firstIndex(of: a.name) ?? 999
                let bi = preferred.firstIndex(of: b.name) ?? 999
                return ai == bi ? a.name < b.name : ai < bi
            }
    }

    var dueObjects: [LearningObject] {
        snapshot.studyObjects.filter { object in
            let state = snapshot.reviewStates[object.id] ?? ReviewState(learningObjectID: object.id)
            return [.due, .fading].contains(scheduler.mastery(for: state, at: Date()))
        }.sorted { lhs, rhs in
            (snapshot.reviewStates[lhs.id]?.nextReviewAt ?? .distantFuture) <
            (snapshot.reviewStates[rhs.id]?.nextReviewAt ?? .distantFuture)
        }
    }

    var blindSpotObjects: [LearningObject] {
        let ids = Set(snapshot.attempts.filter { $0.confidence == .certain && $0.wasCorrect == false }
            .map(\.learningObjectID))
        return snapshot.studyObjects.filter { ids.contains($0.id) }
    }

    var currentActivity: StudyActivity? {
        guard let session = activeSession, session.activities.indices.contains(activityIndex) else { return nil }
        return session.activities[activityIndex]
    }

    var currentQuestion: LearningQuestion? {
        guard currentObject != nil, let id = currentActivity?.questionID else { return nil }
        return snapshot.questions.first { $0.id == id }
    }

    var currentObject: LearningObject? {
        guard let id = currentActivity?.learningObjectID else { return nil }
        return snapshot.studyObjects.first { $0.id == id }
    }

    func bootstrap() async {
        guard !isReady else { return }
        do {
            snapshot = try await repository.open()
            if let context = snapshot.resumeStudyContext,
               let sessionID = context.sessionID,
               let session = snapshot.sessions.first(where: { $0.id == sessionID && $0.completedAt == nil }),
               session.activities.indices.contains(context.activityIndex) {
                activeSession = session
                activityIndex = context.activityIndex
                sessionStartedAt = session.createdAt
                restoreActivityState(context)
            }
            isReady = true
            await syncLibrary()
        } catch { errorMessage = error.localizedDescription }
    }

    func syncLibrary() async {
        indexingTask?.cancel()
        indexingTask = Task { [weak self] in
            guard let self else { return }
            let books = library.snapshot.activeBooks
            let pending = books.filter { book in
                guard let analysis = self.snapshot.analyses[book.id] else { return true }
                return analysis.fingerprint != book.fingerprint ||
                    analysis.algorithmVersion != DocumentAnalyzer.algorithmVersion ||
                    analysis.extractionVersion != PDFKitTextExtractor.extractionVersion ||
                    self.snapshot.semanticIndexes[book.id]?.semanticVersion != SemanticCompiler.semanticVersion
            }
            guard !pending.isEmpty else { prepareIntelligence(); return }
            isIndexing = true
            indexingProgress = 0
            defer { isIndexing = false; indexingLabel = nil }
            var noText = 0
            for (offset, book) in pending.enumerated() {
                guard !Task.isCancelled else { return }
                indexingLabel = "Preparing \(book.title) for study"
                let monitor = Task { @MainActor [weak self] in
                    guard let self else { return }
                    while !Task.isCancelled {
                        let documentProgress = await indexer.progressValue()
                        indexingProgress = (Double(offset) + documentProgress) / Double(max(1, pending.count))
                        try? await Task.sleep(for: .milliseconds(90))
                    }
                }
                do {
                    let previousVersion = snapshot.analyses[book.id]?.extractionVersion
                    let previousHistory = snapshot.attempts
                    let previousConfidence = snapshot.confidenceRecords
                    let bundle = try await indexer.index(book: book, url: library.originalURL(book))
                    try await repository.upsertAnalysis(bundle.analysis, topics: bundle.topics, questions: bundle.questions, semanticIndex: bundle.semanticIndex)
                    await indexer.commitCompleted(documentID: book.id)
                    if !bundle.hasUsableText { noText += 1 }
                    snapshot = try await repository.snapshot()
                    if previousVersion != bundle.analysis.extractionVersion {
                        let history = Dictionary(uniqueKeysWithValues: snapshot.attempts.map { ($0.id, $0) })
                        let confidence = Dictionary(uniqueKeysWithValues: snapshot.confidenceRecords.map { ($0.id, $0) })
                        let retained = previousHistory.allSatisfy { history[$0.id] == $0 } && previousConfidence.allSatisfy { confidence[$0.id] == $0 }
                        let trace = "document=\(book.id) fingerprint=\(book.fingerprint) extraction=\(previousVersion ?? 0)->\(bundle.analysis.extractionVersion ?? 0) studyObjects=\(snapshot.studyObjects.filter { $0.source.documentID == book.id }.count) historyRetained=\(retained)"
                        migrationDiagnostics.append(trace)
                        StudyInteractionTrace.record("migration.persisted \(trace)")
                    }
                    if let session = activeSession, session.activities.contains(where: { activity in
                        self.snapshot.learningObjects.contains { $0.id == activity.learningObjectID && $0.sourceIsStale == true }
                    }) {
                        // Keep attempts and the stored session as history. A new
                        // session must use the repaired source, not obsolete cards.
                        endSession()
                        notice = "The source text was rebuilt. Start a new session with the repaired passages; your study history is retained."
                    }
                    StudyInteractionTrace.record("index.persisted document=\(book.id) bank=\(snapshot.questions.filter { $0.source.documentID == book.id }.count) objects=\(snapshot.studyObjects.filter { $0.source.documentID == book.id }.count)")
                } catch is CancellationError {
                    monitor.cancel()
                    return
                } catch {
                    errorMessage = "\(book.title): \(error.localizedDescription)"
                }
                monitor.cancel()
                indexingProgress = Double(offset + 1) / Double(max(1, pending.count))
            }
            if noText > 0 {
                notice = "\(noText) PDF\(noText == 1 ? "" : "s") can still be read, but had too little selectable text for reliable study material."
            }
            prepareIntelligence()
        }
        await indexingTask?.value
    }

    func play(_ event: HapticEvent) { ShelfHaptics.shared.play(event) }
}
