import Foundation
#if canImport(FoundationModels)
import FoundationModels

extension AppleLearningIntelligenceProvider {
    @available(iOS 26, macOS 26, *)
    func exampleExplanationSchema(spanIDs: [String]) throws -> GenerationSchema {
        let text = DynamicGenerationSchema(type: String.self)
        let span = DynamicGenerationSchema(name: "ExampleSourceSpanID", anyOf: spanIDs.sorted())
        func block(_ name: String, kind: String, description: String) -> DynamicGenerationSchema {
            .init(name: name, description: description, properties: [
                .init(name: "kind", schema: .init(name: name + "Kind", anyOf: [kind])),
                .init(name: "text", description: description, schema: text),
                .init(name: "sourceSpanIDs", schema: .init(arrayOf: span, minimumElements: 1, maximumElements: spanIDs.count))
            ])
        }
        let term = DynamicGenerationSchema(name: "ExamplePreservedTerm", properties: [
            .init(name: "literal", description: "An exact technical term from the supplied source.", schema: text),
            .init(name: "meaning", description: "A brief definition using only the supplied source.", schema: text)
        ])
        let explained = DynamicGenerationSchema(name: "ExplainedWithExample", properties: [
            .init(name: "explanation", schema: block("ExampleExplanation", kind: "plainMeaning",
                description: "A concise explanation of the source. Preserve conditions, negation, numbers and protected code identifiers.")),
            .init(name: "illustration", schema: block("SourceGroundedIllustration", kind: "example",
                description: "A distinct concrete illustration or simple analogy, explicitly imagined. Help a beginner understand this source; do not repeat the explanation or invent technical facts, numbers or code. Connect the illustration back to the supplied idea.")),
            .init(name: "term", schema: term, isOptional: true)
        ])
        let missing = DynamicGenerationSchema(name: "MissingExplanationContext", properties: [
            .init(name: "needsContextReason", description: "Only when the source itself lacks necessary context. State what is missing in at most 300 characters.", schema: text)
        ])
        return try GenerationSchema(root: .init(name: "ExampleExplanationResult", anyOf: [explained, missing]), dependencies: [])
    }
}
#endif
