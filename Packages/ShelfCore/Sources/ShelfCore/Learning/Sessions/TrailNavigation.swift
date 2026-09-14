import Foundation

public enum TrailNavigation {
    public static func source(for node: TrailNode, snapshot: LearningSnapshot) -> LearningSource? {
        switch node.kind {
        case .document, .pageRange:
            guard let id = node.documentID else { return nil }
            return LearningSource(documentID: id, pageIndex: node.pageRange?.lowerBound ?? 0, sourceText: "")
        case .learningObject: return snapshot.learningObjects.first { $0.id == node.referenceID }?.source
        case .question: return snapshot.questions.first { $0.id == node.referenceID }?.source
        case .mask: return snapshot.masks.first { $0.id == node.referenceID }?.source
        case .connection:
            guard let relationship = snapshot.relationships.first(where: { $0.id == node.referenceID }) else { return nil }
            return snapshot.learningObjects.first { $0.id == relationship.sourceObjectID }?.source
        case .lab: return nil
        }
    }

    public static func resumeNode(in trail: LearningTrail, availableIDs: Set<UUID>) -> TrailNode? {
        let start = trail.nodes.firstIndex { $0.id == trail.currentNodeID } ?? 0
        return trail.nodes.dropFirst(start).first { availableIDs.contains($0.id) }
            ?? trail.nodes.first { availableIDs.contains($0.id) }
    }
}
