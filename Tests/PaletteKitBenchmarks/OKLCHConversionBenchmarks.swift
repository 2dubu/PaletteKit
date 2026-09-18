import XCTest
@testable import PaletteKit

final class OKLCHConversionBenchmarks: XCTestCase {
    func testSRGBBatchConversion() {
        measureConversion(sourceSpace: .sRGB)
    }

    func testDisplayP3BatchConversion() {
        measureConversion(sourceSpace: .displayP3)
    }

    private func measureConversion(sourceSpace: ColorSpace) {
        var state: UInt64 = 0x1234_5678_9abc_def0
        let pixels = (0..<100_000).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return PixelTriplet(
                r: UInt8(truncatingIfNeeded: state >> 32),
                g: UInt8(truncatingIfNeeded: state >> 40),
                b: UInt8(truncatingIfNeeded: state >> 48)
            )
        }
        // Warm the conversion separately so this measures steady-state extraction.
        let expected = BatchConversion.pixelsToOKLCHScaled(pixels, sourceSpace: sourceSpace)
        var result: [PixelTriplet] = []

        measure(metrics: [XCTClockMetric(), XCTCPUMetric()]) {
            result = BatchConversion.pixelsToOKLCHScaled(pixels, sourceSpace: sourceSpace)
        }

        XCTAssertEqual(result, expected)
    }
}
