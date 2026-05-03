import CoreImage
import CoreImage.CIFilterBuiltins
import PaletteKit
import SwiftUI
import UIKit

/// `PaletteGraphic` — palette-driven gradient + grain primitive (SwiftUI).
/// Renders a rectangular graphic that callers compose into cards, posters,
/// share assets, or any SwiftUI layout. Apply standard SwiftUI clipping
/// (`.clipShape`, `.mask`, …) for non-rectangular silhouettes.
///
/// Pair type: ``PaletteGraphicView`` (UIView) for UIKit-only call sites.
///
/// ```swift
/// PaletteGraphic(palette: p, swatches: s, configuration: .init(
///     direction: .linear,
///     stops: 3,
///     swatchStrategy: .vibrant,
///     grain: .standard
/// ))
/// .frame(width: 320, height: 410)
/// .clipShape(RoundedRectangle(cornerRadius: 24))
/// ```
struct PaletteGraphic: View {
    let palette: Palette
    let swatches: SwatchMap?
    let configuration: Configuration

    @Environment(\.displayScale) private var displayScale

    init(
        palette: Palette,
        swatches: SwatchMap?,
        configuration: Configuration = .init()
    ) {
        self.palette = palette
        self.swatches = swatches
        self.configuration = configuration
    }

    var body: some View {
        GeometryReader { geo in
            let scale = max(displayScale, 1)
            let size = CGSize(
                width: max(geo.size.width * scale, 1),
                height: max(geo.size.height * scale, 1)
            )
            if let cg = PaletteGraphicRenderer.makeCGImage(
                palette: palette,
                swatches: swatches,
                configuration: configuration,
                pixelSize: size
            ) {
                Image(uiImage: UIImage(cgImage: cg, scale: scale, orientation: .up))
                    .resizable()
                    .scaledToFill()
            } else {
                Color(CardPalette(palette: palette, swatches: swatches, strategy: configuration.swatchStrategy).center)
            }
        }
    }

    /// Render this graphic to a `UIImage` at the given logical size.
    /// Bypasses SwiftUI's view hierarchy. The result is rectangular — apply
    /// your own clipping (`UIBezierPath` mask, `CALayer.mask`, …) for
    /// non-rectangular silhouettes.
    ///
    /// `scale` defaults to `2.0` for predictable output regardless of where
    /// the call originates. Pass an explicit value (e.g. trait collection's
    /// `displayScale`) when device-accurate rendering matters.
    func makeImage(size: CGSize, scale: CGFloat = 2.0) -> UIImage? {
        let pixelSize = CGSize(
            width: max(size.width * scale, 1),
            height: max(size.height * scale, 1)
        )
        guard let cg = PaletteGraphicRenderer.makeCGImage(
            palette: palette,
            swatches: swatches,
            configuration: configuration,
            pixelSize: pixelSize
        ) else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}

extension PaletteGraphic {
    /// Style options for ``PaletteGraphic`` and ``PaletteGraphicView``.
    /// All fields have sensible defaults; pass a customised instance to
    /// override any subset.
    struct Configuration: Sendable {
        var direction: GradientDirection
        /// Start anchor for the linear gradient flow. Ignored when
        /// ``direction`` is `.radial`. Uses SwiftUI's standard
        /// ``SwiftUI/UnitPoint`` (origin top-leading, y down).
        var linearStart: UnitPoint
        /// End anchor for the linear gradient flow. Ignored when
        /// ``direction`` is `.radial`.
        var linearEnd: UnitPoint
        /// How many colors compose the gradient.
        ///
        /// First and last colors are anchored to the strategy's resolved
        /// center / edge. Middle colors are pulled from the source palette
        /// + any available `SwatchMap` roles, sorted by luminance so the
        /// flow stays monotonic. If the source has fewer distinct colors
        /// than requested, the available count is used.
        var colorCount: ColorCount
        var swatchStrategy: SwatchStrategy
        var grain: GrainStyle

        init(
            direction: GradientDirection = .linear,
            linearStart: UnitPoint = .bottomLeading,
            linearEnd: UnitPoint = .topTrailing,
            colorCount: ColorCount = .two,
            swatchStrategy: SwatchStrategy = .vibrant,
            grain: GrainStyle = .standard
        ) {
            self.direction = direction
            self.linearStart = linearStart
            self.linearEnd = linearEnd
            self.colorCount = colorCount
            self.swatchStrategy = swatchStrategy
            self.grain = grain
        }
    }
}

/// Number of distinct colors used along a ``PaletteGraphic`` gradient.
///
/// Endpoint colors are picked by the configuration's ``SwatchStrategy``;
/// any additional middle colors are pulled from the source palette in
/// luminance order. If the source doesn't expose enough distinct colors
/// for the requested count, the renderer silently falls back to whatever
/// is available.
enum ColorCount: Int, CaseIterable, Identifiable, Sendable {
    case two   = 2
    case three = 3
    case four  = 4
    case five  = 5

    var id: Int { rawValue }
}

/// How a ``PaletteGraphic`` flows its color stops across the bounds.
///
/// Independent of the `stops` count — any direction supports 2 to 5 color
/// stops, distributed evenly along the flow.
enum GradientDirection: String, CaseIterable, Identifiable, Sendable {
    /// Diagonal flow from bottom-left (first stop) to top-right (last stop).
    /// Mirrors the angular gradient direction common in printed posters and
    /// Arc-style membership cards.
    case linear = "Linear"

    /// Concentric color rings radiating from an off-center anchor in the
    /// upper-right quadrant. The first stop sits at the anchor; later stops
    /// expand outward.
    case radial = "Radial"

    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .linear: return "diagonal flow"
        case .radial: return "off-center radial"
        }
    }
}

/// Film-grain texture intensity for ``PaletteGraphic``.
///
/// Grain is a low-amplitude noise overlay multiplied onto the gradient so
/// the result reads as a printed/analog surface rather than a flat digital
/// fill. Each case maps to a tuned numeric weight; expose semantic levels
/// instead of raw doubles so callers don't need to guess what `0.4` means.
enum GrainStyle: String, CaseIterable, Identifiable, Sendable {
    /// No grain at all — clean digital gradient. Use when the surrounding
    /// design language is already textured (e.g. on top of paper backgrounds).
    case none = "None"

    /// Barely-perceptible grain. Hint of texture without changing the overall
    /// tone of the gradient.
    case subtle = "Subtle"

    /// Default level — visible film grain that still reads as the gradient's
    /// surface, not a separate layer.
    case standard = "Standard"

    /// Strong, poster-style grain. Best for large hero graphics where the
    /// texture is meant to be part of the composition.
    case heavy = "Heavy"

    var id: String { rawValue }

    /// Numeric weight applied to the grain ColorMatrix inside the renderer.
    var intensity: Double {
        switch self {
        case .none:     return 0.0
        case .subtle:   return 0.3
        case .standard: return 0.55
        case .heavy:    return 0.85
        }
    }
}
