import Foundation
import simd

/// Spring-driven, non-periodic motion for N color points — a port of ColorfulX's
/// random speckle director: each point springs toward a random target in the unit
/// square and, once close, picks a new one. No sin/cos, so motion never visibly
/// repeats. Seedable so layouts are reproducible (and shareable across views).
///
/// Not `Sendable`: instances are owned and mutated on the main thread by the
/// animated graphic views.
final class FlowMotion {
    private struct Point { var pos: SIMD2<Float>; var vel: SIMD2<Float>; var target: SIMD2<Float> }
    private var pts: [Point]
    private var rng: SplitMix64

    init(count: Int, seed: UInt64 = 0xA11CE) {
        var g = SplitMix64(seed: seed)
        pts = (0..<max(1, count)).map { _ in
            Point(pos: SIMD2(Float(g.unit()), Float(g.unit())),
                  vel: .zero,
                  target: SIMD2(Float(g.unit()), Float(g.unit())))
        }
        rng = g
    }

    var positions: [SIMD2<Float>] { pts.map(\.pos) }

    /// Advance by a raw delta (seconds), scaled by `speed`.
    func advance(dt rawDt: Float, speed: Float) {
        let dt = min(max(rawDt, 0), 1.0 / 30.0) * max(speed, 0) * 1.6
        guard dt > 0 else { return }
        let k: Float = 8.0                 // stiffness
        let d: Float = 2 * k.squareRoot()  // critical damping
        for i in pts.indices {
            var p = pts[i]
            let accel = -k * (p.pos - p.target) - d * p.vel
            p.vel += accel * dt
            p.pos += p.vel * dt
            if abs(p.pos.x - p.target.x) < 0.12, abs(p.pos.y - p.target.y) < 0.12 {
                p.target = SIMD2(Float(rng.unit()), Float(rng.unit()))
            }
            pts[i] = p
        }
    }
}

/// Tiny deterministic PRNG so seeded layouts are reproducible in tests.
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func unit() -> Double {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z ^= (z >> 31)
        return Double(z >> 11) * (1.0 / 9007199254740992.0)
    }
}
