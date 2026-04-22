import Foundation

public struct ExtractionTimings: Sendable {
    public var decode: Duration
    public var sample: Duration
    public var quantize: Duration
    public var swatches: Duration?
    public var total: Duration
    public var quantizerUsed: String

    public init(
        decode: Duration,
        sample: Duration,
        quantize: Duration,
        swatches: Duration? = nil,
        total: Duration,
        quantizerUsed: String
    ) {
        self.decode = decode
        self.sample = sample
        self.quantize = quantize
        self.swatches = swatches
        self.total = total
        self.quantizerUsed = quantizerUsed
    }
}

public struct Palette: Sendable {
    public let colors: [PaletteColor]
    public let colorSpaceUsed: ColorSpace
    public let timings: ExtractionTimings?

    public init(
        colors: [PaletteColor],
        colorSpaceUsed: ColorSpace,
        timings: ExtractionTimings? = nil
    ) {
        self.colors = colors
        self.colorSpaceUsed = colorSpaceUsed
        self.timings = timings
    }

    public var dominant: PaletteColor? {
        colors.first
    }

    public var isEmpty: Bool {
        colors.isEmpty
    }

    public var count: Int {
        colors.count
    }
}

extension Palette: Collection {
    public typealias Index = Int
    public typealias Element = PaletteColor

    public var startIndex: Int { colors.startIndex }
    public var endIndex: Int { colors.endIndex }
    public subscript(position: Int) -> PaletteColor { colors[position] }
    public func index(after i: Int) -> Int { colors.index(after: i) }
}
