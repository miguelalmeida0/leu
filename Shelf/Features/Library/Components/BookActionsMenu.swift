import SwiftUI
import ShelfCore

@MainActor
struct BookActionsMenu: View {
    let book: Book
    let model: LibraryModel
    @Bindable var knowledge: KnowledgeModel
    @State private var showConnections = false
    var body: some View {
        LeuMenu {
            Button("Open", systemImage: "book") { model.open(book) }
            Button(book.isFavorite ? "Remove favorite" : "Add to favorites", systemImage: book.isFavorite ? "heart.slash" : "heart") {
                Task { await model.favorite(book) }
            }
            Button("Title, cover & collections", systemImage: "pencil") { model.editingBook = book }
            Button("Connections", systemImage: "link") { showConnections = true }
            Divider()
            Button("Move to Trash", systemImage: "trash", role: .destructive) { Task { await model.trash(book) } }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 17, weight: .medium)).frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Actions for " + book.title).accessibilityIdentifier("actions-" + book.title)
        .sheet(isPresented: $showConnections) { BookConnectionsSheet(knowledge: knowledge, book: book) }
    }
}

@MainActor
struct BookListRow: View {
    let book: Book
    let model: LibraryModel
    @Bindable var knowledge: KnowledgeModel
    var body: some View {
        HStack(spacing: 14) {
            Button { model.open(book) } label: {
                HStack(spacing: 14) {
                    CoverIllustration(art: book.artwork, colors: CoverColors(book.palette))
                        .background(CoverColors(book.palette).background)
                        .frame(width: 52, height: 68).clipShape(RoundedRectangle(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title).font(.system(.headline, design: .serif)).foregroundStyle(ShelfTheme.text)
                        Text("\(book.pageCount) pages" + (book.lastOpenedAt != nil ? " · Page \(book.currentPageNumber)" : ""))
                            .font(.subheadline).foregroundStyle(ShelfTheme.secondary)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("book-" + book.title)
            BookActionsMenu(book: book, model: model, knowledge: knowledge)
        }.padding(.vertical, 14).overlay(alignment: .bottom) { Divider().overlay(ShelfTheme.line) }
    }
}
