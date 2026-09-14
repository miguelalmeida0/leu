import SwiftUI
import ShelfCore

@MainActor
struct NoteEditorSheet: View {
    let model: ReaderModel
    @State var draft: NoteDraft
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                if !draft.quote.isEmpty {
                    Section("Selected passage") { Text(draft.quote).font(.system(.body, design: .serif)).lineLimit(8) }
                } else {
                    Section { Text("Page \(draft.fragments.first.map { $0.pageIndex + 1 } ?? model.pageNumber)") }
                }
                Section("Keep this as") {
                    Picker("Type", selection: $draft.kind) {
                        ForEach(AnnotationKind.allCases.filter { $0 != .underline || !draft.quote.isEmpty }, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    Picker("Color", selection: $draft.color) {
                        ForEach(MarkColor.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
                Section("Your note") {
                    TextEditor(text: $draft.text).frame(minHeight: 160).accessibilityIdentifier("note-text-input")
                }
                if let error = model.errorMessage { Text(error).foregroundStyle(ShelfTheme.danger) }
                Section {
                    Text("Saved locally, separate from the original PDF. You can export an annotated copy at any time.")
                        .font(.footnote).foregroundStyle(ShelfTheme.secondary)
                }
            }.scrollContentBackground(.hidden).background(ShelfTheme.background)
                .navigationTitle(draft.kind.isStudyMarker ? "Study marker" : "Make a note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.isSaving) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { if await model.saveNote(draft) { dismiss() } } }
                            .disabled(model.isSaving).accessibilityIdentifier("save-note")
                    }
                }
        }.preferredColorScheme(.dark).tint(ShelfTheme.accent)
            .interactiveDismissDisabled(model.isSaving)
            .onAppear { model.errorMessage = nil }
    }
}
