import Foundation
import ShelfCore

extension KnowledgeModel {
    func createConcept(name: String, passageID: UUID? = nil) async -> KnowledgeConcept? {
        do {
            let concept = try await repository.createConcept(name: name)
            if let passageID { try await repository.bind(passageID: passageID, conceptID: concept.id) }
            snapshot = try await repository.snapshot()
            return concept
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func bind(passageID: UUID, to conceptID: UUID) async {
        do {
            try await repository.bind(passageID: passageID, conceptID: conceptID)
            snapshot = try await repository.snapshot()
            ShelfHaptics.shared.play(.objectConnected)
        } catch { errorMessage = error.localizedDescription }
    }

    func concepts(for passageID: UUID) -> [KnowledgeConcept] {
        let ids = Set((snapshot.detectedBindings + snapshot.userBindings)
            .filter { $0.passageID == passageID }.map(\.conceptID))
        return snapshot.concepts.filter { ids.contains($0.id) }.sorted { $0.name < $1.name }
    }

    func rebuildDerivedIndex() async {
        guard !isIndexing else { return }
        do {
            try await repository.clearDerivedIndex()
            snapshot = try await repository.snapshot()
            await syncLibrary()
        } catch { errorMessage = error.localizedDescription }
    }

    func createChain(title: String, passageIDs: [UUID] = []) async -> TopicChain? {
        do {
            var chain = try await repository.createChain(title: title)
            var seen = Set<UUID>()
            let unique = passageIDs.filter { seen.insert($0).inserted }
            chain.items = unique.enumerated().compactMap { index, id in
                guard let passage = snapshot.passages.first(where: { $0.id == id }) else { return nil }
                return TopicChainItem(chainID: chain.id, kind: .passage, passageID: id,
                    documentID: passage.documentID, pageIndex: passage.pageIndex,
                    sourcePreview: String(passage.text.prefix(180)), position: index)
            }
            try await repository.saveChain(chain)
            snapshot = try await repository.snapshot()
            ShelfHaptics.shared.play(.snapToTarget)
            return snapshot.topicChains.first(where: { $0.id == chain.id })
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func saveChain(_ chain: TopicChain) async {
        do {
            try await repository.saveChain(chain)
            snapshot = try await repository.snapshot()
        } catch { errorMessage = error.localizedDescription }
    }

    func addPassages(_ passageIDs: [UUID], to chainID: UUID) async {
        guard var chain = snapshot.topicChains.first(where: { $0.id == chainID }) else {
            errorMessage = "That Topic Chain is no longer available."
            return
        }
        var existing = Set(chain.items.compactMap(\.passageID))
        var nextPosition = chain.items.count
        var inserted = false
        for passageID in passageIDs where existing.insert(passageID).inserted {
            guard let passage = snapshot.passages.first(where: { $0.id == passageID }) else { continue }
            chain.items.append(TopicChainItem(chainID: chain.id, kind: .passage, passageID: passageID,
                documentID: passage.documentID, pageIndex: passage.pageIndex,
                sourcePreview: String(passage.text.prefix(180)), position: nextPosition))
            nextPosition += 1
            inserted = true
        }
        guard inserted else { return }
        await saveChain(chain)
        ShelfHaptics.shared.play(.snapToTarget)
    }

    func passage(_ id: UUID?) -> KnowledgePassage? {
        guard let id else { return nil }
        return snapshot.passages.first(where: { $0.id == id })
    }

    func concept(_ id: UUID?) -> KnowledgeConcept? {
        guard let id else { return nil }
        return snapshot.concepts.first(where: { $0.id == id })
    }

    func title(for documentID: UUID) -> String {
        library.snapshot.books.first(where: { $0.id == documentID })?.title ?? "Unavailable PDF"
    }
}
