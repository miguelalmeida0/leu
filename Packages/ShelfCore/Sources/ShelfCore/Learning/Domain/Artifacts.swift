import Foundation

public struct DiagramMask: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var learningObjectID: UUID
    public var source: LearningSource
    public var regions: [SourceBounds]
    public var label: String?
    public var createdAt: Date
    public init(id: UUID = UUID(), learningObjectID: UUID, source: LearningSource,
                regions: [SourceBounds], label: String? = nil, createdAt: Date = Date()) {
        self.id = id; self.learningObjectID = learningObjectID; self.source = source
        self.regions = regions; self.label = label; self.createdAt = createdAt
    }
}

public struct ExplanationRecording: Identifiable, Codable, Equatable, Sendable {
    public enum SelfRating: String, Codable, CaseIterable, Sendable { case shaky, okay, clear }
    public var id: UUID
    public var learningObjectID: UUID
    public var filename: String
    public var createdAt: Date
    public var duration: TimeInterval
    public var selfRating: SelfRating?
    public init(id: UUID = UUID(), learningObjectID: UUID, filename: String,
                createdAt: Date = Date(), duration: TimeInterval = 0, selfRating: SelfRating? = nil) {
        self.id = id; self.learningObjectID = learningObjectID; self.filename = filename
        self.createdAt = createdAt; self.duration = max(0, duration); self.selfRating = selfRating
    }
}

public enum TimelineEventKind: String, Codable, Sendable {
    case encountered, recalled, forgot, difficult, learned, connected, recorded, masked, session
}

public struct LearningTimelineEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var occurredAt: Date
    public var kind: TimelineEventKind
    public var title: String
    public var learningObjectID: UUID?
    public var source: LearningSource?
    public init(id: UUID = UUID(), occurredAt: Date = Date(), kind: TimelineEventKind,
                title: String, learningObjectID: UUID? = nil, source: LearningSource? = nil) {
        self.id = id; self.occurredAt = occurredAt; self.kind = kind; self.title = title
        self.learningObjectID = learningObjectID; self.source = source
    }
}
