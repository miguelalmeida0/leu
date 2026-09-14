import SwiftUI
import ShelfCore

@MainActor
struct ConnectionsSheet: View {
    @Bindable var model: LearningModel
    let sourceObject: LearningObject
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var kind: RelationshipKind = .related
    @State private var customLabel = ""

    var body: some View {
        ShelfSheet(title: "Connect") {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(sourceObject.title).font(LearningTokens.Typography.compactTitle).lineLimit(3)
                    Picker("Relationship", selection: $kind) {
                        ForEach(RelationshipKind.allCases, id: \.self) { kind in
                            Text(label(kind)).tag(kind)
                        }
                    }.pickerStyle(.inline)
                    if kind == .custom {
                        LeuTextField("Describe the relationship", text: $customLabel)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("connection-custom-label")
                    }
                    LeuTextField("Search concepts or PDFs", text: $query)
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("connection-search")
                }.padding(ShelfTheme.gutter)
                Divider().overlay(ShelfTheme.line)
                List(filteredObjects) { target in
                    Button {
                        Task {
                            do {
                                let cleanLabel = customLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                                try await model.repository.connect(sourceObject.id, to: target.id, kind: kind,
                                                                   customLabel: kind == .custom && !cleanLabel.isEmpty ? cleanLabel : nil)
                                model.snapshot = try await model.repository.snapshot()
                                model.play(.objectConnected); dismiss()
                            } catch { model.errorMessage = error.localizedDescription }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(target.title).foregroundStyle(ShelfTheme.text).lineLimit(2)
                            Text(target.source.sectionTitle ?? documentTitle(target.source.documentID))
                                .font(.caption).foregroundStyle(ShelfTheme.secondary)
                        }.padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    .disabled(kind == .custom && customLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(ShelfTheme.surface)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var filteredObjects: [LearningObject] {
        model.snapshot.learningObjects.filter { object in
            guard object.id != sourceObject.id else { return false }
            guard !query.isEmpty else { return true }
            let topicNames = object.topicIDs.compactMap { id in model.snapshot.topics.first(where: { $0.id == id })?.name }.joined(separator: " ")
            let haystack = object.title + " " + object.source.sourceText + " " + documentTitle(object.source.documentID) + " " + topicNames
            return haystack.localizedCaseInsensitiveContains(query)
        }.prefix(60).map { $0 }
    }
    private func documentTitle(_ id: UUID) -> String {
        model.library.snapshot.activeBooks.first(where: { $0.id == id })?.title ?? "PDF"
    }
    private func label(_ kind: RelationshipKind) -> String {
        switch kind { case .buildsOn: return "Builds on"; case .sameIdea: return "Same idea"; default: return kind.rawValue.capitalized }
    }
}
