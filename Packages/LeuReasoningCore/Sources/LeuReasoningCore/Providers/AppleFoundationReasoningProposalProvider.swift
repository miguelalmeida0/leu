import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Optional on-device provider.
///
/// It may only ever *propose*. Everything it returns goes through
/// `ProposalAdmissionGate`, which requires a verbatim span and in-span subject
/// and object, so a hallucinated claim cannot enter the graph — it is counted
/// as a rejection instead.
///
/// The type compiles on every platform. Where Foundation Models is unavailable
/// it reports `isAvailable == false` and returns no proposals, and the engine
/// runs unchanged on the deterministic provider.
public struct AppleFoundationReasoningProposalProvider: ReasoningProposalProvider {
    public var identifier: String { "apple-foundation" }

    /// Used when the model is unavailable, and for the parts of extraction that
    /// must stay deterministic regardless of provider.
    private let fallback: DeterministicReasoningProposalProvider

    public init(fallback: DeterministicReasoningProposalProvider = DeterministicReasoningProposalProvider()) {
        self.fallback = fallback
    }

    public var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 18.2, macOS 15.2, *) {
            return AppleFoundationAvailability.isModelAvailable
        }
        return false
        #else
        return false
        #endif
    }

    public func proposeAtoms(for assignment: SourceRoleAssignment) async -> [AtomProposal] {
        guard isAvailable else { return await fallback.proposeAtoms(for: assignment) }
        #if canImport(FoundationModels)
        if #available(iOS 18.2, macOS 15.2, *) {
            let proposals = await AppleFoundationAtomProposer().propose(for: assignment)
            // Deterministic proposals are always included: the model may add
            // structure, never remove it.
            let deterministic = await fallback.proposeAtoms(for: assignment)
            var merged = deterministic
            for proposal in proposals where !merged.contains(proposal) { merged.append(proposal) }
            return merged
        }
        #endif
        return await fallback.proposeAtoms(for: assignment)
    }

    public func proposeRelations(among atoms: [KnowledgeAtom]) async -> [RelationProposal] {
        await fallback.proposeRelations(among: atoms)
    }

    public func proposeParaphrases(for proposition: LearnerProposition,
                                   candidates: [KnowledgeAtom]) async -> [ParaphraseProposal] {
        await fallback.proposeParaphrases(for: proposition, candidates: candidates)
    }
}

#if canImport(FoundationModels)
@available(iOS 18.2, macOS 15.2, *)
enum AppleFoundationAvailability {
    static var isModelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }
}

@available(iOS 18.2, macOS 15.2, *)
struct AppleFoundationAtomProposer {
    /// The prompt asks only for decomposition of text that is already present.
    /// It never asks the model for facts, explanations or judgements.
    static let instructions = """
    You decompose a sentence into claim structure. You never add information.
    For each claim in the sentence, output subject, relation, object, and any \
    condition, using only words that appear in the sentence. Use one of these \
    relations: enables, causes, prevents, requires, explains, contrastsWith, \
    exampleOf, consequenceOf, prerequisiteOf, failureOf, refines, scopes, qualifies.
    """

    func propose(for assignment: SourceRoleAssignment) async -> [AtomProposal] {
        let session = LanguageModelSession(instructions: AppleFoundationAtomProposer.instructions)
        var proposals: [AtomProposal] = []
        for sentence in TextScanning.sentences(in: assignment.block.text) {
            guard let response = try? await session.respond(to: sentence) else { continue }
            proposals.append(contentsOf: AppleFoundationAtomProposer.parse(response.content, span: sentence))
        }
        return proposals
    }

    /// Parses the model's lines. Anything malformed is dropped here; anything
    /// ungrounded is dropped later by the admission gate.
    static func parse(_ content: String, span: String) -> [AtomProposal] {
        var proposals: [AtomProposal] = []
        for line in content.split(separator: "\n") {
            let parts = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 3, RelationKind(rawValue: parts[1]) != nil else { continue }
            let conditions = parts.count > 3 && !parts[3].isEmpty
                ? [ClaimCondition(text: parts[3], isPositive: true, concepts: [TextScanning.conceptSlug(parts[3])])]
                : []
            proposals.append(AtomProposal(claimType: .mechanism,
                                          subject: parts[0],
                                          relation: parts[1],
                                          object: parts[2],
                                          conditions: conditions,
                                          claimedSpan: span))
        }
        return proposals
    }
}
#endif
