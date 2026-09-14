import SwiftUI
import ShelfCore

@MainActor
struct TrashSheet: View {
    let model: LibraryModel
    @State private var deleting: Book?
    var body: some View {
        ShelfSheet(title: "Trash") {
            List {
                Section {
                    if let error = model.errorMessage {
                        Text(error).foregroundStyle(ShelfTheme.danger)
                        Button("Dismiss error") { model.errorMessage = nil }
                    }
                    if model.trashedBooks.isEmpty { Text("Nothing in Trash.").foregroundStyle(ShelfTheme.secondary) }
                    ForEach(model.trashedBooks) { book in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(book.title).font(.system(.headline, design: .serif))
                            HStack {
                                Button("Restore") { Task { await model.restore(book) } }.buttonStyle(.borderless)
                                Spacer()
                                Button("Delete permanently", role: .destructive) { deleting = book }.buttonStyle(.borderless)
                            }
                        }.padding(.vertical, 8)
                    }
                } footer: { Text("Trash is never emptied automatically. Restore a document with its notes and reading position intact.") }
            }.leuDialog("Permanently delete this PDF and its notes?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible, presenting: deleting) { book in
                    Button("Delete permanently", role: .destructive) {
                        Task { await model.permanentlyDelete(book) }
                    }
                } message: { _ in
                    Text("This cannot be undone. An exported backup is the only recovery option.")
                }
        }
    }
}
