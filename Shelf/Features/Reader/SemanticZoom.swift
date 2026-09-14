import Foundation

enum SemanticZoomLevel: Int, CaseIterable, Identifiable {
    case sentence
    case page
    case section
    case chapter
    case book

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .sentence: return "Sentence"
        case .page: return "Page"
        case .section: return "Section"
        case .chapter: return "Chapter"
        case .book: return "Book"
        }
    }

    func zoomedOut() -> SemanticZoomLevel {
        switch self {
        case .sentence: return .page
        case .page: return .section
        case .section: return .chapter
        case .chapter, .book: return .book
        }
    }

    func zoomedIn() -> SemanticZoomLevel {
        switch self {
        case .book: return .chapter
        case .chapter: return .section
        case .section: return .page
        case .page, .sentence: return .sentence
        }
    }
}
