import Foundation

public enum ColorSpace: Sendable, Equatable {
    case sRGB
    case displayP3
    case oklch
}

public enum Quality: Sendable, Equatable {
    case stride(Int)

    public static let `default` = Quality.stride(10)
    public static let highest = Quality.stride(1)

    var strideValue: Int {
        switch self {
        case .stride(let value):
            return max(1, value)
        }
    }
}

public enum FallbackStrategy: Sendable, Equatable {
    case relax
    case fail
    case averageOnly
}

public enum Downsample: Sendable, Equatable {
    case disabled
    case automatic(maxPixels: Int)
    case maxEdge(Int)

    public static let `default` = Downsample.automatic(maxPixels: 1_000_000)
}

public enum QuantizerSelection: Sendable {
    case auto
    case cpu
    case metal
    case custom(any Quantizer)

    public static func == (lhs: QuantizerSelection, rhs: QuantizerSelection) -> Bool {
        switch (lhs, rhs) {
        case (.auto, .auto), (.cpu, .cpu), (.metal, .metal):
            return true
        default:
            return false
        }
    }
}

public struct ExtractionOptions: Sendable {
    public var colorCount: Int
    public var quality: Quality
    public var colorSpace: ColorSpace
    public var ignoreWhite: Bool
    public var whiteThreshold: UInt8
    public var alphaThreshold: UInt8
    public var minSaturation: Double
    public var fallbackStrategy: FallbackStrategy
    public var autoOrient: Bool
    public var downsample: Downsample
    public var quantizer: QuantizerSelection
    public var collectTimings: Bool

    public init(
        colorCount: Int = 10,
        quality: Quality = .default,
        colorSpace: ColorSpace = .oklch,
        ignoreWhite: Bool = true,
        whiteThreshold: UInt8 = 250,
        alphaThreshold: UInt8 = 125,
        minSaturation: Double = 0,
        fallbackStrategy: FallbackStrategy = .relax,
        autoOrient: Bool = true,
        downsample: Downsample = .default,
        quantizer: QuantizerSelection = .auto,
        collectTimings: Bool = false
    ) {
        self.colorCount = colorCount
        self.quality = quality
        self.colorSpace = colorSpace
        self.ignoreWhite = ignoreWhite
        self.whiteThreshold = whiteThreshold
        self.alphaThreshold = alphaThreshold
        self.minSaturation = min(max(minSaturation, 0), 1)
        self.fallbackStrategy = fallbackStrategy
        self.autoOrient = autoOrient
        self.downsample = downsample
        self.quantizer = quantizer
        self.collectTimings = collectTimings
    }
}
