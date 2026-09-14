import Foundation

/// Page index is zero-based. Scale is relative to PDFKit's fit-to-page scale.
public struct ReadingPosition: Codable, Equatable, Sendable {
    public var pageIndex: Int
    public var scaleRatio: Double
    public var pointX: Double?
    public var pointY: Double?
    public var updatedAt: Date

    public init(pageIndex: Int = 0, scaleRatio: Double = 1,
                pointX: Double? = nil, pointY: Double? = nil, updatedAt: Date = Date()) {
        self.pageIndex = pageIndex
        self.scaleRatio = scaleRatio
        self.pointX = pointX
        self.pointY = pointY
        self.updatedAt = updatedAt
    }

    public func clamped(toPageCount count: Int) -> ReadingPosition {
        ReadingPosition(
            pageIndex: min(max(0, pageIndex), max(0, count - 1)),
            scaleRatio: scaleRatio.isFinite ? min(max(scaleRatio, 0.5), 8) : 1,
            pointX: pointX?.isFinite == true ? pointX : nil,
            pointY: pointY?.isFinite == true ? pointY : nil,
            updatedAt: updatedAt
        )
    }
}
