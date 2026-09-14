import Foundation

public struct GroundedQuestionSelection: Codable, Equatable, Sendable {
    public let claimID: String
    public let cognitiveOperation: String
    public init(claimID: String, cognitiveOperation: String) {
        self.claimID = claimID; self.cognitiveOperation = cognitiveOperation
    }
}

public struct GroundedQuestionClaim: Codable, Equatable, Sendable {
    public let id: String
    public let concept: String
    public let cognitiveOperation: String
    public let relation: String
    public let predicate: String
    public let object: String
    public let qualifier: String?
    public let negated: Bool
    public let documentID: UUID
    public let pageIndex: Int
    public let evidence: CanonicalWhitespaceResolver.Span
    public let prompt: String
    /// The answer is the complete source assertion, including scope and qualifications.
    public var canonicalAnswer: String { evidence.text }
}

public struct QuestionRepresentability: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case representable, noRepresentableQuestion, noDefensibleChoices
    }
    public let status: Status
    public let meaningfulClaims: [GroundedQuestionClaim]
    public let selectableClaims: [GroundedQuestionClaim]
    public let questions: [LearningModelCandidate]
}

/// The model selects; source-derived realization owns all factual output. No network/model call here.
public struct GroundedQuestionRealizer: Sendable {
    public init() {}
    public func realize(_ selection: GroundedQuestionSelection,
                        from preflight: QuestionRepresentability) -> LearningModelCandidate? {
        preflight.questions.first { $0.selection == selection }
    }
}

/// Run this same preflight at the inference boundary and again during admission.
public enum GroundedQuestionGeneration {
    public static func generate(from packet: LearningSourcePacket,
        select: @Sendable (QuestionRepresentability) async throws -> GroundedQuestionSelection) async throws -> LearningModelCandidate {
        let preflight = QuestionV3Contract().compile(packet)
        guard preflight.status == .representable else { throw GroundedQuestionGenerationError.noRepresentableQuestion }
        let selection = try await select(preflight)
        guard let candidate = GroundedQuestionRealizer().realize(selection, from: preflight) else {
            throw LearningIntelligenceError.invalidResponse
        }
        return candidate
    }
}

public enum GroundedQuestionGenerationError: Error { case noRepresentableQuestion }
