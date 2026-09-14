import SwiftUI
import ShelfCore

@MainActor
struct BookConnectionsSheet: View {
    @Bindable var knowledge: KnowledgeModel
    let book: Book

    var body: some View {
        ShelfSheet(title: "Connections") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title).font(.system(.title2, design: .serif))
                        Text("THIS BOOK CONNECTS TO").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
                    }
                    if relatedBooks.isEmpty {
                        Text(knowledge.isIndexing ? "Connecting this book to your library…" : "No strong book-level connections yet.")
                            .foregroundStyle(ShelfTheme.secondary).padding(.vertical, 18)
                    } else {
                        ForEach(relatedBooks, id: \.book.id) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.book.title).font(.headline)
                                Text(item.detail).font(.callout).foregroundStyle(ShelfTheme.secondary)
                            }.padding(.vertical, 10)
                            Divider().overlay(ShelfTheme.line)
                        }
                    }
                }.padding(ShelfTheme.gutter)
            }
        }
    }

    private var relatedBooks: [(book: Book, detail: String)] {
        let strengths = knowledge.documentRelationshipStrengths(from: book.id)
        let passageMap = Dictionary(uniqueKeysWithValues: knowledge.snapshot.passages.map { ($0.id, $0) })
        return strengths.sorted { $0.value > $1.value }.prefix(12).compactMap { documentID, _ in
            guard let target = knowledge.library.snapshot.activeBooks.first(where: { $0.id == documentID }) else { return nil }
            let manual = knowledge.snapshot.confirmedConnections.filter { connection in
                guard let a = passageMap[connection.sourcePassageID], let b = passageMap[connection.destinationPassageID] else { return false }
                return Set([a.documentID, b.documentID]) == Set([book.id, documentID])
            }.count
            let related = knowledge.snapshot.indexRecords.filter { $0.documentID == documentID }.count
            let detail = manual > 0 ? "\(manual) confirmed link\(manual == 1 ? "" : "s") · related passages available" : "Related passages available"
            return (target, detail + (related == 0 ? "" : ""))
        }
    }
}
