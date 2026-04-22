import CoreGraphics
import Foundation
import Testing
@testable import PaletteKit

@Suite("PaletteExtractor")
struct PaletteExtractorTests {
    @Test("solid red image yields red dominant color")
    func solidRed() async throws {
        let image = try makeSolidImage(color: (255, 0, 0), size: 64)
        let extractor = PaletteExtractor()
        let color = try await extractor.dominantColor(from: .cgImage(image))
        try #require(color != nil)
        #expect(color!.rgb.r > 200)
        #expect(color!.rgb.g < 50)
        #expect(color!.rgb.b < 50)
    }

    @Test("solid black image yields near-black")
    func solidBlack() async throws {
        let image = try makeSolidImage(color: (0, 0, 0), size: 32)
        let extractor = PaletteExtractor()
        let options = ExtractionOptions(ignoreWhite: false)
        let color = try await extractor.dominantColor(from: .cgImage(image), options: options)
        try #require(color != nil)
        #expect(color!.rgb.r < 30)
        #expect(color!.rgb.g < 30)
        #expect(color!.rgb.b < 30)
    }

    @Test("white image with ignoreWhite relaxes filter and returns white")
    func whiteWithRelax() async throws {
        let image = try makeSolidImage(color: (255, 255, 255), size: 32)
        let extractor = PaletteExtractor()
        let palette = try await extractor.palette(from: .cgImage(image))
        try #require(!palette.isEmpty)
        let dominant = palette.dominant!
        #expect(dominant.rgb.r > 240)
        #expect(dominant.rgb.g > 240)
        #expect(dominant.rgb.b > 240)
    }

    @Test("white image with fail strategy throws")
    func whiteWithFail() async throws {
        let image = try makeSolidImage(color: (255, 255, 255), size: 32)
        let extractor = PaletteExtractor()
        let options = ExtractionOptions(fallbackStrategy: .fail)
        await #expect(throws: PaletteError.self) {
            _ = try await extractor.palette(from: .cgImage(image), options: options)
        }
    }

    @Test("two-color image yields both colors in palette")
    func twoColors() async throws {
        let image = try makeTwoColorImage(
            leftColor: (200, 30, 30),
            rightColor: (30, 30, 200),
            size: 64
        )
        let extractor = PaletteExtractor()
        let palette = try await extractor.palette(
            from: .cgImage(image),
            options: ExtractionOptions(colorCount: 2, colorSpace: .sRGB)
        )
        #expect(palette.count >= 2)
        let hasReddish = palette.colors.contains { $0.rgb.r > 150 && $0.rgb.b < 80 }
        let hasBluish = palette.colors.contains { $0.rgb.b > 150 && $0.rgb.r < 80 }
        #expect(hasReddish)
        #expect(hasBluish)
    }

    @Test("proportions sum to approximately 1")
    func proportionsSumToOne() async throws {
        let image = try makeTwoColorImage(
            leftColor: (200, 30, 30),
            rightColor: (30, 30, 200),
            size: 64
        )
        let extractor = PaletteExtractor()
        let palette = try await extractor.palette(
            from: .cgImage(image),
            options: ExtractionOptions(colorCount: 5)
        )
        let totalProportion = palette.colors.reduce(0) { $0 + $1.proportion }
        #expect(abs(totalProportion - 1) < 0.01)
    }

    @Test("timings are populated when requested")
    func timingsCollected() async throws {
        let image = try makeSolidImage(color: (128, 64, 32), size: 32)
        let extractor = PaletteExtractor()
        let palette = try await extractor.palette(
            from: .cgImage(image),
            options: ExtractionOptions(collectTimings: true)
        )
        try #require(palette.timings != nil)
        #expect(palette.timings!.quantizerUsed == "MMCQ-CPU")
    }

    @Test("custom quantizer is honored")
    func customQuantizer() async throws {
        struct NoopQuantizer: Quantizer {
            let name = "NOOP"
            func prepare() async throws {}
            func quantize(pixels: [PixelTriplet], maxColors _: Int) async throws -> [QuantizedColor] {
                guard let first = pixels.first else { return [] }
                return [QuantizedColor(color: first, population: pixels.count)]
            }
        }

        let image = try makeSolidImage(color: (10, 20, 30), size: 16)
        let extractor = PaletteExtractor()
        let palette = try await extractor.palette(
            from: .cgImage(image),
            options: ExtractionOptions(
                colorSpace: .sRGB,
                quantizer: .custom(NoopQuantizer()),
                collectTimings: true
            )
        )
        #expect(palette.count == 1)
        #expect(palette.timings?.quantizerUsed == "NOOP")
    }
}

// MARK: - Test image builders

private func makeSolidImage(color: (UInt8, UInt8, UInt8), size: Int) throws -> CGImage {
    let width = size
    let height = size
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
    for row in 0..<height {
        for column in 0..<width {
            let offset = row * bytesPerRow + column * 4
            pixels[offset] = color.0
            pixels[offset + 1] = color.1
            pixels[offset + 2] = color.2
            pixels[offset + 3] = 255
        }
    }
    return try makeCGImage(pixels: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
}

private func makeTwoColorImage(
    leftColor: (UInt8, UInt8, UInt8),
    rightColor: (UInt8, UInt8, UInt8),
    size: Int
) throws -> CGImage {
    let width = size
    let height = size
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
    for row in 0..<height {
        for column in 0..<width {
            let offset = row * bytesPerRow + column * 4
            let color = column < width / 2 ? leftColor : rightColor
            pixels[offset] = color.0
            pixels[offset + 1] = color.1
            pixels[offset + 2] = color.2
            pixels[offset + 3] = 255
        }
    }
    return try makeCGImage(pixels: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
}

private func makeCGImage(
    pixels: [UInt8],
    width: Int,
    height: Int,
    bytesPerRow: Int
) throws -> CGImage {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    guard let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        throw NSError(domain: "PaletteKitTests", code: -1)
    }
    return image
}
