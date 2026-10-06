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

    @ScaledMetric(relativeTo: .headline) private var patchHeight: CGFloat = 112
    /// The quilt unfolds in handfuls so a large library never builds every patch at once.
    @State private var visibleCount = 24

    private var wide: Bool { sizeClass == .regular && !typeSize.isAccessibilitySize }

    var body: some View {
        content
            .background(LeuDesign.felt)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.query) { _, _ in model.updateSearch() }
            .onChange(of: model.selectedCollectionID) { _, _ in model.updateSearch(); visibleCount = 24 }
            .onChange(of: model.selectedTab) { _, _ in visibleCount = 24 }
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
        HStack(alignment: .top, spacing: 0) {
            if wide {
                ShelfIndex(model: model)
                    .frame(width: 270)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !wide {
                        LibraryScopeBar(model: model)
                    }
                    if showNeedle {
                        OnTheNeedle(books: needleBooks, model: model, knowledge: knowledge)
                    }
                    header
                    searchSection
                    selectedTag
                    recoveryNotice
                    operationProgress
                    documentArea
                }
                .padding(.horizontal, wide ? 28 : ShelfTheme.gutter)
                .padding(.top, 16)
                .padding(.bottom, 26)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        LibraryHeader(model: model, preferences: preferences) {
            presentPDFPicker()
        }
    }

    private var showNeedle: Bool {
        model.selectedTab == .library && model.selectedCollectionID == nil && model.query.isEmpty && !needleBooks.isEmpty
    }

    /// Books you are in the middle of, most recently touched first.
    private var needleBooks: [Book] {
        model.snapshot.activeBooks
            .filter { $0.lastOpenedAt != nil && $0.currentPageNumber < $0.pageCount }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            LibrarySearchBar(text: $model.query)
            if !wide && model.selectedTab == .library && !model.collections.isEmpty {
                Text("SHELVES")
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
                    .font(.leu(.callout, weight: .semibold)).foregroundStyle(ShelfTheme.accent)
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
                    .font(.leu(.callout))
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
                .font(.leu(.callout))
                .foregroundStyle(ShelfTheme.accent)
        }
    }

    @ViewBuilder
    private var operationProgress: some View {
        if let label = model.importLabel ?? model.operationLabel {
            HStack(spacing: 12) {
                ProgressView()
                Text(label)
                    .font(.leu(.callout))
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
        let books = model.filteredBooks
        if preferences.compactLibrary {
            LazyVStack(spacing: 0) {
                ForEach(books) { book in
                    BookListRow(book: book, model: model, knowledge: knowledge)
                }
            }
        } else {
            QuiltLayout(rowHeight: patchHeight, spacing: 12, idealUnitWidth: wide ? 210 : 160) {
                ForEach(books.prefix(visibleCount)) { book in
                    FeltBookPatch(
                        book: book,
                        model: model,
                        knowledge: knowledge,
                        cover: preferences.usePDFCovers ? (model.originalURL(book), thumbnails) : nil,
                        relationshipLift: relationshipLift(for: book),
                        onRelationshipProbe: { activateRelationships(from: book) }
                    )
                    .quiltWeight(Self.weight(for: book))
                }
            }
            if books.count > visibleCount {
                Button {
                    visibleCount += 24
                    ShelfHaptics.shared.play(.selectionChanged)
                } label: {
                    Text("Unfold \(min(24, books.count - visibleCount)) more")
                }
                .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .accessibilityIdentifier("library-unfold-more")
            }
        }

        if !model.query.isEmpty {
            PassageResultsView(model: model)
        }

        if model.query.isEmpty && !books.isEmpty {
            Text("\(books.count) PDFs · stored on this device")
                .font(.leu(.footnote))
                .foregroundStyle(ShelfTheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    /// Longer books are wider patches, gently: 1.0 for a short paper, up to 1.7 for a tome.
    static func weight(for book: Book) -> CGFloat {
        let pages = Double(max(book.pageCount, 1))
        return CGFloat(min(1.7, max(1.0, 0.75 + log10(pages) * 0.42)))
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.selectedTab == .library {
            EmptyLibraryState(
                symbol: model.selectedTab.symbol,
                title: emptyTitle,
                message: "Sew in a PDF. Give it a shelf. Pick up where you left off.",
                actionTitle: "Sew in a PDF",
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
