import SwiftUI
import ShelfCore

@MainActor
struct CollectionsSheet: View {
    let model: LibraryModel
    @State private var name = ""
    @State private var editing: BookCollection?
    @State private var deleteTarget: BookCollection?
    @State private var rename = ""
    var body: some View {
        ShelfSheet(title: "Your collections") {
            List {
                Section {
                    HStack {
                        LeuTextField("New collection", text: $name).submitLabel(.done)
                            .onSubmit { create() }.accessibilityIdentifier("collection-name-input")
                        Button("Add", action: create).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } footer: { Text("Collections do not duplicate your PDFs. Deleting a collection never deletes its documents.") }
                Section("Collections · drag to reorder") {
                    ForEach(model.collections) { collection in
                        HStack {
                            Image(systemName: "folder").foregroundStyle(ShelfTheme.accent)
                            Text(collection.name)
                            Spacer()
                            Button { rename = collection.name; editing = collection } label: {
                                Image(systemName: "pencil").frame(minWidth: 44, minHeight: 44)
                            }.buttonStyle(.borderless).accessibilityLabel("Rename " + collection.name)
                            Button(role: .destructive) { deleteTarget = collection } label: {
                                Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
                            }.buttonStyle(.borderless).accessibilityLabel("Delete collection " + collection.name)
                        }
                    }.onMove { source, destination in Task { await model.moveCollections(from: source, to: destination) } }
                }
                if let error = model.errorMessage { Text(error).foregroundStyle(ShelfTheme.danger) }
            }.environment(\.editMode, .constant(.active))
                .leuDialog("Rename collection", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
                    LeuTextField("Collection name", text: $rename)
                    Button("Save") {
                        if let collection = editing { Task { _ = await model.renameCollection(collection.id, name: rename) } }
                    }
                    Button("Cancel", role: .cancel) { editing = nil }
                }
                .leuDialog("Delete this collection? Your PDFs will stay in the library.",
                    isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
                        Button("Delete collection", role: .destructive) {
                            if let collection = deleteTarget { Task { await model.deleteCollection(collection.id) } }
                        }
                    }
        }.onAppear { model.errorMessage = nil }
    }
    private func create() {
        let value = name
        Task { if await model.createCollection(value) { name = "" } }
    }
}
