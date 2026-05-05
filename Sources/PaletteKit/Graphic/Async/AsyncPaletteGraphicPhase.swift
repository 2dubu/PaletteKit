#if canImport(UIKit)
import Foundation

/// Resolution state for ``AsyncPaletteGraphic``.
///
/// Passed to the phase content closure on every state change. Use
/// pattern matching to render different views per phase, observe
/// telemetry, or compose secondary UI (e.g., swatch chips alongside
/// the resolved graphic).
///
/// Cache hits skip `.loading` and land directly in
/// `.success(_, _, fromCache: true)`. Failures are surfaced here too —
/// there is no separate `onFailure` callback in the phase API; observe
/// `.failure(_)` directly.
public enum AsyncPaletteGraphicPhase: Sendable {
    /// Initial state before any load attempt.
    case empty

    /// Extraction in flight.
    case loading

    /// Palette resolved. `fromCache` is `true` when the result came
    /// from ``PaletteCache`` (synchronous resolution, no transition);
    /// `false` when newly extracted.
    case success(palette: Palette, swatches: SwatchMap?, fromCache: Bool)

    /// Extraction failed. The placeholder remains visible by default
    /// in the convenience init; the phase init lets the caller render
    /// any error UI they want.
    case failure(any Error)
}
#endif
