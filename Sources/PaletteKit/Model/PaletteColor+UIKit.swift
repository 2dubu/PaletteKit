import Foundation
#if canImport(UIKit)
import UIKit
import CoreGraphics

extension UIColor {
    /// Create a UIColor from a ``PaletteColor``. Always sRGB-tagged with full opacity.
    public convenience init(_ paletteColor: PaletteColor) {
        self.init(
            red: CGFloat(paletteColor.rgb.r) / 255,
            green: CGFloat(paletteColor.rgb.g) / 255,
            blue: CGFloat(paletteColor.rgb.b) / 255,
            alpha: 1
        )
    }
}

extension PaletteColor {
    /// A Core Graphics representation of this color tagged sRGB. Use directly
    /// with `CALayer.backgroundColor`, `CGContext` fills, etc., without an
    /// intermediate ``UIColor`` round-trip.
    public var cgColor: CGColor {
        CGColor(
            srgbRed: CGFloat(rgb.r) / 255,
            green: CGFloat(rgb.g) / 255,
            blue: CGFloat(rgb.b) / 255,
            alpha: 1
        )
    }
}
#endif
