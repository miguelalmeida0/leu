import Foundation

public enum CoverPalette: String, Codable, CaseIterable, Sendable {
    case ocean, graphite, ivory, forest, sand, slate
}

public enum CoverArt: String, Codable, CaseIterable, Sendable {
    case dunes, mountains, spheres, cube, arches, folds
}

public enum TextIndexStatus: String, Codable, Sendable {
    case ready, partial, noText, pending
}

/// Identity and presentation metadata. PDF bytes never live in the database.
public struct Book: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var originalFilename: String
    public var fingerprint: String
    public var pageCount: Int
    public var byteCount: Int64
    public var importedAt: Date
    public var lastOpenedAt: Date?
    public var trashedAt: Date?
    public var isFavorite: Bool
    public var isSample: Bool
    public var collectionIDs: Set<UUID>
    public var tags: [String]
    public var palette: CoverPalette
    public var artwork: CoverArt
    public var position: ReadingPosition
    public var indexStatus: TextIndexStatus

    public init(id: UUID = UUID(), title: String, originalFilename: String,
                fingerprint: String, pageCount: Int, byteCount: Int64,
                importedAt: Date = Date(), palette: CoverPalette = .ocean,
                artwork: CoverArt = .dunes, indexStatus: TextIndexStatus = .pending) {
        self.id = id
        self.title = title
        self.originalFilename = originalFilename
        self.fingerprint = fingerprint
        self.pageCount = pageCount
        self.byteCount = byteCount
        self.importedAt = importedAt
        self.palette = palette
        self.artwork = artwork
        self.indexStatus = indexStatus
        self.lastOpenedAt = nil
        self.trashedAt = nil
        self.isFavorite = false
        self.isSample = false
        self.collectionIDs = []
        self.tags = []
        self.position = ReadingPosition()
    }

    public var isTrashed: Bool { trashedAt != nil }
    public var currentPageNumber: Int { min(max(position.pageIndex + 1, 1), pageCount) }
}
