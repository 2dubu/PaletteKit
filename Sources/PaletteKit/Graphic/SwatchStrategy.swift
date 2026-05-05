import Foundation

/// Which `SwatchMap` roles a ``PaletteGraphic`` maps to its `center` and
/// `edge` gradient stops, controlling the overall mood of the resulting
/// graphic.
///
/// Each strategy falls back through a sibling `SwatchMap` role and then
/// to a raw ``Palette`` color when the requested role is absent, so a
/// graphic always renders even on photos that don't expose every swatch.
///
/// Raw values are display-ready capitalised strings, suitable for direct
/// use in pickers without further localisation.
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
