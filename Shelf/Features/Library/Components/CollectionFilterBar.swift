import SwiftUI
import ShelfCore

@MainActor
struct CollectionFilterBar: View {
    @Bindable var model: LibraryModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", id: "all", selected: model.selectedCollectionID == nil) {
                        model.selectedCollectionID = nil
                    }
                    ForEach(model.collections) { collection in
                        chip(collection.name, id: collection.id.uuidString,
                             selected: model.selectedCollectionID == collection.id) {
                            model.selectedCollectionID = collection.id
                        }
                    }
                    Button { model.showCollections = true } label: {
                        Label("Edit", systemImage: "plus")
                            .font(.system(.subheadline, design: .serif))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 38)
                            .foregroundStyle(ShelfTheme.secondary)
                            .background(Color.clear, in: Capsule())
                            .overlay { Capsule().stroke(LeuDesign.separator, lineWidth: 0.7) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add or manage collections")
                }
                .padding(.horizontal, 1)
            }
            .onChange(of: model.selectedCollectionID) { _, selected in
                let target = selected?.uuidString ?? "all"
                withAnimation(.easeOut(duration: 0.20)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }

    private func chip(_ name: String, id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(.subheadline, design: .serif).weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 13)
                .frame(minHeight: 38)
                .foregroundStyle(selected ? LeuDesign.onSignal : ShelfTheme.secondary)
                .background(selected ? ShelfTheme.olive : ShelfTheme.surface, in: Capsule())
                .overlay { Capsule().stroke(selected ? ShelfTheme.olive : LeuDesign.separator, lineWidth: 0.7) }
        }
        .id(id)
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
