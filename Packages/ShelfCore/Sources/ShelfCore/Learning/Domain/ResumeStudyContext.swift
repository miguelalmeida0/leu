import Foundation

/// A committed study checkpoint. Optional additions preserve V24.0/V24.1 snapshots.
public struct ResumeStudyContext: Codable, Equatable, Sendable {
    public var sessionID: UUID?
    public var activityIndex: Int
    public var updatedAt: Date
    public var questionID: UUID?
    public var selectedAnswerID: UUID?
    public var selectedConfidence: ConfidenceLevel?
    public var answerCommitted: Bool
    public var revealedHintCount: Int

    public init(sessionID: UUID? = nil, activityIndex: Int = 0, updatedAt: Date = Date(),
                questionID: UUID? = nil, selectedAnswerID: UUID? = nil,
                selectedConfidence: ConfidenceLevel? = nil, answerCommitted: Bool = false,
                revealedHintCount: Int = 0) {
        self.sessionID = sessionID; self.activityIndex = max(0, activityIndex); self.updatedAt = updatedAt
        self.questionID = questionID; self.selectedAnswerID = selectedAnswerID
        self.selectedConfidence = selectedConfidence; self.answerCommitted = answerCommitted
        self.revealedHintCount = max(0, revealedHintCount)
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID, activityIndex, updatedAt, questionID, selectedAnswerID, selectedConfidence
        case answerCommitted, revealedHintCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try c.decodeIfPresent(UUID.self, forKey: .sessionID)
        activityIndex = max(0, try c.decode(Int.self, forKey: .activityIndex))
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        questionID = try c.decodeIfPresent(UUID.self, forKey: .questionID)
        selectedAnswerID = try c.decodeIfPresent(UUID.self, forKey: .selectedAnswerID)
        selectedConfidence = try c.decodeIfPresent(ConfidenceLevel.self, forKey: .selectedConfidence)
        answerCommitted = try c.decodeIfPresent(Bool.self, forKey: .answerCommitted) ?? false
        revealedHintCount = max(0, try c.decodeIfPresent(Int.self, forKey: .revealedHintCount) ?? 0)
    }
}

public enum StudyCheckpointError: LocalizedError, Equatable {
    case inconsistentSession
    public var errorDescription: String? { "The study checkpoint does not match an active session." }
}
