import Foundation

public struct SourceTextRange: Codable, Equatable, Hashable, Sendable {
    public var location: Int
    public var length: Int
    public init(location: Int, length: Int) {
        self.location = max(0, location)
        self.length = max(0, length)
    }
}

public struct SourceBounds: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public struct LearningSource: Codable, Equatable, Hashable, Sendable {
    public var documentID: UUID
    public var pageIndex: Int
    public var sourceText: String
    public var range: SourceTextRange?
    public var bounds: SourceBounds?
    public var sectionTitle: String?

    public init(documentID: UUID, pageIndex: Int, sourceText: String,
                range: SourceTextRange? = nil, bounds: SourceBounds? = nil,
                sectionTitle: String? = nil) {
        self.documentID = documentID
        self.pageIndex = max(0, pageIndex)
        self.sourceText = sourceText
        self.range = range
        self.bounds = bounds
        self.sectionTitle = sectionTitle
    }
}
