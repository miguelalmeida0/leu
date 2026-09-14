import Foundation

/// An exact, current extraction-bound citation. Never accepts a searchable but
/// unverified page as evidence. All V27 feature admission shares this boundary.
public struct IntelligenceSource: Codable, Equatable, Sendable, Identifiable {
    public let packet: LearningSourcePacket
    public let passage: LearningSource
    public let claims: [GroundedQuestionClaim]
    public var id: String { packet.cacheKey + "|" + String(StableIdentity.hash64(passage.sourceText)) }
    public var extractionVersion: Int { packet.extractionVersion }
    public var integrity: String { "verified" }
    public init?(source: LearningSource, analysis: DocumentAnalysis) {
        guard source.documentID == analysis.documentID,
              let page = analysis.pages.first(where: { $0.pageIndex == source.pageIndex }),
              page.spatialIntegrityPassed == true, analysis.extractionVersion == SourceExtractionVersion.current,
              let packet = LearningSourcePacket(analysis: analysis, page: page),
              let span = CanonicalWhitespaceResolver.resolve(source.sourceText, in: packet.sourceText) else { return nil }
        self.packet = packet
        passage = LearningSource(documentID: source.documentID, pageIndex: source.pageIndex,
            sourceText: span.text, range: span.range, sectionTitle: source.sectionTitle)
        claims = GroundedQuestionCompiler().compile(packet).meaningfulClaims.filter {
            CanonicalWhitespaceResolver.normalize(span.text).contains(CanonicalWhitespaceResolver.normalize($0.evidence.text))
        }
    }
    public func isCurrent(in analyses: [UUID: DocumentAnalysis]) -> Bool {
        guard let analysis = analyses[packet.documentID],
              let rebound = IntelligenceSource(source: passage, analysis: analysis) else { return false }
        return rebound == self
    }
}

public struct UnderstandingEvent: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case askedExplanation, answeredQuestion, taughtConcept, openedConnection, triedActivity, savedQuestion, returnedToSource
    }
    public let id: UUID
    public let kind: Kind
    public let source: IntelligenceSource
    public let occurredAt: Date
    public init(kind: Kind, source: IntelligenceSource, occurredAt: Date = Date()) {
        id = UUID(); self.kind = kind; self.source = source; self.occurredAt = occurredAt
    }
}

public struct UnderstandingAttempt: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let source: IntelligenceSource
    public var learnerExplanation: String
    public var result: TeachLeuResult?
    public let createdAt: Date
    public var resolved: Bool
    public var supportedClaimIDs: [String] { result?.supported.map(\.claimID) ?? [] }
    public var omittedClaimIDs: [String] { result?.omitted.map(\.id) ?? [] }
    public var challengedClaimIDs: [String] { result?.challenged.compactMap(\.sourceClaimID) ?? [] }
    public init(id: UUID = UUID(), source: IntelligenceSource, learnerExplanation: String = "", createdAt: Date = Date()) {
        self.id = id; self.source = source; self.learnerExplanation = learnerExplanation
        self.createdAt = createdAt; result = nil; resolved = false
    }
}

public enum UnderstandingTimeline {
    public static func thought(documentID: UUID, attempts: [UnderstandingAttempt], analyses: [UUID: DocumentAnalysis]) -> UnderstandingAttempt? {
        attempts.filter { !$0.resolved && $0.source.packet.documentID == documentID &&
            !$0.learnerExplanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.source.isCurrent(in: analyses) }
            .max { $0.createdAt < $1.createdAt }
    }
}
