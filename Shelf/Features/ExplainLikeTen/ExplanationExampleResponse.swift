import Foundation
import ShelfCore

/// Wire contract for the example refinement. The model must generate a specifically
/// typed illustration. This mapping never promotes ordinary prose to an example.
enum ExplanationExampleResponse {
    private struct Explained: Decodable {
        struct Term: Decodable { let literal: String; let meaning: String }
        let explanation: ExplanationBlock
        let illustration: ExplanationBlock
        let term: Term?
    }

    static func candidateJSON(from json: String) throws -> String {
        guard json.utf16.count <= 20_000,
              let object = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw LearningIntelligenceError.invalidResponse
        }
        let candidate: ExplanationCandidate
        if Set(object.keys) == ["needsContextReason"], let reason = object["needsContextReason"] as? String {
            candidate = .init(blocks: [], needsContext: true, needsContextReason: reason)
        } else {
            guard Set(object.keys).isSubset(of: ["explanation", "illustration", "term"]) else {
                throw LearningIntelligenceError.invalidResponse
            }
            let generated = try JSONDecoder().decode(Explained.self, from: Data(json.utf8))
            guard generated.explanation.kind == .plainMeaning, generated.illustration.kind == .example else {
                throw LearningIntelligenceError.invalidResponse
            }
            candidate = .init(blocks: [generated.explanation, generated.illustration],
                preservedTerm: generated.term?.literal, preservedTermMeaning: generated.term?.meaning)
        }
        return String(decoding: try JSONEncoder().encode(candidate), as: UTF8.self)
    }
}
