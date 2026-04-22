import Foundation

/// A single color extracted from an image, including its population within the
/// source palette and common presentation helpers.
///
/// `PaletteColor` stores the raw RGB triple and exposes lazy, cached accessors for
/// `hex`, `hsl`, `oklch`, `luminance`, `isDark`/`isLight`, a readable
/// `textColor`, and a WCAG `contrast` block. All computations are deterministic
/// and do not allocate.
///
/// Values compare by full RGB equality regardless of population so they can be
/// used as `Set` / `Dictionary` keys.
public struct PaletteColor: Hashable, Sendable {
    /// The raw 8-bit RGB channels.
    public let rgb: RGB
    /// How many pixels from the source image contributed to this color.
    ///
    /// Units are relative — the exact count is meaningful only compared to
    /// other colors in the same ``Palette``. Use ``proportion`` for the
    /// normalized share.
    public let population: Int
    /// Share of the total palette population, in `0...1`.
    public let proportion: Double

    public init(rgb: RGB, population: Int = 0, proportion: Double = 0) {
        self.rgb = rgb
        self.population = population
        self.proportion = proportion
    }

    public init(r: UInt8, g: UInt8, b: UInt8, population: Int = 0, proportion: Double = 0) {
        self.init(rgb: RGB(r: r, g: g, b: b), population: population, proportion: proportion)
    }
}

extension PaletteColor {
    public var hex: String {
        String(format: "#%02x%02x%02x", rgb.r, rgb.g, rgb.b)
    }

    public var hsl: HSL {
        Self.rgbToHSL(rgb)
    }

    public var oklch: OKLCH {
        OKLCHConversion.rgbToOKLCH(rgb)
    }

    public var luminance: Double {
        Self.relativeLuminance(rgb)
    }

    public var isDark: Bool {
        luminance <= 0.179
    }

    public var isLight: Bool {
        !isDark
    }

    public var textColor: PaletteColor {
        isDark ? .white : .black
    }

    public struct Contrast: Hashable, Sendable {
        public var white: Double
        public var black: Double
        public var foreground: PaletteColor
    }

    public var contrast: Contrast {
        let lum = luminance
        let white = Self.contrastRatio(lum, 1)
        let black = Self.contrastRatio(lum, 0)
        return Contrast(
            white: (white * 100).rounded() / 100,
            black: (black * 100).rounded() / 100,
            foreground: textColor
        )
    }
}

extension PaletteColor {
    public static let white = PaletteColor(r: 255, g: 255, b: 255)
    public static let black = PaletteColor(r: 0, g: 0, b: 0)
}

extension PaletteColor {
    public enum CSSFormat: Sendable {
        case rgb
        case hsl
        case oklch
    }

    public func css(_ format: CSSFormat = .rgb) -> String {
        switch format {
        case .rgb:
            return "rgb(\(rgb.r), \(rgb.g), \(rgb.b))"
        case .hsl:
            let value = hsl
            return "hsl(\(value.h), \(value.s)%, \(value.l)%)"
        case .oklch:
            let value = oklch
            let l = String(format: "%.3f", value.l)
            let c = String(format: "%.3f", value.c)
            let h = String(format: "%.1f", value.h)
            return "oklch(\(l) \(c) \(h))"
        }
    }
}

extension PaletteColor {
    static func rgbToHSL(_ color: RGB) -> HSL {
        let r = Double(color.r) / 255
        let g = Double(color.g) / 255
        let b = Double(color.b) / 255
        let maxChannel = max(r, g, b)
        let minChannel = min(r, g, b)
        let l = (maxChannel + minChannel) / 2
        var h = 0.0
        var s = 0.0

        if maxChannel != minChannel {
            let delta = maxChannel - minChannel
            s = l > 0.5 ? delta / (2 - maxChannel - minChannel) : delta / (maxChannel + minChannel)
            switch maxChannel {
            case r:
                h = ((g - b) / delta + (g < b ? 6 : 0)) / 6
            case g:
                h = ((b - r) / delta + 2) / 6
            default:
                h = ((r - g) / delta + 4) / 6
            }
        }

        return HSL(
            h: Int((h * 360).rounded()),
            s: Int((s * 100).rounded()),
            l: Int((l * 100).rounded())
        )
    }

    static func relativeLuminance(_ color: RGB) -> Double {
        func toLinear(_ channel: UInt8) -> Double {
            let s = Double(channel) / 255
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * toLinear(color.r)
            + 0.7152 * toLinear(color.g)
            + 0.0722 * toLinear(color.b)
    }

    static func contrastRatio(_ l1: Double, _ l2: Double) -> Double {
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
