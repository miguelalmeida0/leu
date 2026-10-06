import Foundation
import ShelfCore

/// The ways to spend a few minutes of study, in a reader's words. Each maps to a real
/// session the app already runs; nothing here invents a mode.
enum StudyWay: String, CaseIterable, Identifiable {
    case learn, recall, interview, explain

    var id: String { rawValue }

    /// The words that sit in the sentence: "I'd like to …".
    var phrase: String {
        switch self {
        case .learn: "ask me a few things"
        case .recall: "test my memory"
        case .interview: "talk it through"
        case .explain: "explain it my way"
        }
    }

    var detail: String {
        switch self {
        case .learn: "gentle questions, a wrong answer shows the page"
        case .recall: "bring it back first, then check the page"
        case .interview: "open questions, the way an interviewer asks"
        case .explain: "your own words, every idea lights a window in the snow globe"
        }
    }

    /// Whether the session is shaped by a time budget.
    var usesMinutes: Bool { self == .learn || self == .interview }

    /// Interview length follows the time chosen: about two minutes a question.
    static func interviewQuestions(minutes: Int) -> Int { min(max(minutes / 2, 3), 12) }
}

/// A passage the reader has been near recently, ready to explain in their own words.
struct StudyPassage: Identifiable {
    let source: IntelligenceSource
    let bookTitle: String
    let bit: String
    var id: String { source.id }
    var page: Int { source.packet.pageIndex + 1 }
    var ideaCount: Int { source.claims.count }

    /// Recent passages first (from the timeline), then what study material came from,
    /// one per page, each one verified against its analysis and holding checkable ideas.
    @MainActor
    static func recent(in model: LearningModel, limit: Int = 5) -> [StudyPassage] {
        let snapshot = model.snapshot
        let timeline = snapshot.timeline.sorted { $0.occurredAt > $1.occurredAt }.compactMap(\.source)
        let material = snapshot.studyObjects.sorted { $0.createdAt > $1.createdAt }.map(\.source)
        var seen = Set<String>(), found: [StudyPassage] = []
        for source in timeline + material where found.count < limit {
            let key = "\(source.documentID)|\(source.pageIndex)"
            guard !seen.contains(key), let analysis = snapshot.analyses[source.documentID],
                  let verified = IntelligenceSource(source: source, analysis: analysis), !verified.claims.isEmpty else { continue }
            seen.insert(key)
            let title = model.library.snapshot.activeBooks.first { $0.id == source.documentID }?.title ?? "your book"
            found.append(StudyPassage(source: verified, bookTitle: title, bit: bit(for: source)))
        }
        return found
    }

    /// What the passage is about: its section heading, or the opening of the passage.
    static func bit(for source: LearningSource) -> String {
        if let heading = source.sectionTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !heading.isEmpty {
            return heading
        }
        let words = source.sourceText.split(whereSeparator: \.isWhitespace).prefix(7).joined(separator: " ")
        return words.isEmpty ? "page \(source.pageIndex + 1)" : words + "…"
    }
}
