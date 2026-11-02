import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PaletteKit

@Suite("Shared extraction preprocessing")
struct SharedExtractionTests {
    @Test("paired CPU extraction preserves palette and richer swatches", arguments: [2, 10, 16, 32], [ColorSpace.sRGB, .displayP3, .oklch])
    func pairedMatchesSeparate(colorCount: Int, colorSpace: ColorSpace) async throws {
        let extractor = PaletteExtractor()
        for sourceSpace in [CGColorSpace.sRGB, CGColorSpace.displayP3] {
            let image = try makeImage(colorSpace: sourceSpace)
            for quantizer in [QuantizerSelection.auto, .cpu] {
                let options = ExtractionOptions(
                    colorCount: colorCount,
                    quality: .highest,
                    colorSpace: colorSpace,
                    ignoreWhite: false,
                    downsample: .disabled,
                    quantizer: quantizer,
                    collectTimings: true
                )
                let expectedPalette = try await extractor.palette(from: .cgImage(image), options: options)
                let expectedSwatches = try await extractor.swatches(from: .cgImage(image), options: options)
                let actual = try await extractor.paletteAndSwatches(from: .cgImage(image), options: options)
                expectEquivalent(actual.palette, expectedPalette)
                expectEquivalent(try #require(actual.swatches), expectedSwatches)
                #expect(actual.palette.count <= colorCount)
                let timings = try #require(actual.palette.timings)
                #expect(timings.quantizerUsed == "MMCQ-CPU")
                #expect(timings.total >= timings.decode + timings.sample + timings.quantize)
            }
        }
    }

    @Test("encoded input preserves sampling, resizing, and filter options")
    func encodedInputWithOptions() async throws {
        let image = try makeImage()
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        let source = ImageSource.data(data as Data)
        let options = ExtractionOptions(
            colorCount: 5,
            quality: .stride(3),
            ignoreWhite: true,
            whiteThreshold: 210,
            alphaThreshold: 200,
            minSaturation: 0.2,
            downsample: .maxEdge(23),
            quantizer: .cpu
        )
        let extractor = PaletteExtractor()
        let expected = try await extractor.palette(from: source, options: options)
        let expectedSwatches = try await extractor.swatches(from: source, options: options)
        let actual = try await extractor.paletteAndSwatches(from: source, options: options)
        expectEquivalent(actual.palette, expected)
        expectEquivalent(try #require(actual.swatches), expectedSwatches)
        #expect(actual.palette.timings == nil)
    }

    @Test("empty-filter fallbacks use the original pixel buffer", arguments: [FallbackStrategy.relax, .averageOnly], [ColorSpace.sRGB, .oklch])
    func averageFallback(strategy: FallbackStrategy, colorSpace: ColorSpace) async throws {
        let image = try makeImage(solid: (80, 80, 80, 255))
        let options = ExtractionOptions(
            colorSpace: colorSpace,
            minSaturation: 1,
            fallbackStrategy: strategy,
            quantizer: .cpu
        )
        let extractor = PaletteExtractor()
        let expected = try await extractor.palette(from: .cgImage(image), options: options)
        let actual = try await extractor.paletteAndSwatches(from: .cgImage(image), options: options)
        expectEquivalent(actual.palette, expected)
        #expect(actual.palette.colors.map(\.rgb) == [RGB(r: 80, g: 80, b: 80)])
        expectEquivalent(try #require(actual.swatches), SwatchClassifier().classify(palette: expected))
    }

    @Test("relaxed white and alpha filters preserve separate extraction results")
    func relaxedFilters() async throws {
        let extractor = PaletteExtractor()
        for pixel: (UInt8, UInt8, UInt8, UInt8) in [(255, 255, 255, 255), (0, 0, 0, 0)] {
            let source = ImageSource.cgImage(try makeImage(solid: pixel))
            let options = ExtractionOptions(quantizer: .cpu)
            let expected = try await extractor.palette(from: source, options: options)
            let actual = try await extractor.paletteAndSwatches(from: source, options: options)
            expectEquivalent(actual.palette, expected)
            expectEquivalent(try #require(actual.swatches), try await extractor.swatches(from: source, options: options))
        }
    }

    @Test("first extraction failures propagate before swatch work")
    func firstFailure() async throws {
        let source = ImageSource.cgImage(try makeImage(solid: (255, 255, 255, 255)))
        let extractor = PaletteExtractor()
        await #expect(throws: PaletteError.allPixelsFiltered) {
            _ = try await extractor.paletteAndSwatches(from: source, options: .init(fallbackStrategy: .fail))
        }
        for count in [0, 1, 257] {
            await #expect(throws: PaletteError.self) {
                _ = try await extractor.paletteAndSwatches(from: source, options: .init(colorCount: count))
            }
        }
    }

    @Test("custom quantizers retain two prepare and quantize calls", arguments: [2, 16, 32])
    func customCalls(colorCount: Int) async throws {
        let quantizer = RecordingQuantizer()
        let result = try await PaletteExtractor().paletteAndSwatches(
            from: .cgImage(try makeImage()),
            options: .init(colorCount: colorCount, colorSpace: .sRGB, quantizer: .custom(quantizer), collectTimings: true)
        )
        #expect(await quantizer.events == ["prepare", "quantize:\(colorCount)", "prepare", "quantize:\(max(colorCount, 16))"])
        #expect(result.palette.timings?.quantizerUsed == "Recording")
        #expect(result.swatches != nil)
    }

    @Test("second custom failure preserves the first palette and nil swatches")
    func secondFailure() async throws {
        let quantizer = RecordingQuantizer(failOnCall: 2)
        let result = try await PaletteExtractor().paletteAndSwatches(
            from: .cgImage(try makeImage()),
            options: .init(colorSpace: .sRGB, quantizer: .custom(quantizer))
        )
        #expect(result.palette.colors.map(\.rgb) == [RGB(r: 180, g: 60, b: 40)])
        #expect(result.swatches == nil)
        #expect(await quantizer.events == ["prepare", "quantize:10", "prepare", "quantize:16"])
    }

    @Test("cancelled extraction does not start preparation")
    func cancelledBeforePreparation() async throws {
        let quantizer = RecordingQuantizer()
        let image = try makeImage()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await PaletteExtractor().paletteAndSwatches(
                from: .cgImage(image),
                options: .init(quantizer: .custom(quantizer))
            )
        }
        await #expect(throws: CancellationError.self) { _ = try await task.value }
        #expect(await quantizer.events.isEmpty)
    }
}

private actor RecordingQuantizer: Quantizer {
    nonisolated let name = "Recording"
    var events: [String] = []
    private var calls = 0
    private let failOnCall: Int?

    init(failOnCall: Int? = nil) { self.failOnCall = failOnCall }
    func prepare() async throws { events.append("prepare") }
    func quantize(pixels: [PixelTriplet], maxColors: Int) async throws -> [QuantizedColor] {
        calls += 1
        events.append("quantize:\(maxColors)")
        if calls == failOnCall { throw PaletteError.imageEmpty }
        return [QuantizedColor(color: PixelTriplet(r: 180, g: 60, b: 40), population: pixels.count)]
    }
}

private func expectEquivalent(_ actual: Palette, _ expected: Palette) {
    #expect(actual.colors.map(\.rgb) == expected.colors.map(\.rgb))
    #expect(actual.colors.map(\.population) == expected.colors.map(\.population))
    #expect(actual.colors.map(\.proportion) == expected.colors.map(\.proportion))
    #expect(actual.colorSpaceUsed == expected.colorSpaceUsed)
}

private func expectEquivalent(_ actual: SwatchMap, _ expected: SwatchMap) {
    for role in SwatchRole.allCases { #expect(actual[role] == expected[role], "role: \(role)") }
}

private func makeImage(
    colorSpace: CFString = CGColorSpace.sRGB,
    solid: (UInt8, UInt8, UInt8, UInt8)? = nil
) throws -> CGImage {
    let size = 48
    var pixels = [UInt8](repeating: 0, count: size * size * 4)
    var state: UInt64 = 0x1985_1028
    for i in 0..<(size * size) {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let rgba = solid ?? (UInt8(truncatingIfNeeded: state >> 24), UInt8(truncatingIfNeeded: state >> 40), UInt8(truncatingIfNeeded: state >> 56), 255)
        pixels[i * 4] = rgba.0
        pixels[i * 4 + 1] = rgba.1
        pixels[i * 4 + 2] = rgba.2
        pixels[i * 4 + 3] = rgba.3
    }
    let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
    let space = try #require(CGColorSpace(name: colorSpace))
    return try #require(CGImage(
        width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
        space: space,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    ))
}
