import CoreGraphics
import Foundation

public struct PaletteExtractor: Sendable {
    private let loader: PixelLoader
    private let sampler: PixelSampler
    private let builder: PaletteBuilder

    public init() {
        self.loader = PixelLoader()
        self.sampler = PixelSampler()
        self.builder = PaletteBuilder()
    }

    public func palette(
        from source: ImageSource,
        options: ExtractionOptions = .init()
    ) async throws -> Palette {
        try validate(options: options)
        try Task.checkCancellation()

        let signposter = PaletteKitLog.signposter
        let signpostID = signposter.makeSignpostID()
        let signpostState = signposter.beginInterval("extract", id: signpostID)
        defer { signposter.endInterval("extract", signpostState) }

        var timingsBuilder = ExtractionTimingsBuilder()
        let collectTimings = options.collectTimings
        let clock = ContinuousClock()
        let totalStart = clock.now

        let (buffer, decodeDuration) = try measure {
            try loader.load(source: source, options: options)
        }
        if collectTimings { timingsBuilder.set(decode: decodeDuration) }
        try Task.checkCancellation()

        let (sampled, sampleDuration) = try measure {
            try sampler.sample(buffer: buffer, options: options)
        }
        if collectTimings { timingsBuilder.set(sample: sampleDuration) }
        try Task.checkCancellation()

        let outputColorSpace: ColorSpace = {
            switch options.colorSpace {
            case .oklch: return buffer.colorSpace
            case .sRGB: return .sRGB
            case .displayP3: return .displayP3
            }
        }()

        if sampled.triplets.isEmpty {
            return try emptyPipeline(
                options: options,
                buffer: buffer,
                colorSpaceUsed: outputColorSpace,
                timingsBuilder: &timingsBuilder,
                clock: clock,
                totalStart: totalStart,
                collectTimings: collectTimings
            )
        }

        let quantizer = resolveQuantizer(options: options, pixelCount: sampled.triplets.count)
        try await quantizer.prepare()

        let pixelsForQuantization: [PixelTriplet]
        if options.colorSpace == .oklch {
            pixelsForQuantization = BatchConversion.pixelsToOKLCHScaled(
                sampled.triplets,
                sourceSpace: buffer.colorSpace
            )
        } else {
            pixelsForQuantization = sampled.triplets
        }

        let (quantized, quantizeDuration) = try await measure {
            try await quantizer.quantize(
                pixels: pixelsForQuantization,
                maxColors: options.colorCount
            )
        }
        if collectTimings {
            timingsBuilder.set(quantize: quantizeDuration)
            timingsBuilder.set(quantizerUsed: quantizer.name)
        }
        try Task.checkCancellation()

        let finalQuantized: [QuantizedColor]
        if options.colorSpace == .oklch {
            finalQuantized = BatchConversion.scaledOKLCHToRGB(quantized)
        } else {
            finalQuantized = quantized
        }

        let timings = collectTimings ? buildTimings(&timingsBuilder, clock: clock, totalStart: totalStart) : nil

        return builder.build(
            quantized: finalQuantized,
            colorSpaceUsed: outputColorSpace,
            timings: timings
        )
    }

    public func dominantColor(
        from source: ImageSource,
        options: ExtractionOptions = .init()
    ) async throws -> PaletteColor? {
        var opts = options
        if opts.colorCount < 2 { opts.colorCount = 5 }
        let palette = try await palette(from: source, options: opts)
        return palette.dominant
    }

    public func swatches(
        from source: ImageSource,
        options: ExtractionOptions = .init()
    ) async throws -> SwatchMap {
        var opts = options
        if opts.colorCount < 16 { opts.colorCount = 16 }
        let palette = try await palette(from: source, options: opts)
        return SwatchClassifier().classify(palette: palette)
    }

    private func emptyPipeline(
        options: ExtractionOptions,
        buffer: PixelBuffer,
        colorSpaceUsed: ColorSpace,
        timingsBuilder: inout ExtractionTimingsBuilder,
        clock: ContinuousClock,
        totalStart: ContinuousClock.Instant,
        collectTimings: Bool
    ) throws -> Palette {
        switch options.fallbackStrategy {
        case .fail:
            throw PaletteError.allPixelsFiltered
        case .averageOnly, .relax:
            let timings = collectTimings ? buildTimings(&timingsBuilder, clock: clock, totalStart: totalStart) : nil
            return builder.averageFallback(
                buffer: buffer,
                quality: options.quality.strideValue,
                colorSpaceUsed: colorSpaceUsed,
                timings: timings
            )
        }
    }

    private func resolveQuantizer(options: ExtractionOptions, pixelCount: Int) -> any Quantizer {
        switch options.quantizer {
        case .auto:
            return pixelCount >= PaletteExtractor.metalAutoThreshold
                ? metalOrCPUFallback()
                : MmcqQuantizer()
        case .cpu:
            return MmcqQuantizer()
        case .metal:
            return metalOrCPUFallback()
        case .custom(let quantizer):
            return quantizer
        }
    }

    /// Jointly chosen threshold. Subject to retuning once v0.4+ benchmarks land.
    static let metalAutoThreshold = 500_000

    private func metalOrCPUFallback() -> any Quantizer {
        #if canImport(Metal)
        return MetalMmcqQuantizer()
        #else
        PaletteKitLog.extraction.notice("Metal requested but unavailable on this platform — using CPU.")
        return MmcqQuantizer()
        #endif
    }

    private func validate(options: ExtractionOptions) throws {
        guard options.colorCount >= 2, options.colorCount <= 256 else {
            throw PaletteError.decodingFailed(reason: "colorCount must be between 2 and 256; got \(options.colorCount).")
        }
    }

    private func buildTimings(
        _ builder: inout ExtractionTimingsBuilder,
        clock: ContinuousClock,
        totalStart: ContinuousClock.Instant
    ) -> ExtractionTimings {
        builder.set(total: totalStart.duration(to: clock.now))
        return builder.build()
    }
}
