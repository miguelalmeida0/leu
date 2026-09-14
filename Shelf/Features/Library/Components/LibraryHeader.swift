import SwiftUI
import ShelfCore

@MainActor
struct LibraryHeader: View {
    @Bindable var model: LibraryModel
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    // The eyebrow states a fact about the product, not a slogan:
                    // everything here is local, which is the thing worth saying.
                    LeuEyebrow("On this device")
                    Text(title)
                        .leuScaledFont(40, weight: .bold, relativeTo: .largeTitle)
                        .tracking(LeuDesign.displayTracking)
                        .foregroundStyle(LeuDesign.text)
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 12)

                LeuMenu {
                    Picker("Sort by", selection: $model.sort) {
                        ForEach(LibrarySort.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    Divider()
                    Button("Manage collections", systemImage: "folder") { model.showCollections = true }
                    Button("Tags & marks", systemImage: "tag") { model.selectedTab = .tags }
                    Button("Settings", systemImage: "slider.horizontal.3") { model.selectedTab = .settings }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(LeuDesign.secondary)
                        .leuTapTarget()
                }
                .accessibilityLabel("Library options")
                .accessibilityIdentifier("library-options")

                Button(action: onImport) {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(LeuDesign.onSignal)
                        .frame(width: 46, height: 46)
                        .background(LeuDesign.signal, in: Circle())
                        .contentShape([.interaction, .accessibility], Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Import PDFs")
                .accessibilityIdentifier("import-pdf")
            }

            // Real counts, in the monospace metadata voice. No tagline.
            LeuMeta(subtitle)
        }
    }

    private var title: String {
        switch model.selectedTab {
        case .favorites: return "Kept close"
        case .recents: return "Recent"
        default: return "Library"
        }
    }

    /// States what is actually on the device rather than describing the screen.
    private var subtitle: String {
        let count = model.snapshot.activeBooks.count
        let sources = count == 1 ? "1 source" : "\(count) sources"
        switch model.selectedTab {
        case .favorites: return sources + " · kept close"
        case .recents: return sources + " · by last opened"
        default: return sources + " · stored locally"
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
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(ShelfTheme.secondary)
            LeuTextField("Search books and passages…", text: $text)
                .font(.system(.body, design: .serif))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .accessibilityIdentifier("library-search")
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 32, height: 44)
                }
                .foregroundStyle(ShelfTheme.secondary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(ShelfTheme.surface, in: RoundedRectangle(cornerRadius: ShelfTheme.smallRadius))
        .overlay { RoundedRectangle(cornerRadius: ShelfTheme.smallRadius).stroke(LeuDesign.separator, lineWidth: 0.7) }
    }
}

@MainActor
struct ContinueReadingHero: View {
    let book: Book
    let model: LibraryModel

    var body: some View {
        Button { model.open(book) } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONTINUE")
                            .font(ShelfTheme.eyebrow())
                            .tracking(2.2)
                            .foregroundStyle(ShelfTheme.accent)
                        Text("You were in the middle\nof a thought.")
                            .leuScaledFont(31, weight: .regular, design: .serif)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(ShelfTheme.text)
                        Text("Continue from page \(book.currentPageNumber).")
                            .font(.system(.subheadline, design: .serif).italic())
                            .foregroundStyle(ShelfTheme.secondary)
                    }
                    Spacer(minLength: 12)
                    ZStack {
                        Circle().fill(ShelfTheme.action).frame(width: 44, height: 44)
                        Image(systemName: "arrow.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(LeuDesign.onSignal)
                    }
                }

                Rectangle().fill(ShelfTheme.line).frame(height: 0.5)

                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CoverColors(book.palette).background)
                        .frame(width: 46, height: 64)
                        .overlay(alignment: .bottomLeading) {
                            Rectangle().fill(CoverColors(book.palette).shadow.opacity(0.7)).frame(height: 18)
                        }
                        .overlay { RoundedRectangle(cornerRadius: 4).stroke(ShelfTheme.line.opacity(0.8), lineWidth: 0.6) }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.title)
                            .leuScaledFont(18, weight: .regular, design: .serif)
                            .foregroundStyle(ShelfTheme.text)
                            .lineLimit(2)
                        Text("Page \(book.currentPageNumber) of \(book.pageCount)")
                            .font(.caption)
                            .foregroundStyle(ShelfTheme.secondary)
                        Text("Resume reading")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(1.4)
                            .foregroundStyle(ShelfTheme.action)
                    }
                    Spacer()
                }
            }
            .padding(20)
            .background(
                LeuDesign.surfaceSecondary,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(ShelfTheme.line, lineWidth: 0.8) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("continue-reading")
        .accessibilityLabel("Resume \(book.title) from page \(book.currentPageNumber)")
    }
}

