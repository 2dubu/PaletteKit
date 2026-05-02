#if canImport(SwiftUI)
import SwiftUI

extension PaletteColor: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        Color.Resolved(
            colorSpace: .sRGB,
            red: Float(rgb.r) / 255,
            green: Float(rgb.g) / 255,
            blue: Float(rgb.b) / 255,
            opacity: 1
        )
    }
}
#endif
