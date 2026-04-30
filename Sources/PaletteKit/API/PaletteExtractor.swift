import CoreGraphics
import Foundation

/// Entry point for extracting palettes, dominant colors, and semantic swatches from an image.
///
/// `PaletteExtractor` is a `Sendable` value type with no mutable state: create one per
/// call site, share one across actors, or cache a single static instance — all behave the
/// same. All public methods are `async throws` and honour cooperative cancellation via
/// `Task.cancel()`.
///
/// ```swift
/// let extractor = PaletteExtractor()
/// let palette = try await extractor.palette(from: .url(imageURL))
/// ```
///
/// See ``ExtractionOptions`` for tunable parameters and
/// <doc:GettingStarted> for a runnable example.
public struct PaletteExtractor: Sendable {
    private let loader: PixelLoader
    private let sampler: PixelSampler
    private let builder: PaletteBuilder

    /// Create a new extractor. Extractors are cheap: construct as needed.
    public init() {
        self.loader = PixelLoader()
        self.sampler = PixelSampler()
        self.builder = PaletteBuilder()
    }

    /// Extract a palette of representative colors.
    ///
    /// Runs the full pipeline: decode → downsample → filter → (optional OKLCH
    /// conversion) → quantize → assemble. Returns a ``Palette`` sorted by
    /// population.
    ///
    /// - Parameters:
    ///   - source: Where to read pixels from. See ``ImageSource``.
    ///   - options: Quality, filters, quantizer selection, etc. See
    ///     ``ExtractionOptions``.
    /// - Throws: ``PaletteError`` for decoding failures, empty input, or
    ///   filter-empty input when `fallbackStrategy == .fail`. `CancellationError`
    ///   when the calling task is cancelled.
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

    /// Convenience: returns the single most representative color.
    ///
    /// Runs a 5-color extraction internally and returns the color with the
    /// highest population. Use ``palette(from:options:)`` instead when you need
    /// the full result.
    public func dominantColor(
        from source: ImageSource,
        options: ExtractionOptions = .init()
    ) async throws -> PaletteColor? {
        var opts = options
        if opts.colorCount < 2 { opts.colorCount = 5 }
        let palette = try await palette(from: source, options: opts)
        return palette.dominant
    }

    /// Extract semantic swatches classified into six OKLCH-based roles.
    ///
    /// Runs a richer (16-color) extraction internally so the classifier has
    /// enough candidates for every role. Roles that don't clear their
    /// lightness / chroma bands are returned as `nil`.
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

    /// Sampled pixel count at which `.auto` switches from CPU to Metal.
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
