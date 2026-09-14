import Foundation
import FoundationModels

@main struct ModelIsolation {
    @MainActor static func main() async throws {
        var report: [String: Any] = ["platform": "macOS host, not iOS", "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "locale": Locale.current.identifier, "availability": String(describing: SystemLanguageModel.default.availability),
            "supportedLanguages": SystemLanguageModel.default.supportedLanguages.map(\.minimalIdentifier).sorted()]
        var cases: [[String: Any]] = []
        for structured in [false, true] {
            let start = Date()
            var result: [String: Any] = ["kind": structured ? "minimal closed schema" : "minimal plain response",
                "tools": 0, "customInstructions": false]
            do {
                let session = LanguageModelSession()
                if structured {
                    let schema = DynamicGenerationSchema(name: "Choice", properties: [
                        .init(name: "word", schema: .init(name: "Word", anyOf: ["hello", "goodbye"]))])
                    let response = try await session.respond(to: "Choose the greeting hello.",
                        schema: try GenerationSchema(root: schema, dependencies: []), options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 30))
                    result["output"] = response.content.jsonString
                } else {
                    result["output"] = try await session.respond(to: "Say hello.", options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 30)).content
                }
                result["realInference"] = true
            } catch {
                result["realInference"] = false
                result["errorType"] = String(reflecting: type(of: error))
                result["error"] = String(reflecting: error)
                result["nsError"] = String(reflecting: error as NSError)
                result["userInfo"] = String(reflecting: (error as NSError).userInfo)
            }
            result["milliseconds"] = Date().timeIntervalSince(start) * 1000
            cases.append(result)
        }
        report["cases"] = cases
        let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted])
        try data.write(to: URL(fileURLWithPath: "docs/v28/evidence/model-isolation.json"))
        print(String(decoding: data, as: UTF8.self))
    }
}
