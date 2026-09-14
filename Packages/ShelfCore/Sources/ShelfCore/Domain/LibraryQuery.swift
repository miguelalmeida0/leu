import Foundation

public enum LibrarySection: String, CaseIterable, Sendable {
    case library, favorites, recents, review
}

public enum LibrarySort: String, CaseIterable, Sendable {
    case added, title, opened
    public var title: String {
        switch self { case .added: return "Recently added"
        case .title: return "Title"; case .opened: return "Last opened" }
    }
}

public struct LibraryQuery: Sendable {
    public var section: LibrarySection
    public var text: String
    public var collectionID: UUID?
    public var tag: String?
    public var sort: LibrarySort
    public init(section: LibrarySection = .library, text: String = "",
                collectionID: UUID? = nil, tag: String? = nil, sort: LibrarySort = .added) {
        self.section = section; self.text = text; self.collectionID = collectionID
        self.tag = tag; self.sort = sort
    }
    public func apply(to snapshot: LibrarySnapshot) -> [Book] {
        let needle = text.normalizedSearch
        let marked = Set(snapshot.annotations.filter { $0.kind.isStudyMarker }.map(\.bookID))
        let matchingNotes: Set<UUID> = needle.isEmpty ? [] : Set(snapshot.annotations.compactMap { annotation in
            let content = annotation.quote + " " + annotation.note
            return content.normalizedSearch.contains(needle) ? annotation.bookID : nil
        })
        let filtered = snapshot.activeBooks.filter { book in
            if section == .favorites && !book.isFavorite { return false }
            if section == .recents && book.lastOpenedAt == nil { return false }
            if section == .review && !marked.contains(book.id) { return false }
            if let collectionID, !book.collectionIDs.contains(collectionID) { return false }
            if let tag, !book.tags.contains(tag) { return false }
            let haystack = ([book.title, book.originalFilename] + book.tags).joined(separator: " ")
            return needle.isEmpty || haystack.normalizedSearch.contains(needle) || matchingNotes.contains(book.id)
        }
        return filtered.sorted { left, right in
            switch section == .recents ? .opened : sort {
            case .title:
                let result = left.title.localizedStandardCompare(right.title)
                return result == .orderedSame ? left.id.uuidString < right.id.uuidString : result == .orderedAscending
            case .added:
                return left.importedAt == right.importedAt
                    ? left.id.uuidString < right.id.uuidString : left.importedAt > right.importedAt
            case .opened:
                let a = left.lastOpenedAt ?? .distantPast, b = right.lastOpenedAt ?? .distantPast
                return a == b ? left.importedAt > right.importedAt : a > b
            }
        }
    }
}

public extension String {
    var normalizedSearch: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
