import Foundation
import LeuReasoningCore
import ShelfCore
import LeuQwenRuntime

struct QwenCase: Decodable {
    let id, split, category, source, learner, title: String
    let question: String?
}
@main struct Benchmark {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count >= 5 else { fatalError("qwen-benchmark FIXTURES MODEL CONTEXT OUTPUT [verify]") }
        guard EmbeddedQwen.available else { fatalError("Native module is unavailable; no inference attempted") }
        let cases = try JSONDecoder().decode([QwenCase].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
        let model = URL(fileURLWithPath: args[2]), context = Int(args[3])!
        let output = URL(fileURLWithPath: args[4])
        guard !FileManager.default.fileExists(atPath: output.path) else { fatalError("Refusing to overwrite results") }
        try Data().write(to: output)
        let file = try FileHandle(forWritingTo: output); defer { try? file.close() }
        let verify = args.last == "verify"
        for item in cases {
            let document = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            var page = AnalyzedPage(pageIndex: 0, normalizedText: item.source,
                segments: [.init(pageIndex: 0, kind: .paragraph, text: item.source, sectionTitle: item.title)])
            page.canonicalText = item.source; page.spatialIntegrityPassed = true
            var analysis = DocumentAnalysis(documentID: document, fingerprint: item.id, algorithmVersion: 5, pages: [page])
            analysis.extractionVersion = SourceExtractionVersion.current
            let analyses = [document: analysis]
            let facts = RelationalSourceFact.extract(analysis: analysis, documentTitle: item.title)
            let baseline = TeachReasoningAdapter(sources: facts, analyses: analyses).compare(item.learner, analyses: analyses)
            var row: [String: Any] = ["id": item.id, "split": item.split, "category": item.category,
                "context": context, "verify": verify, "contract": LocalExplanationContract.version,
                "thermal_before": ProcessInfo.processInfo.thermalState.rawValue,
                "backend": "Mac CPU", "request_count": 1,
                "retry_count": 0, "baseline": ["captured": baseline.captured.map(\.learner),
                    "check": baseline.check.map(\.learner), "unsettled": baseline.unsettled,
                    "worthAdding": baseline.worthAdding.map { $0.source.quote.text }, "sources": facts.count]]
            let input = LocalExplanationInput(learner: item.learner, question: item.question, passages: [
                .init(id: "s1", document: document.uuidString, page: 1, version: item.id, title: item.title, text: item.source)
            ])
            let start = Date()
            func raw(_ run: QwenRun) -> [String: Any] {
                ["prompt_tokens": run.promptTokens, "output_tokens": run.outputTokens,
                 "load_ms": run.loadMilliseconds, "prompt_ms": run.promptMilliseconds,
                 "first_token_ms": run.firstTokenMilliseconds, "total_ms": run.totalMilliseconds,
                 "peak_observed_footprint": run.peakObservedFootprint]
            }
            do {
                let result = try await LocalQwenProvider().assess(input, model: model,
                    maximumFootprint: 7_000_000_000, context: context, verifyApprovals: verify, developmentCPUOnly: true)
                row["raw"] = try JSONSerialization.jsonObject(with: result.raw)
                row["guarded"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.assessment))
                row["runs"] = result.runs.map(raw); row["request_count"] = result.runs.count
                row["status"] = "completed"
            } catch let rejected as QwenAssessmentRejection {
                row["raw"] = try JSONSerialization.jsonObject(with: rejected.run.json)
                row["runs"] = [raw(rejected.run)]; row["status"] = "guard_rejected"
            } catch let rejected as QwenVerificationRejection {
                row["raw"] = try JSONSerialization.jsonObject(with: rejected.runs[0].json)
                row["runs"] = rejected.runs.map(raw); row["status"] = "verification_rejected"
                row["request_count"] = 2; row["error"] = rejected.reason
            } catch {
                row["status"] = "failed"; row["error"] = String(describing: error)
            }
            row["wall_ms"] = Date().timeIntervalSince(start) * 1000
            row["thermal_after"] = ProcessInfo.processInfo.thermalState.rawValue
            try file.write(contentsOf: JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]))
            try file.write(contentsOf: Data([10])); try file.synchronize()
            print("\(item.id) \(row["status"]!) \(row["wall_ms"]!)ms", terminator: "\n")
            fflush(stdout)
        }
    }
}
