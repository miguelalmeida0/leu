import Foundation

public enum AnnotationKind: String, Codable, CaseIterable, Sendable {
    case highlight, underline, note, important, review, confusing
    public var title: String { rawValue.capitalized }
    public var isStudyMarker: Bool { [.important, .review, .confusing].contains(self) }
}

public enum MarkColor: String, Codable, CaseIterable, Sendable {
    case amber, sage, blue, rose
}

/// Coordinates in the original PDF page's coordinate system, not screen pixels.
public struct PDFRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && width >= 0 && height >= 0
    }
}

/// Sidecar annotation; adding a mark never modifies the original PDF.
public struct StudyAnnotation: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var bookID: UUID
    public var pageIndex: Int
    public var kind: AnnotationKind
    public var color: MarkColor
    public var rects: [PDFRect]
    public var quote: String
    public var note: String
    public var createdAt: Date

    public init(id: UUID = UUID(), bookID: UUID, pageIndex: Int,
                kind: AnnotationKind, color: MarkColor = .amber,
                rects: [PDFRect] = [], quote: String = "", note: String = "",
                createdAt: Date = Date()) {
        self.id = id; self.bookID = bookID; self.pageIndex = pageIndex
        self.kind = kind; self.color = color; self.rects = rects
        self.quote = quote; self.note = note; self.createdAt = createdAt
    }
}
