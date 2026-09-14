import Foundation

/// Capability boundaries keep the presentation layer independent from a
/// particular deterministic implementation. Future implementations can change
/// without changing the persistent domain model or UI contracts.
public protocol DocumentAnalyzing: Sendable {
    func analyze(documentID: UUID, fingerprint: String, pages: [SourcePageInput]) -> DocumentAnalysis
}

public protocol TopicClassifying: Sendable {
    func classify(title: String, filename: String, outline: [String], texts: [String]) -> [TopicClassification]
}

public protocol QuestionGenerating: Sendable {
    func generate(from analysis: DocumentAnalysis, topicIDs: Set<UUID>) -> [LearningQuestion]
}

extension DocumentAnalyzer: DocumentAnalyzing {}
extension TopicClassifier: TopicClassifying {}
extension DeterministicQuestionEngine: QuestionGenerating {}
