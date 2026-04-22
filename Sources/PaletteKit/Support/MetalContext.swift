import Foundation
#if canImport(Metal)
import Metal

/// Caches the `MTLDevice`, `MTLCommandQueue`, and the histogram pipeline so the cold-start
/// cost (shader compile + pipeline build) is paid at most once per process.
actor MetalContext {
    static let shared = MetalContext()

    private var device: (any MTLDevice)?
    private var commandQueue: (any MTLCommandQueue)?
    private var histogramPipeline: (any MTLComputePipelineState)?

    private init() {}

    func histogramResources() throws -> (any MTLDevice, any MTLCommandQueue, any MTLComputePipelineState) {
        if let device, let commandQueue, let histogramPipeline {
            return (device, commandQueue, histogramPipeline)
        }

        guard let device = MTLCreateSystemDefaultDevice() else {
            throw PaletteError.metalUnavailable
        }
        guard let queue = device.makeCommandQueue() else {
            throw PaletteError.metalUnavailable
        }

        let library: any MTLLibrary
        do {
            library = try device.makeLibrary(source: Self.histogramShaderSource, options: nil)
        } catch {
            throw PaletteError.decodingFailed(reason: "Failed to compile PaletteKit Metal shader: \(error).")
        }

        guard let function = library.makeFunction(name: "mmcq_build_histogram") else {
            throw PaletteError.decodingFailed(reason: "Metal function 'mmcq_build_histogram' not found.")
        }

        let pipeline: any MTLComputePipelineState
        do {
            pipeline = try device.makeComputePipelineState(function: function)
        } catch {
            throw PaletteError.decodingFailed(reason: "Could not build Metal compute pipeline: \(error).")
        }

        self.device = device
        self.commandQueue = queue
        self.histogramPipeline = pipeline
        return (device, queue, pipeline)
    }

    /// 5-bit-per-channel 3D histogram. Each threadgroup processes one slab of the pixel
    /// buffer and atomically accumulates into a single 32,768-bin Uint32 buffer that the
    /// CPU-side median-cut phases consume verbatim. Mirrored verbatim in
    /// Sources/PaletteKit/Metal/Histogram.metal for reference / Xcode-native builds.
    fileprivate static let histogramShaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void mmcq_build_histogram(
        device const uchar *pixels [[buffer(0)]],
        device atomic_uint *histogram [[buffer(1)]],
        constant uint &pixelCount [[buffer(2)]],
        uint tid [[thread_position_in_grid]]
    ) {
        if (tid >= pixelCount) { return; }
        const uint offset = tid * 3u;
        const uint r = uint(pixels[offset]) >> 3u;
        const uint g = uint(pixels[offset + 1u]) >> 3u;
        const uint b = uint(pixels[offset + 2u]) >> 3u;
        const uint index = (r << 10u) + (g << 5u) + b;
        atomic_fetch_add_explicit(&histogram[index], 1u, memory_order_relaxed);
    }
    """
}
#endif
