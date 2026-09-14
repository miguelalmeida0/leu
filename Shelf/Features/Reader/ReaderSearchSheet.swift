import SwiftUI

@MainActor
struct ReaderSearchSheet: View {
    @Bindable var model: ReaderModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        ShelfSheet(title: "Search this PDF") {
            VStack(spacing: 0) {
                searchField

                if model.isSearching {
                    ProgressView("Searching pages…")
                        .padding(20)
                } else if !model.searchResults.isEmpty {
                    HStack {
                        Text("\(model.searchResults.count) matches")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ShelfTheme.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)
                }

                results
            }
            .onChange(of: model.searchText) { _, _ in model.search() }
            .onAppear {
                focused = true
                model.search()
            }
            .onDisappear { model.searchTask?.cancel() }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ShelfTheme.secondary)
            LeuTextField("Find a word or phrase", text: $model.searchText)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityIdentifier("pdf-search-input")
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(ShelfTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(16)
    }

    private var results: some View {
        List {
            if let error = model.errorMessage {
                Text(error).foregroundStyle(ShelfTheme.danger)
                Button("Dismiss error") { model.errorMessage = nil }
            }

            if !model.isSearching && model.searchText.count >= 2 && model.searchResults.isEmpty {
                Text("No matching text. Image-only scans can be read and bookmarked, but are not searchable without OCR.")
                    .foregroundStyle(ShelfTheme.secondary)
            }

            ForEach(model.searchResults) { match in
                Button {
                    focused = false
                    model.openSearchResult(match)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text("Page \(match.pageIndex + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ShelfTheme.accent)
                            if let section = model.sectionTitle(for: match.pageIndex) {
                                Text(section)
                                    .font(.caption)
                                    .foregroundStyle(ShelfTheme.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Text(highlighted(match.excerpt, query: model.searchText))
                            .font(.body)
                            .lineLimit(3)
                            .foregroundStyle(ShelfTheme.text)
                    }
                    .padding(.vertical, 8)
                }
                .accessibilityLabel("Match on page \(match.pageIndex + 1): \(match.excerpt)")
            }

            if model.searchResults.count == 200 {
                Text("First 200 matches. Refine your search.")
                    .font(.footnote)
                    .foregroundStyle(ShelfTheme.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func highlighted(_ excerpt: String, query: String) -> AttributedString {
        var result = AttributedString(excerpt)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty,
              let range = result.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) else { return result }
        result[range][AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = LeuDesign.signal
        result[range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = LeuDesign.onSignal
        result[range][AttributeScopes.SwiftUIAttributes.FontAttribute.self] = .body.bold()
        return result
    }
}
