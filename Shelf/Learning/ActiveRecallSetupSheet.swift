import SwiftUI
import ShelfCore

@MainActor
struct ActiveRecallSetupSheet: View {
    @Bindable var model: LearningModel
    @Environment(\.dismiss) private var dismiss
    @State private var scope: Scope = .all
    @State private var topicID: UUID?
    @State private var documentID: UUID?
    @State private var trailID: UUID?
    enum Scope: String, CaseIterable { case all = "All passages", due = "All due", topic = "One topic", document = "One PDF", trail = "One trail" }

    var body: some View {
        ShelfSheet(title: "Active Recall") {
            Form {
                Section("Recall from") {
                    Picker("Scope", selection: $scope) { ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                }
                if scope == .topic {
                    Picker("Topic", selection: $topicID) { Text("Choose").tag(UUID?.none); ForEach(model.visibleTopics) { Text($0.name).tag(UUID?.some($0.id)) } }
                }
                if scope == .document {
                    Picker("PDF", selection: $documentID) { Text("Choose").tag(UUID?.none); ForEach(model.library.snapshot.activeBooks) { Text($0.title).tag(UUID?.some($0.id)) } }
                }
                if scope == .trail {
                    Picker("Trail", selection: $trailID) { Text("Choose").tag(UUID?.none); ForEach(model.snapshot.trails) { Text($0.title).tag(UUID?.some($0.id)) } }
                }
                Section {
                    Button("Begin recall") {
                        switch scope {
                        case .all: model.startActiveRecall()
                        case .due: model.startActiveRecall(dueOnly: true)
                        case .topic: model.startActiveRecall(topicID: topicID)
                        case .document: model.startActiveRecall(documentID: documentID)
                        case .trail: model.startActiveRecall(trailID: trailID)
                        }
                        dismiss()
                    }.buttonStyle(ShelfButtonStyle(filled: true))
                        .disabled(!selectionReady)
                    if scope == .due && model.dueObjects.isEmpty {
                        Text("Nothing is due yet. Choose All passages to practise now.").font(.callout)
                    }
                }
            }.scrollContentBackground(.hidden)
        }
    }
    private var selectionReady: Bool {
        switch scope {
        case .all: return !model.isIndexing && !model.snapshot.studyObjects.isEmpty
        case .due: return !model.dueObjects.isEmpty
        case .topic: return topicID != nil
        case .document: return documentID != nil
        case .trail: return trailID != nil
        }
    }

}
