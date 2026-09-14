import Foundation

public enum KnowledgeConnectionType: String, Codable, CaseIterable, Sendable {
    case related, prerequisite, example, contrast, buildsOn, sameIdea, custom
}

public enum KnowledgeConnectionOrigin: String, Codable, Sendable {
    case suggested, user
}

public struct KnowledgeConnectionReason: Codable, Equatable, Hashable, Sendable {
    public var sharedConcepts: [String]
    public var sharedPhrases: [String]
    public var sourceHeading: String?
    public var destinationHeading: String?
    public var explanation: String

    public init(sharedConcepts: [String] = [], sharedPhrases: [String] = [],
                sourceHeading: String? = nil, destinationHeading: String? = nil,
                explanation: String) {
        self.sharedConcepts = sharedConcepts
        self.sharedPhrases = sharedPhrases
        self.sourceHeading = sourceHeading
        self.destinationHeading = destinationHeading
        self.explanation = explanation
    }
}

public struct KnowledgeConnection: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var sourcePassageID: UUID
    public var destinationPassageID: UUID
    public var type: KnowledgeConnectionType
    public var origin: KnowledgeConnectionOrigin
    public var score: Double?
    public var reason: KnowledgeConnectionReason?
    public var customLabel: String?
    public var createdAt: Date
    public var requiresRecovery: Bool

    public init(id: UUID = UUID(), sourcePassageID: UUID, destinationPassageID: UUID,
                type: KnowledgeConnectionType = .related, origin: KnowledgeConnectionOrigin,
                score: Double? = nil, reason: KnowledgeConnectionReason? = nil,
                customLabel: String? = nil, createdAt: Date = Date(), requiresRecovery: Bool = false) {
        self.id = id; self.sourcePassageID = sourcePassageID; self.destinationPassageID = destinationPassageID
        self.type = type; self.origin = origin; self.score = score; self.reason = reason
        self.customLabel = customLabel; self.createdAt = createdAt; self.requiresRecovery = requiresRecovery
    }
}

public extension KnowledgeConnectionType {
    var title: String {
        switch self {
        case .related: "Related"
        case .prerequisite: "Prerequisite"
        case .example: "Example"
        case .contrast: "Contrast"
        case .buildsOn: "Builds on"
        case .sameIdea: "Same idea"
        case .custom: "Custom"
        }
    }
}
