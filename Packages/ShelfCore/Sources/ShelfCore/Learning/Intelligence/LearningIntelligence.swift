import Foundation

public enum LearningModelState: String, Codable, Sendable {
    case available, unavailable, loading, unsupportedDevice, unsupportedOS
    case appleIntelligenceDisabled, modelNotReady, failed, timedOut, cancelled
}

public struct LearningSourcePacket: Codable, Equatable, Sendable {
    public let documentID: UUID
    public let fingerprint: String
    public let extractionVersion: Int
    public let pageIndex: Int
    public let sourceText: String
    public let range: SourceTextRange
    public let sectionTitle: String?
    public var claimSegments: [String]? = nil
    public var sourceIntegrityPassed: Bool? = nil
    public var cacheKey: String {
        "\(documentID)|\(fingerprint)|\(extractionVersion)|\(pageIndex)|\(StableIdentity.hash64(sourceText))|apple-on-device|question|schema3|validator3|claims1"
    }
    public init?(analysis: DocumentAnalysis, page: AnalyzedPage) {
        guard page.isIntelligenceEligible, let version = analysis.extractionVersion, version >= SourceExtractionVersion.current,
              let canonical = page.canonicalText, canonical.utf16.count >= 80,
              canonical.utf16.count <= 2400, !canonical.contains("\u{FFFD}"),
              !analysis.fingerprint.isEmpty else { return nil }
        documentID = analysis.documentID; fingerprint = analysis.fingerprint
        extractionVersion = version; pageIndex = page.pageIndex
        sourceText = canonical; range = SourceTextRange(location: 0, length: canonical.utf16.count)
        claimSegments = page.segments.filter(Self.isGroundable).map(\.text)
        sourceIntegrityPassed = page.spatialIntegrityPassed
        sectionTitle = page.segments.first(where: { $0.kind == .heading })?.text
    }
    static func isGroundable(_ segment: SourceSegment) -> Bool {
        segment.kind != .code && segment.kind != .heading && !InstructionalText.excludesFromStudy(segment)
    }

}

public struct LearningModelCandidate: Codable, Equatable, Sendable {
    public var prompt: String
    public var choices: [String]
    public var correctChoice: Int
    public var explanation: String
    public var supportingQuote: String
    public var concept: String
    public var skill: String
    public var selection: GroundedQuestionSelection? = nil
    public init(prompt: String, choices: [String], correctChoice: Int, explanation: String,
                supportingQuote: String, concept: String, skill: String) {
        self.prompt = prompt; self.choices = choices; self.correctChoice = correctChoice
        self.explanation = explanation; self.supportingQuote = supportingQuote
        self.concept = concept; self.skill = skill
    }
}

public protocol LearningIntelligenceProvider: Sendable {
    var backend: String { get }
    func availability() async -> LearningModelState
    func generateQuestion(from packet: LearningSourcePacket) async throws -> LearningModelCandidate
}

public struct LearningGenerationProvenance: Codable, Equatable, Sendable {
    public var packet: LearningSourcePacket
    public var backend: String
    public var availability: LearningModelState
    public var schemaVersion: Int = 1
    public var validatorVersion: Int = 1
    public var generatedAt: Date
    public var explanation: String
    public var selectedClaimID: String? = nil
    public var modelInferencePerformed: Bool? = nil
    public var cognitiveOperation: String? = nil
    public var generationConfiguration: String = "greedy; maximumResponseTokens=700; timeout=30s; no-tools"
    public init(packet: LearningSourcePacket, backend: String, explanation: String, selection: GroundedQuestionSelection? = nil) {
        self.packet = packet; self.backend = backend; self.explanation = explanation
        availability = .available; generatedAt = Date()
        if let selection {
            schemaVersion = 3; validatorVersion = 3
            selectedClaimID = selection.claimID; cognitiveOperation = selection.cognitiveOperation
            generationConfiguration = "grounded-selection-v3; greedy; maximumResponseTokens=256; timeout=30s; no-tools"
        }
        modelInferencePerformed = backend == "apple-on-device"
        if backend == "deterministic-v3" {
            // Availability describes this named backend. Local deterministic
            // admission worked; it says nothing about Apple's availability.
            generationConfiguration = "deterministic-v3; no-model-inference; canonical-answer-binding; independent-admission"
        }
    }
}

public enum LearningIntelligenceError: Error { case unavailable(LearningModelState), sourceIntegrityFailed, invalidResponse, timedOut }
