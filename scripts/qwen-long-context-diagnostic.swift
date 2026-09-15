import Foundation
import LeuReasoningCore
import LeuQwenRuntime

@main struct LongContextDiagnostic {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 3 else { fatalError("MODEL OUTPUT") }
        let output = URL(fileURLWithPath: args[2])
        guard !FileManager.default.fileExists(atPath: output.path) else { fatalError("Preserve prior diagnostic") }
        let source = String(repeating: "The ledger has routine entries. ", count: 260) + "Unlocking requires a green flag."
        let input = LocalExplanationInput(learner: "Unlocking requires a green flag.", question: "What does unlocking require?", passages: [
            .init(id: "s1", document: "fixture", page: 1, version: "long-context-v1", title: "Ledger", text: source)])
        let payload = String(decoding: try JSONEncoder().encode(input), as: UTF8.self)
        let run = try await EmbeddedQwen.shared.run(model: URL(fileURLWithPath: args[1]),
            system: LocalExplanationContract.prompt, input: payload, schema: try LocalExplanationContract.schema(for: input),
            context: 4096, maximumFootprint: 7_000_000_000, developmentCPUOnly: true)
        var report: [String: Any] = ["purpose": "Explicit diagnostic repeat of the failed long-context request values; does not replace the original failure",
            "original_payload_bytes_recorded": false, "retry_count": 1,
            "input_json": payload, "raw": try JSONSerialization.jsonObject(with: run.json),
            "context": 4096, "prompt_tokens": run.promptTokens, "output_tokens": run.outputTokens,
            "total_ms": run.totalMilliseconds, "peak_observed_footprint": run.peakObservedFootprint]
        do {
            let result = try LocalExplanationContract.validate(run.json, for: input)
            report["guarded"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result))
            report["claim_quote_contains_final_condition"] = result.claims.contains { $0.source_quote.contains("green flag") }
        } catch { report["validation_error"] = String(describing: error) }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output)
    }
}
