import SwiftUI
import ShelfCore

@MainActor
struct LibraryHeader: View {
    @Bindable var model: LibraryModel
    let preferences: AppPreferences
    let onImport: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(title)
                    .leuScaledFont(40, weight: .black, relativeTo: .largeTitle)
                    .tracking(LeuDesign.displayTracking)
                    .foregroundStyle(LeuDesign.text)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 12)
                if sizeClass != .regular { options }
                Button(action: onImport) {
                    Label("Sew in a PDF", systemImage: "plus")
                        .labelStyle(SewInLabelStyle(compact: sizeClass != .regular))
                }
                .buttonStyle(LeuPrimaryButtonStyle(filled: true, pill: true))
                .accessibilityLabel("Import PDFs")
                .accessibilityIdentifier("import-pdf")
            }
            // Real counts, in the metadata voice. No tagline.
            LeuMeta(subtitle, tint: LeuDesign.secondary)
            controls
        }
    }

    private var options: some View {
        LeuMenu {
            Button("Manage shelves", systemImage: "folder") { model.showCollections = true }
            Button("Tags & marks", systemImage: "tag") { model.selectedTab = .tags }
            Button("Settings", systemImage: "slider.horizontal.3") { model.selectedTab = .settings }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LeuDesign.secondary)
                .leuTapTarget()
        }
        .accessibilityLabel("Library options")
        .accessibilityIdentifier("library-options")
    }

    /// Sort in plain words, and patches or a list. Inline, so they are one tap away.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) { sortButtons; Spacer(minLength: 12); viewButtons }
            VStack(alignment: .leading, spacing: 4) { HStack(spacing: 18) { sortButtons }; HStack(spacing: 18) { viewButtons } }
        }
    }

    @ViewBuilder private var sortButtons: some View {
        textToggle("Recently touched", isOn: model.sort == .opened) { model.sort = .opened }
        textToggle("Added", isOn: model.sort == .added) { model.sort = .added }
        textToggle("A–Z", isOn: model.sort == .title) { model.sort = .title }
    }

    @ViewBuilder private var viewButtons: some View {
        textToggle("Patches", isOn: !preferences.compactLibrary) { preferences.compactLibrary = false }
        textToggle("List", isOn: preferences.compactLibrary) { preferences.compactLibrary = true }
    }

    private func textToggle(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            model.updateSearch()
            ShelfHaptics.shared.play(.selectionChanged)
        } label: {
            Text(title)
                .font(.leu(.subheadline, weight: isOn ? .bold : .semibold))
                .foregroundStyle(isOn ? LeuDesign.ink : LeuDesign.tertiary)
                .leuTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var title: String {
        switch model.selectedTab {
        case .favorites: return "Kept close"
        case .recents: return "Recent"
        default:
            if let id = model.selectedCollectionID, let shelf = model.collections.first(where: { $0.id == id }) {
                return shelf.name
            }
            return "Everything"
        }
    }

    /// States what is actually on the shelf rather than describing the screen.
    private var subtitle: String {
        let books = model.filteredBooks
        let sources = books.count == 1 ? "1 source" : "\(books.count) sources"
        let opened = books.filter { $0.lastOpenedAt != nil && $0.pageCount > 0 }
        guard !opened.isEmpty else { return sources + " · stored on this device" }
        let read = opened.reduce(0.0) { $0 + Double($1.currentPageNumber) / Double($1.pageCount) } / Double(books.count)
        let finished = opened.filter { $0.currentPageNumber >= $0.pageCount }.count
        return sources + " · about \(Int((read * 100).rounded()))% sewn" + (finished > 0 ? " · \(finished) finished" : "")
    }
}

/// "Sew in a PDF" with its plus; just the plus where width is tight.
private struct SewInLabelStyle: LabelStyle {
    let compact: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
            if !compact { configuration.title }
        }
    }
}

@MainActor
struct LibraryScopeBar: View {
    @Bindable var model: LibraryModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                scope("All", tab: .library, id: "library-filter-all")
                scope("Favorites", tab: .favorites, id: "library-filter-favorites")
                scope("Recents", tab: .recents, id: "library-filter-recents")
                LeuFilterPill(title: "Tags", isOn: false) {
                    model.selectedTab = .tags
                    ShelfHaptics.shared.play(.selectionChanged)
                }
                .accessibilityIdentifier("library-filter-tags")
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func scope(_ title: String, tab: ShelfTab, id: String) -> some View {
        LeuFilterPill(title: title, isOn: model.selectedTab == tab) {
            model.selectedTab = tab
            model.selectedTag = nil
            model.updateSearch()
            ShelfHaptics.shared.play(.selectionChanged)
        }
        .accessibilityIdentifier(id)
    }
}

@MainActor
struct LibrarySearchBar: View {
    @Binding var text: String
    var placeholder = "Search your books and passages"
    var identifier = "library-search"
    /// The larger field used by Search your books.
    var large = false
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.leu(.body, weight: .semibold))
                .foregroundStyle(LeuDesign.ink)
                .accessibilityHidden(true)
            // One field, drawn once: no field-inside-a-field.
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.leu(large ? .title3 : .body, weight: .medium))
                .foregroundStyle(LeuDesign.ink)
                .tint(LeuDesign.redThread)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit(onSubmit)
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.leu(large ? .title3 : .body, weight: .medium))
                            .foregroundStyle(LeuDesign.fieldPlaceholder)
                            .lineLimit(1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(placeholder)
                .accessibilityIdentifier(identifier)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.leu(.body)).frame(width: 36, height: 44)
                }
                .foregroundStyle(LeuDesign.secondary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, large ? 20 : 16)
        .frame(minHeight: large ? 60 : 50)
        .background(LeuDesign.cream, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(focused ? LeuDesign.ink : LeuDesign.separator, lineWidth: focused ? 1.5 : 0.75)
        }
        .shadow(color: LeuDesign.ink.opacity(focused ? 0.10 : 0.05), radius: 8, x: 0, y: 4)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture { focused = true }
        .animation(.easeInOut(duration: 0.25), value: focused)
    }
}

/// "On the needle": the books you are in the middle of, as patches, with the one you were
/// last in outlined. Replaces the old resume card. Never tree or foliage imagery; the
/// resume line names the real book and page.
@MainActor
struct OnTheNeedle: View {
    let books: [Book]
    let model: LibraryModel
    @Bindable var knowledge: KnowledgeModel
    @ScaledMetric(relativeTo: .headline) private var patchHeight: CGFloat = 108

    var body: some View {
        if let first = books.first {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    LeuEyebrow("On the needle", tint: LeuDesign.eyebrowOnFelt)
                    Text("You stopped on p. \(first.currentPageNumber) of \(first.title).")
                        .font(.leu(.subheadline, weight: .medium))
                        .foregroundStyle(LeuDesign.secondary)
                    Button("Pick it back up") { model.open(first) }
                        .font(.leu(.subheadline, weight: .bold))
                        .foregroundStyle(LeuDesign.ink)
                        .underline()
                        .buttonStyle(.plain)
                        .leuTapTarget()
                        .accessibilityIdentifier("continue-reading")
                }
                QuiltLayout(rowHeight: patchHeight, spacing: 12, idealUnitWidth: 260) {
                    ForEach(Array(books.prefix(3).enumerated()), id: \.element.id) { index, book in
                        FeltBookPatch(book: book, model: model, knowledge: knowledge, emphasis: index == 0)
                    }
                }
                StitchDivider().padding(.top, 8)
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// A long dashed seam between parts of a page.
struct StitchDivider: View {
    var body: some View {
        Line()
            .stroke(LeuDesign.separator, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            .frame(height: 2)
            .accessibilityHidden(true)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
