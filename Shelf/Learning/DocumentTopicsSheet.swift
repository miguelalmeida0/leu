import SwiftUI
import ShelfCore

@MainActor
struct DocumentTopicsSheet: View {
    @Bindable var model: LearningModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDocumentID: UUID?
    @State private var selection = Set<UUID>()
    @State private var newTopic = ""

    var body: some View {
        ShelfSheet(title: "Document Topics") {
            Form {
                Section("PDF") {
                    Picker("Document", selection: $selectedDocumentID) {
                        Text("Choose a PDF").tag(UUID?.none)
                        ForEach(model.library.snapshot.activeBooks) { book in Text(book.title).tag(UUID?.some(book.id)) }
                    }
                    .onChange(of: selectedDocumentID) { _, id in
                        selection = id.flatMap { model.snapshot.manualDocumentTopics[$0] } ?? []
                    }
                }
                if selectedDocumentID != nil {
                    Section("Topics") {
                        ForEach(model.snapshot.topics) { topic in
                            Toggle(isOn: Binding(get: { selection.contains(topic.id) }, set: { on in
                                if on { selection.insert(topic.id) } else { selection.remove(topic.id) }
                            })) { Text(topic.name) }
                        }
                    }
                    Section("Add a topic") {
                        HStack {
                            LeuTextField("e.g. GraphQL", text: $newTopic)
                            Button("Add") { Task { if let topic = await model.addTopic(name: newTopic) { selection.insert(topic.id); newTopic = "" } } }
                                .disabled(newTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    Section {
                        Button("Save topics") {
                            if let id = selectedDocumentID { Task { await model.setManualTopics(documentID: id, topicIDs: selection); dismiss() } }
                        }.buttonStyle(ShelfButtonStyle(filled: true))
                    } footer: {
                        Text("Manual topics override automatic topic scoring for study planning.")
                    }
                }
            }.scrollContentBackground(.hidden)
        }
    }
}
