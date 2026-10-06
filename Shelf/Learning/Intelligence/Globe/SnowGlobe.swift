import SwiftUI

/// A snow globe with a cottage inside. Each idea the reader gets across lights one of its
/// three windows; the third glows in slowly and gives the water a little swirl.
///
/// The globe, cottage and base are a Blender render; snow, window light and glow are drawn
/// live. Drag across the glass (or move the iPad pointer over it) to stir the snow; tap it,
/// or use the VoiceOver action, to give it a gentle shake. Reduce Motion stills the snow.
@MainActor
struct SnowGlobe: View {
    /// Windows lit, 0…3.
    let lit: Int
    @State private var snow: GlobeSnow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(lit: Int) {
        self.lit = lit
        _snow = State(initialValue: GlobeSnow(count: 170, lit: lit))
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / GlobeArt.size.width
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                Canvas { [snow, reduceMotion, lit] context, size in
                    _ = lit
                    snow.advance(to: timeline.date.timeIntervalSinceReferenceDate, reduced: reduceMotion)
                    GlobePainter.paint(snow, in: &context, size: size, reduced: reduceMotion)
                }
            }
            .contentShape(Circle().path(in: GlobeArt.glass(scale: scale)))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in snow.stir(at: GlobeArt.artwork(value.location, scale: scale)) }
                .onEnded { value in
                    if hypot(value.translation.width, value.translation.height) < 6 && !reduceMotion { snow.shake() }
                    snow.release()
                })
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): snow.stir(at: GlobeArt.artwork(point, scale: scale))
                case .ended: snow.release()
                }
            }
        }
        .aspectRatio(GlobeArt.size.width / GlobeArt.size.height, contentMode: .fit)
        .onChange(of: lit, initial: false) { _, windows in snow.light(windows, reduced: reduceMotion) }
        .accessibilityElement()
        .accessibilityLabel("A snow globe with a little cottage inside")
        .accessibilityValue(lit == 0 ? "No windows lit yet" : lit == 3 ? "All three windows lit" : "\(lit) of 3 windows lit")
        .accessibilityHint("Each idea you get across lights a window.")
        .accessibilityAction(named: "Shake the globe") { if !reduceMotion { snow.shake() } }
    }
}

/// Where things are in the artwork, in its own pixels (`Globe/Base` is 1155 × 855).
enum GlobeArt {
    static let size = CGSize(width: 1155, height: 855)
    /// Offset of the cropped artwork inside the full Blender frame the camera matrix uses.
    static let cropOrigin = (x: 238.0, y: 77.0)
    static let centre = CGPoint(x: 512, y: 315.07)
    static let radius: CGFloat = 301.25 * 0.985
    /// The lit third window and the light it spills on the snow.
    static let litRect = CGRect(x: 317, y: 190, width: 382, height: 262)
    /// Window glass, left to right. The render has the first two lit and the third dark.
    static let panes = [CGRect(x: 440, y: 352, width: 29.5, height: 32.5),
                        CGRect(x: 493, y: 353.5, width: 29, height: 31.5),
                        CGRect(x: 547, y: 356, width: 29, height: 31)]

    static func glass(scale: CGFloat) -> CGRect {
        CGRect(x: (centre.x - radius) * scale, y: (centre.y - radius) * scale, width: radius * 2 * scale, height: radius * 2 * scale)
    }

    static func artwork(_ point: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: point.x / max(scale, 0.01), y: point.y / max(scale, 0.01))
    }
}

/// Draws one frame of the globe. Free of view state so it can run inside `Canvas`.
enum GlobePainter {
    private static let warm = Color(hex: 0xFFCD78)
    private static let darkGlass = Color(hex: 0x2C2A2D)
    private static let mullion = Color(hex: 0xE2D6BE)

    static func paint(_ snow: GlobeSnow, in context: inout GraphicsContext, size: CGSize, reduced: Bool) {
        let s = size.width / GlobeArt.size.width
        context.draw(Image("Globe/Base"), in: CGRect(origin: .zero, size: size))
        context.drawLayer { inside in
            inside.clip(to: Path(ellipseIn: GlobeArt.glass(scale: s)))
            // Snow behind the cottage, hidden wherever the cottage, trees and hill stand.
            inside.drawLayer { back in
                for flake in snow.flakes where flake.y > 0.006 { draw(flake, in: &back, scale: s, now: snow.now, reduced: reduced) }
                back.blendMode = .destinationOut
                back.draw(Image("Globe/Interior"), in: CGRect(origin: .zero, size: size))
            }
            let shown = snow.shown
            // The first two windows are lit in the render: dark glass covers them until earned.
            for k in 0..<2 {
                let dark = min(max(Double(k + 1) - shown, 0), 1)
                if dark > 0 { drawDarkPane(GlobeArt.panes[k], in: &inside, scale: s, opacity: dark) }
            }
            let third = smooth(min(max(shown - 2, 0), 1))
            if third > 0 {
                var lit = inside
                lit.opacity = third
                lit.draw(Image("Globe/Lit"), in: scaled(GlobeArt.litRect, s))
            }
            // A soft breathing glow in every lit window.
            for (k, pane) in GlobeArt.panes.enumerated() {
                let on = smooth(min(max(shown - Double(k), 0), 1))
                guard on > 0 else { continue }
                let t = snow.now, j = Double(k)
                let flicker: Double = reduced ? 0.85 : 0.75 + 0.25 * sin(t * (1.1 + j * 0.23) + j * 2) * sin(t * 0.37 + j)
                let bloom: Double = k == 2 ? 1.6 * (1 - abs(on * 2 - 1)) : 0
                let r = CGFloat(25.9 * (2.4 + bloom)) * s, c = CGPoint(x: pane.midX * s, y: pane.midY * s)
                var glow = inside
                glow.blendMode = .plusLighter
                glow.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                          with: .radialGradient(Gradient(colors: [warm.opacity(0.22 * on * flicker), warm.opacity(0)]),
                                                center: c, startRadius: 0, endRadius: r))
            }
            for flake in snow.flakes where flake.y <= 0.006 { draw(flake, in: &inside, scale: s, now: snow.now, reduced: reduced) }
        }
    }

    /// A soft flake: a faint halo and a brighter core, two flat fills.
    private static func draw(_ f: GlobeSnow.Flake, in context: inout GraphicsContext, scale: CGFloat, now: Double, reduced: Bool) {
        let q = GlobeSnow.project(f.x, f.y, f.z), k = Double(scale)
        let r: Double = f.size * 2.5 * (1.25 - q.depth * 0.25) * k
        let twinkle: Double = reduced ? 0.75 : 0.55 + 0.35 * sin(now * 0.7 + f.phase)
        let alpha = f.alpha * twinkle
        guard alpha > 0.02, r > 0.2 else { return }
        let x: Double = q.x * k, y: Double = q.y * k
        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha * 0.3)))
        context.fill(Path(ellipseIn: CGRect(x: x - r * 0.45, y: y - r * 0.45, width: r * 0.9, height: r * 0.9)), with: .color(.white.opacity(alpha * 0.9)))
    }

    private static func drawDarkPane(_ pane: CGRect, in context: inout GraphicsContext, scale: CGFloat, opacity: Double) {
        let rect = scaled(pane, scale)
        var layer = context
        layer.opacity = opacity
        layer.fill(Path(roundedRect: rect, cornerRadius: 1.5 * scale), with: .color(darkGlass))
        var bars = Path()
        bars.move(to: CGPoint(x: rect.midX, y: rect.minY)); bars.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        bars.move(to: CGPoint(x: rect.minX, y: rect.midY)); bars.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        layer.stroke(bars, with: .color(mullion), lineWidth: 2.7 * scale)
    }

    private static func scaled(_ rect: CGRect, _ s: CGFloat) -> CGRect {
        CGRect(x: rect.minX * s, y: rect.minY * s, width: rect.width * s, height: rect.height * s)
    }

    private static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
}
