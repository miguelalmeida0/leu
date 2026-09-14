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
    var connections: [GroundedConnection] = []
    let activity: ActivityDefinition?
    var inferring = false
    var message: String?
    var readerRoute: IntelligenceReaderRoute?
    @ObservationIgnored private var request: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSave: UnderstandingAttempt?
    @ObservationIgnored private var revision = UUID()

    init(learning: LearningModel, source: IntelligenceSource, attempt: UnderstandingAttempt? = nil) {
        self.learning = learning; self.source = source
        self.attempt = attempt ?? UnderstandingAttempt(source: source)
        // A selected paragraph may name an activity whose complete rule spans
        // several paragraphs on this same verified page. Show that full citation.
        let pageSource = learning.snapshot.analyses[source.packet.documentID].flatMap {
            IntelligenceSource(source: LearningSource(documentID: source.packet.documentID,
                pageIndex: source.packet.pageIndex, sourceText: source.packet.sourceText,
                sectionTitle: source.packet.sectionTitle), analysis: $0)
        }
        activity = (pageSource ?? source).claims.isEmpty ? nil : ActivityValidator.definition(for: pageSource ?? source)
    }
    var canTeach: Bool { !source.claims.isEmpty }
    var sourceLabel: String {
        (learning.library.snapshot.activeBooks.first { $0.id == source.packet.documentID }?.title ?? "Source") + " · p. \(source.packet.pageIndex + 1)"
    }
    func retrieve() async {
        let analyses = learning.snapshot.analyses
        let version = analyses.values.map { "\($0.documentID)|\($0.fingerprint)|\($0.extractionVersion ?? 0)" }.sorted().joined()
        if learning.connectionIndexVersion != version {
            let index = await Task.detached(priority: .userInitiated) { GroundedConnectionIndex(analyses: analyses) }.value
            guard !Task.isCancelled else { return }
            learning.connectionIndex = index; learning.connectionIndexVersion = version
        }
        guard !Task.isCancelled, source.isCurrent(in: learning.snapshot.analyses) else { return }
        let index = learning.connectionIndex
        let source = source
        let found = await Task.detached(priority: .userInitiated) { index?.connections(from: source) ?? [] }.value
        guard !Task.isCancelled else { return }
        connections = found
    }
    func edit(_ text: String) {
        request?.cancel(); request = nil; inferring = false; revision = UUID()
        attempt.learnerExplanation = String(text.prefix(6000)); attempt.result = nil; attempt.resolved = false
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
        guard request == nil, canTeach, !attempt.learnerExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if attempt.result != nil { return }
        let token = UUID(); revision = token
        let text = attempt.learnerExplanation, source = source
        request = Task { [weak self] in
            guard let self else { return }
            defer { if revision == token { request = nil; inferring = false } }
            let availability = await learning.intelligenceProvider.availability()
            learning.intelligenceCapability = IntelligenceCapabilityReport(availability: availability)
            if availability != .available { message = IntelligenceCapabilityReport.fallbackMessage }
            var pairs: [ClaimAlignment] = [], backend = "local source comparison"
            if availability == .available {
                guard !Task.isCancelled else { return }
                inferring = true
                do {
                    pairs = try await learning.intelligenceProvider.proposeAlignments(explanation: text, source: source)
                    learning.intelligenceCapability = IntelligenceCapabilityReport(availability: .available, generationVerified: true)
                    backend = "apple-on-device + verified source comparison"
                } catch is CancellationError { return }
                catch {
                    learning.intelligenceCapability = IntelligenceCapabilityReport(availability: availability, error: error)
                    message = IntelligenceCapabilityReport.fallbackMessage
                }
            }
            guard !Task.isCancelled, revision == token, source.isCurrent(in: learning.snapshot.analyses) else { return }
            attempt.result = TeachLeuValidator.evaluate(text, source: source, proposals: pairs, backend: backend)
            persistDraft()
            await record(.taughtConcept)
        }
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
