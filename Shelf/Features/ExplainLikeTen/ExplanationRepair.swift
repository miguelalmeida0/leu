import Foundation

/// Describes observed structural violations for a bounded repair. Never decides
/// acceptance; the original validator runs again on every proposed repair.
enum ExplanationRepair {
    static func reasons(candidate: ExplanationCandidate, mode: ExplanationMode,
                        failures: [ExplanationValidator.Failure]) -> [String] {
        var result = failures.map(\.code)
        guard failures.contains(.invalidStructure) else { return result }
        let exampleCount = candidate.blocks.filter { $0.kind == .example }.count
        if mode == .withExample && exampleCount != 1 {
            result.append("Show an example requires exactly one block of kind example; the previous response had \(exampleCount). Generate the ExplainedWithExample variant with a plainMeaning explanation and a distinct, source-grounded illustration of kind example. Ordinary mechanism prose does not satisfy this requirement.")
        }
        if !candidate.needsContext && candidate.needsContextReason != nil {
            result.append("The previous response included needsContextReason alongside an explanation. A successful ExplainedWithExample response must not contain a refusal reason. MissingExplanationContext is a separate alternative only when the supplied source lacks necessary context.")
        }
        if candidate.blocks.first?.kind != .plainMeaning || candidate.blocks.filter({ $0.kind == .plainMeaning }).count != 1 {
            result.append("The first block must be plainMeaning and it must be the only plainMeaning block.")
        }
        return result
    }
}
