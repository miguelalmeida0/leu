import Foundation

public enum RelationshipKind: String, Codable, CaseIterable, Sendable {
    case related, prerequisite, example, contrast, buildsOn, sameIdea, custom
}

public struct LearningRelationship: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sourceObjectID: UUID
    public var targetObjectID: UUID
    public var kind: RelationshipKind
    public var customLabel: String?
    public var createdAt: Date
    public init(id: UUID = UUID(), sourceObjectID: UUID, targetObjectID: UUID,
                kind: RelationshipKind, customLabel: String? = nil, createdAt: Date = Date()) {
        self.id = id; self.sourceObjectID = sourceObjectID; self.targetObjectID = targetObjectID
        self.kind = kind; self.customLabel = customLabel; self.createdAt = createdAt
    }
}

public enum TrailNodeKind: String, Codable, Hashable, Sendable {
    case document, pageRange, learningObject, question, lab, mask, connection
}

public struct TrailNode: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: TrailNodeKind
    public var referenceID: UUID?
    public var documentID: UUID?
    public var pageRange: ClosedRange<Int>?
    public var title: String
    public var isOptional: Bool
    public init(id: UUID = UUID(), kind: TrailNodeKind, referenceID: UUID? = nil,
                documentID: UUID? = nil, pageRange: ClosedRange<Int>? = nil,
                title: String, isOptional: Bool = false) {
        self.id = id; self.kind = kind; self.referenceID = referenceID; self.documentID = documentID
        self.pageRange = pageRange; self.title = title; self.isOptional = isOptional
    }
}

public struct LearningTrail: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var nodes: [TrailNode]
    public var createdAt: Date
    public var currentNodeID: UUID?
    public init(id: UUID = UUID(), title: String, nodes: [TrailNode] = [], createdAt: Date = Date(), currentNodeID: UUID? = nil) {
        self.id = id; self.title = title; self.nodes = nodes; self.createdAt = createdAt
        self.currentNodeID = currentNodeID
    }
}
