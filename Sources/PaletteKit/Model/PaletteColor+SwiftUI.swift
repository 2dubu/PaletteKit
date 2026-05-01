import Foundation
#if canImport(UIKit)
import UIKit
#endif

public extension PaletteColor {
    #if canImport(UIKit)
    var uiColor: UIColor {
        UIColor(
            red: CGFloat(rgb.r) / 255,
            green: CGFloat(rgb.g) / 255,
            blue: CGFloat(rgb.b) / 255,
            alpha: 1
        )
    }
    #endif
}
