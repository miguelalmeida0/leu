import SwiftUI
import ShelfCore

@MainActor
struct TrailAddSheet: View {
    @Bindable var model: LearningModel
    let onAdd: (TrailNode) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pageDocumentID: UUID?
    @State private var startPage = 1
    @State private var endPage = 1

    var body: some View {
        ShelfSheet(title: "Add to Trail") {
            List {
                Section("Documents") {
                    ForEach(model.library.snapshot.activeBooks) { book in
                        Button(book.title) {
                            add(TrailNode(kind: .document, documentID: book.id, title: book.title))
                        }
                    }
                }
                Section("Page range") {
                    Picker("PDF", selection: $pageDocumentID) {
                        Text("Choose a PDF").tag(UUID?.none)
                        ForEach(model.library.snapshot.activeBooks) { book in
                            Text(book.title).tag(UUID?.some(book.id))
                        }
                    }
                    if let book = selectedBook {
                        Stepper("Start page \(startPage)", value: $startPage, in: 1...max(1, book.pageCount))
                        Stepper("End page \(endPage)", value: $endPage, in: startPage...max(startPage, book.pageCount))
                        Button("Add pages \(startPage)–\(endPage)") {
                            let range = (startPage - 1)...(endPage - 1)
                            add(TrailNode(kind: .pageRange, documentID: book.id, pageRange: range,
                                          title: "\(book.title) · pages \(startPage)–\(endPage)"))
                        }
                    }
                }
                Section("Learning objects") {
                    ForEach(model.snapshot.learningObjects.prefix(50)) { object in
                        Button(object.title) {
                            add(TrailNode(kind: .learningObject, referenceID: object.id,
                                          documentID: object.source.documentID, title: object.title))
                        }
                    }
                }
                if !model.snapshot.questions.isEmpty {
                    Section("Questions") {
                        ForEach(model.snapshot.questions.prefix(30)) { question in
                            Button(question.prompt) {
                                add(TrailNode(kind: .question, referenceID: question.id,
                                              documentID: question.source.documentID,
                                              title: String(question.prompt.prefix(80))))
                            }
                        }
                    }
                }
                if !model.snapshot.masks.isEmpty {
                    Section("Diagram recall") {
                        ForEach(model.snapshot.masks.prefix(30)) { mask in
                            Button(mask.label ?? "Masked source · p. \(mask.source.pageIndex + 1)") {
                                add(TrailNode(kind: .mask, referenceID: mask.id,
                                              documentID: mask.source.documentID,
                                              title: mask.label ?? "Diagram recall"))
                            }
                        }
                    }
                }
                if !model.snapshot.relationships.isEmpty {
                    Section("Connections") {
                        ForEach(model.snapshot.relationships.prefix(30)) { relation in
                            Button(connectionTitle(relation)) {
                                add(TrailNode(kind: .connection, referenceID: relation.id,
                                              title: connectionTitle(relation)))
                            }
                        }
                    }
                }
                Section("Labs") {
                    ForEach(LabCatalog.all()) { lab in
                        Button(lab.title) { add(TrailNode(kind: .lab, referenceID: lab.id, title: lab.title)) }
                    }
                }
            }
            .onChange(of: pageDocumentID) { _, _ in startPage = 1; endPage = 1 }
        }
    }

    private var selectedBook: Book? {
        guard let pageDocumentID else { return nil }
        return model.library.snapshot.activeBooks.first { $0.id == pageDocumentID }
    }

    private func add(_ node: TrailNode) {
        onAdd(node)
        dismiss()
    }

    private func connectionTitle(_ relation: LearningRelationship) -> String {
        let source = model.snapshot.learningObjects.first { $0.id == relation.sourceObjectID }?.title ?? "Concept"
        let target = model.snapshot.learningObjects.first { $0.id == relation.targetObjectID }?.title ?? "Concept"
        return "\(source) ↔ \(target)"
    }
}
