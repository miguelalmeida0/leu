import SwiftUI
import ShelfCore

@MainActor
struct SessionLabActivity: View {
    @Bindable var model: LearningModel
    @State private var selectedLab = LabCatalog.defaultLab
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Reconstruct").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
            Text(selectedLab.title).font(LearningTokens.Typography.title)
            Text(selectedLab.instruction).foregroundStyle(ShelfTheme.secondary)
            MiniLabSequence(lab: selectedLab)
            Button("Continue") { model.advance() }.buttonStyle(ShelfButtonStyle(filled: true))
        }
        .onAppear { selectedLab = labForTopic() }
    }

    private func labForTopic() -> ReconstructionLab {
        let topic = model.currentObject?.topicIDs.compactMap { id in model.snapshot.topics.first(where: { $0.id == id })?.name.lowercased() }.joined(separator: " ") ?? ""
        if topic.contains("react") { return LabCatalog.all().first { $0.kind == .reactIdentity } ?? LabCatalog.defaultLab }
        if topic.contains("typescript") { return LabCatalog.all().first { $0.kind == .structuralTyping } ?? LabCatalog.defaultLab }
        if topic.contains("backend") { return LabCatalog.all().first { $0.kind == .databaseTransaction } ?? LabCatalog.defaultLab }
        return LabCatalog.defaultLab
    }
}

@MainActor
struct ContinueReadingActivity: View {
    @Bindable var model: LearningModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Continue reading").font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
            Text("Finish with the source, not another card.").font(LearningTokens.Typography.title)
            Text("Open the material you were studying, read until the idea settles, then return to complete the session.")
                .foregroundStyle(ShelfTheme.secondary)
            if let object = model.currentObject {
                Button("Open source") { model.openSource(object.source) }.buttonStyle(ShelfButtonStyle(filled: true))
            }
            Button("Finish session") { model.completeSession() }.buttonStyle(ShelfButtonStyle())
        }
    }
}
