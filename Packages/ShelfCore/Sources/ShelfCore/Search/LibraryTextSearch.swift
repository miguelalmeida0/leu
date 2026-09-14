import Foundation

public struct PassageMatch: Identifiable, Equatable, Sendable {
    public var id: String { "\(bookID.uuidString)-\(pageIndex)-\(location)" }
    public let bookID: UUID
    public let pageIndex: Int
    public let excerpt: String
    public let location: Int
    public let length: Int
    public init(bookID: UUID, pageIndex: Int, excerpt: String, location: Int, length: Int) {
        self.bookID = bookID; self.pageIndex = pageIndex; self.excerpt = excerpt
        self.location = location; self.length = length
    }
}

/// Serialized disk search with bounded output. Cancellation is checked between pages.
public actor LibraryTextSearch {
    private let indexes: any TextIndexPersistence
    public init(indexes: any TextIndexPersistence) { self.indexes = indexes }

    public func search(_ query: String, books: [Book], limit: Int = 60) throws -> [PassageMatch] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2, limit > 0 else { return [] }
        var results: [PassageMatch] = []
        for book in books {
            try Task.checkCancellation()
            guard let index = try? indexes.read(id: book.id) else { continue }
            for page in index.pages {
                try Task.checkCancellation()
                let source = page.text as NSString
                let range = source.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive])
                guard range.location != NSNotFound else { continue }
                let start = max(0, range.location - 60)
                let end = min(source.length, range.location + range.length + 120)
                let excerpt = source.substring(with: NSRange(location: start, length: end - start))
                    .replacingOccurrences(of: "\n", with: " ")
                results.append(PassageMatch(bookID: book.id, pageIndex: page.pageIndex,
                                            excerpt: excerpt, location: range.location, length: range.length))
                if results.count >= limit { return results }
            }
        }
        return results
    }
}
