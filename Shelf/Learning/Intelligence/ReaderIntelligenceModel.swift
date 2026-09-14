import Foundation
import Observation
import ShelfCore

struct IntelligenceReaderRoute: Identifiable {
    let id = UUID()
    let reader: ReaderModel
    let thumbnails: PDFThumbnailService
}

@MainActor @Observable
final class ReaderIntelligenceModel {
    let learning: LearningModel
    let source: IntelligenceSource
    var attempt: UnderstandingAttempt
    var connections: [GroundedConnectionV2] = []
    var semanticSources: [RelationalSourceFact] = []
    var feedback: ReasonedTeachFeedback?
    var libraryExplanations: [LibraryExplanationItem] = []
    var canTeach = false
    var activity: ActivityDefinition?
    var inferring = false
    var retrieving = false
    var message: String?
    var readerRoute: IntelligenceReaderRoute?
    @ObservationIgnored private var request: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSave: UnderstandingAttempt?
    @ObservationIgnored private var revision = UUID()
    @ObservationIgnored private var teachAdapter: TeachReasoningAdapter?

    init(learning: LearningModel, source: IntelligenceSource, attempt: UnderstandingAttempt? = nil) {
        self.learning = learning; self.source = source
        self.attempt = attempt ?? UnderstandingAttempt(source: source)
    }
    var sourceLabel: String {
        (learning.library.snapshot.activeBooks.first { $0.id == source.packet.documentID }?.title ?? "Source") + " · p. \(source.packet.pageIndex + 1)"
    }
    func retrieve() async {
        retrieving = true
        defer { retrieving = false }
        let ids = Set(learning.library.snapshot.activeBooks.map(\.id))
        let analyses = learning.snapshot.analyses.filter { ids.contains($0.key) }
        let titles = Dictionary(uniqueKeysWithValues: learning.library.snapshot.activeBooks.map { ($0.id, $0.title) })
        do {
            let cache = learning.libraryIntelligenceCache
            let anchors = try await cache.sources(for: source, analyses: analyses, titles: titles)
            guard !Task.isCancelled, source.isCurrent(in: learning.snapshot.analyses) else { return }
            semanticSources = anchors
            let adapter = await Task.detached(priority: .userInitiated) {
                TeachReasoningAdapter(sources: anchors, analyses: analyses)
            }.value
            guard !Task.isCancelled, source.isCurrent(in: learning.snapshot.analyses) else { return }
            teachAdapter = adapter; self.canTeach = adapter.canTeach
            let found = try await cache.retrieve(source: source, analyses: analyses, titles: titles)
            guard !Task.isCancelled, source.isCurrent(in: learning.snapshot.analyses),
                  Set(learning.library.snapshot.activeBooks.map(\.id)) == ids else { return }
            connections = found.connections; semanticSources = found.sources
            libraryExplanations = found.explanations; activity = found.activity
        } catch { message = "These source tools are temporarily unavailable." }
    }
    func edit(_ text: String) {
        request?.cancel(); request = nil; inferring = false; revision = UUID()
        attempt.learnerExplanation = String(text.prefix(6000)); feedback = nil; attempt.result = nil; attempt.resolved = false
        persistDraft()
    }
    func persistDraft() {
        pendingSave = attempt
        guard saveTask == nil else { return }
        let repository = learning.repository
        saveTask = Task { [weak self] in
            guard let self else { return }
            defer { saveTask = nil }
            while let latest = pendingSave {
                pendingSave = nil
                do {
                    try await repository.storeUnderstandingAttempt(latest)
                    learning.snapshot = try await repository.snapshot()
                } catch { message = "This thought could not be saved. Your text is still here." }
            }
        }
    }
    func assess() {
        guard request == nil, canTeach, let adapter = teachAdapter, !attempt.learnerExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let token = UUID(); revision = token; inferring = true
        let text = attempt.learnerExplanation, analyses = learning.snapshot.analyses
        request = Task { [weak self] in
            guard let self else { return }
            defer { if revision == token { request = nil; inferring = false } }
            let result = await Task.detached(priority: .userInitiated) {
                adapter.compare(text, analyses: analyses)
            }.value
            guard !Task.isCancelled, revision == token, source.isCurrent(in: learning.snapshot.analyses) else { return }
            feedback = result
            persistDraft()
            // Drafts are retained verbatim. An unsupported or mixed response
            // is not recorded as a taught concept or a learned source claim.
            if result.fullySupported { await record(.taughtConcept) }
        }
    }
    func viewFact(_ fact: RelationalSourceFact, returningTo title: String) {
        guard let citation = fact.citation(in: learning.snapshot.analyses) else { message = "This source changed. Reopen it to continue."; return }
        viewSource(citation, returningTo: title)
    }
    func viewLibraryItem(_ item: LibraryExplanationItem) {
        guard item.isCurrent(in: learning.snapshot.analyses), let analysis = learning.snapshot.analyses[item.passage.documentID],
              let citation = IntelligenceSource(source: item.passage, analysis: analysis) else { message = "This source changed. Reopen it to continue."; return }
        viewSource(citation, returningTo: "Explain from my library")
    }
    func cancel() { revision = UUID(); request?.cancel(); request = nil; inferring = false }
    func resolve() { attempt.resolved = true; persistDraft() }
    func record(_ kind: UnderstandingEvent.Kind, citation: IntelligenceSource? = nil) async {
        do {
            try await learning.repository.storeUnderstandingEvent(.init(kind: kind, source: citation ?? source))
            learning.snapshot = try await learning.repository.snapshot()
        } catch { message = "The learning event could not be saved." }
    }
    func viewSource(_ citation: IntelligenceSource? = nil, returningTo title: String) {
        let citation = citation ?? source
        guard citation.isCurrent(in: learning.snapshot.analyses) else { message = "This source changed. Reopen the passage to compare it again."; return }
        readerRoute = learning.makeIntelligenceReader?(citation.passage, "Back to " + title)
        Task { await record(.returnedToSource, citation: citation) }
    }
}
