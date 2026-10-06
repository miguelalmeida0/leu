import SwiftUI

/// Steam from the cup: wisps born at the rim that rise, lean with a slow draft, curl,
/// widen and thin out. Purely decorative, so it is hidden from VoiceOver; under Reduce
/// Motion it slows to a near-still haze.
struct TeaSteam: View {
    /// Rim position inside this view, in points.
    let rim: CGPoint
    /// Rim half-width and how tall the wisps rise, in points.
    let rimRadius: CGFloat
    let height: CGFloat
    @State private var plume = SteamPlume()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { [plume, reduceMotion, rim, rimRadius, height] context, _ in
                let now = timeline.date.timeIntervalSinceReferenceDate
                plume.advance(to: now, reduced: reduceMotion, rimRadius: rimRadius)
                plume.paint(in: &context, now: now, rim: rim, height: height, slow: reduceMotion ? 0.3 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

final class SteamPlume {
    private struct Wisp { var born: Double; var life: Double; var x0: Double; var lean: Double; var phase: Double; var curl: Double; var width: Double }
    private var wisps: [Wisp] = []
    private var nextBirth: Double = 0

    func advance(to now: Double, reduced: Bool, rimRadius: CGFloat) {
        if now > nextBirth {
            wisps.append(Wisp(born: now, life: reduced ? 9 : .random(in: 6.2...7.8), x0: .random(in: -1...1) * Double(rimRadius) * 0.7,
                              lean: .random(in: -1...1) * 16 + 8, phase: .random(in: 0...9), curl: .random(in: 0.8...1.4), width: .random(in: 0.8...1.3)))
            nextBirth = now + (reduced ? 3.2 : .random(in: 1.25...1.85))
        }
        wisps.removeAll { (now - $0.born) / $0.life >= 1 }
    }

    func paint(in context: inout GraphicsContext, now: Double, rim: CGPoint, height: CGFloat, slow: Double) {
        let t = now * slow
        let tall = Double(height)
        let puff = Gradient(stops: [.init(color: Color(hex: 0xFFFDF8, opacity: 1), location: 0),
                                    .init(color: Color(hex: 0xFFFDF8, opacity: 0.55), location: 0.35),
                                    .init(color: Color(hex: 0xFFFDF8, opacity: 0), location: 1)])
        for wisp in wisps {
            let age = (now - wisp.born) / wisp.life
            // The wisp is a ribbon: its head rises with age, points along it trail back to the cup.
            let head = smooth(age * 1.25) * tall
            let envelope = smooth(age / 0.12) * (1 - smooth((age - 0.45) / 0.55))
            for step in 0..<28 {
                let f = Double(step) / 27
                let y = head * f
                guard y >= 1 else { continue }
                let rise = y / tall
                let drift = wisp.lean * rise * rise + sin(t * 0.35 + wisp.phase) * 6 * rise
                let curl = (sin(rise * 5.5 * wisp.curl - t + wisp.phase) * 17 + sin(rise * 2.6 - t * 0.4 + wisp.phase * 1.7) * 14) * pow(rise, 0.95)
                let x = Double(rim.x) + wisp.x0 * (1 - rise) + drift + curl
                let yy = Double(rim.y) - 4 - y
                let r = (3.5 + (19 - 3.5) * pow(rise, 0.9)) * wisp.width
                let alpha = envelope * sin(.pi * min(1, f * 1.05)) * smooth(rise / 0.12) * (1 - rise * 0.6) * 0.2
                guard alpha > 0.003 else { continue }
                let center = CGPoint(x: x, y: yy)
                var layer = context
                layer.opacity = alpha
                layer.fill(Path(ellipseIn: CGRect(x: x - r, y: yy - r, width: r * 2, height: r * 2)),
                           with: .radialGradient(puff, center: center, startRadius: 0, endRadius: r))
            }
        }
    }

    private func smooth(_ x: Double) -> Double {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }
}
