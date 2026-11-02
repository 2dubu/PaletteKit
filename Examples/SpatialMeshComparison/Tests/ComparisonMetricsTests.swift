import CoreGraphics
import Testing
@testable import SpatialMeshComparison

@Suite("Spatial comparison metrics")
@MainActor
struct ComparisonMetricsTests {
    @Test("rendered pixels match the exact reference size", arguments: [
        SIMD2(64, 64), SIMD2(100, 60), SIMD2(53, 97), SIMD2(128, 80)
    ])
    func referenceSize(_ size: SIMD2<Int>) throws {
        let reference = try solidImage(width: size.x, height: size.y)
        let rendered = try solidImage(width: 384, height: 384 * size.y / size.x)
        let sample = try Comparison.resample(rendered, matching: reference)
        #expect(sample.width == reference.width)
        #expect(sample.height == reference.height)
        let expected = try Comparison.pixels(reference)
        let actual = try Comparison.pixels(sample)
        #expect(actual.count == expected.count)
        let mean = zip(actual, expected).map { Comparison.distance($0, $1) }
            .reduce(0, +) / Double(expected.count)
        #expect(mean < 0.000001)
    }

    @Test("resampling preserves top and bottom color positions")
    func orientation() throws {
        let rendered = Comparison.fixture { _, y in
            y < 100 ? Comparison.red : Comparison.blue
        }
        let reference = try solidImage(width: 64, height: 40)
        let sample = try Comparison.resample(rendered, matching: reference)
        let pixels = try Comparison.pixels(sample)
        let red = try Comparison.pixels(solidImage(width: 1, height: 1))[0]
        // This checks position, allowing the color conversion/interpolation
        // difference between a raw provider image and a bitmap-context image.
        #expect(Comparison.distance(pixels[0], red) < 0.05)
        #expect(Comparison.distance(pixels[64 * 39], red) > 0.1)
    }

    private func solidImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }
}
