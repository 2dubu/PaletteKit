import CoreGraphics
import Foundation
import XCTest
@testable import PaletteKit

@MainActor
final class SharedExtractionBenchmarks: XCTestCase {
    private var consumedChecksum: UInt64 = 0
    private enum Operation { case palette, separate, shared }

    func testStandalonePalette() throws {
        try measureResolution(.palette)
    }

    func testSeparatePaletteAndSwatches() throws {
        try measureResolution(.separate)
    }

    func testSharedPaletteAndSwatches() throws {
        try measureResolution(.shared)
    }

    private func measureResolution(_ operation: Operation) throws {
        let image = try makeImage()
        let extractor = PaletteExtractor()
        let options = ExtractionOptions(colorCount: 10, colorSpace: .oklch, quantizer: .cpu)
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let completed = expectation(description: "palette and swatches")
            Task {
                defer { completed.fulfill() }
                do {
                    let palette: Palette
                    let swatches: SwatchMap?
                    switch operation {
                    case .palette:
                        palette = try await extractor.palette(from: .cgImage(image), options: options)
                        swatches = nil
                    case .separate:
                        palette = try await extractor.palette(from: .cgImage(image), options: options)
                        swatches = try await extractor.swatches(from: .cgImage(image), options: options)
                    case .shared:
                        (palette, swatches) = try await extractor.paletteAndSwatches(from: .cgImage(image), options: options)
                    }
                    consumedChecksum = checksum(palette: palette, swatches: swatches)
                } catch {
                    XCTFail("extraction failed: \(error)")
                }
            }
            wait(for: [completed], timeout: 30)
        }
        XCTAssertNotEqual(consumedChecksum, 0)
    }

    @inline(never)
    private func checksum(palette: Palette, swatches: SwatchMap?) -> UInt64 {
        var result: UInt64 = 14695981039346656037
        func append(_ value: UInt64) {
            result = (result ^ value) &* 1099511628211
        }
        func appendColor(_ color: PaletteColor) {
            append(UInt64(color.rgb.r))
            append(UInt64(color.rgb.g))
            append(UInt64(color.rgb.b))
            append(UInt64(color.population))
            append(color.proportion.bitPattern)
        }
        for color in palette.colors {
            appendColor(color)
        }
        for role in SwatchRole.allCases {
            guard let swatch = swatches?[role] else {
                append(0)
                continue
            }
            for byte in swatch.role.rawValue.utf8 {
                append(UInt64(byte))
            }
            appendColor(swatch.color)
            appendColor(swatch.titleTextColor)
            appendColor(swatch.bodyTextColor)
        }
        return result
    }

    private func makeImage() throws -> CGImage {
        let size = 1024
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        var state: UInt64 = 0x1985_1028
        for i in 0..<(size * size) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            pixels[i * 4] = UInt8(truncatingIfNeeded: state >> 24)
            pixels[i * 4 + 1] = UInt8(truncatingIfNeeded: state >> 40)
            pixels[i * 4 + 2] = UInt8(truncatingIfNeeded: state >> 56)
        }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        return try XCTUnwrap(CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
            space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
    }
}
