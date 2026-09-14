import SwiftUI
import ShelfCore

@MainActor
struct KnowledgeSearchSheet: View {
    @Bindable var knowledge: KnowledgeModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConcept: KnowledgeConcept?
    @State private var selectedChain: TopicChain?

    var body: some View {
        ShelfSheet(title: "Search ideas") {
            VStack(spacing: 0) {
                searchField.padding(ShelfTheme.gutter)
                Divider().overlay(ShelfTheme.line)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if knowledge.searchText.isEmpty { prompt }
                        else { results }
                    }.padding(ShelfTheme.gutter)
                }
            }
        }
        .sheet(item: $selectedConcept) { ConceptDetailSheet(knowledge: knowledge, concept: $0) }
        .sheet(item: $selectedChain) { TopicChainDetailSheet(knowledge: knowledge, chainID: $0.id) }
        .accessibilityIdentifier("knowledge-search")
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(ShelfTheme.secondary)
            LeuTextField("Search concepts, passages, chains…", text: $knowledge.searchText)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .onChange(of: knowledge.searchText) { _, _ in knowledge.search() }
                .accessibilityIdentifier("knowledge-search-field")
            if !knowledge.searchText.isEmpty {
                Button { knowledge.searchText = ""; knowledge.search() } label: { Image(systemName: "xmark.circle.fill") }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14).frame(minHeight: 50)
        .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search across the ideas inside your library.").font(.system(.title3, design: .serif))
            Text("Exact technical terms stay intact: useEffect, React.memo, Promise.all, HTTP/2 and Big O notation.")
                .font(.callout).foregroundStyle(ShelfTheme.secondary)
        }.padding(.vertical, 10)
    }

    @ViewBuilder private var results: some View {
        if knowledge.searchResult.concepts.isEmpty && knowledge.searchResult.passages.isEmpty && knowledge.searchResult.chains.isEmpty && knowledge.matchingHighlights.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(knowledge.isIndexing ? "Connecting your library…" : "No strong matches.")
                    .font(.headline).foregroundStyle(ShelfTheme.text)
                if knowledge.isIndexing {
                    Text("Results update automatically as local passage indexing completes.")
                        .font(.callout).foregroundStyle(ShelfTheme.secondary)
                }
            }
            .padding(.vertical, 24)
            .accessibilityIdentifier("knowledge-search-status")
        }
        if !knowledge.searchResult.concepts.isEmpty {
            group("CONCEPTS") {
                ForEach(knowledge.searchResult.concepts) { concept in
                    Button { selectedConcept = concept } label: { row(concept.name, detail: concept.pack ?? "Concept", symbol: "text.book.closed") }
                        .buttonStyle(.plain)
                }
            }
        }
        if !knowledge.searchResult.chains.isEmpty {
            group("TOPIC CHAINS") {
                ForEach(knowledge.searchResult.chains) { chain in
                    Button { selectedChain = chain } label: { row(chain.title, detail: "\(chain.items.count) passages", symbol: "point.3.connected.trianglepath.dotted") }
                        .buttonStyle(.plain)
                }
            }
        }
        if !knowledge.matchingHighlights.isEmpty {
            group("YOUR HIGHLIGHTS") {
                ForEach(knowledge.matchingHighlights.prefix(20)) { annotation in
                    Button { knowledge.queueNavigation(to: annotation); dismiss() } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(annotation.quote).font(.system(.callout, design: .serif)).foregroundStyle(ShelfTheme.text).lineLimit(3)
                            Text("\(knowledge.title(for: annotation.bookID)) · p. \(annotation.pageIndex + 1)")
                                .font(.caption).foregroundStyle(ShelfTheme.secondary)
                        }.padding(.vertical, 7).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }
        if !knowledge.searchResult.passages.isEmpty {
            group("PASSAGES") {
                ForEach(knowledge.searchResult.passages.prefix(30)) { passage in
                    Button { knowledge.queueNavigation(to: passage); dismiss() } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(knowledge.title(for: passage.documentID)).font(.headline); Spacer(); Text("p. \(passage.pageIndex + 1)").font(.caption.monospacedDigit()) }
                            Text(passage.text).font(.system(.callout, design: .serif)).foregroundStyle(ShelfTheme.secondary).lineLimit(3)
                        }.padding(.vertical, 8).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider().overlay(ShelfTheme.line)
                }
            }
        }
        if !knowledge.searchResult.documentIDs.isEmpty {
            group("BOOKS") {
                ForEach(knowledge.searchResult.documentIDs.prefix(12), id: \.self) { documentID in
                    if let first = knowledge.searchResult.passages.first(where: { $0.documentID == documentID }) {
                        Button { knowledge.queueNavigation(to: first); dismiss() } label: {
                            row(knowledge.title(for: documentID), detail: "Open the strongest matching passage", symbol: "book.closed")
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(ShelfTheme.secondary)
            content()
        }
    }

    private func row(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(ShelfTheme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) { Text(title).foregroundStyle(ShelfTheme.text); Text(detail).font(.caption).foregroundStyle(ShelfTheme.secondary) }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(ShelfTheme.secondary)
        }.padding(.vertical, 8).contentShape(Rectangle())
    }
}
