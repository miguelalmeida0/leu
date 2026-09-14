import SwiftUI
import ShelfCore

@MainActor
struct ConceptDetailSheet: View {
    @Bindable var knowledge: KnowledgeModel
    let concept: KnowledgeConcept
    @Environment(\.dismiss) private var dismiss
    @State private var newChainTitle = ""
    @State private var createChain = false
    @State private var newAlias = ""
    @State private var aliasPresented = false

    var body: some View {
        ShelfSheet(title: concept.name) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if !highlights.isEmpty { passageGroup("Strong passages", passages: highlights) }
                    if !connectedConcepts.isEmpty { conceptGroup }
                    if !chains.isEmpty { chainGroup }
                    Button("Start Topic Chain") { newChainTitle = concept.name; createChain = true }
                        .buttonStyle(ShelfButtonStyle(filled: true))
                }.padding(ShelfTheme.gutter)
            }
        }
        .leuDialog("Add alias", isPresented: $aliasPresented) {
            LeuTextField("Alias", text: $newAlias)
            Button("Save") { saveAlias() }
            Button("Cancel", role: .cancel) { newAlias = "" }
        } message: { Text("Aliases help Leu recognize the same concept across different books.") }
        .leuDialog("New Topic Chain", isPresented: $createChain) {
            LeuTextField(concept.name, text: $newChainTitle)
            Button("Create") { Task { _ = await knowledge.createChain(title: newChainTitle, passageIDs: highlights.prefix(1).map(\.id)) } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var allBindings: [PassageConceptBinding] { knowledge.snapshot.detectedBindings + knowledge.snapshot.userBindings }
    private var passageIDs: Set<UUID> { Set(allBindings.filter { $0.conceptID == concept.id }.map(\.passageID)) }
    private var highlights: [KnowledgePassage] { knowledge.snapshot.passages.filter { passageIDs.contains($0.id) && $0.isAvailable }.prefix(30).map { $0 } }
    private var documentCount: Int { Set(highlights.map(\.documentID)).count }
    private var connectionCount: Int { knowledge.snapshot.confirmedConnections.filter { passageIDs.contains($0.sourcePassageID) || passageIDs.contains($0.destinationPassageID) }.count }
    private var chains: [TopicChain] { knowledge.snapshot.topicChains.filter { $0.conceptID == concept.id || $0.items.contains(where: { $0.passageID.map(passageIDs.contains) == true }) } }

    private var connectedConcepts: [KnowledgeConcept] {
        let bound = Set(knowledge.snapshot.indexRecords.filter { passageIDs.contains($0.passageID) }.flatMap { $0.conceptIDs }).subtracting([concept.id])
        return knowledge.snapshot.concepts.filter { bound.contains($0.id) }.prefix(8).map { $0 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(concept.name).font(.system(size: 36, weight: .regular, design: .serif))
            HStack(spacing: 16) {
                Text("\(documentCount) books"); Text("\(highlights.count) passages"); Text("\(connectionCount) connections")
            }.font(.caption.monospacedDigit()).foregroundStyle(ShelfTheme.secondary)
            if let pack = concept.pack { Text(pack).font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent) }
            let aliases = knowledge.snapshot.aliases.filter { $0.conceptID == concept.id }.map(\.value)
            if !aliases.isEmpty { Text(aliases.joined(separator: " · ")).font(.caption).foregroundStyle(ShelfTheme.secondary) }
            if concept.isUserCreated {
                Button("Add alias") { aliasPresented = true }.font(.caption.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
            }
        }
    }

    private func saveAlias() {
        let clean = newAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }
        Task {
            do {
                try await knowledge.repository.addAlias(clean, to: concept.id)
                knowledge.snapshot = try await knowledge.repository.snapshot()
            } catch { knowledge.errorMessage = error.localizedDescription }
        }
        newAlias = ""
    }

    private func passageGroup(_ title: String, passages: [KnowledgePassage]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ForEach(passages) { passage in
                Button { knowledge.queueNavigation(to: passage); dismiss() } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(passage.text).font(.system(.callout, design: .serif)).foregroundStyle(ShelfTheme.text).lineLimit(3)
                        Text("\(knowledge.title(for: passage.documentID)) · p. \(passage.pageIndex + 1)").font(.caption).foregroundStyle(ShelfTheme.secondary)
                    }.padding(.vertical, 6).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }
    }

    private var conceptGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connected concepts").font(.headline)
            ForEach(connectedConcepts) { item in Text(item.name).foregroundStyle(ShelfTheme.secondary).padding(.vertical, 3) }
        }
    }

    private var chainGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appears in Topic Chains").font(.headline)
            ForEach(chains) { chain in Text(chain.title).foregroundStyle(ShelfTheme.secondary).padding(.vertical, 3) }
        }
    }
}
