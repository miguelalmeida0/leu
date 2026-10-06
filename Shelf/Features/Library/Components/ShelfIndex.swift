import ShelfCore
import SwiftUI

/// The shelf index down the left of the Library on iPad: everything, the books kept
/// close, recent ones, every shelf with its dye and count, and the quieter places (tags,
/// settings). Compact widths use the chip rows in `LibraryScopeBar` instead.
@MainActor
struct ShelfIndex: View {
    @Bindable var model: LibraryModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                section("Library")
                row("Everything", count: books.count, swatch: AnyShapeStyle(everythingDye),
                    selected: model.selectedTab == .library && model.selectedCollectionID == nil) {
                    select(.library, collection: nil)
                }
                row("Kept close", count: books.filter(\.isFavorite).count, swatch: AnyShapeStyle(LeuDesign.tomato),
                    selected: model.selectedTab == .favorites) { select(.favorites, collection: nil) }
                row("Recent", count: books.filter { $0.lastOpenedAt != nil }.count, swatch: AnyShapeStyle(LeuDesign.ink),
                    selected: model.selectedTab == .recents) { select(.recents, collection: nil) }

                section("Shelves")
                ForEach(model.collections) { collection in
                    row(collection.name, count: books.filter { $0.collectionIDs.contains(collection.id) }.count,
                        swatch: AnyShapeStyle(LeuDesign.conceptColor(for: collection.name)),
                        selected: model.selectedTab == .library && model.selectedCollectionID == collection.id) {
                        select(.library, collection: collection.id)
                    }
                }
                Button { model.showCollections = true } label: {
                    Label("New shelf", systemImage: "plus")
                        .font(.leu(.subheadline, weight: .semibold))
                        .foregroundStyle(LeuDesign.secondary)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: LeuDesign.touchTarget, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New shelf or manage shelves")
                .accessibilityIdentifier("library-new-shelf")

                section("More")
                row("Tags & marks", count: model.allTags.count, swatch: AnyShapeStyle(LeuDesign.oat),
                    selected: model.selectedTab == .tags) { select(.tags, collection: nil) }
                row("Settings", count: nil, swatch: AnyShapeStyle(LeuDesign.feltDeep),
                    selected: model.selectedTab == .settings) { select(.settings, collection: nil) }
            }
            .padding(.leading, 30)
            .padding(.trailing, 14)
            .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shelves")
        .accessibilityIdentifier("library-shelf-index")
    }

    private var books: [Book] { model.snapshot.activeBooks }

    /// Everything is every dye at once: four felt squares.
    private var everythingDye: some ShapeStyle {
        AngularGradient(colors: [LeuDesign.butter, LeuDesign.tomato, LeuDesign.denim, LeuDesign.moss, LeuDesign.butter],
                        center: .center)
    }

    private func section(_ title: String) -> some View {
        Text(title.uppercased())
            .font(LeuDesign.eyebrow(11))
            .tracking(LeuDesign.eyebrowTracking)
            .foregroundStyle(LeuDesign.eyebrowOnFelt)
            .padding(.horizontal, 12)
            .padding(.top, 20)
            .padding(.bottom, 6)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ title: String, count: Int?, swatch: AnyShapeStyle, selected: Bool,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(swatch)
                    .frame(width: 16, height: 16)
                    .overlay { RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(LeuDesign.ink.opacity(0.18), lineWidth: 0.75) }
                Text(title)
                    .font(.leu(.subheadline, weight: selected ? .bold : .semibold))
                    .foregroundStyle(LeuDesign.ink)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let count {
                    Text("\(count)")
                        .font(.leu(.caption, weight: .semibold).monospacedDigit())
                        .foregroundStyle(LeuDesign.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: LeuDesign.touchTarget)
            .background(selected ? LeuDesign.feltLight : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Switching tab resets the shelf (RootView clears scope on tab change), so a shelf is
    /// applied after the tab change has settled.
    private func select(_ tab: ShelfTab, collection: UUID?) {
        let tabChanges = model.selectedTab != tab
        model.selectedTab = tab
        model.selectedTag = nil
        if tabChanges {
            DispatchQueue.main.async {
                model.selectedCollectionID = collection
                model.updateSearch()
            }
        } else {
            model.selectedCollectionID = collection
            model.updateSearch()
        }
        ShelfHaptics.shared.play(.selectionChanged)
    }
}
