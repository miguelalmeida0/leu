import Foundation
import ShelfCore

/// An idea that turns up in your books, with the passages that say it.
struct ExploreIdea: Identifiable, Equatable {
    let concept: KnowledgeConcept
    let passages: [KnowledgePassage]
    var id: UUID { concept.id }
    var bookIDs: Set<UUID> { Set(passages.map(\.documentID)) }
}

/// Explore's reading of the library, built only from what the books contain: concepts the
/// index found (or you named) and the passages bound to them. Pure, so it is tested directly.
enum ExploreMap {
    /// The ideas that reach furthest across your books, widest first.
    static func ideas(in snapshot: KnowledgeSnapshot, limit: Int = 8) -> [ExploreIdea] {
        let available = Dictionary(snapshot.passages.filter(\.isAvailable).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var byConcept: [UUID: [UUID: KnowledgePassage]] = [:]
        for binding in snapshot.detectedBindings + snapshot.userBindings {
            if let passage = available[binding.passageID] { byConcept[binding.conceptID, default: [:]][passage.id] = passage }
        }
        let ideas: [ExploreIdea] = snapshot.concepts.compactMap { concept in
            guard let passages = byConcept[concept.id], !passages.isEmpty else { return nil }
            let ordered = passages.values.sorted { ($0.documentID.uuidString, $0.pageIndex) < ($1.documentID.uuidString, $1.pageIndex) }
            return ExploreIdea(concept: concept, passages: ordered)
        }
        return Array(ideas.sorted { a, b in
            if a.bookIDs.count != b.bookIDs.count { return a.bookIDs.count > b.bookIDs.count }
            if a.passages.count != b.passages.count { return a.passages.count > b.passages.count }
            return a.concept.name < b.concept.name
        }.prefix(limit))
    }

    /// Ideas that share pages with this one, then ideas that share books.
    static func neighbours(of idea: ExploreIdea, among ideas: [ExploreIdea], limit: Int = 3) -> [ExploreIdea] {
        let pages = Set(idea.passages.map { "\($0.documentID)|\($0.pageIndex)" })
        let scored = ideas.filter { $0.id != idea.id }.map { other -> (ExploreIdea, Int) in
            let sharedPages = other.passages.filter { pages.contains("\($0.documentID)|\($0.pageIndex)") }.count
            let sharedBooks = other.bookIDs.intersection(idea.bookIDs).count
            return (other, sharedPages * 10 + sharedBooks)
        }
        return scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    /// Where your books say it: one passage from each book, the most self-contained first.
    static func voices(of idea: ExploreIdea, limit: Int = 4) -> [KnowledgePassage] {
        var chosen: [UUID: KnowledgePassage] = [:]
        for passage in idea.passages {
            let length = passage.text.count
            guard length >= 40 else { continue }
            if let current = chosen[passage.documentID], abs(current.text.count - 220) <= abs(length - 220) { continue }
            chosen[passage.documentID] = passage
        }
        return Array(chosen.values.sorted { $0.text.count < $1.text.count }.prefix(limit))
    }
}
