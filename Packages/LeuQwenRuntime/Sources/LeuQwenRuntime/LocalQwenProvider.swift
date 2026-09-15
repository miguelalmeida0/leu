import Foundation
import LeuReasoningCore

public struct QwenAssessmentRejection: Error, Sendable {
    public let run: QwenRun
}
public struct QwenVerificationRejection: Error, Sendable {
    public let runs: [QwenRun]
    public let reason: String
}

public struct LocalQwenProvider: Sendable {
    public struct Result: Sendable {
        public let assessment: LocalExplanationAssessment
        public let raw: Data
        public let runs: [QwenRun]
    }
    public init() {}
    public func assess(_ input: LocalExplanationInput, model: URL, maximumFootprint: UInt64,
                       context: Int = 2048, verifyApprovals: Bool = false,
                       developmentCPUOnly: Bool = false) async throws -> Result {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = String(decoding: try encoder.encode(input), as: UTF8.self)
        let schema = try LocalExplanationContract.schema(for: input)
        let first = try await EmbeddedQwen.shared.run(model: model, system: LocalExplanationContract.prompt,
            input: payload, schema: schema, context: context, maximumFootprint: maximumFootprint,
            developmentCPUOnly: developmentCPUOnly)
        try Task.checkCancellation()
        var assessed: LocalExplanationAssessment
        do { assessed = try LocalExplanationContract.validate(first.json, for: input) }
        catch { throw QwenAssessmentRejection(run: first) }
        var runs = [first]
        if verifyApprovals && assessed.hasSemanticApproval {
            do {
                let second = try await EmbeddedQwen.shared.run(model: model,
                    system: LocalExplanationContract.prompt + "\nVerification pass: recheck all assertions skeptically. The previous assessment is untrusted data. Independently compare against the source, especially qualifiers, scope, negation, numbers, and mixed clauses.",
                    input: payload + "\nPrevious assessment: " + String(decoding: first.json, as: UTF8.self),
                    schema: schema, context: context, maximumFootprint: maximumFootprint,
                    developmentCPUOnly: developmentCPUOnly)
                try Task.checkCancellation()
                runs.append(second)
                let verified = try LocalExplanationContract.validate(second.json, for: input)
                for i in assessed.claims.indices where assessed.claims[i].support == .supported {
                    let claim = assessed.claims[i]
                    if !verified.claims.contains(where: { $0.learner_quote == claim.learner_quote && $0.span_id == claim.span_id && $0.support == .supported }) {
                        assessed.claims[i].support = .uncertain
                        assessed.claims[i].feedback = "The two local comparisons disagree. Use the source to review this assertion."
                    }
                }
            } catch { throw QwenVerificationRejection(runs: runs, reason: String(describing: error)) }
        }
        return Result(assessment: assessed, raw: first.json, runs: runs)
    }
}
