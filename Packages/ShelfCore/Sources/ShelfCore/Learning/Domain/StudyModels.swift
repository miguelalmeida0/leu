import Foundation

public enum StudyActivityKind: String, Codable, CaseIterable, Sendable {
    case question, recall, mask, reconstruction, explain, continueReading
}

public struct StudyActivity: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: StudyActivityKind
    public var learningObjectID: UUID?
    public var questionID: UUID?
    public var title: String
    public var estimatedSeconds: Int
    public init(id: UUID = UUID(), kind: StudyActivityKind, learningObjectID: UUID? = nil,
                questionID: UUID? = nil, title: String, estimatedSeconds: Int) {
        self.id = id; self.kind = kind; self.learningObjectID = learningObjectID
        self.questionID = questionID; self.title = title; self.estimatedSeconds = max(15, estimatedSeconds)
    }
}

public enum StudySessionMode: String, Codable, Sendable { case learn, activeRecall, interview }

public struct StudySession: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var topicID: UUID?
    public var requestedMinutes: Int
    public var mode: StudySessionMode
    public var activities: [StudyActivity]
    public var createdAt: Date
    public var completedAt: Date?
    public init(id: UUID = UUID(), topicID: UUID? = nil, requestedMinutes: Int,
                mode: StudySessionMode = .learn, activities: [StudyActivity], createdAt: Date = Date(),
                completedAt: Date? = nil) {
        self.id = id; self.topicID = topicID; self.requestedMinutes = requestedMinutes
        self.mode = mode; self.activities = activities; self.createdAt = createdAt; self.completedAt = completedAt
    }
}

public struct ProgressiveHint: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var level: Int
    public var text: String
    public init(id: UUID = UUID(), level: Int, text: String) { self.id = id; self.level = level; self.text = text }
}
