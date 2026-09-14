import SwiftUI
import ShelfCore

@MainActor
struct LibraryScreen: View {
    @Bindable var model: LibraryModel
    let preferences: AppPreferences
    let thumbnails: PDFThumbnailService
    @Bindable var knowledge: KnowledgeModel

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showingPDFPicker = false
    @State private var activeRelationshipBookID: UUID?
    @State private var knowledgeSearchPresented = false

    private var columnCount: Int {
        if typeSize.isAccessibilitySize { return 1 }
        return sizeClass == .regular ? 3 : 2
    }

    var body: some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.query) { _, _ in model.updateSearch() }
            .onChange(of: model.selectedCollectionID) { _, _ in model.updateSearch() }
            .sheet(isPresented: $knowledgeSearchPresented) { KnowledgeSearchSheet(knowledge: knowledge) }
            .sheet(isPresented: $showingPDFPicker) {
                PDFDocumentPickerView(
                    didPick: { urls in handlePickedPDFs(urls) },
                    didCancel: { dismissPDFPicker() }
                )
                .ignoresSafeArea()
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("library-screen")
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                LibraryScopeBar(model: model)
                if let recentBook, model.selectedTab == .library, model.query.isEmpty {
                    ContinueReadingHero(book: recentBook, model: model)
                }
                searchSection
                selectedTag
                recoveryNotice
                operationProgress
                documentArea
            }
            .padding(.horizontal, ShelfTheme.gutter)
            .padding(.top, 16)
            .padding(.bottom, 26)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
    }

    private var header: some View {
        LibraryHeader(model: model) {
            presentPDFPicker()
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            LibrarySearchBar(text: $model.query)
            if model.selectedTab == .library && !model.collections.isEmpty {
                Text("COLLECTIONS")
                    .font(ShelfTheme.eyebrow())
                    .tracking(1.8)
                    .foregroundStyle(ShelfTheme.secondary)
                CollectionFilterBar(model: model)
            }
            if !model.query.isEmpty {
                Button {
                    knowledge.searchText = model.query
                    knowledge.search()
                    knowledgeSearchPresented = true
                } label: {
                    HStack {
                        Image(systemName: "text.magnifyingglass")
                        Text("Search concepts, passages and Topic Chains")
                        Spacer(); Image(systemName: "arrow.up.right")
                    }
                    .font(.callout.weight(.semibold)).foregroundStyle(ShelfTheme.accent)
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library-knowledge-search")
            }
        }
    }

    @ViewBuilder
    private var selectedTag: some View {
        if let tag = model.selectedTag {
            HStack {
                Label(tag, systemImage: "tag")
                    .font(.callout)
                Button("Clear") {
                    model.selectedTag = nil
                    model.updateSearch()
                }
                .foregroundStyle(ShelfTheme.accent)
            }
        }
    }

    @ViewBuilder
    private var recoveryNotice: some View {
        if model.recoveredMetadata {
            Text("Leu recovered its previous metadata checkpoint. Recent changes may need review. Original PDFs were preserved.")
                .font(.callout)
                .foregroundStyle(ShelfTheme.accent)
        }
    }

    @ViewBuilder
    private var operationProgress: some View {
        if let label = model.importLabel ?? model.operationLabel {
            HStack(spacing: 12) {
                ProgressView()
                Text(label)
                    .font(.callout)
                    .lineLimit(2)
            }
            .accessibilityLabel("Working: \(label)")
        }
    }

    @ViewBuilder
    private var documentArea: some View {
        if model.filteredBooks.isEmpty && model.query.isEmpty {
            emptyState
        } else {
            populatedLibrary
        }
    }

    @ViewBuilder
    private var populatedLibrary: some View {
        if preferences.compactLibrary {
            LazyVStack(spacing: 0) {
                ForEach(model.filteredBooks) { book in
                    BookListRow(book: book, model: model, knowledge: knowledge)
                }
            }
        } else {
            LazyVGrid(columns: gridColumns, spacing: 18) {
                ForEach(model.filteredBooks) { book in
                    BookTile(
                        book: book,
                        model: model,
                        preferences: preferences,
                        thumbnails: thumbnails,
                        knowledge: knowledge,
                        relationshipLift: relationshipLift(for: book),
                        onRelationshipProbe: { activateRelationships(from: book) }
                    )
                }
            }
        }

        if !model.query.isEmpty {
            PassageResultsView(model: model)
        }

        if model.query.isEmpty && !model.filteredBooks.isEmpty {
            Text("\(model.filteredBooks.count) PDFs · stored on this iPhone")
                .font(.footnote)
                .foregroundStyle(ShelfTheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 14),
            count: columnCount
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.selectedTab == .library {
            EmptyLibraryState(
                symbol: model.selectedTab.symbol,
                title: emptyTitle,
                message: "Import a PDF. Give it a place. Pick up where you left off.",
                actionTitle: "Import PDFs",
                action: { presentPDFPicker() }
            )
        } else if model.selectedTab == .favorites {
            EmptyLibraryState(
                symbol: "heart",
                title: "No favorites yet.",
                message: "Favorite a PDF you want to keep close.",
                actionTitle: "Browse library",
                action: { model.selectedTab = .library }
            )
        } else {
            EmptyLibraryState(
                symbol: "clock",
                title: "Nothing recent yet.",
                message: "Open a PDF and it will appear here for quick return.",
                actionTitle: "Browse library",
                action: { model.selectedTab = .library }
            )
        }
    }

    private var emptyTitle: String {
        switch model.selectedTab {
        case .favorites:
            return "Keep the good ones close."
        case .recents:
            return "A place to pick up again."
        default:
            return model.selectedCollectionID == nil
                ? "No PDFs yet."
                : "No PDFs in this collection."
        }
    }

    private func relationshipLift(for book: Book) -> Double {
        guard let source = activeRelationshipBookID, source != book.id else { return 0 }
        return knowledge.documentRelationshipStrengths(from: source)[book.id] ?? 0
    }

    private func activateRelationships(from book: Book) {
        guard !knowledge.snapshot.indexRecords.isEmpty else { return }
        activeRelationshipBookID = book.id
        ShelfHaptics.shared.play(.selectionChanged)
        Task {
            try? await Task.sleep(for: .seconds(1.35))
            guard !Task.isCancelled, activeRelationshipBookID == book.id else { return }
            activeRelationshipBookID = nil
        }
    }

    private var recentBook: Book? {
        model.snapshot.activeBooks
            .filter { $0.lastOpenedAt != nil }
            .max { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) }
    }

    private func presentPDFPicker() {
        guard !model.busy else {
            model.announce("Finish the current library operation first.")
            return
        }

        model.errorMessage = nil
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        showingPDFPicker = true
    }

    private func handlePickedPDFs(_ urls: [URL]) {
        showingPDFPicker = false
        guard !urls.isEmpty else { return }
        model.importPickerResult(.success(urls))
    }

    private func dismissPDFPicker() {
        showingPDFPicker = false
    }
}
