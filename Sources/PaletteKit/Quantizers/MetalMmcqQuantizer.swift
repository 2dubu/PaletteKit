import Foundation
#if canImport(Metal)
@preconcurrency import Metal

public struct MetalMmcqQuantizer: Quantizer {
    public let name = "MMCQ-Metal"

    public init() {}

    public func prepare() async throws {
        _ = try await MetalContext.shared.histogramResources()
    }

    public func quantize(
        pixels: [PixelTriplet],
        maxColors: Int
    ) async throws -> [QuantizedColor] {
        guard !pixels.isEmpty, maxColors >= 2, maxColors <= 256 else { return [] }
        try Task.checkCancellation()

        let histogram = try await buildHistogramOnGPU(pixels: pixels)
        try Task.checkCancellation()
        return try MmcqEngine.quantize(pixels: pixels, maxColors: maxColors, providedHistogram: histogram)
    }

    private func buildHistogramOnGPU(pixels: [PixelTriplet]) async throws -> [UInt32] {
        let (device, queue, pipeline) = try await MetalContext.shared.histogramResources()

        let pixelCount = pixels.count
        let flatBytes = pixelCount * 3
        guard let pixelBuffer = device.makeBuffer(length: flatBytes, options: MTLResourceOptions.storageModeShared) else {
            throw PaletteError.decodingFailed(reason: "Could not allocate Metal pixel buffer.")
        }
        pixelBuffer.contents().withMemoryRebound(to: UInt8.self, capacity: flatBytes) { dst in
            var cursor = 0
            for pixel in pixels {
                dst[cursor] = pixel.r
                dst[cursor + 1] = pixel.g
                dst[cursor + 2] = pixel.b
                cursor += 3
            }
        }

        let histogramLength = MmcqEngine.histSize * MemoryLayout<UInt32>.size
        guard let histogramBuffer = device.makeBuffer(length: histogramLength, options: MTLResourceOptions.storageModeShared) else {
            throw PaletteError.decodingFailed(reason: "Could not allocate Metal histogram buffer.")
        }
        memset(histogramBuffer.contents(), 0, histogramLength)

        var pixelCountArg = UInt32(pixelCount)

        guard let commandBuffer = queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw PaletteError.decodingFailed(reason: "Could not create Metal command encoder.")
        }

        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(pixelBuffer, offset: 0, index: 0)
        encoder.setBuffer(histogramBuffer, offset: 0, index: 1)
        encoder.setBytes(&pixelCountArg, length: MemoryLayout<UInt32>.size, index: 2)

        let threadsPerGroup = MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, 256), height: 1, depth: 1)
        let threadgroups = MTLSize(
            width: (pixelCount + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
            commandBuffer.commit()
        }
        if let error = commandBuffer.error {
            throw PaletteError.decodingFailed(reason: "Metal command buffer failed: \(error).")
        }

        var histogram = [UInt32](repeating: 0, count: MmcqEngine.histSize)
        let sourcePtr = histogramBuffer.contents().bindMemory(to: UInt32.self, capacity: MmcqEngine.histSize)
        histogram.withUnsafeMutableBufferPointer { dest in
            if let base = dest.baseAddress {
                base.update(from: sourcePtr, count: MmcqEngine.histSize)
            }
        }
        return histogram
    }

}
#endif
