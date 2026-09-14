import Foundation
import ShelfCore

@main struct V27ModelProbe {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let output = root.appendingPathComponent("docs/v27/evidence")
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let analysis = try decoder.decode(DocumentAnalysis.self, from: Data(contentsOf: output.appendingPathComponent("React Notes-analysis.json")))
        let source = IntelligenceSource(source: LearningSource(documentID: analysis.documentID,
            pageIndex: 2, sourceText: analysis.pages.first { $0.pageIndex == 2 }!.canonicalText!), analysis: analysis)!
        let provider = AppleLearningIntelligenceProvider(), availability = await provider.availability()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var report: [String: Any] = ["platform": "macOS host, not iOS", "backend": provider.backend,
            "availability": availability.rawValue, "realInference": false, "sourcePage": 3]
        if availability == .available {
            do {
                let begin = Date()
                let candidate = try await provider.generateQuestion(from: source.packet)
                report["questionMilliseconds"] = Date().timeIntervalSince(begin) * 1000
                report["realInference"] = true
                report["candidate"] = try JSONSerialization.jsonObject(with: encoder.encode(candidate))
                report["validation"] = String(describing: LearningCandidateValidator().validate(candidate,
                    packet: source.packet, analysis: analysis, existing: []))
                let text = "Keys tell React which item is which when a list changes."
                let teachStart = Date()
                let pairs = try await provider.proposeAlignments(explanation: text, source: source)
                report["teachMilliseconds"] = Date().timeIntervalSince(teachStart) * 1000
                report["alignments"] = try JSONSerialization.jsonObject(with: encoder.encode(pairs))
                report["teachResult"] = try JSONSerialization.jsonObject(with: encoder.encode(TeachLeuValidator.evaluate(text, source: source, proposals: pairs, backend: provider.backend)))
            } catch { report["error"] = String(describing: error) }
        }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("mac-model-probe.json"))
        print(String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self))
    }
}
