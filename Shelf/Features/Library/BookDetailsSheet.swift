import SwiftUI
import ShelfCore

@MainActor
struct BookDetailsSheet: View {
    let book: Book
    let model: LibraryModel
    @State private var draft: BookDetailsDraft
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss
    init(book: Book, model: LibraryModel) {
        self.book = book; self.model = model; _draft = State(initialValue: BookDetailsDraft(book: book))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") { LeuTextField("Document title", text: $draft.title).accessibilityIdentifier("book-title-input") }
                Section("Collections") {
                    ForEach(model.collections) { collection in
                        Toggle(collection.name, isOn: Binding(
                            get: { draft.collectionIDs.contains(collection.id) },
                            set: { on in if on { draft.collectionIDs.insert(collection.id) } else { draft.collectionIDs.remove(collection.id) } }))
                    }
                    if model.collections.isEmpty { Text("Create a collection from the Library screen.").foregroundStyle(ShelfTheme.secondary) }
                }
                Section { LeuTextField("react, frontend, interview", text: $draft.tags).autocorrectionDisabled() }
                    header: { Text("Tags") } footer: { Text("Separate tags with commas. A document can belong to several collections without being copied.") }
                Section("Cover") {
                    Picker("Palette", selection: $draft.palette) {
                        ForEach(CoverPalette.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Picker("Artwork", selection: $draft.artwork) {
                        ForEach(CoverArt.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    CoverIllustration(art: draft.artwork, colors: CoverColors(draft.palette))
                        .frame(height: 120).background(CoverColors(draft.palette).background)
                        .clipShape(RoundedRectangle(cornerRadius: 10)).listRowBackground(Color.clear)
                }
                Section("Original") {
                    LabeledContent("Filename", value: book.originalFilename)
                    LabeledContent("Pages", value: String(book.pageCount))
                    LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: book.byteCount, countStyle: .file))
                    Text("The original PDF is never renamed or overwritten. Your title and cover live in Leu.")
                        .font(.footnote).foregroundStyle(ShelfTheme.secondary)
                }
                if let error = model.errorMessage { Text(error).foregroundStyle(ShelfTheme.danger) }
            }.scrollContentBackground(.hidden).background(ShelfTheme.background)
                .navigationTitle("Make it yours").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task {
                            saving = true
                            if await model.saveDetails(id: book.id, draft: draft) { dismiss() }
                            saving = false
                        } }.disabled(saving || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("save-book-details")
                    }
                }
        }.tint(ShelfTheme.accent).preferredColorScheme(.dark).onAppear { model.errorMessage = nil }
    }
}
