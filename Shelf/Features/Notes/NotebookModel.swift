import Foundation
import ShelfCore

/// One thing kept in the notebook: a note you wrote, or a passage you marked.
struct NotebookEntry: Identifiable, Equatable {
    let annotation: StudyAnnotation
    let bookTitle: String
    var id: UUID { annotation.id }
    /// What you wrote, or the passage itself when you only marked it.
    var text: String {
        let note = annotation.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return note.isEmpty ? "“\(annotation.quote.trimmingCharacters(in: .whitespacesAndNewlines))”" : note
    }
    var isQuote: Bool { annotation.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var place: String { "\(bookTitle), page \(annotation.pageIndex + 1)" }
}

/// Builds the notebook from every mark in the library. Pure, so it is tested directly.
enum NotebookModel {
    /// Everything with words in it, newest first, optionally from one book.
    static func entries(annotations: [StudyAnnotation], books: [Book], bookID: UUID? = nil) -> [NotebookEntry] {
        let titles = Dictionary(books.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        return annotations
            .filter { titles[$0.bookID] != nil && (bookID == nil || $0.bookID == bookID) }
            .filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !$0.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.createdAt > $1.createdAt }
            .map { NotebookEntry(annotation: $0, bookTitle: titles[$0.bookID] ?? "A book") }
    }

    /// The left page holds this week; the right page holds everything earlier.
    static func split(_ entries: [NotebookEntry], now: Date = Date(), calendar: Calendar = .current)
        -> (thisWeek: [NotebookEntry], earlier: [NotebookEntry]) {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return (entries.filter { $0.annotation.createdAt >= cutoff }, entries.filter { $0.annotation.createdAt < cutoff })
    }

    /// "Five things worth keeping." Small counts in words, large ones in figures.
    static func headline(count: Int) -> String {
        let words = ["Nothing", "One thing", "Two things", "Three things", "Four things", "Five things",
                     "Six things", "Seven things", "Eight things", "Nine things", "Ten things"]
        let lead = count < words.count ? words[count] : "\(count) things"
        return count == 0 ? "Nothing kept yet." : "\(lead) worth keeping."
    }

    /// Books that have at least one entry, in the order they were last written in.
    static func books(in entries: [NotebookEntry], from books: [Book]) -> [Book] {
        var seen = Set<UUID>(), ordered: [Book] = []
        for entry in entries where !seen.contains(entry.annotation.bookID) {
            seen.insert(entry.annotation.bookID)
            if let book = books.first(where: { $0.id == entry.annotation.bookID }) { ordered.append(book) }
        }
        return ordered
    }
}
