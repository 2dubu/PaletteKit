import Foundation
#if canImport(UIKit)
import UIKit

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
#endif
