import Foundation

public struct SampledPixels: Sendable {
    public let triplets: [PixelTriplet]
    public let filtersApplied: FiltersApplied

    public struct FiltersApplied: Sendable, Equatable {
        public var ignoreWhite: Bool
        public var alphaThreshold: UInt8
        public var minSaturation: Double
    }
}

public struct PixelSampler: Sendable {
    public init() {}

    public func sample(
        buffer: PixelBuffer,
        options: ExtractionOptions
    ) throws -> SampledPixels {
        try Task.checkCancellation()

        var filters = SampledPixels.FiltersApplied(
            ignoreWhite: options.ignoreWhite,
            alphaThreshold: options.alphaThreshold,
            minSaturation: options.minSaturation
        )
        var triplets = subsample(buffer: buffer, quality: options.quality.strideValue, filters: filters, whiteThreshold: options.whiteThreshold)

        if triplets.isEmpty, options.fallbackStrategy == .relax, options.ignoreWhite {
            filters.ignoreWhite = false
            triplets = subsample(buffer: buffer, quality: options.quality.strideValue, filters: filters, whiteThreshold: options.whiteThreshold)
        }

        if triplets.isEmpty, options.fallbackStrategy == .relax, options.alphaThreshold > 0 {
            filters.alphaThreshold = 0
            triplets = subsample(buffer: buffer, quality: options.quality.strideValue, filters: filters, whiteThreshold: options.whiteThreshold)
        }

        return SampledPixels(triplets: triplets, filtersApplied: filters)
    }

    private func subsample(
        buffer: PixelBuffer,
        quality: Int,
        filters: SampledPixels.FiltersApplied,
        whiteThreshold: UInt8
    ) -> [PixelTriplet] {
        let pixelCount = buffer.pixelCount
        guard pixelCount > 0 else { return [] }

        var result: [PixelTriplet] = []
        let estimated = max(1, pixelCount / quality)
        result.reserveCapacity(estimated)

        buffer.data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var index = 0
            while index < pixelCount {
                let offset = index * 4
                let r = base[offset]
                let g = base[offset + 1]
                let b = base[offset + 2]
                let a = base[offset + 3]

                if a < filters.alphaThreshold { index += quality; continue }

                if filters.ignoreWhite,
                   r > whiteThreshold,
                   g > whiteThreshold,
                   b > whiteThreshold {
                    index += quality; continue
                }

                if filters.minSaturation > 0 {
                    let maxChannel = max(r, max(g, b))
                    let minChannel = min(r, min(g, b))
                    if maxChannel == 0 {
                        index += quality; continue
                    }
                    let saturation = Double(maxChannel - minChannel) / Double(maxChannel)
                    if saturation < filters.minSaturation {
                        index += quality; continue
                    }
                }

                result.append(PixelTriplet(r: r, g: g, b: b))
                index += quality
            }
        }
        return result
    }
}
