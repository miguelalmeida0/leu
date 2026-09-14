import Foundation

public enum EmotionalCheckInPreference: String, Codable, CaseIterable, Sendable {
    case on, reduced, off
}

public enum StudyFeeling: String, Codable, CaseIterable, Sendable {
    case amazing, accomplished, irritated, drained

    public var displayName: String {
        switch self {
        case .amazing: return "Amazing"
        case .accomplished: return "Accomplished"
        case .irritated: return "Irritated"
        case .drained: return "Drained"
        }
    }
}

public struct EmotionalCheckIn: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var sessionID: UUID?
    public var feeling: StudyFeeling
    public var occurredAt: Date

    public init(id: UUID = UUID(), sessionID: UUID? = nil, feeling: StudyFeeling, occurredAt: Date = Date()) {
        self.id = id; self.sessionID = sessionID; self.feeling = feeling; self.occurredAt = occurredAt
    }
}

public struct ConfidenceRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var questionID: UUID
    public var propositionID: String?
    public var confidence: ConfidenceLevel
    public var wasCorrect: Bool
    public var occurredAt: Date

    public init(id: UUID = UUID(), questionID: UUID, propositionID: String?, confidence: ConfidenceLevel,
                wasCorrect: Bool, occurredAt: Date = Date()) {
        self.id = id; self.questionID = questionID; self.propositionID = propositionID
        self.confidence = confidence; self.wasCorrect = wasCorrect; self.occurredAt = occurredAt
    }
}

public struct EmotionalCheckInPolicy: Sendable {
    public init() {}

    public func shouldOffer(preference: EmotionalCheckInPreference, attempts: [LearningAttempt],
                            lastCheckIn: Date?, now: Date = Date()) -> Bool {
        guard preference != .off, attempts.count >= 3 else { return false }
        let cooldown: TimeInterval = preference == .reduced ? 60 * 60 * 24 * 10 : 60 * 60 * 24 * 3
        if let lastCheckIn, now.timeIntervalSince(lastCheckIn) < cooldown { return false }
        let misses = attempts.filter { $0.wasCorrect == false }.count
        let confidentMisses = attempts.filter { $0.wasCorrect == false && $0.confidence == .certain }.count
        return attempts.count >= 6 || misses >= 2 || confidentMisses >= 1
    }
}
