import Foundation

public enum SourceExtractionVersion { public static let current = 5 }

public enum SourceSegmentKind: String, Codable, Sendable {
    case heading, paragraph, listItem, definition, code, unknown
}

public struct SourceSegment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pageIndex: Int
    public var kind: SourceSegmentKind
    public var text: String
    public var sectionTitle: String?
    public var importance: Double
    public init(id: UUID = UUID(), pageIndex: Int, kind: SourceSegmentKind,
                text: String, sectionTitle: String? = nil, importance: Double = 0.5) {
        self.id = id; self.pageIndex = pageIndex; self.kind = kind; self.text = text
        self.sectionTitle = sectionTitle; self.importance = min(max(importance, 0), 1)
    }
}

public struct AnalyzedPage: Codable, Equatable, Sendable {
    public var pageIndex: Int
    public var normalizedText: String
    public var segments: [SourceSegment]
    public var canonicalText: String? = nil
    /// False pages remain searchable/readable, but supply no intelligence. Nil is legacy.
    public var spatialIntegrityPassed: Bool? = nil
    public var isIntelligenceEligible: Bool { spatialIntegrityPassed != false && !InstructionalText.isReaderGuidePage(normalizedText) }
    public init(pageIndex: Int, normalizedText: String, segments: [SourceSegment]) {
        self.pageIndex = pageIndex; self.normalizedText = normalizedText; self.segments = segments
    }
}

public struct DocumentAnalysis: Codable, Equatable, Sendable {
    public var documentID: UUID
    public var fingerprint: String
    public var algorithmVersion: Int
    /// Optional for pre-spatial caches; the PDF adapter owns this version.
    public var extractionVersion: Int? = nil
    public var createdAt: Date
    public var pages: [AnalyzedPage]
    public var topicScores: [UUID: Double]
    public var repeatedHeaders: [String]
    public var repeatedFooters: [String]
    public init(documentID: UUID, fingerprint: String, algorithmVersion: Int,
                createdAt: Date = Date(), pages: [AnalyzedPage], topicScores: [UUID: Double] = [:],
                repeatedHeaders: [String] = [], repeatedFooters: [String] = []) {
        self.documentID = documentID; self.fingerprint = fingerprint; self.algorithmVersion = algorithmVersion
        self.createdAt = createdAt; self.pages = pages; self.topicScores = topicScores
        self.repeatedHeaders = repeatedHeaders; self.repeatedFooters = repeatedFooters
    }
}
