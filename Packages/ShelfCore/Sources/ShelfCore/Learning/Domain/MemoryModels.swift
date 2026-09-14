import Foundation

public enum RecallRating: String, Codable, CaseIterable, Sendable {
    case forgot, difficult, knewIt
}

public enum ConfidenceLevel: String, Codable, CaseIterable, Sendable {
    case guessing, unsure, fairlySure, certain

    public var numericValue: Double {
        switch self {
        case .guessing: return 0.2
        case .unsure: return 0.4
        case .fairlySure: return 0.65
        case .certain: return 0.9
        }
    }

    public var displayName: String {
        switch self {
        case .guessing: return "Guessing"
        case .unsure: return "Unsure"
        case .fairlySure: return "Fairly sure"
        case .certain: return "Certain"
        }
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "low": self = .guessing
        case "medium": self = .fairlySure
        case "high": self = .certain
        default:
            guard let value = ConfidenceLevel(rawValue: raw) else {
                throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Unknown confidence value")
            }
            self = value
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum MasteryState: String, Codable, CaseIterable, Sendable {
    case new, learning, strengthening, durable, due, fading
}

public struct ReviewState: Codable, Equatable, Sendable {
    public var learningObjectID: UUID
    public var lastReviewedAt: Date?
    public var nextReviewAt: Date?
    public var reviewCount: Int
    public var successfulRecalls: Int
    public var failedRecalls: Int
    public var difficulty: Double
    public var stability: Double
    public var importance: Double

    public init(learningObjectID: UUID, lastReviewedAt: Date? = nil, nextReviewAt: Date? = nil,
                reviewCount: Int = 0, successfulRecalls: Int = 0, failedRecalls: Int = 0,
                difficulty: Double = 0.5, stability: Double = 1, importance: Double = 0.5) {
        self.learningObjectID = learningObjectID; self.lastReviewedAt = lastReviewedAt
        self.nextReviewAt = nextReviewAt; self.reviewCount = reviewCount
        self.successfulRecalls = successfulRecalls; self.failedRecalls = failedRecalls
        self.difficulty = min(max(difficulty, 0), 1); self.stability = max(0.2, stability)
        self.importance = min(max(importance, 0), 1)
    }
}

public struct LearningAttempt: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var learningObjectID: UUID
    public var questionID: UUID?
    public var occurredAt: Date
    public var rating: RecallRating
    public var wasCorrect: Bool?
    public var confidence: ConfidenceLevel?
    public var responseTime: TimeInterval?
    public var hintCount: Int

    public init(id: UUID = UUID(), learningObjectID: UUID, questionID: UUID? = nil,
                occurredAt: Date = Date(), rating: RecallRating, wasCorrect: Bool? = nil,
                confidence: ConfidenceLevel? = nil, responseTime: TimeInterval? = nil,
                hintCount: Int = 0) {
        self.id = id; self.learningObjectID = learningObjectID; self.questionID = questionID
        self.occurredAt = occurredAt; self.rating = rating; self.wasCorrect = wasCorrect
        self.confidence = confidence; self.responseTime = responseTime; self.hintCount = max(0, hintCount)
    }
}

public struct TopicLearningState: Codable, Equatable, Sendable {
    public var topicID: UUID
    public var encounters: Int
    public var attempts: Int
    public var successfulRecalls: Int
    public var failedRecalls: Int
    public var averageConfidence: Double
    public var calibrationDelta: Double
    public var nextReviewAt: Date?
    public var state: MasteryState
}
