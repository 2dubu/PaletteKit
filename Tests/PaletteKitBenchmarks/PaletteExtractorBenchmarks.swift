import CoreGraphics
import Foundation
import XCTest
@testable import PaletteKit

/// XCTest-Metrics benchmarks. These are intentionally kept in a separate target
/// so CI can run `swift test --filter PaletteKitTests` for correctness while the
/// release workflow runs `swift test --filter PaletteKitBenchmarks` on device.
final class PaletteExtractorBenchmarks: XCTestCase {
    func testExtractionOnSmallImage() throws {
        let image = try Self.makeImage(width: 128, height: 128)
        let extractor = PaletteExtractor()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let expectation = expectation(description: "palette")
            Task {
                _ = try await extractor.palette(
                    from: .cgImage(image),
                    options: ExtractionOptions(colorCount: 10, colorSpace: .sRGB, quantizer: .cpu)
                )
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10)
        }
    }

    func testExtractionOnLargeImage() throws {
        let image = try Self.makeImage(width: 1024, height: 1024)
        let extractor = PaletteExtractor()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let expectation = expectation(description: "palette")
            Task {
                _ = try await extractor.palette(
                    from: .cgImage(image),
                    options: ExtractionOptions(colorCount: 10, colorSpace: .sRGB, quantizer: .cpu)
                )
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    #if canImport(Metal)
    func testExtractionOnLargeImageWithMetal() throws {
        let image = try Self.makeImage(width: 1024, height: 1024)
        let extractor = PaletteExtractor()
        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            let expectation = expectation(description: "palette")
            Task {
                _ = try await extractor.palette(
                    from: .cgImage(image),
                    options: ExtractionOptions(colorCount: 10, colorSpace: .sRGB, quantizer: .metal)
                )
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    #endif

    // MARK: - Fixtures

    private static func makeImage(width: Int, height: Int) throws -> CGImage {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for row in 0..<height {
            for column in 0..<width {
                let offset = row * bytesPerRow + column * 4
                pixels[offset] = UInt8((column * 255) / max(width - 1, 1))
                pixels[offset + 1] = UInt8((row * 255) / max(height - 1, 1))
                pixels[offset + 2] = UInt8((column + row) * 255 / max(width + height - 2, 1))
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
            throw NSError(domain: "PaletteKitBenchmarks", code: -1)
        }
        return image
    }
}
