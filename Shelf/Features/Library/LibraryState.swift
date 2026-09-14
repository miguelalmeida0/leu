import Foundation
import ShelfCore

enum ShelfTab: String, CaseIterable, Identifiable {
    case library, favorites, recents, tags, settings
    var id: Self { self }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .library: return "books.vertical"
        case .favorites: return "heart"
        case .recents: return "clock"
        case .tags: return "tag"
        case .settings: return "slider.horizontal.3"
        }
    }
    var section: LibrarySection {
        switch self {
        case .favorites: return .favorites; case .recents: return .recents; default: return .library
        }
    }
}

enum LibraryPhase: Equatable {
    case loading, ready, failed(String)
}

struct ReaderRoute: Identifiable {
    let id = UUID()
    let book: Book
    var pageIndex: Int? = nil
    var sourceText: String? = nil
    var knowledgeTravel: Bool = false
    var restoreLens: LearningSource? = nil
    var sourceReturnLabel: String? = nil
}

struct BookDetailsDraft {
    var title: String
    var tags: String
    var collectionIDs: Set<UUID>
    var palette: CoverPalette
    var artwork: CoverArt
    init(book: Book) {
        title = book.title; tags = book.tags.joined(separator: ", ")
        collectionIDs = book.collectionIDs; palette = book.palette; artwork = book.artwork
    }
}
