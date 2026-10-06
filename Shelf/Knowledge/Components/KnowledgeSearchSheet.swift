import SwiftUI
import ShelfCore

/// Search your books (14). One large field, quiet scopes, and the best answer from your
/// own library first, with the words you searched for marked in butter. Return opens the
/// best answer at its passage.
@MainActor
struct KnowledgeSearchSheet: View {
    @Bindable var knowledge: KnowledgeModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedConcept: KnowledgeConcept?
    @State private var selectedChain: TopicChain?
    @State private var scope: Scope = .everything

    enum Scope: String, CaseIterable, Identifiable {
        case everything = "Everything", passages = "Passages", books = "Sources", ideas = "Ideas", notes = "Your notes", chains = "Chains"
        var id: String { rawValue }
    }

    var body: some View {
        ShelfSheet(title: "Search your books") {
            VStack(alignment: .leading, spacing: 14) {
                searchField
                if !knowledge.searchText.isEmpty { scopes }
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if knowledge.searchText.isEmpty { prompt } else { results }
                    }
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .sheet(item: $selectedConcept) { ConceptDetailSheet(knowledge: knowledge, concept: $0) }
        .sheet(item: $selectedChain) { TopicChainDetailSheet(knowledge: knowledge, chainID: $0.id) }
        .accessibilityIdentifier("knowledge-search")
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.leu(.title3, weight: .bold))
                .foregroundStyle(LeuDesign.ink)
                .accessibilityHidden(true)
            LeuTextField("Ask your books anything", text: $knowledge.searchText)
                .font(.leu(.title3, weight: .semibold))
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit(openBestAnswer)
                .onChange(of: knowledge.searchText) { _, _ in knowledge.search() }
                .accessibilityIdentifier("knowledge-search-field")
            if !knowledge.searchText.isEmpty {
                Button { knowledge.searchText = ""; knowledge.search() } label: { Image(systemName: "xmark.circle.fill") }
                    .font(.leu(.body))
                    .foregroundStyle(LeuDesign.secondary)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 60)
        .background(LeuDesign.cream, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(LeuDesign.ink, lineWidth: 2) }
    }

    private var scopes: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Scope.allCases) { option in
                    let selected = option == scope
                    Button(option.rawValue) { scope = option }
                        .font(.leu(.footnote, weight: .semibold))
                        .foregroundStyle(selected ? LeuDesign.cream : LeuDesign.ink)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(selected ? LeuDesign.ink : LeuDesign.feltLight, in: Capsule())
                        .contentShape(Capsule())
                        .frame(minHeight: 44)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search in")
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search across the ideas inside your library.")
                .font(LeuDesign.display(24)).foregroundStyle(LeuDesign.ink)
            Text("Ask it like a question, or use the exact term: useEffect, React.memo, Promise.all, HTTP/2 and Big O notation stay intact.")
                .font(.leu(.callout)).foregroundStyle(LeuDesign.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
    }

    private func shows(_ section: Scope) -> Bool { scope == .everything || scope == section }

    @ViewBuilder private var results: some View {
        let result = knowledge.searchResult
        let passages = Array(result.passages.prefix(30))
        if result.concepts.isEmpty && passages.isEmpty && result.chains.isEmpty && knowledge.matchingHighlights.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(knowledge.isIndexing ? "Connecting your library…" : "Nothing in your books says that yet.")
                    .font(.leu(.headline)).foregroundStyle(LeuDesign.ink)
                Text(knowledge.isIndexing ? "Results update by themselves as your passages are indexed on this device."
                                          : "Try fewer words, or the word the book would use.")
                    .font(.leu(.callout)).foregroundStyle(LeuDesign.secondary)
            }
            .padding(.vertical, 24)
            .accessibilityIdentifier("knowledge-search-status")
        }
        if shows(.passages), let best = passages.first {
            group("Best answer, from your own library") { passageRow(best, best: true) }
            if passages.count > 1 {
                group("More passages · \(passages.count - 1)") {
                    ForEach(passages.dropFirst()) { passage in passageRow(passage, best: false) }
                }
            }
        }
        if shows(.ideas) && !result.concepts.isEmpty {
            group("Ideas") {
                ForEach(result.concepts) { concept in
                    Button { selectedConcept = concept } label: {
                        row(concept.name, detail: concept.pack ?? "An idea across your books", swatch: LeuDesign.conceptColor(for: concept.name))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if shows(.chains) && !result.chains.isEmpty {
            group("Chains") {
                ForEach(result.chains) { chain in
                    Button { selectedChain = chain } label: {
                        row(chain.title, detail: chain.items.count == 1 ? "1 passage" : "\(chain.items.count) passages", swatch: LeuDesign.redThread)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if shows(.notes) && !knowledge.matchingHighlights.isEmpty {
            group("Your notes and highlights") {
                ForEach(knowledge.matchingHighlights.prefix(20)) { annotation in
                    Button { knowledge.queueNavigation(to: annotation); dismiss() } label: {
                        resultRow(title: "\(knowledge.title(for: annotation.bookID)) · p. \(annotation.pageIndex + 1)",
                               text: annotation.note.isEmpty ? annotation.quote : annotation.note,
                               swatch: dye(for: annotation.bookID), best: false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if shows(.books) && !result.documentIDs.isEmpty {
            group("Sources") {
                ForEach(result.documentIDs.prefix(12), id: \.self) { documentID in
                    if let first = passages.first(where: { $0.documentID == documentID }) {
                        Button { knowledge.queueNavigation(to: first); dismiss() } label: {
                            row(knowledge.title(for: documentID), detail: "Opens the strongest matching passage", swatch: dye(for: documentID))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Rows

    private func openBestAnswer() {
        guard let best = knowledge.searchResult.passages.first else { return }
        knowledge.queueNavigation(to: best)
        dismiss()
    }

    private func passageRow(_ passage: KnowledgePassage, best: Bool) -> some View {
        Button { knowledge.queueNavigation(to: passage); dismiss() } label: {
            resultRow(title: "\(knowledge.title(for: passage.documentID)) · p. \(passage.pageIndex + 1)",
                   text: passage.text, swatch: dye(for: passage.documentID), best: best)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the book at this passage")
    }

    private func resultRow(title: String, text: String, swatch: Color, best: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(swatch).frame(width: 30, height: 22).padding(.top, 2)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.leu(.subheadline, weight: .bold)).foregroundStyle(LeuDesign.ink)
                Text(marked(text))
                    .font(.leu(.callout, serif: true))
                    .foregroundStyle(LeuDesign.ink)
                    .lineLimit(best ? 5 : 3)
            }
            Spacer(minLength: 0)
            if best {
                Text("↵ open").font(.leu(.caption, weight: .semibold)).foregroundStyle(LeuDesign.secondary).accessibilityHidden(true)
            }
        }
        .padding(best ? 14 : 4)
        .padding(.vertical, best ? 0 : 6)
        .background(best ? LeuDesign.feltLight : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    private func row(_ title: String, detail: String, swatch: Color) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(swatch).frame(width: 30, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.leu(.subheadline, weight: .bold)).foregroundStyle(LeuDesign.ink)
                Text(detail).font(.leu(.caption)).foregroundStyle(LeuDesign.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(LeuDesign.eyebrow(10)).tracking(LeuDesign.eyebrowTracking)
                .foregroundStyle(LeuDesign.eyebrowOnFelt)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func dye(for documentID: UUID) -> Color {
        knowledge.library.snapshot.activeBooks.first { $0.id == documentID }.map { CoverColors($0.palette).background } ?? LeuDesign.oat
    }

    /// The searched words, marked in butter wherever they appear.
    private func marked(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let words = knowledge.searchText.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).filter { $0.count >= 3 }
        for word in Set(words) {
            var searchRange = attributed.startIndex..<attributed.endIndex
            while let found = attributed[searchRange].range(of: String(word), options: .caseInsensitive) {
                attributed[found].backgroundColor = LeuDesign.butter
                searchRange = found.upperBound..<attributed.endIndex
            }
        }
        return attributed
    }
}
