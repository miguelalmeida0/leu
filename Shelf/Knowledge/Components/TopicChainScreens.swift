import SwiftUI
import ShelfCore

@MainActor
struct TopicChainsSection: View {
    @Bindable var knowledge: KnowledgeModel
    @State private var selected: TopicChain?

    var body: some View {
        Group {
            if !knowledge.snapshot.topicChains.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("FROM CONNECTIONS")
                        .font(ShelfTheme.eyebrow(10)).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
                        .padding(.bottom, 8)
                    ForEach(knowledge.snapshot.topicChains.sorted { $0.updatedAt > $1.updatedAt }) { chain in
                        Button { selected = chain } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "link").foregroundStyle(ShelfTheme.accent).frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chain.title)
                                        .font(.system(.body, design: .serif).weight(.medium))
                                        .foregroundStyle(ShelfTheme.text)
                                    Text("\(chain.items.count) stops")
                                        .font(.caption).foregroundStyle(ShelfTheme.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(ShelfTheme.secondary)
                            }
                            .padding(.vertical, 12).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(ShelfTheme.line)
                    }
                }
            }
        }
        .sheet(item: $selected) { TopicChainDetailSheet(knowledge: knowledge, chainID: $0.id) }
    }
}

@MainActor
struct TopicChainDetailSheet: View {
    @Bindable var knowledge: KnowledgeModel
    let chainID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var reading = false

    var body: some View {
        ShelfSheet(title: chain?.title ?? "Trail") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let chain {
                        Text("An ordered path through your own library.").foregroundStyle(ShelfTheme.secondary)
                        if chain.items.isEmpty { Text("Add passages from Connections to build this trail.").foregroundStyle(ShelfTheme.secondary).padding(.vertical, 20) }
                        else { items(chain) }
                        Button("Read Trail") { reading = true }
                            .buttonStyle(ShelfButtonStyle(filled: true)).disabled(chain.items.isEmpty)
                            .accessibilityIdentifier("read-topic-chain")
                    }
                }.padding(ShelfTheme.gutter)
            }
        }
        .sheet(isPresented: $reading) { if let chain { ReadTopicChainScreen(knowledge: knowledge, chain: chain) } }
    }

    private var chain: TopicChain? { knowledge.snapshot.topicChains.first(where: { $0.id == chainID }) }

    private func items(_ chain: TopicChain) -> some View {
        VStack(spacing: 0) {
            ForEach(chain.items.sorted { $0.position < $1.position }) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(format: "%02d", item.position + 1)).font(.caption.monospacedDigit()).foregroundStyle(ShelfTheme.accent).frame(width: 26)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(itemTitle(item)).font(.system(.body, design: .serif)).lineLimit(3)
                        Text(provenance(item)).font(.caption).foregroundStyle(ShelfTheme.secondary)
                    }
                    Spacer()
                    LeuMenu {
                        Button("Move earlier", systemImage: "arrow.up") { move(item, by: -1, in: chain) }
                            .disabled(item.position == 0)
                        Button("Move later", systemImage: "arrow.down") { move(item, by: 1, in: chain) }
                            .disabled(item.position + 1 >= chain.items.count)
                        Divider()
                        Button("Remove from trail", systemImage: "minus.circle", role: .destructive) { remove(item, from: chain) }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel("Actions for trail item \(item.position + 1)")
                }.padding(.vertical, 12)
                Divider().overlay(ShelfTheme.line)
            }
        }
    }

    private func itemTitle(_ item: TopicChainItem) -> String {
        if let passage = knowledge.passage(item.passageID) { return passage.text }
        if let concept = knowledge.concept(item.conceptID) { return concept.name }
        return item.sourcePreview ?? "Unavailable source"
    }

    private func move(_ item: TopicChainItem, by delta: Int, in chain: TopicChain) {
        var next = chain
        let ordered = next.items.sorted { $0.position < $1.position }
        guard let index = ordered.firstIndex(where: { $0.id == item.id }) else { return }
        let destination = min(max(index + delta, 0), ordered.count - 1)
        guard destination != index else { return }
        var mutable = ordered
        let moved = mutable.remove(at: index); mutable.insert(moved, at: destination)
        next.items = mutable.enumerated().map { offset, value in var copy = value; copy.position = offset; return copy }
        Task { await knowledge.saveChain(next); ShelfHaptics.shared.play(.selectionChanged) }
    }

    private func remove(_ item: TopicChainItem, from chain: TopicChain) {
        var next = chain
        next.items.removeAll { $0.id == item.id }
        next.items = next.items.sorted { $0.position < $1.position }.enumerated().map { offset, value in
            var copy = value; copy.position = offset; return copy
        }
        Task { await knowledge.saveChain(next); ShelfHaptics.shared.play(.destructiveWarning) }
    }

    private func provenance(_ item: TopicChainItem) -> String {
        guard let doc = item.documentID, let page = item.pageIndex else { return item.kind.rawValue.capitalized }
        return "\(knowledge.title(for: doc)) · p. \(page + 1)"
    }
}

@MainActor
struct ReadTopicChainScreen: View {
    @Bindable var knowledge: KnowledgeModel
    let chain: TopicChain
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let item = currentItem { passage(item) }
                else { Text("This chain has no readable passages.").foregroundStyle(ShelfTheme.secondary).frame(maxHeight: .infinity) }
                controls
            }
            .background(ShelfTheme.background)
            .navigationTitle(chain.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private var readableItems: [TopicChainItem] { chain.items.sorted { $0.position < $1.position }.filter { knowledge.passage($0.passageID) != nil } }
    private var currentItem: TopicChainItem? { readableItems.indices.contains(index) ? readableItems[index] : nil }

    private func passage(_ item: TopicChainItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let passage = knowledge.passage(item.passageID) {
                    Text(knowledge.title(for: passage.documentID).uppercased()).font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(ShelfTheme.accent)
                    Text(passage.sectionTitle ?? "Passage").font(.system(.title2, design: .serif))
                    Text(passage.text).font(.system(size: 22, weight: .regular, design: .serif)).lineSpacing(7)
                    Text("p. \(passage.pageIndex + 1)").font(.caption.monospacedDigit()).foregroundStyle(ShelfTheme.secondary)
                    Button("Open original page") { knowledge.queueNavigation(to: passage); dismiss() }
                        .buttonStyle(ShelfButtonStyle())
                }
                if let note = item.annotation { Text(note).font(.callout).foregroundStyle(ShelfTheme.secondary) }
            }.padding(28).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
    }

    private var controls: some View {
        HStack {
            Button { index = max(0, index - 1); ShelfHaptics.shared.play(.selectionChanged) } label: { Image(systemName: "chevron.left").frame(width: 48, height: 48) }
                .disabled(index == 0).accessibilityLabel("Previous chain item")
            Spacer(); Text("\(min(index + 1, max(1, readableItems.count))) / \(readableItems.count)").font(.callout.monospacedDigit())
            Spacer()
            Button { index = min(max(0, readableItems.count - 1), index + 1); ShelfHaptics.shared.play(.selectionChanged) } label: { Image(systemName: "chevron.right").frame(width: 48, height: 48) }
                .disabled(index + 1 >= readableItems.count).accessibilityLabel("Next chain item")
        }.padding(.horizontal, 18).padding(.vertical, 8).overlay(alignment: .top) { Divider().overlay(ShelfTheme.line) }
    }
}
