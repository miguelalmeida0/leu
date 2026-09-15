import Foundation
import Observation
import ShelfCore
import LeuReasoningCore
import LeuQwenRuntime
import os

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
    var offlineFeedback: LocalExplanationAssessment?
    var assessmentProvider: String?
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
        attempt.learnerExplanation = text; feedback = nil; offlineFeedback = nil; assessmentProvider = nil
        attempt.result = nil; attempt.resolved = false
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
        if OfflineModelStore.shared.enabled { assessOffline(); return }
        guard attempt.learnerExplanation.count <= 6000 else {
            message = "This explanation is too long for existing Teach Leu. Your text has not been shortened; shorten it to compare."; return
        }
        guard request == nil, canTeach, let adapter = teachAdapter, !attempt.learnerExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let token = UUID(); revision = token; inferring = true; message = nil
        let text = attempt.learnerExplanation, analyses = learning.snapshot.analyses
        request = Task { [weak self] in
            guard let self else { return }
            defer { if revision == token { request = nil; inferring = false } }
            let result = await Task.detached(priority: .userInitiated) {
                adapter.compare(text, analyses: analyses)
            }.value
            guard !Task.isCancelled, revision == token, source.isCurrent(in: learning.snapshot.analyses) else { return }
            feedback = result
            offlineFeedback = nil; assessmentProvider = "Existing Teach Leu"
            persistDraft()
            // Drafts are retained verbatim. An unsupported or mixed response
            // is not recorded as a taught concept or a learned source claim.
            if result.fullySupported { await record(.taughtConcept) }
        }
    }
    private func assessOffline() {
        guard request == nil, source.isCurrent(in: learning.snapshot.analyses) else { return }
        guard EmbeddedQwen.available, OfflineModelStore.shared.installed, !OfflineModelStore.shared.busy else {
            message = "Offline model is unavailable. Turn it off to use existing Teach Leu."; return
        }
        // Coexistence is unmeasured. Defer Qwen whenever neural voice resources
        // are available; do not evict voice sessions or interrupt playback.
        guard SupertonicAssets.resourceURLs() == nil else {
            message = "Offline comparison is deferred while neural voice resources are available. Turn Offline model off to use existing Teach Leu."; return
        }
        guard ProcessInfo.processInfo.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue else {
            message = "This device needs to cool before an offline comparison. Your draft is kept."; return
        }
        let available = os_proc_available_memory()
        // Provisional guard, not a certified device ceiling. Actual footprint
        // is sampled by native code; physical-device acceptance remains required.
        guard available > 3_000_000_000 else {
            message = "There is not enough available memory for this offline model. Your draft is kept."; return
        }
        let token = UUID(); revision = token; inferring = true; feedback = nil; offlineFeedback = nil
        assessmentProvider = nil; message = nil
        let input = LocalExplanationInput(learner: attempt.learnerExplanation, question: nil, passages: [
            .init(id: "s1", document: source.packet.documentID.uuidString,
                page: source.packet.pageIndex + 1, version: source.packet.cacheKey,
                title: source.passage.sectionTitle ?? sourceLabel, text: source.passage.sourceText)
        ])
        // This uses the full current selected passage even when no bounded atom
        // extractor represents its sentences. No re-extraction or PDF request.
        request = Task { [weak self] in
            guard let self else { return }
            defer { if revision == token { request = nil; inferring = false } }
            do {
                try await OfflineModelStore.verify(OfflineModelStore.modelURL)
                let result = try await LocalQwenProvider().assess(input, model: OfflineModelStore.modelURL,
                    maximumFootprint: 3_000_000_000)
                guard !Task.isCancelled, revision == token, source.isCurrent(in: learning.snapshot.analyses) else { return }
                offlineFeedback = result.assessment; assessmentProvider = "Offline model · Qwen 2B · model-assessed"
                persistDraft() // No taughtConcept event or authoritative claim.
            } catch {
                guard revision == token, !Task.isCancelled else { return }
                assessmentProvider = "Offline model did not complete"
                if let failure = error as? QwenRuntimeError, case .inputTooLong = failure {
                    message = "This passage and explanation exceed the offline context budget. Shorten the explanation or choose a smaller passage. No text was truncated."
                } else {
                    message = "The offline comparison could not be established. Your draft and source are kept. Turn Offline model off to use existing Teach Leu."
                }
            }
        }
    }
    func dismissOfflineFeedback() { offlineFeedback = nil; assessmentProvider = nil }
    func changeAssessmentProvider() {
        cancel(); feedback = nil; offlineFeedback = nil; assessmentProvider = nil; message = nil
    }
    func checkOfflineResources() {
        guard inferring, OfflineModelStore.shared.enabled else { return }
        if ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue || os_proc_available_memory() < 300_000_000 || SupertonicAssets.resourceURLs() != nil {
            cancel(); message = "Offline comparison stopped to preserve device resources. Your draft is kept."
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
    func viewSource(_ citation: IntelligenceSource? = nil, exactQuote: String? = nil, returningTo title: String) {
        if inferring, OfflineModelStore.shared.enabled { cancel() }
        let citation = citation ?? source
        guard citation.isCurrent(in: learning.snapshot.analyses) else { message = "This source changed. Reopen the passage to compare it again."; return }
        let passage: LearningSource
        if let exactQuote {
            guard let bound = citation.exactExcerpt(exactQuote, in: learning.snapshot.analyses) else {
                message = "This excerpt no longer matches the selected passage. Reopen the source to continue."; return
            }
            passage = bound
        } else { passage = citation.passage }
        readerRoute = learning.makeIntelligenceReader?(passage, "Back to " + title, exactQuote == nil ? nil : passage.range)
        Task { await record(.returnedToSource, citation: citation) }
    }
}
