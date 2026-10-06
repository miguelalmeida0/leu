import SwiftUI

/// The rainy window over the evening city.
///
/// Rain lands on the glass and a few drops slip down it. The pane is fogged; drawing on it
/// with a finger (or the iPad pointer) wipes it clear, and about seven seconds after you
/// stop it slowly fogs over again, like a real window. Under Reduce Motion the rain is
/// still, nothing slides, and the fog returns without animation.
@MainActor
struct FoggedWindow: View {
    @State private var glass = GlassState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 30.0)) { timeline in
            Canvas { [glass, reduceMotion] context, size in
                glass.advance(to: timeline.date.timeIntervalSinceReferenceDate, size: size, reduced: reduceMotion)
                WindowPainter.paint(glass, in: &context, size: size)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in glass.wipe(at: value.location) }
            .onEnded { _ in glass.lift() })
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): glass.wipe(at: point)
            case .ended: glass.lift()
            }
        }
        .accessibilityElement()
        .accessibilityLabel("A rainy window over the city at night")
        .accessibilityHint("Draw on the fogged glass to wipe it clear. It slowly fogs up again.")
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityAction(named: "Wipe the glass") { glass.wipeBand() }
    }

}

/// Draws one frame of the window. Free of view state so it can run inside `Canvas`.
enum WindowPainter {
    static func paint(_ glass: GlassState, in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.draw(Image("Home/WindowClear"), in: rect)
        // Fog: the softer, paler city, with every wipe cut out of it.
        context.drawLayer { layer in
            layer.draw(Image("Home/WindowFog"), in: rect)
            layer.blendMode = .destinationOut
            let clearing = 1 - glass.refog
            for wipe in glass.wipes + glass.trails {
                let center = CGPoint(x: wipe.x * size.width, y: wipe.y * size.height)
                let radius = wipe.radius * size.width
                let shade = Gradient(colors: [.black.opacity(wipe.strength * clearing), .black.opacity(0)])
                layer.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                           with: .radialGradient(shade, center: center, startRadius: 0, endRadius: radius))
            }
        }
        for drop in glass.drops { drawDrop(drop, in: &context, size: size, stretch: 1) }
        for mover in glass.movers { drawDrop(mover.drop, in: &context, size: size, stretch: 1.14) }
        // Warm lamplight from the room, falling across the top-left of the pane.
        let lamp = Gradient(colors: [Color(hex: 0xFFE2A0, opacity: 0.22), Color(hex: 0xFFE2A0, opacity: 0)])
        context.fill(Path(rect), with: .radialGradient(lamp, center: CGPoint(x: size.width * 0.09, y: size.height * 0.1),
                                                      startRadius: 4, endRadius: size.width * 1.1))
    }

    /// A drop is a small lens: a cool shadow below, a lighter body, a bright fleck above.
    /// Three flat fills each, so hundreds of drops stay cheap at 30 frames a second.
    private static func drawDrop(_ drop: GlassState.Drop, in context: inout GraphicsContext, size: CGSize, stretch: CGFloat) {
        let r = drop.radius * size.width
        guard r > 0.3 else { return }
        let x = drop.x * size.width, y = drop.y * size.height
        let body = CGRect(x: x - r, y: y - r * stretch, width: r * 2, height: r * 2 * stretch)
        context.fill(Path(ellipseIn: body.offsetBy(dx: 0, dy: r * 0.18)), with: .color(Color(hex: 0x121A12, opacity: 0.26)))
        context.fill(Path(ellipseIn: body.insetBy(dx: r * 0.12, dy: r * 0.12)), with: .color(.white.opacity(0.13)))
        let fleck = CGRect(x: x - r * 0.53, y: y - r * 0.56 * stretch, width: max(0.7, r * 0.4), height: max(0.6, r * 0.28))
        context.fill(Path(ellipseIn: fleck), with: .color(.white.opacity(0.6)))
    }
}

/// Everything the window remembers between frames. Coordinates are unit fractions of the
/// pane so the effect is identical at every size. Only ever touched from the view's
/// render pass and gesture callbacks, both on the main thread.
final class GlassState {
    struct Drop { var x: CGFloat; var y: CGFloat; var radius: CGFloat }
    struct Wipe { var x: CGFloat; var y: CGFloat; var radius: CGFloat; var strength: Double }
    struct Mover { var drop: Drop; var speed: CGFloat; var target: CGFloat; var pause: Double; var travelled: CGFloat; var phase: Double }

    private(set) var drops: [Drop] = []
    private(set) var movers: [Mover] = []
    private(set) var wipes: [Wipe] = []
    /// Clear trails left by sliding drops; kept apart so they never push out your drawing.
    private(set) var trails: [Wipe] = []
    /// 0 = every wipe fully clear, 1 = fogged over again.
    private(set) var refog: Double = 0
    private var size: CGSize = .zero
    private var last: TimeInterval?
    private var lastWipe: TimeInterval = -.infinity
    private var lastPoint: CGPoint?
    private var nextMover: Double = 0.4

    func advance(to now: TimeInterval, size: CGSize, reduced: Bool) {
        if self.size != size || drops.isEmpty { seed(size) }
        let dt = min(0.1, now - (last ?? now)); last = now
        // New rain keeps landing; the oldest drops dry up so the count stays bounded.
        if !reduced, Double.random(in: 0...1) < dt * 26 {
            drops.append(Drop(x: .random(in: 0...1), y: .random(in: 0...1), radius: dropRadius(0.6, 2.4)))
            if drops.count > 520 { drops.removeFirst(drops.count - 520) }
        }
        // The fog creeps back seven seconds after the last touch, over about ten seconds.
        let since = now - lastWipe
        if since > 7 {
            refog = reduced ? 1 : min(1, refog + (1 - exp(-dt / 9)) * smooth((since - 7) / 3))
            if refog >= 0.999 { wipes.removeAll(); trails.removeAll(); refog = 0; lastWipe = -.infinity }
        }
        guard !reduced, size.width > 0 else { movers.removeAll(); return }
        nextMover -= dt
        if nextMover <= 0, movers.count < 14 {
            let drop = Drop(x: .random(in: 0.03...0.97), y: .random(in: -0.02...0.55), radius: .random(in: 3.6...7.4) / 464)
            movers.append(Mover(drop: drop, speed: 0, target: .random(in: 30...90), pause: .random(in: 0.2...1.5), travelled: 0, phase: .random(in: 0...9)))
            nextMover = .random(in: 0.7...1.8)
        }
        for index in movers.indices.reversed() {
            var mover = movers[index]
            if mover.pause > 0 { mover.pause -= dt; mover.speed *= 0.9 } else {
                mover.speed += (mover.target * (mover.drop.radius * 464 / 6) - mover.speed) * CGFloat(min(1, dt * 2.5))
                if Double.random(in: 0...1) < dt * 0.55 { mover.pause = .random(in: 0.25...1.4); mover.target = .random(in: 30...90) }
            }
            // Speeds are in design points on a 464pt-wide pane; convert to a fraction of the height.
            let aspect = size.width / size.height
            let dy = mover.speed * CGFloat(dt) / 464 * aspect
            mover.drop.y += dy
            mover.drop.x += CGFloat(sin(now * 1.3 + mover.phase) * dt * 3 / 464) * (mover.speed / 60)
            mover.travelled += dy
            if mover.travelled > mover.drop.radius * 1.4 * aspect {
                mover.travelled = 0
                trails.append(Wipe(x: mover.drop.x, y: mover.drop.y, radius: mover.drop.radius * 2.2, strength: 0.55))
                drops.append(Drop(x: mover.drop.x, y: mover.drop.y - mover.drop.radius * 1.5 * aspect, radius: .random(in: 0.6...1.3) / 464))
                mover.drop.radius -= 0.035 / 464
            }
            if mover.drop.y > 1.03 || mover.drop.radius * 464 < 2.4 { movers.remove(at: index) } else { movers[index] = mover }
        }
        if wipes.count > 600 { wipes.removeFirst(wipes.count - 600) }
        if trails.count > 160 { trails.removeFirst(trails.count - 160) }
    }

    /// Wipes along the finger's path in small overlapping stamps, so a fast stroke stays continuous.
    func wipe(at point: CGPoint) {
        guard size.width > 0 else { return }
        let from = lastPoint ?? point
        let distance = hypot(point.x - from.x, point.y - from.y)
        let steps = max(1, Int(ceil(distance / 9)))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let x = (from.x + (point.x - from.x) * t) / size.width
            let y = (from.y + (point.y - from.y) * t) / size.height
            wipes.append(Wipe(x: x, y: y, radius: 30 / 464, strength: 0.9))
            let reach = 11 / 464 as CGFloat
            drops.removeAll { abs($0.x - x) < reach && abs($0.y - y) * size.height / size.width < reach }
        }
        lastPoint = point
        lastWipe = Date.timeIntervalSinceReferenceDate
        refog = 0
    }

    func lift() { lastPoint = nil }

    /// The accessible equivalent of drawing: clear a band across the middle of the pane.
    func wipeBand() {
        lift()
        for step in 0...24 {
            wipe(at: CGPoint(x: size.width * (0.1 + 0.8 * CGFloat(step) / 24), y: size.height * 0.55))
        }
        lift()
    }

    private func seed(_ size: CGSize) {
        self.size = size
        drops = (0..<420).map { _ in Drop(x: .random(in: 0...1), y: .random(in: 0...1), radius: dropRadius(0.7, 2.8)) }
    }

    /// Mostly tiny drops, a few large ones, as on real glass.
    private func dropRadius(_ base: Double, _ spread: Double) -> CGFloat {
        CGFloat(base + pow(Double.random(in: 0...1), 3) * spread) / 464
    }

    private func smooth(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
