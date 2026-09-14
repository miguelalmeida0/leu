import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A recorded XCUIElement frame replayed as plain arithmetic.
///
/// The queries below reproduce `CGRect`'s standardised semantics for the three questions
/// this harness asks, so the V24.4 geometry stays checkable without depending on the
/// platform geometry overlay being visible to a two-file `swiftc` invocation.
struct RecordedFrame {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    var minX: CGFloat { x }
    var minY: CGFloat { y }
    var maxX: CGFloat { x + width }
    var maxY: CGFloat { y + height }
    var midX: CGFloat { x + width / 2 }

    /// Matches `CGRect.contains(_ point:)`: half-open on the far edges, as hit testing is.
    func contains(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x < maxX && point.y >= minY && point.y < maxY
    }

    /// Matches `CGRect.contains(_ rect:)`: full containment of a non-empty rectangle.
    func contains(_ other: RecordedFrame) -> Bool {
        other.minX >= minX && other.maxX <= maxX && other.minY >= minY && other.maxY <= maxY
    }
}

@main
@MainActor
struct ReleaseStateHarness {
    static var checks = 0
    static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fatalError("FAIL: " + message) }
        checks += 1
        print("PASS: " + message)
    }

    static func main() {
        let size = CGSize(width: 340, height: 160)
        let origin = CGPoint(x: 0, y: 0)
        var state = ReleaseInteractionState()
        expect(state.phase == .drawing, "Release is initially optional, without required drawing")
        expect(state.pointCount == 0 && state.strokes.isEmpty, "No previous drawing is loaded")
        expect(state.release(), "Accessible Release works with an empty canvas")
        expect(state.phase == .released, "Release produces a distinct completed state")
        expect(!state.release(), "Repeated completion cannot repeat its haptic effect")
        state.append(CGPoint(x: 10, y: 10), in: size)
        expect(state.pointCount == 0, "Late gesture events after release do not resurrect drawings")

        state = ReleaseInteractionState()
        state.append(CGPoint(x: 10, y: 10), in: size)
        expect(state.hasDrawing && state.pointCount == 1, "Finger input changes actual state")
        state.append(CGPoint(x: 10.1, y: 10.1), in: size)
        expect(state.pointCount == 1, "Subpixel gesture noise is not stored indefinitely")
        state.append(CGPoint(x: 30, y: 30), in: size)
        expect(state.strokes[0].count == 2, "One stroke preserves its ordered points")
        state.endStroke()
        state.append(CGPoint(x: 100, y: 100), in: size)
        expect(state.strokes.count == 2, "Separate strokes are not joined by a false line")
        state.append(CGPoint(x: -100, y: 600), in: size)
        let clamped = state.strokes.last?.last
        expect(clamped?.x == 0 && clamped?.y == 160, "Drawing locations remain inside the canvas")
        let before = state.pointCount
        state.append(CGPoint(x: CGFloat.nan, y: 0), in: size)
        state.append(CGPoint(x: 0, y: CGFloat.infinity), in: size)
        expect(state.pointCount == before, "Non-finite gesture locations are rejected")
        state.append(origin, in: CGSize(width: 0, height: 0))
        state.append(origin, in: CGSize(width: CGFloat.infinity, height: 160))
        expect(state.pointCount == before, "Invalid canvas geometry is rejected")
        expect(state.release(), "Release clears a populated canvas")
        expect(state.strokes.isEmpty && !state.hasDrawing, "Released content is erased, not merely hidden")
        expect(state.pointCount == 0, "Point accounting resets when content is erased")

        state = ReleaseInteractionState()
        for index in 0..<30_000 {
            state.append(CGPoint(x: index.isMultiple(of: 2) ? 1 : 300, y: 80), in: size)
        }
        expect(state.pointCount == ReleaseInteractionState.maximumPoints, "Long gestures have a fixed storage ceiling")
        expect(state.strokes.flatMap { $0 }.count == state.pointCount, "Point accounting matches retained storage")
        state.endStroke()
        state.append(origin, in: size)
        expect(state.pointCount == ReleaseInteractionState.maximumPoints, "New strokes cannot bypass the total-point ceiling")
        state.erase()
        expect(state.strokes.isEmpty && state.pointCount == 0, "Closing clears all ephemeral storage")
        state.append(CGPoint(x: 2, y: 2), in: size)
        expect(state.strokes.count == 1, "Erasing resets the open-stroke state")

        state = ReleaseInteractionState()
        for _ in 0..<1_000 {
            state.append(CGPoint(x: 1, y: 1), in: size)
            state.endStroke()
        }
        expect(state.strokes.count == ReleaseInteractionState.maximumStrokes, "Many short strokes also have a storage ceiling")
        expect(state.pointCount == ReleaseInteractionState.maximumStrokes, "Stroke limit cannot leak orphan points")
        expect(state.release() && state.strokes.isEmpty, "Release remains available at the storage ceiling")

        // Replay the recorded V24.4 geometry against the unchanged helper's formula.
        // This checks the arithmetic, not a simulator's gesture-recognizer arbitration.
        let viewport = RecordedFrame(x: 2, y: 76, width: 416, height: 736)
        let canvas = RecordedFrame(x: 40.2, y: 644.3, width: 340.3, height: 130)
        let button = RecordedFrame(x: 39.8, y: 785.9, width: 100.1, height: 48.8)
        let dragStart = CGPoint(x: viewport.midX, y: viewport.minY + viewport.height * 0.8)
        expect(!viewport.contains(button), "The logged V24.4 action really crosses the unobscured viewport")
        expect(canvas.contains(dragStart), "The old reveal helper starts its scroll gesture inside the canvas")
        expect(button.maxY > 820, "The logged action overlaps the actual bottom navigation")
        print("PASS: \(checks) Release state/recorded-geometry checks; no Apple UI execution claimed")
    }
}
