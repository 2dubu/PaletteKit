import Foundation

public struct PixelTriplet: Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public struct QuantizedColor: Hashable, Sendable {
    public var color: PixelTriplet
    public var population: Int

    public init(color: PixelTriplet, population: Int) {
        self.color = color
        self.population = population
    }
}

public protocol Quantizer: Sendable {
    var name: String { get }

    func prepare() async throws

    func quantize(
        pixels: [PixelTriplet],
        maxColors: Int
    ) async throws -> [QuantizedColor]
}
