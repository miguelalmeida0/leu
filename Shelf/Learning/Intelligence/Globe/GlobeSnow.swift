import CoreGraphics
import Foundation

/// The water inside the snow globe: flakes that fall slowly, wander, settle on the hill and
/// the cottage roof, then quietly return. Lives outside SwiftUI so `Canvas` can step it.
///
/// Space is the render's world space in metres (globe centred at x = y = 0, z = `centreZ`).
/// `project` maps it into the artwork's pixel space (`GlobeArt.size`) with the camera
/// matrix exported from Blender, so every flake sits where the camera would have seen it.
final class GlobeSnow {
    struct Flake {
        var x = 0.0, y = 0.0, z = 0.0
        var vx = 0.0, vy = 0.0, vz = 0.0
        var size = 1.0, phase = 0.0, alpha = 0.0, settle = 0.0
    }

    private(set) var flakes: [Flake] = []
    /// How many windows should be lit (0…3) and how many are, eased toward it.
    var target = 0.0
    private(set) var shown = 0.0
    private(set) var swirl = 0.0
    private(set) var now = 0.0
    private var last: Double?
    private var pointer: (x: Double, y: Double)?
    private var push = (dx: 0.0, dy: 0.0)

    static let radius = 0.1, centreZ = 0.138

    init(count: Int, lit: Int) {
        target = Double(lit); shown = target
        flakes = (0..<count).map { _ in var flake = Flake(); Self.spawn(&flake, anywhere: true); return flake }
    }

    /// Light (or darken) windows. A new window shakes the globe a little, like a cheer.
    func light(_ windows: Int, reduced: Bool) {
        let next = Double(min(max(windows, 0), 3))
        if next > target && !reduced { swirl = 1 }
        target = next
        if reduced { shown = next }
    }

    func shake() { swirl = 1 }

    /// A finger or pointer moving over the glass, in artwork pixels.
    func stir(at point: CGPoint) {
        let next = (x: Double(point.x), y: Double(point.y))
        if let pointer {
            push = (dx: min(max(next.x - pointer.x, -40), 40), dy: min(max(next.y - pointer.y, -40), 40))
        }
        pointer = next
    }

    func release() { pointer = nil }

    func advance(to time: Double, reduced: Bool) {
        let dt = min(max(time - (last ?? time), 0), 1.0 / 15.0)
        last = time; now = time
        guard !reduced else { shown = target; swirl = 0; return }
        push.dx *= exp(-dt * 3); push.dy *= exp(-dt * 3)
        swirl = max(0, swirl - dt * 0.22)
        // A window warms up over a couple of seconds; one that goes out fades faster.
        shown = shown < target ? min(target, shown + dt / 2.6) : max(target, shown - dt / 1.2)
        let r = Self.radius, cz = Self.centreZ, spin = swirl * swirl
        for index in flakes.indices {
            var f = flakes[index]
            defer { flakes[index] = f }
            if f.settle > 0 {
                f.settle += dt; f.alpha = max(0, 1 - f.settle / 1.6)
                if f.settle > 1.6 { Self.spawn(&f, anywhere: false) }
                continue
            }
            f.alpha = min(1, f.alpha + dt / 1.2)
            // Snow in water: a slow fall, a little wandering, and a turn with the swirl.
            let n1 = Self.noise(now * 0.25 + f.phase, f.phase), n2 = Self.noise(now * 0.25 + f.phase + 40, f.phase * 1.3)
            f.vx += (n1 * 0.004 - f.y * 1.6 * spin - f.vx * 1.4) * dt
            f.vy += (n2 * 0.004 + f.x * 1.6 * spin - f.vy * 1.4) * dt
            f.vz += (-0.0055 - f.vz * 1.4 + spin * 0.016 * (1 - (f.z - cz) / r)) * dt
            if let pointer {
                let q = Self.project(f.x, f.y, f.z), d = hypot(q.x - pointer.x, q.y - pointer.y)
                if d < 80 { let k = pow(1 - d / 80, 2) * 0.000_06; f.vx += push.dx * k; f.vz -= push.dy * k }
            }
            f.x += f.vx * dt; f.y += f.vy * dt; f.z += f.vz * dt
            let distance = (f.x * f.x + f.y * f.y + (f.z - cz) * (f.z - cz)).squareRoot()
            if distance > r * 0.9 {
                let k = r * 0.9 / distance
                f.x *= k; f.y *= k; f.z = cz + (f.z - cz) * k; f.vx *= -0.3; f.vy *= -0.3
            }
            if f.z < Self.ground(hypot(f.x, f.y)) + 0.002 || Self.inHouse(f.x, f.y, f.z) { f.settle = 0.001 }
        }
    }

    // MARK: The scene, measured from the render

    /// Camera projection from world space to artwork pixels, plus the camera depth term.
    static func project(_ x: Double, _ y: Double, _ z: Double) -> (x: Double, y: Double, depth: Double) {
        let w = -0.1557 * x + 1.2842 * y - 0.4242 * z + 1
        let px = (2698.82 * x + 1304.43 * y - 318.13 * z + 750.0) / w
        let py = (33.72 * x - 278.20 * y - 2892.87 * z + 768.34) / w
        return (px - GlobeArt.cropOrigin.x, py - GlobeArt.cropOrigin.y, w)
    }

    /// Height of the snowy hill at a distance from the centre.
    static func ground(_ r: Double) -> Double {
        let profile: [(Double, Double)] = [(0, 0.112), (0.03, 0.11), (0.055, 0.103), (0.068, 0.093), (0.072, 0.08)]
        for i in 1..<profile.count where r <= profile[i].0 {
            let (r0, z0) = profile[i - 1], (r1, z1) = profile[i]
            return z0 + (z1 - z0) * (r - r0) / (r1 - r0)
        }
        return profile[profile.count - 1].1
    }

    static func inHouse(_ x: Double, _ y: Double, _ z: Double) -> Bool {
        abs(x) < 0.033 && abs(y - 0.008) < 0.026 && z < 0.162 && z > 0.1
    }

    private static func spawn(_ f: inout Flake, anywhere: Bool) {
        let r = radius * 0.86
        var x = 0.0, y = 0.0, z = 0.0
        repeat {
            x = Double.random(in: -1...1) * r; y = Double.random(in: -1...1) * r
            z = centreZ + (anywhere ? Double.random(in: -1...1) : Double.random(in: 0.35...0.9)) * r
        } while (x * x + y * y + (z - centreZ) * (z - centreZ)).squareRoot() > r || z < ground(hypot(x, y)) + 0.004
        f = Flake(x: x, y: y, z: z, size: Double.random(in: 0.55...1.45), phase: Double.random(in: 0...30), alpha: anywhere ? 1 : 0)
    }

    /// Smooth wandering in −1…1 without a noise table.
    private static func noise(_ t: Double, _ seed: Double) -> Double {
        sin(t * 1.7 + seed) * 0.6 + sin(t * 0.73 + seed * 2.1) * 0.4
    }
}
