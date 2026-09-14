import Foundation

public enum TopicChainItemKind: String, Codable, Sendable {
    case passage, highlight, concept, note
}

public struct TopicChainItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var chainID: UUID
    public var kind: TopicChainItemKind
    public var passageID: UUID?
    public var annotationID: UUID?
    public var conceptID: UUID?
    public var documentID: UUID?
    public var pageIndex: Int?
    public var sourcePreview: String?
    public var annotation: String?
    public var position: Int

    public init(id: UUID = UUID(), chainID: UUID, kind: TopicChainItemKind,
                passageID: UUID? = nil, annotationID: UUID? = nil, conceptID: UUID? = nil,
                documentID: UUID? = nil, pageIndex: Int? = nil, sourcePreview: String? = nil,
                annotation: String? = nil, position: Int) {
        self.id = id; self.chainID = chainID; self.kind = kind; self.passageID = passageID
        self.annotationID = annotationID; self.conceptID = conceptID; self.documentID = documentID
        self.pageIndex = pageIndex; self.sourcePreview = sourcePreview; self.annotation = annotation
        self.position = max(0, position)
    }
}

public struct TopicChain: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var conceptID: UUID?
    public var pinned: Bool
    public var items: [TopicChainItem]

    public init(id: UUID = UUID(), title: String, createdAt: Date = Date(), updatedAt: Date = Date(),
                conceptID: UUID? = nil, pinned: Bool = false, items: [TopicChainItem] = []) {
        self.id = id; self.title = title; self.createdAt = createdAt; self.updatedAt = updatedAt
        self.conceptID = conceptID; self.pinned = pinned; self.items = items
    }
}
