import Foundation
import CoreGraphics
import ShelfCore

@MainActor
extension LearningModel {
    func openSource(_ source: LearningSource) {
        guard let book = library.snapshot.activeBooks.first(where: { $0.id == source.documentID }) else {
            errorMessage = "The source PDF is no longer in the active library."
            return
        }
        library.open(book, page: source.pageIndex, sourceText: source.sourceText)
        play(.sourceRevealed)
    }

    func mastery(topic: LearningTopic) -> TopicLearningState {
        topicAggregator.state(topicID: topic.id, snapshot: snapshot)
    }

    func capture(type: LearningObjectType, source: LearningSource, promptOverride: String? = nil) async throws -> LearningObject {
        let automatic = Set(snapshot.analyses[source.documentID]?.topicScores
            .filter { $0.value >= 0.18 }.map(\.key) ?? [])
        let topicIDs = snapshot.manualDocumentTopics[source.documentID] ?? automatic
        let rawTitle = source.sectionTitle ?? source.sourceText
        let title = String(rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).prefix(72))
        let cleanOverride = promptOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt: String? = {
            if let cleanOverride, !cleanOverride.isEmpty { return String(cleanOverride.prefix(500)) }
            return type == .recall ? suggestedRecallPrompt(for: source) : nil
        }()
        let object = try await repository.capture(type: type, source: source,
                                                  title: title.isEmpty ? "Learning item" : title,
                                                  prompt: prompt, topicIDs: topicIDs,
                                                  importance: 0.68, origin: .userSelection)
        snapshot = try await repository.snapshot()
        return object
    }


    func suggestedRecallPrompt(for source: LearningSource) -> String {
        let raw = source.sectionTitle ?? source.sourceText
        let title = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(72))
        return title.isEmpty ? "What do you remember from this source?" : "What do you remember about \(title)?"
    }

    func bestQuestion(for source: LearningSource) -> LearningQuestion? {
        let samePage = snapshot.questions.filter { question in
            question.source.documentID == source.documentID && question.source.pageIndex == source.pageIndex
        }
        let overlapping = samePage.filter { question in
            let answerMatches = question.correctOption.map { option in
                !option.text.isEmpty && source.sourceText.localizedCaseInsensitiveContains(option.text)
            } ?? false
            let sourcePrefix = String(source.sourceText.prefix(96)).trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceMatches = !sourcePrefix.isEmpty && question.source.sourceText.localizedCaseInsensitiveContains(sourcePrefix)
            return answerMatches || sourceMatches
        }
        return ConceptImportanceModel().ranked(overlapping.isEmpty ? samePage : overlapping,
            snapshot: snapshot, annotations: library.snapshot.annotations).first
    }

    func saveMask(object: LearningObject, normalizedRegions: [CGRect], label: String) async throws {
        let regions = normalizedRegions.map { rect in
            SourceBounds(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        }
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        try await repository.saveMask(DiagramMask(learningObjectID: object.id, source: object.source,
                                                  regions: regions,
                                                  label: cleanLabel.isEmpty ? nil : cleanLabel))
        snapshot = try await repository.snapshot()
        play(.objectCaptured)
    }

    func newRecordingURL() -> URL {
        recordingsDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
    }

    func recordingURL(filename: String) -> URL {
        recordingsDirectory.appendingPathComponent(filename)
    }

    func saveRecording(object: LearningObject, url: URL, duration: TimeInterval,
                       rating: ExplanationRecording.SelfRating?) async throws {
        let recording = ExplanationRecording(learningObjectID: object.id, filename: url.lastPathComponent,
                                             duration: duration, selfRating: rating)
        try await repository.saveRecording(recording)
        snapshot = try await repository.snapshot()
    }

    func setManualTopics(documentID: UUID, topicIDs: Set<UUID>) async {
        do {
            try await repository.setManualTopics(documentID: documentID, topicIDs: topicIDs)
            snapshot = try await repository.snapshot()
        } catch { errorMessage = error.localizedDescription }
    }

    func addTopic(name: String) async -> LearningTopic? {
        do {
            let topic = try await repository.addTopic(name: name)
            snapshot = try await repository.snapshot()
            return topic
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func createTrail(title: String) async {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        do {
            _ = try await repository.saveTrail(LearningTrail(title: clean))
            snapshot = try await repository.snapshot()
        } catch { errorMessage = error.localizedDescription }
    }
}
