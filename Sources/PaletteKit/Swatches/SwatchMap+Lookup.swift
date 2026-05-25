#if canImport(SwiftUI)
import Foundation

extension SwatchMap {
    /// The selected role's swatch color, or `fallback` if the role is
    /// absent from this map.
    public func color(for role: SwatchRole, fallback: PaletteColor) -> PaletteColor {
        self[role]?.color ?? fallback
    }

    /// The selected role's title text color, or `fallback` if the role
    /// is absent from this map.
    public func titleTextColor(for role: SwatchRole, fallback: PaletteColor) -> PaletteColor {
        self[role]?.titleTextColor ?? fallback
    }

    /// The selected role's body text color, or `fallback` if the role
    /// is absent from this map.
    public func bodyTextColor(for role: SwatchRole, fallback: PaletteColor) -> PaletteColor {
        self[role]?.bodyTextColor ?? fallback
    }
}

extension Optional where Wrapped == SwatchMap {
    /// The selected role's swatch color, or `fallback` if the map or
    /// role is absent.
    public func color(for role: SwatchRole, fallback: PaletteColor) -> PaletteColor {
        self?[role]?.color ?? fallback
    }

    /// The selected role's title text color, or `fallback` if the map
    /// or role is absent.
    public func titleTextColor(for role: SwatchRole, fallback: PaletteColor) -> PaletteColor {
        self?[role]?.titleTextColor ?? fallback
    }

    /// The selected role's body text color, or `fallback` if the map
    /// or role is absent.
    public func bodyTextColor(for role: SwatchRole, fallback: PaletteColor) -> PaletteColor {
        self?[role]?.bodyTextColor ?? fallback
    }
}
#endif
