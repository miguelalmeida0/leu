import Foundation

/// An additive task capability; question generation keeps its existing contract.
public struct LearningExplanationRequest: Codable, Equatable, Sendable {
    public var promptBody: String
    public var instructions: String
    public var allowedSpanIDs: [String]
    public var maximumWords: Int
    public var requiresExample: Bool

    public init(promptBody: String, instructions: String, allowedSpanIDs: [String], maximumWords: Int,
                requiresExample: Bool = false) {
        self.promptBody = promptBody
        self.instructions = instructions
        self.allowedSpanIDs = allowedSpanIDs
        self.maximumWords = maximumWords
        self.requiresExample = requiresExample
    }

    private enum CodingKeys: String, CodingKey { case promptBody, instructions, allowedSpanIDs, maximumWords, requiresExample }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        promptBody = try values.decode(String.self, forKey: .promptBody)
        instructions = try values.decode(String.self, forKey: .instructions)
        allowedSpanIDs = try values.decode([String].self, forKey: .allowedSpanIDs)
        maximumWords = try values.decode(Int.self, forKey: .maximumWords)
        requiresExample = try values.decodeIfPresent(Bool.self, forKey: .requiresExample) ?? false
    }
}

public protocol LearningExplanationCapable: Sendable {
    func generateExplanationJSON(_ request: LearningExplanationRequest) async throws -> String
}
