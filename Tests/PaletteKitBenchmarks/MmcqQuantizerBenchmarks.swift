import Foundation
import XCTest
@testable import PaletteKit

/// Run with `swift test -c release --filter MmcqQuantizerBenchmarks`.
/// Measures quantization and an output checksum; fixture construction is untimed.
final class MmcqQuantizerBenchmarks: XCTestCase {
    func testTenColorQuantization() throws {
        try measureQuantization(maxColors: 10)
    }

    func testSixteenColorQuantization() throws {
        try measureQuantization(maxColors: 16)
    }

    private func measureQuantization(maxColors: Int) throws {
        let pixels = Self.makeSampledGradient()
        let iterations = 20
        let reference = try MmcqEngine.quantize(pixels: pixels, maxColors: maxColors)
        let expectedChecksum = Self.checksum(reference) &* UInt64(iterations)
        var measuredChecksum: UInt64 = 0

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            do {
                measuredChecksum = 0
                for _ in 0..<iterations {
                    let colors = try MmcqEngine.quantize(pixels: pixels, maxColors: maxColors)
                    measuredChecksum &+= Self.checksum(colors)
                }
            } catch {
                XCTFail("Quantization failed: \(error)")
            }
        }

        XCTAssertEqual(measuredChecksum, expectedChecksum)
    }

    private static func makeSampledGradient() -> [PixelTriplet] {
        let edge = 1_000
        return stride(from: 0, to: edge * edge, by: 10).map { index in
            let x = index % edge
            let y = index / edge
            return PixelTriplet(
                r: UInt8(x * 255 / (edge - 1)),
                g: UInt8(y * 255 / (edge - 1)),
                b: UInt8((x + y) * 255 / (2 * edge - 2))
            )
        }
    }

    private static func checksum(_ colors: [QuantizedColor]) -> UInt64 {
        colors.reduce(0) { checksum, entry in
            let rgb = UInt64(entry.color.r) << 16 | UInt64(entry.color.g) << 8 | UInt64(entry.color.b)
            return (checksum &* 16_777_619) ^ rgb ^ UInt64(entry.population)
        }
    }
}
