import Foundation

// THROWAWAY — V37 capability spike only.

/// A stand-in model for checking the pipeline and the harness contract where no Apple model exists
/// (Linux, CI). It answers every schema with its first allowed values, numbering `n` and `item`
/// fields in order, so a reading says "statement / first claim / entails" for every segment. Its
/// output means nothing; it is never used for any reported result.
public struct FirstChoiceModel: SpikeModel {
    public init() {}

    public func respond(_ request: ModelRequest) async -> ModelResponse {
        let value = Self.value(request.schema, index: 0)
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) else {
            return ModelResponse(status: "error", latencyMs: 0, retries: 0, json: nil)
        }
        return ModelResponse(status: "ok", latencyMs: 1, retries: 0, json: String(decoding: data, as: UTF8.self))
    }

    static func value(_ node: SchemaNode, index: Int) -> Any {
        switch node {
        case let .object(_, properties):
            var object: [String: Any] = [:]
            for property in properties {
                if ["n", "item"].contains(property.name), case let .choice(_, values) = property.node {
                    object[property.name] = values[min(index, values.count - 1)]
                } else {
                    object[property.name] = value(property.node, index: 0)
                }
            }
            return object
        case let .choice(_, values): return values.first ?? ""
        case .text: return "fake"
        case let .array(of, min, _): return (0..<min).map { value(of, index: $0) }
        }
    }
}
