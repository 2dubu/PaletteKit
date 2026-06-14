import Foundation
import simd
import Testing
@testable import PaletteKit

@Suite("FlowMotion")
struct FlowMotionTests {
    @Test("positions stay near the unit square")
    func bounds() {
        let motion = FlowMotion(count: 6, seed: 42)
        for _ in 0..<600 { motion.advance(dt: 1.0 / 60.0, speed: 1) }
        for p in motion.positions {
            #expect(p.x >= -0.3 && p.x <= 1.3)   // springs may overshoot slightly
            #expect(p.y >= -0.3 && p.y <= 1.3)
        }
    }

    @Test("is deterministic for a fixed seed")
    func deterministic() {
        let a = FlowMotion(count: 4, seed: 7)
        let b = FlowMotion(count: 4, seed: 7)
        for _ in 0..<120 { a.advance(dt: 1.0 / 60.0, speed: 1); b.advance(dt: 1.0 / 60.0, speed: 1) }
        for (pa, pb) in zip(a.positions, b.positions) {
            #expect(pa.x == pb.x)
            #expect(pa.y == pb.y)
        }
    }

    @Test("different seeds give different initial layouts")
    func seedVaries() {
        let a = FlowMotion(count: 4, seed: 1)
        let b = FlowMotion(count: 4, seed: 2)
        #expect(a.positions != b.positions)
    }

    @Test("dt of zero does not move points")
    func frozen() {
        let motion = FlowMotion(count: 3, seed: 1)
        let before = motion.positions
        motion.advance(dt: 0, speed: 1)
        #expect(motion.positions == before)
    }
}
