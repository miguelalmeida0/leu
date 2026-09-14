import SwiftUI
import ShelfCore

/// Original, deterministic cover artwork. No downloaded art, runtime generation service, or network.
struct CoverIllustration: View {
    let art: CoverArt
    let colors: CoverColors
    var body: some View {
        Canvas { context, size in
            switch art {
            case .dunes: dunes(context, size)
            case .mountains: mountains(context, size)
            case .spheres: spheres(context, size)
            case .cube: cube(context, size)
            case .arches: arches(context, size)
            case .folds: folds(context, size)
            }
        }.accessibilityHidden(true)
    }
    private func dunes(_ c: GraphicsContext, _ s: CGSize) {
        for i in 0..<4 {
            let y = s.height * (0.24 + Double(i) * 0.15)
            var p = Path(); p.move(to: CGPoint(x: -20, y: y + 50))
            p.addCurve(to: CGPoint(x: s.width + 25, y: y - 30),
                       control1: CGPoint(x: s.width * 0.36, y: y - 95),
                       control2: CGPoint(x: s.width * 0.6, y: y + 90))
            p.addLine(to: CGPoint(x: s.width + 25, y: s.height + 10))
            p.addLine(to: CGPoint(x: -20, y: s.height + 10)); p.closeSubpath()
            c.fill(p, with: .color(i.isMultiple(of: 2) ? colors.light.opacity(0.7) : colors.shadow))
        }
    }
    private func mountains(_ c: GraphicsContext, _ s: CGSize) {
        for i in 0..<3 {
            let y = s.height * (0.08 + Double(i) * 0.21)
            var p = Path(); p.move(to: CGPoint(x: -8, y: s.height))
            p.addLine(to: CGPoint(x: s.width * 0.46, y: y + 32))
            p.addLine(to: CGPoint(x: s.width * 0.60, y: y + 51))
            p.addLine(to: CGPoint(x: s.width * 0.80, y: y))
            p.addLine(to: CGPoint(x: s.width + 10, y: s.height)); p.closeSubpath()
            c.fill(p, with: .color(i == 1 ? colors.shadow : colors.light.opacity(i == 0 ? 0.6 : 0.9)))
            var ridge = Path(); ridge.move(to: CGPoint(x: s.width * 0.8, y: y))
            ridge.addLine(to: CGPoint(x: s.width * 0.62, y: s.height))
            ridge.addLine(to: CGPoint(x: s.width + 10, y: s.height)); ridge.closeSubpath()
            c.fill(ridge, with: .color(colors.background.opacity(0.35)))
        }
    }
    private func spheres(_ c: GraphicsContext, _ s: CGSize) {
        let radius = s.width * 0.23
        for (x, y, factor) in [(0.48, 0.38, 1.0), (0.72, 0.69, 0.8)] {
            let rect = CGRect(x: s.width*x-radius*factor, y: s.height*y-radius*factor,
                              width: radius*2*factor, height: radius*2*factor)
            c.fill(Path(ellipseIn: rect), with: .linearGradient(
                Gradient(colors: [colors.light, colors.shadow, colors.background]),
                startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
        }
    }
    private func cube(_ c: GraphicsContext, _ s: CGSize) {
        let center = CGPoint(x: s.width*0.55, y: s.height*0.55)
        let w = s.width*0.31, h = w*0.46
        func poly(_ points: [CGPoint], _ color: Color) {
            var p = Path(); p.addLines(points); p.closeSubpath(); c.fill(p, with: .color(color))
        }
        let top = CGPoint(x: center.x, y: center.y-h*1.8)
        let left = CGPoint(x: center.x-w, y: center.y-h*0.8)
        let right = CGPoint(x: center.x+w, y: center.y-h*0.8)
        let front = CGPoint(x: center.x, y: center.y+h*0.2)
        poly([top, right, front, left], colors.light)
        poly([left, front, CGPoint(x: front.x, y: front.y+w), CGPoint(x: left.x, y: left.y+w)], colors.shadow)
        poly([front, right, CGPoint(x: right.x, y: right.y+w), CGPoint(x: front.x, y: front.y+w)], colors.muted.opacity(0.6))
    }
    private func arches(_ c: GraphicsContext, _ s: CGSize) {
        for i in 0..<4 {
            let x = s.width*(0.18 + Double(i)*0.25), y = s.height*(0.22 + Double(i % 2)*0.23)
            let rect = CGRect(x: x, y: y, width: s.width*0.5, height: s.height*1.2)
            c.fill(Path(roundedRect: rect, cornerRadius: s.width*0.25),
                   with: .color(i.isMultiple(of: 2) ? colors.shadow : colors.light.opacity(0.8)))
        }
    }
    private func folds(_ c: GraphicsContext, _ s: CGSize) {
        for i in 0..<4 {
            let x = Double(i) * s.width * 0.27
            var p = Path(); p.move(to: CGPoint(x: x, y: s.height*0.4))
            p.addLine(to: CGPoint(x: x+s.width*0.32, y: s.height*0.1))
            p.addLine(to: CGPoint(x: x+s.width*0.32, y: s.height*0.8))
            p.addLine(to: CGPoint(x: x, y: s.height)); p.closeSubpath()
            c.fill(p, with: .color(i.isMultiple(of: 2) ? colors.light : colors.shadow))
        }
    }
}
