import Foundation
import SpikeKit
#if canImport(FoundationModels)
import FoundationModels

// THROWAWAY — V37 capability spike only. Compiled only where Foundation Models exists (macOS 26,
// iOS 26); on Linux this module is empty and the runner offers only the fake model.

/// Apple's on-device model (SPIKE_SPEC §6): `SystemLanguageModel.default`, a fresh session per call,
/// greedy sampling, a hard timeout per call, and at most two retries after 2 s for `rateLimited`.
/// No prewarming, caching or streaming.
@available(macOS 26.0, iOS 26.0, *)
public struct FoundationModelsEngine: SpikeModel {
    public init() {}

    public static func availability() -> String {
        switch SystemLanguageModel.default.availability {
        case .available: return "available"
        case .unavailable(.deviceNotEligible): return "unavailable: device not eligible"
        case .unavailable(.appleIntelligenceNotEnabled): return "unavailable: Apple Intelligence is not enabled"
        case .unavailable(.modelNotReady): return "unavailable: model not ready (still downloading?)"
        case .unavailable(let reason): return "unavailable: \(reason)"
        }
    }

    public func respond(_ request: ModelRequest) async -> ModelResponse {
        let clock = ContinuousClock(), start = clock.now
        var retries = 0
        while true {
            let (status, json, end) = await attempt(request)
            if status == "rateLimited", retries < Settings.maxRetries {
                retries += 1
                try? await Task.sleep(for: .seconds(Settings.retryDelay))
                continue
            }
            return ModelResponse(status: status, latencyMs: SpikePipeline.milliseconds(start.duration(to: end)), retries: retries, json: json)
        }
    }

    /// One call raced against its timeout. The end is taken when the first of the two finishes.
    private func attempt(_ request: ModelRequest) async -> (String, String?, ContinuousClock.Instant) {
        await withTaskGroup(of: (String, String?).self) { group in
            group.addTask {
                do { return ("ok", try await Self.generate(request)) } catch { return (Self.classify(error), nil) }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(request.timeout))
                return ("timeout", nil)
            }
            let first = await group.next() ?? ("error", nil)
            let end = ContinuousClock.now
            group.cancelAll()
            return (first.0, first.1, end)
        }
    }

    @MainActor private static func generate(_ request: ModelRequest) async throws -> String {
        let session = LanguageModelSession(model: .default, tools: [], instructions: request.instructions)
        let response = try await session.respond(to: request.prompt, schema: try GenerationSchema(root: dynamic(request.schema), dependencies: []),
                                                 options: GenerationOptions(sampling: .greedy, maximumResponseTokens: request.maxTokens))
        return response.content.jsonString
    }

    static func dynamic(_ node: SchemaNode) -> DynamicGenerationSchema {
        switch node {
        case let .object(name, properties):
            return DynamicGenerationSchema(name: name, properties: properties.map {
                DynamicGenerationSchema.Property(name: $0.name, description: $0.description, schema: dynamic($0.node))
            })
        case let .choice(name, values): return DynamicGenerationSchema(name: name, anyOf: values)
        case .text: return DynamicGenerationSchema(type: String.self)
        case let .array(of, min, max): return DynamicGenerationSchema(arrayOf: dynamic(of), minimumElements: min, maximumElements: max)
        }
    }

    /// Named by the error's own description, so the classification survives SDK changes.
    static func classify(_ error: Error) -> String {
        let text = String(describing: error)
        // Diagnostics only (stderr, opt-in): the SDK's own error text, never learner text.
        if ProcessInfo.processInfo.environment["SPIKE_DEBUG_ERRORS"] != nil {
            FileHandle.standardError.write(Data(("SPIKE-ERROR " + text.prefix(600) + "\n").utf8))
        }
        if text.contains("exceededContextWindowSize") { return "contextOverflow" }
        if text.contains("guardrailViolation") || text.contains("refusal") { return "refused" }
        if text.contains("rateLimited") { return "rateLimited" }
        if text.contains("decodingFailure") || text.contains("unsupportedGuide") { return "schemaError" }
        if text.contains("assetsUnavailable") || text.contains("unsupportedLanguageOrLocale") { return "unavailable" }
        return "error"
    }
}
#endif
