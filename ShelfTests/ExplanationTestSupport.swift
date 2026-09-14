import Foundation
import ShelfCore
@testable import Shelf

/// TEST DOUBLE — NOT PRODUCTION INFERENCE.
///
/// This exists so the state machine, validator, cache and view can be exercised without
/// a model. It composes its text from the supplied source only, and it is never wired
/// into the shipping path: `ExplainLikeTenFeature.live` refuses to use it.
struct StubExplanationProvider: ExplanationIntelligenceProvider {
    let backend = "stub-test-double"
    var providerRevision: String? { nil }
    var state: LearningModelState = .available
    /// Set to force the refusal path in tests.
    var forceNeedsContext = false

    func availability() async -> LearningModelState { state }

    func explain(_ packet: ExplanationSourcePacket, mode: ExplanationMode, repairReasons: [String] = []) async throws -> ExplanationCandidate {
        guard state == .available else { throw LearningIntelligenceError.unavailable(state) }
        try Task.checkCancellation()
        if forceNeedsContext {
            return ExplanationCandidate(blocks: [], needsContext: true,
                                        needsContextReason: "The passage refers to something defined elsewhere.")
        }
        let sentence = packet.selectionText
            .split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            .first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? packet.selectionText
        var blocks: [ExplanationBlock] = [
            .init(kind: .plainMeaning, text: "\(sentence). " + String(repeating: "This restates the passage in plain words without adding anything. ", count: 2),
                  sourceSpanIDs: ["s1"]),
            .init(kind: .mechanism, text: String(repeating: "The passage explains the steps involved and the conditions under which they apply. ", count: 3),
                  sourceSpanIDs: ["s1"])
        ]
        if mode == .withExample {
            blocks.append(.init(kind: .example, text: "For instance, imagine the described situation happening once, with nothing else changing. This is an illustration, not a quotation.",
                                sourceSpanIDs: ["s1"]))
        }
        return ExplanationCandidate(blocks: blocks, needsContext: false)
    }
}
