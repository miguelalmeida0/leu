import SwiftUI
import ShelfCore

@MainActor
struct ReaderNotesSheet: View {
    @Bindable var model: ReaderModel
    @State private var reviewOnly = false
    @State private var removing: StudyAnnotation?
    @State private var connecting: StudyAnnotation?
    @Environment(\.dismiss) private var dismiss
    private var notes: [StudyAnnotation] {
        model.annotations.filter { !reviewOnly || $0.kind.isStudyMarker }
    }
    var body: some View {
        ShelfSheet(title: "Notes & highlights") {
            VStack(spacing: 0) {
                Picker("Notes filter", selection: $reviewOnly) {
                    Text("All notes").tag(false); Text("Study markers").tag(true)
                }.pickerStyle(.segmented).padding(16)
                List {
                    if let error = model.errorMessage {
                        Text(error).foregroundStyle(ShelfTheme.danger)
                        Button("Dismiss error") { model.errorMessage = nil }
                    }
                    if notes.isEmpty {
                        Text("Select text and choose Mark, or add a page note. Everything you save here stays linked to the original page.")
                            .foregroundStyle(ShelfTheme.secondary).padding(.vertical, 16)
                    }
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(note.kind.title).font(.caption.weight(.semibold)).foregroundStyle(markerAccent(note.kind))
                                Spacer()
                                Text("p. \(note.pageIndex + 1)").font(.caption).foregroundStyle(ShelfTheme.secondary)
                            }
                            if !note.quote.isEmpty { Text(note.quote).font(.system(.body, design: .serif)).lineLimit(5) }
                            if !note.note.isEmpty { Text(note.note).font(.callout).foregroundStyle(ShelfTheme.secondary) }
                            HStack {
                                Button("Go to page") { model.go(to: note.pageIndex); dismiss() }.buttonStyle(.borderless)
                                if !note.quote.isEmpty {
                                    Button("Connections") { connecting = note }.buttonStyle(.borderless)
                                        .accessibilityLabel("Connections for this saved passage")
                                }
                                Spacer()
                                Button(role: .destructive) { removing = note } label: {
                                    Image(systemName: "trash").frame(width: 44, height: 44)
                                }.buttonStyle(.borderless).accessibilityLabel("Remove note")
                            }
                        }
                        .padding(12)
                        .background(markerBackground(note.kind), in: RoundedRectangle(cornerRadius: 14))
                    }
                }.scrollContentBackground(.hidden)
            }
            .sheet(item: $connecting) { note in
                ConnectedPassageSheet(knowledge: model.knowledge, source: LearningSource(
                    documentID: note.bookID, pageIndex: note.pageIndex, sourceText: note.quote,
                    sectionTitle: model.sectionTitle(for: note.pageIndex)))
            }
            .leuDialog("Remove this annotation?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible, presenting: removing) { note in
                Button("Remove annotation", role: .destructive) {
                    Task { await model.deleteAnnotation(note) }
                }
            } message: { _ in
                Text("Undo remains available during this reading session.")
            }
        }
    }
    private func markerBackground(_ kind: AnnotationKind) -> Color {
        switch kind {
        case .important: return ShelfTheme.importantBackground
        case .review: return ShelfTheme.reviewBackground
        case .confusing: return ShelfTheme.confusingBackground
        default: return ShelfTheme.surface
        }
    }

    private func markerAccent(_ kind: AnnotationKind) -> Color {
        switch kind {
        case .important: return ShelfTheme.importantAccent
        case .review: return ShelfTheme.reviewAccent
        case .confusing: return ShelfTheme.confusingAccent
        default: return ShelfTheme.accent
        }
    }

}
