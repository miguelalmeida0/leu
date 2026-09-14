import Foundation

/// Pure gesture decisions. UIKit owns touch delivery; this type owns thresholds and direction.
public struct PageTurnPolicy {
    public enum Axis: Equatable { case undecided, horizontal, vertical }
    public private(set) var axis: Axis = .undecided
    public init() {}

    @discardableResult
    public mutating func lock(dx: Double, dy: Double, velocityX: Double = 0, velocityY: Double = 0) -> Axis {
        guard axis == .undecided, dx.isFinite, dy.isFinite,
              velocityX.isFinite, velocityY.isFinite else { return axis }
        guard hypot(dx, dy) >= 8 else { return axis }
        let x = abs(dx), y = abs(dy)
        // A short diagonal has too little directional evidence. A longer thumb arc
        // may commit once lateral travel has a meaningful lead, not just a ratio.
        let displacementIntent = x >= y * 1.15 && x - y >= 6
        let flickIntent = x >= 6 && x >= y * 0.8 && dx * velocityX > 0 &&
            abs(velocityX) >= 550 && abs(velocityX) >= abs(velocityY) * 1.8
        axis = displacementIntent || flickIntent ? .horizontal : .vertical
        return axis
    }

    public func targetDelta(dx: Double, velocityX: Double, velocityY: Double = 0, width: Double,
                            page: Int, count: Int) -> Int? {
        guard axis == .horizontal, width > 0, width.isFinite,
              dx.isFinite, velocityX.isFinite, velocityY.isFinite, (0..<count).contains(page) else { return nil }
        guard abs(dx) >= 22 else { return nil }
        if abs(velocityX) >= 180 && dx * velocityX < 0 { return nil }
        let deliberateDrag = abs(dx) >= width * 0.32
        let horizontalFlick = abs(velocityX) >= 320 && abs(velocityX) >= abs(velocityY) * 1.8 &&
            abs(dx) >= max(22, min(36, width * 0.06))
        guard deliberateDrag || horizontalFlick else { return nil }
        let delta = dx < 0 ? 1 : -1
        return (0..<count).contains(page + delta) ? delta : nil
    }

    public func offset(dx: Double, width: Double, hasNeighbor: Bool) -> Double {
        guard axis == .horizontal, dx.isFinite, width.isFinite, width > 0 else { return 0 }
        if hasNeighbor { return min(max(dx, -width), width) }
        return (dx < 0 ? -1 : 1) * min(18, abs(dx) * 0.12)
    }
}
