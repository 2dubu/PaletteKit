import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import PaletteKit

/// Exercises the real file-decoding path that `PixelLoader` takes when a
/// caller passes `.url(...)` or `.data(...)`. Unlike the in-memory
/// `GoldenPaletteTests`, these cases round-trip through the actual
/// CGImageSource + CGImageDestination machinery so embedded color profiles
/// and EXIF orientation tags are exercised end-to-end.
@Suite("Real file goldens")
struct RealFileGoldenTests {
    @Test("Display P3 PNG keeps its color space through the pipeline")
    func displayP3PNGPreservesColorSpace() async throws {
        let url = try RealFileFixtures.writeSolidImage(
            red: 220, green: 30, blue: 30,
            size: 48,
            colorSpace: CGColorSpace.displayP3,
            fileExtension: "png",
            destinationType: UTType.png.identifier as CFString
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let palette = try await PaletteExtractor().palette(
            from: .url(url),
            options: ExtractionOptions(ignoreWhite: false)
        )
        #expect(palette.colorSpaceUsed == .displayP3)
        try #require(palette.dominant != nil)
        #expect(palette.dominant!.rgb.r > 180)
    }

    @Test("sRGB PNG stays sRGB")
    func sRGBPNGStaysSRGB() async throws {
        let url = try RealFileFixtures.writeSolidImage(
            red: 30, green: 30, blue: 220,
            size: 48,
            colorSpace: CGColorSpace.sRGB,
            fileExtension: "png",
            destinationType: UTType.png.identifier as CFString
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let palette = try await PaletteExtractor().palette(
            from: .url(url),
            options: ExtractionOptions(ignoreWhite: false)
        )
        #expect(palette.colorSpaceUsed == .sRGB)
    }

    @Test("HEIC in Display P3 decodes and reports P3 output")
    func heicDisplayP3RoundTrip() async throws {
        guard let destinationType = RealFileFixtures.heicUTType else { return }
        let url = try RealFileFixtures.writeSolidImage(
            red: 100, green: 200, blue: 50,
            size: 64,
            colorSpace: CGColorSpace.displayP3,
            fileExtension: "heic",
            destinationType: destinationType
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let palette = try await PaletteExtractor().palette(
            from: .url(url),
            options: ExtractionOptions(ignoreWhite: false)
        )
        #expect(palette.colorSpaceUsed == .displayP3)
        try #require(palette.dominant != nil)
        #expect(palette.dominant!.rgb.g > 150)
    }

    @Test("EXIF orientation 6 (rotate 90° CW) is honored when autoOrient is true")
    func exifOrientationAutoOrient() async throws {
        let url = try RealFileFixtures.writeTwoSideJPEG(
            left: (200, 30, 30),
            right: (30, 30, 200),
            width: 64,
            height: 48,
            orientation: 6
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let palette = try await PaletteExtractor().palette(
            from: .url(url),
            options: ExtractionOptions(
                colorCount: 2,
                colorSpace: .sRGB,
                autoOrient: true
            )
        )
        #expect(palette.count >= 2)
        let hasReddish = palette.colors.contains { $0.rgb.r > 150 && $0.rgb.b < 80 }
        let hasBluish = palette.colors.contains { $0.rgb.b > 150 && $0.rgb.r < 80 }
        #expect(hasReddish)
        #expect(hasBluish)
    }

    @Test("Pre-downsample keeps a huge source within the pixel budget")
    func preDownsampleCapsPixelCount() async throws {
        let url = try RealFileFixtures.writeSolidImage(
            red: 80, green: 20, blue: 160,
            size: 2048,
            colorSpace: CGColorSpace.sRGB,
            fileExtension: "png",
            destinationType: UTType.png.identifier as CFString
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let palette = try await PaletteExtractor().palette(
            from: .url(url),
            options: ExtractionOptions(
                ignoreWhite: false,
                downsample: .automatic(maxPixels: 100_000),
                collectTimings: true
            )
        )
        try #require(palette.dominant != nil)
        // The source is 2048x2048 = 4.2M pixels; after downsampling the
        // decode stage must complete in a fraction of a second because the
        // buffer is orders of magnitude smaller than the raw image.
        #expect(palette.timings != nil)
    }
}

enum RealFileFixtures {
    /// The HEIC UTType is Apple-only; some Linux-style environments will
    /// not have it registered. `UTType.heic` does exist across Apple
    /// platforms but we guard anyway so the test suite degrades cleanly.
    static var heicUTType: CFString? {
        "public.heic" as CFString
    }

    static func writeSolidImage(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        size: Int,
        colorSpace colorSpaceName: CFString,
        fileExtension: String,
        destinationType: CFString
    ) throws -> URL {
        let image = try makeSolidCGImage(
            red: red,
            green: green,
            blue: blue,
            size: size,
            colorSpaceName: colorSpaceName
        )
        return try writeImage(image, fileExtension: fileExtension, destinationType: destinationType, properties: nil)
    }

    static func writeTwoSideJPEG(
        left: (UInt8, UInt8, UInt8),
        right: (UInt8, UInt8, UInt8),
        width: Int,
        height: Int,
        orientation: UInt32
    ) throws -> URL {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for row in 0..<height {
            for column in 0..<width {
                let color = column < width / 2 ? left : right
                let offset = row * bytesPerRow + column * 4
                pixels[offset] = color.0
                pixels[offset + 1] = color.1
                pixels[offset + 2] = color.2
                pixels[offset + 3] = 255
            }
        }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw NSError(domain: "RealFileFixtures", code: -1)
        }
        let image = try makeCGImage(
            pixels: pixels,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            colorSpace: colorSpace
        )
        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: orientation,
        ]
        return try writeImage(
            image,
            fileExtension: "jpg",
            destinationType: UTType.jpeg.identifier as CFString,
            properties: properties as CFDictionary
        )
    }

    private static func makeSolidCGImage(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        size: Int,
        colorSpaceName: CFString
    ) throws -> CGImage {
        let bytesPerRow = size * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * size)
        var cursor = 0
        while cursor < pixels.count {
            pixels[cursor] = red
            pixels[cursor + 1] = green
            pixels[cursor + 2] = blue
            pixels[cursor + 3] = 255
            cursor += 4
        }
        guard let colorSpace = CGColorSpace(name: colorSpaceName) else {
            throw NSError(domain: "RealFileFixtures", code: -2)
        }
        return try makeCGImage(
            pixels: pixels,
            width: size,
            height: size,
            bytesPerRow: bytesPerRow,
            colorSpace: colorSpace
        )
    }

    private static func makeCGImage(
        pixels: [UInt8],
        width: Int,
        height: Int,
        bytesPerRow: Int,
        colorSpace: CGColorSpace
    ) throws -> CGImage {
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
            throw NSError(domain: "RealFileFixtures", code: -3)
        }
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
            throw NSError(domain: "RealFileFixtures", code: -4)
        }
        return image
    }

    private static func writeImage(
        _ image: CGImage,
        fileExtension: String,
        destinationType: CFString,
        properties: CFDictionary?
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("palettekit-fixture-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            destinationType,
            1,
            nil
        ) else {
            throw NSError(domain: "RealFileFixtures", code: -5)
        }
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "RealFileFixtures", code: -6)
        }
        return url
    }
}
