import Foundation

public struct KMeansQuantizer: Quantizer {
    public let name = "K-Means-CPU"

    public init() {}

    public func prepare() async throws {}

    public func quantize(
        pixels: [PixelTriplet],
        maxColors: Int
    ) async throws -> [QuantizedColor] {
        try Task.checkCancellation()
        return KMeansEngine.quantize(pixels: pixels, maxColors: maxColors)
    }
}
