import Foundation
import ShelfCore

/// The feature's adapter boundary.
///
/// Uses the additive LearningExplanationCapable capability on the shared Apple provider.
/// Question generation keeps its existing contract and validation pipeline.
protocol ExplanationIntelligenceProvider: Sendable {
    var backend: String { get }
    /// Model revision only when the platform actually exposes one. Never fabricated.
    var providerRevision: String? { get }
    func availability() async -> LearningModelState
    func explain(_ packet: ExplanationSourcePacket, mode: ExplanationMode, repairReasons: [String]) async throws -> ExplanationCandidate
}

extension ExplanationIntelligenceProvider {
    var providerRevision: String? { nil }
}

/// Production adapter. The shared provider owns inference; a missing capability reports
/// unavailable instead of substituting generated-looking text.
struct V26ExplanationAdapter: ExplanationIntelligenceProvider {
    typealias Explain = @Sendable (ExplanationSourcePacket, ExplanationMode, [String]) async throws -> ExplanationCandidate

    let backend: String
    let providerRevision: String?
    private let sharedAvailability: @Sendable () async -> LearningModelState
    private let sharedExplain: Explain?

    /// - Parameter explain: shared provider capability; nil reports unavailable.
    init(backend: String, providerRevision: String? = nil,
         availability: @escaping @Sendable () async -> LearningModelState,
         explain: Explain? = nil) {
        self.backend = backend
        self.providerRevision = providerRevision
        self.sharedAvailability = availability
        self.sharedExplain = explain
    }

    func availability() async -> LearningModelState {
        guard sharedExplain != nil else { return .unavailable }
        return await sharedAvailability()
    }

    func explain(_ packet: ExplanationSourcePacket, mode: ExplanationMode, repairReasons: [String]) async throws -> ExplanationCandidate {
        guard let sharedExplain else { throw LearningIntelligenceError.unavailable(.unavailable) }
        let state = await sharedAvailability()
        guard state == .available else { throw LearningIntelligenceError.unavailable(state) }
        guard packet.extractionVersion >= SourceExtractionVersion.current, !packet.selectionText.isEmpty else {
            throw LearningIntelligenceError.sourceIntegrityFailed
        }
        try Task.checkCancellation()
        do { return try await sharedExplain(packet, mode, repairReasons) }
        catch is DecodingError { throw LearningIntelligenceError.invalidResponse }
    }
}

/// Composition root for the feature.
///
/// The reader composes this with AppleLearningIntelligenceProvider and the local cache.
enum ExplainLikeTenFeature {
    @MainActor
    static func live(sharedAvailability: @escaping @Sendable () async -> LearningModelState,
                     sharedExplain: V26ExplanationAdapter.Explain?,
                     backend: String,
                     providerRevision: String? = nil, cache: ExplanationCache? = nil) -> ExplanationController {
        let adapter = V26ExplanationAdapter(backend: backend, providerRevision: providerRevision,
                                            availability: sharedAvailability, explain: sharedExplain)
        return ExplanationController(provider: adapter, cache: cache)
    }

    @MainActor static func live(provider: any LearningIntelligenceProvider & LearningExplanationCapable,
                               cache: ExplanationCache) -> ExplanationController {
        live(sharedAvailability: { await provider.availability() }, sharedExplain: { packet, mode, failures in
            var instructions = try ExplanationPrompt.text(mode: mode)
            if !failures.isEmpty { instructions += "\nRepair the previous structural rejection: " + failures.joined(separator: ", ") }
            instructions += "\nRespond in language code: " + packet.language
            let request = LearningExplanationRequest(promptBody: packet.promptBody, instructions: instructions,
                allowedSpanIDs: packet.allowedSpanIDs.sorted(), maximumWords: ExplanationSchema.hardMaximumWords,
                requiresExample: mode == .withExample)
            ExplanationAttemptTrace.modelRequest(request)
            let json = try await provider.generateExplanationJSON(request)
            ExplanationAttemptTrace.rawResult(json)
            guard json.utf16.count <= 20_000 else { throw LearningIntelligenceError.invalidResponse }
            return try JSONDecoder().decode(ExplanationCandidate.self, from: Data(json.utf8))
        }, backend: provider.backend, cache: cache)
    }

    /// TEST DOUBLE ONLY. Never call from production code paths.
    @MainActor
    static func harness(provider: ExplanationIntelligenceProvider) -> ExplanationController {
        ExplanationController(provider: provider)
    }
}
