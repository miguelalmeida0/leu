import Foundation

public struct LearnerClaim: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let text: String
    public static func split(_ text: String) -> [Self] {
        text.components(separatedBy: .newlines).flatMap { line in
            line.components(separatedBy: ". ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }.filter { !$0.isEmpty }.prefix(24).enumerated().map {
            Self(id: "learner-\($0.offset)", text: $0.element)
        }
    }
}

public struct ClaimAlignment: Codable, Equatable, Sendable {
    public let learnerClaimID: String
    public let sourceClaimID: String
    public init(learnerClaimID: String, sourceClaimID: String) {
        self.learnerClaimID = learnerClaimID; self.sourceClaimID = sourceClaimID
    }
}

public struct TeachLeuCapture: Codable, Equatable, Sendable {
    public let claimID: String
    public let learnerText: String
    public let description: String
    public let complete: Bool
}
public struct TeachLeuChallenge: Codable, Equatable, Sendable {
    public let learnerText: String
    public let sourceClaimID: String?
    public let explanation: String
}
public struct TeachLeuResult: Codable, Equatable, Sendable {
    public let source: IntelligenceSource
    public let supported: [TeachLeuCapture]
    public let omitted: [GroundedQuestionClaim]
    public let challenged: [TeachLeuChallenge]
    public let unsettled: [String]
    public let backend: String
}

/// The model only suggests pairs. No free-form model judgement is displayed.
/// Exact assertions, literal polarity reversal and bounded source-verified
/// semantic contracts are supported. Other language remains unadjudicated.
public enum TeachLeuValidator {
    public static func evaluate(_ explanation: String, source: IntelligenceSource,
                                proposals: [ClaimAlignment] = [], backend: String = "local source comparison") -> TeachLeuResult {
        let claims = source.claims
        var captured: [TeachLeuCapture] = [], challenged: [TeachLeuChallenge] = [], unsettled: [String] = []
        var covered = Set<String>()
        for learner in LearnerClaim.split(explanation) {
            // Suggested IDs only influence inspection order, never acceptance.
            let suggested = proposals.filter { $0.learnerClaimID == learner.id }.map(\.sourceClaimID)
            let ordered = claims.sorted { suggested.contains($0.id) && !suggested.contains($1.id) }
            var matched = false
            for claim in ordered {
                let original = normalize(claim.evidence.text), expressed = normalize(learner.text)
                if original == expressed {
                    captured.append(.init(claimID: claim.id, learnerText: learner.text,
                        description: claim.evidence.text, complete: true))
                    covered.insert(claim.id); matched = true; break
                }
                if polarityReversal(expressed, source: original) {
                    challenged.append(.init(learnerText: learner.text, sourceClaimID: claim.id,
                        explanation: "Your wording reverses this source statement: " + claim.evidence.text))
                    matched = true; break
                }
                let semantic = TeachLeuV2.compare(learner.text, sourceText: claim.evidence.text, topic: claim.concept)
                if semantic.status == .supported {
                    captured.append(.init(claimID: claim.id, learnerText: learner.text,
                        description: semantic.explanation, complete: false))
                    // A matched core relation does not prove every clause of a
                    // multi-sentence source packet. Keep that packet worth adding.
                    matched = true; break
                }
                if semantic.status == .contradicted || semantic.status == .overgeneralized || semantic.status == .incomplete {
                    challenged.append(.init(learnerText: learner.text, sourceClaimID: claim.id, explanation: semantic.explanation))
                    matched = true; break
                }
            }
            if !matched { unsettled.append(learner.text) }
        }
        return TeachLeuResult(source: source, supported: captured,
            omitted: Array(claims.filter { !covered.contains($0.id) }.prefix(3)),
            challenged: challenged, unsettled: unsettled, backend: backend)
    }
    public static func isValid(_ result: TeachLeuResult, explanation: String, analyses: [UUID: DocumentAnalysis]) -> Bool {
        guard result.source.isCurrent(in: analyses) else { return false }
        return result == evaluate(explanation, source: result.source, backend: result.backend)
    }
    private static func normalize(_ value: String) -> String {
        CanonicalWhitespaceResolver.normalize(value).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".; "))
    }
    private static func polarityReversal(_ learner: String, source: String) -> Bool {
        // No stemming, number removal or qualifier removal. Exactly one negation
        // differs and every other character must agree with the canonical claim.
        guard source.components(separatedBy: " not ").count == 2 else { return false }
        return learner == source.replacingOccurrences(of: " not ", with: " ")
    }
}

public protocol TeachLeuProposing: Sendable {
    func proposeAlignments(explanation: String, source: IntelligenceSource) async throws -> [ClaimAlignment]
}
