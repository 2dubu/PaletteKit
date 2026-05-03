import Foundation

/// Which `SwatchMap` roles a ``CardPalette`` maps to its `center` and `edge`
/// stops, controlling the overall mood of the resulting graphic.
///
/// Each strategy falls back through a sibling `SwatchMap` role and then to a
/// raw ``Palette`` color when the requested role is absent, so a graphic
/// always renders even on photos that don't expose every swatch.
public enum SwatchStrategy: String, CaseIterable, Identifiable, Sendable {
    /// `vibrant → darkVibrant` — the most saturated color as the centerpiece,
    /// fading into its darker counterpart at the edge. Mirrors Android
    /// Palette's primary-color convention; safe for almost any photo.
    case vibrant = "Vibrant"

    /// `lightVibrant → darkMuted` — picks the brightest saturated color and
    /// pairs it with a low-saturation dark, maximising the luminance range.
    /// Reads as more dramatic than ``vibrant``.
    case contrast = "Contrast"

    /// `muted → darkMuted` — desaturated colors only. Quiet, print-leaning
    /// tone; useful when the source image already has strong vibrant noise
    /// that would overpower text composed on top.
    case muted = "Muted"

    public var id: String { rawValue }
}

/// The ``PaletteColor`` values a ``PaletteGraphic`` uses for its gradient
/// stops, surrounding background, and accent text.
///
/// Resolved from a ``Palette`` plus an optional `SwatchMap`. The
/// ``SwatchStrategy`` chosen at init time picks the source roles for
/// ``center`` and ``edge``; ``background`` and ``accent`` follow a fixed
/// rule independent of strategy.
public struct CardPalette: Sendable {
    public let center: PaletteColor
    public let edge: PaletteColor
    public let background: PaletteColor
    public let accent: PaletteColor
    public let strategy: SwatchStrategy

    public init(palette: Palette, swatches: SwatchMap?, strategy: SwatchStrategy = .vibrant) {
        self.strategy = strategy

        let dominant = palette.dominant ?? .black
        let darkest = palette.colors.min(by: { $0.luminance < $1.luminance }) ?? dominant
        let lightest = palette.colors.max(by: { $0.luminance < $1.luminance }) ?? dominant

        let resolvedCenter: PaletteColor
        let resolvedEdge: PaletteColor
        switch strategy {
        case .vibrant:
            resolvedCenter = swatches?.vibrant?.color
                ?? swatches?.lightVibrant?.color
                ?? dominant
            resolvedEdge = swatches?.darkVibrant?.color
                ?? swatches?.darkMuted?.color
                ?? darkest
        case .contrast:
            resolvedCenter = swatches?.lightVibrant?.color
                ?? swatches?.vibrant?.color
                ?? lightest
            resolvedEdge = swatches?.darkMuted?.color
                ?? swatches?.darkVibrant?.color
                ?? darkest
        case .muted:
            resolvedCenter = swatches?.muted?.color
                ?? swatches?.lightMuted?.color
                ?? dominant
            resolvedEdge = swatches?.darkMuted?.color
                ?? swatches?.darkVibrant?.color
                ?? darkest
        }

        self.center = resolvedCenter
        self.edge = resolvedEdge
        self.background = swatches?.lightMuted?.color
            ?? swatches?.lightVibrant?.color
            ?? lightest
        self.accent = swatches?.darkVibrant?.color
            ?? swatches?.vibrant?.color
            ?? darkest
    }
}
