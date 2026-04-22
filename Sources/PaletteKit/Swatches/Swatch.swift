import Foundation

public enum SwatchRole: String, Sendable, Hashable, CaseIterable {
    case vibrant
    case muted
    case darkVibrant
    case darkMuted
    case lightVibrant
    case lightMuted
}

public struct Swatch: Sendable, Hashable {
    public let color: PaletteColor
    public let role: SwatchRole
    public let titleTextColor: PaletteColor
    public let bodyTextColor: PaletteColor
}

public struct SwatchMap: Sendable {
    public let vibrant: Swatch?
    public let muted: Swatch?
    public let darkVibrant: Swatch?
    public let darkMuted: Swatch?
    public let lightVibrant: Swatch?
    public let lightMuted: Swatch?

    public init(
        vibrant: Swatch? = nil,
        muted: Swatch? = nil,
        darkVibrant: Swatch? = nil,
        darkMuted: Swatch? = nil,
        lightVibrant: Swatch? = nil,
        lightMuted: Swatch? = nil
    ) {
        self.vibrant = vibrant
        self.muted = muted
        self.darkVibrant = darkVibrant
        self.darkMuted = darkMuted
        self.lightVibrant = lightVibrant
        self.lightMuted = lightMuted
    }

    public subscript(role: SwatchRole) -> Swatch? {
        switch role {
        case .vibrant: return vibrant
        case .muted: return muted
        case .darkVibrant: return darkVibrant
        case .darkMuted: return darkMuted
        case .lightVibrant: return lightVibrant
        case .lightMuted: return lightMuted
        }
    }
}
