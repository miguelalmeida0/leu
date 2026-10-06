import SwiftUI
import ShelfCore

@MainActor
struct PassageResultsView: View {
    let model: LibraryModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.isSearching {
                HStack { ProgressView(); Text("Searching inside your PDFs…").font(.leu(.callout)) }
            } else if !model.passages.isEmpty {
                Text("Inside your PDFs").font(.leu(.title3, serif: true))
                ForEach(model.passages) { match in
                    if let book = model.snapshot.books.first(where: { $0.id == match.bookID }) {
                        Button { model.open(book, page: match.pageIndex) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(book.title).font(.leu(.headline)).lineLimit(1)
                                    Spacer(); Text("p. \(match.pageIndex + 1)").font(.leu(.caption)).foregroundStyle(ShelfTheme.accent)
                                }
                                Text(match.excerpt).font(.leu(.callout)).lineLimit(3).foregroundStyle(ShelfTheme.secondary)
                            }.foregroundStyle(ShelfTheme.text).padding(.vertical, 12)
                                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Divider().overlay(ShelfTheme.line)
                    }
                }
                if model.passages.count == 60 { Text("Showing the first 60 matching pages. Refine your search for more.").font(.leu(.footnote)) }
            } else if model.filteredBooks.isEmpty {
                EmptyLibraryState(symbol: "magnifyingglass", title: "No matches yet.",
                    message: "Try a title, tag or phrase. Scanned pages need selectable text to be searched.")
            }
            if model.isIndexing {
                Text("Some documents are still being indexed. Reading is available now.")
                    .font(.leu(.footnote)).foregroundStyle(ShelfTheme.secondary)
            }
        }
    }
}
