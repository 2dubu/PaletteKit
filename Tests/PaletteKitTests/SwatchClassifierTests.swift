import CoreGraphics
import Foundation
import Testing
@testable import PaletteKit

@Suite("SwatchClassifier")
struct SwatchClassifierTests {
    @Test("classifies known palette into at least one vibrant swatch")
    func vibrantAssignment() async throws {
        let palette = Palette(
            colors: [
                PaletteColor(r: 232, g: 67, b: 147, population: 400, proportion: 0.4),
                PaletteColor(r: 128, g: 128, b: 128, population: 200, proportion: 0.2),
                PaletteColor(r: 30, g: 30, b: 30, population: 200, proportion: 0.2),
                PaletteColor(r: 240, g: 240, b: 240, population: 200, proportion: 0.2),
            ],
            colorSpaceUsed: .sRGB
        )
        let map = SwatchClassifier().classify(palette: palette)
        try #require(map.vibrant != nil)
        #expect(map.vibrant?.color.rgb.r ?? 0 > 180)
    }

    @Test("empty palette yields all-nil swatch map")
    func emptyPalette() async throws {
        let palette = Palette(colors: [], colorSpaceUsed: .sRGB)
        let map = SwatchClassifier().classify(palette: palette)
        for role in SwatchRole.allCases {
            #expect(map[role] == nil)
        }
    }

    @Test("roles never reuse the same color")
    func rolesUnique() async throws {
        let palette = Palette(
            colors: [
                PaletteColor(r: 232, g: 67, b: 147, population: 500, proportion: 0.25),
                PaletteColor(r: 100, g: 200, b: 100, population: 500, proportion: 0.25),
                PaletteColor(r: 20, g: 20, b: 80, population: 500, proportion: 0.25),
                PaletteColor(r: 240, g: 230, b: 200, population: 500, proportion: 0.25),
            ],
            colorSpaceUsed: .sRGB
        )
        let map = SwatchClassifier().classify(palette: palette)
        let allColors = SwatchRole.allCases.compactMap { map[$0]?.color }
        #expect(Set(allColors).count == allColors.count)
    }

    @Test("extractor.swatches returns a usable SwatchMap")
    func extractorSwatches() async throws {
        let image = try makeGradientImage(size: 64)
        let extractor = PaletteExtractor()
        let map = try await extractor.swatches(
            from: .cgImage(image),
            options: ExtractionOptions(colorCount: 16)
        )
        let anyPopulated = SwatchRole.allCases.contains { map[$0] != nil }
        #expect(anyPopulated)
    }
}

private func makeGradientImage(size: Int) throws -> CGImage {
    let width = size
    let height = size
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
    for row in 0..<height {
        for column in 0..<width {
            let offset = row * bytesPerRow + column * 4
            pixels[offset] = UInt8(Double(column) / Double(width - 1) * 255)
            pixels[offset + 1] = UInt8(Double(row) / Double(height - 1) * 255)
            pixels[offset + 2] = UInt8((Double(column + row) / Double(width + height - 2)) * 255)
            pixels[offset + 3] = 255
        }
    }
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
