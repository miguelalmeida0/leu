import Foundation

public extension LibraryRepository {
    @discardableResult
    func createCollection(name: String) throws -> BookCollection {
        let cleaned = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !cleaned.isEmpty else { throw ShelfError.emptyTitle }
        return try transaction { snapshot in
            guard !snapshot.collections.contains(where: { $0.name.normalizedSearch == cleaned.normalizedSearch }) else {
                throw ShelfError.duplicateCollection
            }
            let collection = BookCollection(name: cleaned, order: snapshot.collections.count)
            snapshot.collections.append(collection)
            return collection
        }
    }

    func renameCollection(id: UUID, name: String) throws {
        let cleaned = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !cleaned.isEmpty else { throw ShelfError.emptyTitle }
        try transaction { snapshot in
            guard let index = snapshot.collections.firstIndex(where: { $0.id == id }) else { throw ShelfError.notFound }
            guard !snapshot.collections.contains(where: {
                $0.id != id && $0.name.normalizedSearch == cleaned.normalizedSearch
            }) else { throw ShelfError.duplicateCollection }
            snapshot.collections[index].name = cleaned
        }
    }

    func deleteCollection(id: UUID) throws {
        try transaction { snapshot in
            snapshot.collections.removeAll { $0.id == id }
            for index in snapshot.books.indices { snapshot.books[index].collectionIDs.remove(id) }
        }
    }

    func reorderCollections(ids: [UUID]) throws {
        try transaction { snapshot in
            guard Set(ids) == Set(snapshot.collections.map(\.id)), ids.count == snapshot.collections.count else {
                throw ShelfError.notFound
            }
            for (order, id) in ids.enumerated() {
                if let index = snapshot.collections.firstIndex(where: { $0.id == id }) {
                    snapshot.collections[index].order = order
                }
            }
        }
    }
}
