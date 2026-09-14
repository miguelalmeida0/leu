import Foundation

public enum LearningObjectType: String, Codable, CaseIterable, Sendable {
    case passage, question, definition, recall, maskedRegion, connection
    case reconstruction, codeExercise, explanationRecording
}

public enum LearningObjectOrigin: String, Codable, Sendable {
    case documentAnalysis, userSelection, userAuthored, lab
}

public struct LearningObject: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var type: LearningObjectType
    public var source: LearningSource
    public var topicIDs: Set<UUID>
    public var title: String
    public var prompt: String?
    public var createdAt: Date
    public var importance: Double
    public var origin: LearningObjectOrigin
    /// Retained for history/trail references, excluded from new study planning.
    public var sourceIsStale: Bool? = nil

    public init(id: UUID = UUID(), type: LearningObjectType, source: LearningSource,
                topicIDs: Set<UUID> = [], title: String, prompt: String? = nil,
                createdAt: Date = Date(), importance: Double = 0.5,
                origin: LearningObjectOrigin = .userSelection) {
        self.id = id; self.type = type; self.source = source; self.topicIDs = topicIDs
        self.title = title; self.prompt = prompt; self.createdAt = createdAt
        self.importance = min(max(importance, 0), 1); self.origin = origin
    }
}

public struct LearningTopic: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var aliases: [String]
    public var isManual: Bool
    public init(id: UUID = UUID(), name: String, aliases: [String] = [], isManual: Bool = false) {
        self.id = id; self.name = name; self.aliases = aliases; self.isManual = isManual
    }
}
