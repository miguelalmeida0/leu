import Foundation

public struct KnowledgePassage: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var pageIndex: Int
    public var chapterID: UUID?
    public var sectionID: UUID?
    public var sectionTitle: String?
    public var text: String
    public var normalizedText: String
    public var sourceRange: SourceTextRange?
    public var bounds: SourceBounds?
    public var precedingContextFingerprint: String?
    public var followingContextFingerprint: String?
    public var contentFingerprint: String
    public var createdAt: Date
    public var indexVersion: Int
    public var isAvailable: Bool

    public init(id: UUID, documentID: UUID, pageIndex: Int,
                chapterID: UUID? = nil, sectionID: UUID? = nil, sectionTitle: String? = nil,
                text: String, normalizedText: String, sourceRange: SourceTextRange? = nil,
                bounds: SourceBounds? = nil, precedingContextFingerprint: String? = nil,
                followingContextFingerprint: String? = nil, contentFingerprint: String,
                createdAt: Date = Date(), indexVersion: Int, isAvailable: Bool = true) {
        self.id = id
        self.documentID = documentID
        self.pageIndex = max(0, pageIndex)
        self.chapterID = chapterID
        self.sectionID = sectionID
        self.sectionTitle = sectionTitle
        self.text = text
        self.normalizedText = normalizedText
        self.sourceRange = sourceRange
        self.bounds = bounds
        self.precedingContextFingerprint = precedingContextFingerprint
        self.followingContextFingerprint = followingContextFingerprint
        self.contentFingerprint = contentFingerprint
        self.createdAt = createdAt
        self.indexVersion = indexVersion
        self.isAvailable = isAvailable
    }
}

public struct KnowledgeSection: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var title: String
    public var startPageIndex: Int
    public var endPageIndex: Int
    public var order: Int

    public init(id: UUID, documentID: UUID, title: String, startPageIndex: Int,
                endPageIndex: Int, order: Int) {
        self.id = id; self.documentID = documentID; self.title = title
        self.startPageIndex = max(0, startPageIndex); self.endPageIndex = max(startPageIndex, endPageIndex)
        self.order = max(0, order)
    }
}

public struct KnowledgeChapter: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var documentID: UUID
    public var title: String
    public var startPageIndex: Int
    public var endPageIndex: Int
    public var order: Int

    public init(id: UUID, documentID: UUID, title: String, startPageIndex: Int,
                endPageIndex: Int, order: Int) {
        self.id = id; self.documentID = documentID; self.title = title
        self.startPageIndex = max(0, startPageIndex); self.endPageIndex = max(startPageIndex, endPageIndex)
        self.order = max(0, order)
    }
}
