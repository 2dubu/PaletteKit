import CoreGraphics
import Foundation
import Testing
@testable import PaletteKit
#if canImport(Metal)
import Metal
#endif

@Suite("Golden palette")
struct GoldenPaletteTests {
    @Test("red golden extracts near-red dominant")
    func redGolden() async throws {
        try await assertDominant(GoldenImages.red, approximately: (220, 30, 30), tolerance: 20)
    }

    @Test("black golden extracts near-black dominant", .disabled(if: false))
    func blackGolden() async throws {
        try await assertDominant(
            GoldenImages.black,
            approximately: (0, 0, 0),
            tolerance: 20,
            options: ExtractionOptions(ignoreWhite: false)
        )
    }

    @Test("white golden relaxes filter and returns near-white")
    func whiteGolden() async throws {
        try await assertDominant(GoldenImages.white, approximately: (250, 250, 250), tolerance: 10)
    }

    @Test("rainbow golden produces at least 5 distinct colors")
    func rainbowGolden() async throws {
        let image = try GoldenImages.rainbow(width: 128, height: 16)
        let extractor = PaletteExtractor()
        let palette = try await extractor.palette(
            from: .cgImage(image),
            options: ExtractionOptions(colorCount: 8, colorSpace: .sRGB)
        )
        let unique = Set(palette.colors.map { "\($0.rgb.r)-\($0.rgb.g)-\($0.rgb.b)" })
        #expect(unique.count >= 5)
    }

    @Test("CPU and Metal agree on the dominant color for a gradient")
    func cpuMetalAgreeOnGradient() async throws {
        let image = try GoldenImages.gradient(width: 64, height: 64)
        let extractor = PaletteExtractor()

        let cpu = try await extractor.dominantColor(
            from: .cgImage(image),
            options: ExtractionOptions(colorSpace: .sRGB, quantizer: .cpu)
        )
        try #require(cpu != nil)

        #if canImport(Metal)
        guard MTLCreateSystemDefaultDevice() != nil else { return }
        let metal = try await extractor.dominantColor(
            from: .cgImage(image),
            options: ExtractionOptions(colorSpace: .sRGB, quantizer: .metal)
        )
        try #require(metal != nil)
        #expect(abs(Int(cpu!.rgb.r) - Int(metal!.rgb.r)) <= 8)
        #expect(abs(Int(cpu!.rgb.g) - Int(metal!.rgb.g)) <= 8)
        #expect(abs(Int(cpu!.rgb.b) - Int(metal!.rgb.b)) <= 8)
        #endif
    }

    // MARK: - Helpers

    private func assertDominant(
        _ imageBuilder: @autoclosure () throws -> CGImage,
        approximately target: (UInt8, UInt8, UInt8),
        tolerance: Int,
        options: ExtractionOptions = .init()
    ) async throws {
        let image = try imageBuilder()
        let extractor = PaletteExtractor()
        let color = try await extractor.dominantColor(from: .cgImage(image), options: options)
        try #require(color != nil)
        let rgb = color!.rgb
        #expect(abs(Int(rgb.r) - Int(target.0)) <= tolerance)
        #expect(abs(Int(rgb.g) - Int(target.1)) <= tolerance)
        #expect(abs(Int(rgb.b) - Int(target.2)) <= tolerance)
    }
}

enum GoldenImages {
    static var red: CGImage {
        get throws {
            try makeSolidImage(color: (220, 30, 30), size: 48)
        }
    }
    static var black: CGImage {
        get throws {
            try makeSolidImage(color: (0, 0, 0), size: 48)
        }
    }
    static var white: CGImage {
        get throws {
            try makeSolidImage(color: (255, 255, 255), size: 48)
        }
    }

    static func rainbow(width: Int, height: Int) throws -> CGImage {
        let colors: [(UInt8, UInt8, UInt8)] = [
            (228, 3, 3),
            (255, 140, 0),
            (255, 237, 0),
            (0, 128, 38),
            (36, 64, 142),
            (115, 41, 130),
        ]
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for row in 0..<height {
            for column in 0..<width {
                let band = min(colors.count - 1, column * colors.count / width)
                let color = colors[band]
                let offset = row * bytesPerRow + column * 4
                pixels[offset] = color.0
                pixels[offset + 1] = color.1
                pixels[offset + 2] = color.2
                pixels[offset + 3] = 255
            }
        }
        return try makeImage(pixels: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
    }

    static func gradient(width: Int, height: Int) throws -> CGImage {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for row in 0..<height {
            for column in 0..<width {
                let offset = row * bytesPerRow + column * 4
                pixels[offset] = UInt8(Double(column) / Double(max(width - 1, 1)) * 255)
                pixels[offset + 1] = UInt8(Double(row) / Double(max(height - 1, 1)) * 255)
                pixels[offset + 2] = 128
                pixels[offset + 3] = 255
            }
        }
        return try makeImage(pixels: pixels, width: width, height: height, bytesPerRow: bytesPerRow)
    }

    static func makeSolidImage(color: (UInt8, UInt8, UInt8), size: Int) throws -> CGImage {
        let bytesPerRow = size * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * size)
        for row in 0..<size {
            for column in 0..<size {
                let offset = row * bytesPerRow + column * 4
                pixels[offset] = color.0
                pixels[offset + 1] = color.1
                pixels[offset + 2] = color.2
                pixels[offset + 3] = 255
            }
        }
        return try makeImage(pixels: pixels, width: size, height: size, bytesPerRow: bytesPerRow)
    }

    static func makeImage(
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
            throw NSError(domain: "GoldenImages", code: -1)
        }
        return image
    }
}
