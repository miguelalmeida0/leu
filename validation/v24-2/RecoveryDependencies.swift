import Foundation
import Observation
import ShelfCore

// Only platform adapters are substituted. The compiled LearningModel, its session
// commands, recovery extension, repository, checkpoint schema and disk store are real.
@MainActor @Observable final class LibraryModel {
    var snapshot = LibrarySnapshot()
    func originalURL(_ book: Book) -> URL { URL(fileURLWithPath: "/unused-in-this-harness") }
}
struct LearningIndexBundle: Sendable {
    let analysis: DocumentAnalysis
    let topics: [TopicClassification]
    let questions: [LearningQuestion]
    let semanticIndex: SemanticIndex
    let hasUsableText: Bool
}
actor PDFLearningIndexer {
    func progressValue() -> Double { 0 }
    func commitCompleted(documentID: UUID) {}
    func index(book: Book, url: URL) throws -> LearningIndexBundle { throw CancellationError() }
}
@MainActor final class ShelfHaptics {
    static let shared = ShelfHaptics()
    func play(_ event: HapticEvent) {}
}
enum StudyInteractionTrace {
    static func record(_ message: String) {}
}

enum HapticEvent: String, CaseIterable {
    case selectionChanged, controlPressed, objectCaptured, objectConnected, snapToTarget
    case answerCommitted, answerCorrect, answerIncorrect, sourceRevealed, memoryStrengthened
    case studySessionStarted, studySessionCompleted, recordingStarted, recordingStopped
    case destructiveWarning, connectionRemoved, pageTurn, chapterBoundary, mark, bookFinished
}
