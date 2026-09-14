import Foundation
import ShelfCore

/// Versioned response shape for Explain like I'm 10.
///
/// This is NOT a request to change V26's `LearningModelCandidate`. The feature adapter
/// decodes the shared provider's structured explanation response into this shape.
/// The model returns content blocks and source-span references only; the application
/// attaches request/document identity, page labels, timestamps, provider identity and
/// cache metadata afterwards.
enum ExplanationSchema {
    static let version = 2
    static let validatorVersion = 2
    /// Normal range is 90-170 words. 220 is a hard ceiling, not a target.
    static let minimumWords = 90
    static let preferredMaximumWords = 170
    static let hardMaximumWords = 220
}

enum ExplanationMode: String, Codable, Sendable, CaseIterable {
    case standard
    case evenSimpler
    case withExample

    var cacheToken: String { rawValue }
}

/// One short content block. `kind` drives typography only; it is never shown as a label
/// like "subject" or "relation".
struct ExplanationBlock: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case plainMeaning
        case mechanism
        case example
        case caveat
    }
    var kind: Kind
    var text: String
    /// IDs of spans in the request packet this block draws on. A referenced span is a
    /// traceability signal, not proof the block follows from it.
    var sourceSpanIDs: [String]
}

/// What the model proposes. Nothing here is trusted until the validator runs, and the
/// validator checks structure and source identity, not semantic truth.
struct ExplanationCandidate: Codable, Equatable, Sendable {
    var blocks: [ExplanationBlock]
    /// A single technical term worth keeping, with a plain definition. Optional.
    var preservedTerm: String?
    var preservedTermMeaning: String?
    /// The model may refuse when the passage cannot be explained from itself alone.
    var needsContext: Bool
    var needsContextReason: String?

    init(blocks: [ExplanationBlock], preservedTerm: String? = nil,
         preservedTermMeaning: String? = nil, needsContext: Bool = false,
         needsContextReason: String? = nil) {
        self.blocks = blocks
        self.preservedTerm = preservedTerm
        self.preservedTermMeaning = preservedTermMeaning
        self.needsContext = needsContext
        self.needsContextReason = needsContextReason
    }

    var wordCount: Int {
        visibleText.split(whereSeparator: \.isWhitespace).count
    }

    var visibleText: String {
        (blocks.map(\.text) + [preservedTerm, preservedTermMeaning].compactMap { $0 }).joined(separator: " ")
    }
}

/// Application-attached metadata. Deliberately separate from the model's output so the
/// model is never asked to invent identity, timestamps or a model revision.
struct ExplanationRecord: Codable, Equatable, Sendable {
    var candidate: ExplanationCandidate
    var packet: ExplanationSourcePacket
    var mode: ExplanationMode
    var backend: String
    var availability: LearningModelState
    var schemaVersion: Int = ExplanationSchema.version
    var validatorVersion: Int = ExplanationSchema.validatorVersion
    var generatedAt: Date
    /// Set only when the OS actually exposes a model revision. Never fabricated.
    var providerRevision: String?
    var servedFromCache: Bool = false
}

/// Loads the versioned teaching prompt and appends the mode-specific instruction.
/// Kept next to the schema so prompt and schema version together form the cache key.
enum ExplanationPrompt {
    static let version = 3

    enum ResourceError: Error { case missingOrMismatchedPrompt }

    static func text(mode: ExplanationMode, bundle: Bundle = .main) throws -> String {
        guard let url = bundle.url(forResource: "RUNTIME_EXPLANATION_PROMPT", withExtension: "txt"),
              let base = try? String(contentsOf: url, encoding: .utf8),
              base.hasPrefix("RUNTIME_EXPLANATION_PROMPT — version \(version) ") else {
            throw ResourceError.missingOrMismatchedPrompt
        }
        return base + "\n\nACTIVE REFINEMENT: " + refinement(mode)
    }

    private static func refinement(_ mode: ExplanationMode) -> String {
        switch mode {
        case .standard:
            return "none. Produce the first explanation of the passage."
        case .evenSimpler:
            return "evenSimpler. Explain the SAME passage again using shorter sentences and more common words. Do not summarise a previous answer."
        case .withExample:
            return "withExample. Use ExplainedWithExample for a supported passage: explanation has kind plainMeaning; illustration has kind example. Generate one concise explanation and one distinct, concrete illustration or analogy that makes the supplied idea easier to understand. The illustration is imagined, not a new technical claim about the source. Keep all conditions and negations. Use MissingExplanationContext only if the source itself lacks necessary context."
        }
    }

}
