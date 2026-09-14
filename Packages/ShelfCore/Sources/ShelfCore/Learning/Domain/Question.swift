import Foundation

public enum QuestionKind: String, Codable, CaseIterable, Sendable {
    case definition, cloze, listMembership, termMatching, sourceStatement, fillKeyConcept, semanticRelationship, codeInterpretation
}

public struct QuestionOption: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public init(id: UUID = UUID(), text: String) { self.id = id; self.text = text }
}

public struct LearningQuestion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var stableKey: String
    public var kind: QuestionKind
    public var prompt: String
    public var options: [QuestionOption]
    public var correctOptionID: UUID
    public var source: LearningSource
    public var topicIDs: Set<UUID>
    public var qualityScore: Double
    public var generatedAt: Date
    public var semanticFingerprint: String?
    public var propositionID: String?
    public var semanticOperator: String?
    public var modelProvenance: LearningGenerationProvenance? = nil

    public init(id: UUID = UUID(), stableKey: String, kind: QuestionKind, prompt: String,
                options: [QuestionOption], correctOptionID: UUID, source: LearningSource,
                topicIDs: Set<UUID> = [], qualityScore: Double, generatedAt: Date = Date(),
                semanticFingerprint: String? = nil, propositionID: String? = nil,
                semanticOperator: String? = nil) {
        self.id = id; self.stableKey = stableKey; self.kind = kind; self.prompt = prompt
        self.options = options; self.correctOptionID = correctOptionID; self.source = source
        self.topicIDs = topicIDs; self.qualityScore = min(max(qualityScore, 0), 1)
        self.generatedAt = generatedAt
        self.semanticFingerprint = semanticFingerprint
        self.propositionID = propositionID
        self.semanticOperator = semanticOperator
    }

    public var correctOption: QuestionOption? { options.first { $0.id == correctOptionID } }
}
