import Foundation

/// Ephemeral drawing state: never persisted, scored, or attached to a learning attempt.
/// Both finger input and the accessible button share the same completion transition.
struct ReleaseInteractionState {
    enum Phase: Equatable { case drawing, released }
    static let maximumPoints = 2_048
    static let maximumStrokes = 64

    private(set) var phase: Phase = .drawing
    private(set) var strokes: [[CGPoint]] = []
    private(set) var pointCount = 0
    private var strokeIsOpen = false

    var hasDrawing: Bool { pointCount > 0 }

    mutating func append(_ point: CGPoint, in size: CGSize) {
        guard phase == .drawing, pointCount < Self.maximumPoints,
              point.x.isFinite, point.y.isFinite,
              size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return }
        let bounded = CGPoint(x: min(size.width, max(0, point.x)),
                              y: min(size.height, max(0, point.y)))
        if !strokeIsOpen {
            guard strokes.count < Self.maximumStrokes else { return }
            strokes.append([])
            strokeIsOpen = true
        }
        let index = strokes.count - 1
        if let previous = strokes[index].last {
            let dx = bounded.x - previous.x
            let dy = bounded.y - previous.y
            guard dx * dx + dy * dy >= 4 else { return }
        }
        strokes[index].append(bounded)
        pointCount += 1
    }

    mutating func endStroke() { strokeIsOpen = false }

    /// Returns true only for the first completion, preventing repeat haptic events.
    @discardableResult
    mutating func release() -> Bool {
        guard phase != .released else { return false }
        erase()
        phase = .released
        return true
    }

    mutating func erase() {
        strokes.removeAll(keepingCapacity: false)
        pointCount = 0
        strokeIsOpen = false
    }
}
