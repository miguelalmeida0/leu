import Foundation

public struct ConceptAlias: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var conceptID: UUID
    public var value: String

    public init(id: UUID, conceptID: UUID, value: String) {
        self.id = id; self.conceptID = conceptID; self.value = value
    }
}

public struct KnowledgeConcept: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var parentID: UUID?
    public var pack: String?
    public var isUserCreated: Bool
    public var createdAt: Date

    public init(id: UUID, name: String, parentID: UUID? = nil, pack: String? = nil,
                isUserCreated: Bool = false, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.parentID = parentID; self.pack = pack
        self.isUserCreated = isUserCreated; self.createdAt = createdAt
    }
}

public struct PassageConceptBinding: Codable, Equatable, Hashable, Sendable {
    public var passageID: UUID
    public var conceptID: UUID
    public var source: Source

    public enum Source: String, Codable, Sendable { case detected, user }

    public init(passageID: UUID, conceptID: UUID, source: Source) {
        self.passageID = passageID; self.conceptID = conceptID; self.source = source
    }
}
