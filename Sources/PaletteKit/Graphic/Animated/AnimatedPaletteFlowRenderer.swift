#if canImport(UIKit)
import MetalKit
import simd

private let kFlowSlots = AnimatedPaletteFlowShader.slots

/// Mirror of the Metal `FlowUniforms` layout. File-scope (not nested in a
/// @MainActor type) so the nonisolated renderer can build it.
private struct FlowUniforms {
    var count: Int32 = 0
    var bias: Float = 0.01
    var power: Float = 4
    var pad: Float = 0
    var points: (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>,
                 SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>) =
        (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
    var colors: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
                 SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) =
        (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
}

/// Drives the Metal pipeline + per-frame draw for ``AnimatedPaletteGraphicView``.
/// Not `@MainActor`: `MTKViewDelegate` requirements are nonisolated, and all
/// access happens on the main thread (view updates + MTKView's main-loop calls).
final class AnimatedPaletteFlowRenderer: NSObject, MTKViewDelegate {
    private var pipeline: MTLRenderPipelineState?
    private var queue: MTLCommandQueue?
    private var motion: FlowMotion?
    private var colors: [SIMD4<Float>] = []   // xyz = LAB
    private var count = 0
    private var speed: Float = 0.2
    private var frozen = false
    private var lastTime = CACurrentMediaTime()

    @MainActor
    func configure(view: MTKView) {
        guard let device = view.device,
              let library = try? device.makeLibrary(source: AnimatedPaletteFlowShader.source, options: nil)
        else { return }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library.makeFunction(name: "paletteFlowVertex")
        desc.fragmentFunction = library.makeFunction(name: "paletteFlowFragment")
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipeline = try? device.makeRenderPipelineState(descriptor: desc)
        queue = device.makeCommandQueue()
    }

    /// `labColors` are CIE LAB vectors (see ``LABConversion``).
    func update(labColors: [SIMD3<Float>], speed: Float, frozen: Bool) {
        let n = min(kFlowSlots, max(1, labColors.count))
        if n != count || motion == nil {
            count = n
            motion = FlowMotion(count: n)
        }
        colors = (0..<n).map { SIMD4(labColors[$0].x, labColors[$0].y, labColors[$0].z, 1) }
        self.speed = speed
        self.frozen = frozen
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pipeline, let queue, let motion,
              let rpd = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let buffer = queue.makeCommandBuffer(),
              let enc = buffer.makeRenderCommandEncoder(descriptor: rpd) else { return }

        let now = CACurrentMediaTime()
        let dt = Float(now - lastTime)
        lastTime = now
        if !frozen { motion.advance(dt: dt, speed: speed) }
        let pos = motion.positions

        var u = FlowUniforms()
        u.count = Int32(count)
        u.power = AnimatedPaletteGraphic.Configuration.power
        withUnsafeMutablePointer(to: &u.points) { ptr in
            ptr.withMemoryRebound(to: SIMD2<Float>.self, capacity: kFlowSlots) { dst in
                for i in 0..<count { dst[i] = pos[i] }
            }
        }
        withUnsafeMutablePointer(to: &u.colors) { ptr in
            ptr.withMemoryRebound(to: SIMD4<Float>.self, capacity: kFlowSlots) { dst in
                for i in 0..<count { dst[i] = colors[i] }
            }
        }
        enc.setRenderPipelineState(pipeline)
        enc.setFragmentBytes(&u, length: MemoryLayout<FlowUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }
}
#endif
