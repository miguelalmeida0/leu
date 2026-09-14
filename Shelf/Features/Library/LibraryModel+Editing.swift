import Foundation
import SwiftUI
import ShelfCore

extension LibraryModel {
    func favorite(_ book: Book) async {
        _ = await perform { try await repository.updateBook(id: book.id) { $0.isFavorite.toggle() } }
    }
    func trash(_ book: Book) async {
        if await perform({ try await repository.trashBook(id: book.id) }) {
            announce("Moved to Trash. You can restore it in Settings.")
        }
    }
    func restore(_ book: Book) async {
        if await perform({ try await repository.restoreBook(id: book.id) }) { announce("Restored to your library.") }
    }
    func permanentlyDelete(_ book: Book) async {
        if await perform({ try await repository.permanentlyDelete(id: book.id, vault: vault, indexes: indexes) }) {
            announce("Permanently deleted from Leu.")
        }
    }
    func saveDetails(id: UUID, draft: BookDetailsDraft) async -> Bool {
        let tags = Array(Set(draft.tags.split(separator: ",").map {
            String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        }.filter { !$0.isEmpty })).sorted()
        return await perform {
            try await repository.updateBook(id: id) { book in
                book.title = draft.title; book.tags = Array(tags.prefix(30))
                book.collectionIDs = draft.collectionIDs
                book.palette = draft.palette; book.artwork = draft.artwork
            }
        }
    }
    func createCollection(_ name: String) async -> Bool {
        await perform { _ = try await repository.createCollection(name: name) }
    }
    func renameCollection(_ id: UUID, name: String) async -> Bool {
        await perform { try await repository.renameCollection(id: id, name: name) }
    }
    func deleteCollection(_ id: UUID) async {
        if await perform({ try await repository.deleteCollection(id: id) }), selectedCollectionID == id {
            selectedCollectionID = nil
        }
    }
    func moveCollections(from source: IndexSet, to destination: Int) async {
        var ids = collections.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        _ = await perform { try await repository.reorderCollections(ids: ids) }
    }
    func chooseTag(_ tag: String) {
        selectedTag = tag; selectedCollectionID = nil; query = ""; selectedTab = .library
    }
    func removeSamples() async {
        if await perform({
            for book in snapshot.activeBooks where book.isSample {
                try await repository.trashBook(id: book.id)
            }
        }) { announce("Sample PDFs moved to Trash. Your imports are unchanged.") }
    }
}
