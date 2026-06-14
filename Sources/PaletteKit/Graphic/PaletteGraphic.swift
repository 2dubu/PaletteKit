#if canImport(SwiftUI) && canImport(UIKit)
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import SwiftUI
import UIKit

/// Palette-driven gradient + grain primitive for SwiftUI.
///
/// Renders a rectangular graphic that callers compose into cards, posters,
/// share assets, or any SwiftUI layout. Apply standard SwiftUI clipping
/// (`.clipShape`, `.mask`, …) for non-rectangular silhouettes.
///
/// Pair type: ``PaletteGraphicView`` (UIView) for UIKit-only call sites.
///
/// ```swift
/// PaletteGraphic(palette: palette, swatches: swatches, configuration: .init(
///     direction: .linear,
///     colorCount: .three,
///     swatchStrategy: .vibrant,
///     grain: .standard
/// ))
/// .frame(width: 320, height: 320)
/// .clipShape(RoundedRectangle(cornerRadius: 24))
/// ```
public struct PaletteGraphic: View {
    public let palette: Palette
    public let swatches: SwatchMap?
    public let configuration: Configuration

    @Environment(\.displayScale) private var displayScale

    public init(
        palette: Palette,
        swatches: SwatchMap?,
        configuration: Configuration = .init()
    ) {
        self.palette = palette
        self.swatches = swatches
        self.configuration = configuration
    }

    public var body: some View {
        GeometryReader { geo in
            let scale = max(displayScale, 1)
            let size = CGSize(
                width: max(geo.size.width * scale, 1),
                height: max(geo.size.height * scale, 1)
            )
            if let cg = PaletteGraphicRenderer.makeCGImage(
                palette: palette, swatches: swatches,
                configuration: configuration, pixelSize: size
            ) {
                Image(uiImage: UIImage(cgImage: cg, scale: scale, orientation: .up))
                    .resizable()
                    .scaledToFill()
            } else {
                Color(PaletteGraphicRenderer.resolveAnchors(
                    palette: palette, swatches: swatches,
                    strategy: configuration.swatchStrategy
                ).center)
            }
        }
    }

    /// Render this graphic to a `UIImage` at the given logical size.
    /// Bypasses SwiftUI's view hierarchy. Result is rectangular — apply
    /// your own clipping (`UIBezierPath` mask, `CALayer.mask`, …) for
    /// non-rectangular silhouettes.
    ///
    /// `scale` defaults to `2.0` for predictable output regardless of
    /// caller context; pass an explicit value for device-accurate output.
    public func makeImage(size: CGSize, scale: CGFloat = 2.0) -> UIImage? {
        let pixelSize = CGSize(
            width: max(size.width * scale, 1),
            height: max(size.height * scale, 1)
        )
        guard let cg = PaletteGraphicRenderer.makeCGImage(
            palette: palette, swatches: swatches,
            configuration: configuration, pixelSize: pixelSize
        ) else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}

extension PaletteGraphic {
    /// Style options for ``PaletteGraphic`` and ``PaletteGraphicView``.
    /// All fields have sensible defaults; pass a customised instance to
    /// override any subset.
    public struct Configuration: Sendable, Equatable, Hashable {
        public var direction: GradientDirection
        /// Start anchor for the linear gradient flow. Ignored when
        /// ``direction`` is `.radial`. Uses SwiftUI's standard
        /// ``SwiftUI/UnitPoint`` (origin top-leading, y down).
        public var linearStart: UnitPoint
        /// End anchor for the linear gradient flow. Ignored when
        /// ``direction`` is `.radial`.
        public var linearEnd: UnitPoint
        /// How many colors compose the gradient.
        ///
        /// First and last colors are anchored to the strategy's resolved
        /// center / edge. Middle colors are pulled from the source palette
        /// + any available `SwatchMap` roles via cumulative bisection so
        /// raising the count adds one color at a time.
        public var colorCount: ColorCount
        public var swatchStrategy: SwatchStrategy
        public var grain: GrainStyle

        public init(
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

/// How a ``PaletteGraphic`` flows its color stops across the bounds.
public enum GradientDirection: String, CaseIterable, Identifiable, Sendable {
    /// Diagonal flow from `linearStart` to `linearEnd`. Default anchors
    /// run bottom-leading → top-trailing.
    case linear = "Linear"

    /// Concentric color rings radiating from an off-center anchor in the
    /// upper-right quadrant.
    case radial = "Radial"

    public var id: String { rawValue }

    /// Short human-readable description of the flow shape, suitable for
    /// picker subtitles or accessibility labels.
    public var subtitle: String {
        switch self {
        case .linear: return "diagonal flow"
        case .radial: return "off-center radial"
        }
    }
}

/// Film-grain texture intensity for ``PaletteGraphic``.
public enum GrainStyle: String, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case subtle = "Subtle"
    case standard = "Standard"
    case heavy = "Heavy"

    public var id: String { rawValue }

    /// Numeric weight applied to the grain ColorMatrix inside the renderer.
    public var intensity: Double {
        switch self {
        case .none:     return 0.0
        case .subtle:   return 0.3
        case .standard: return 0.55
        case .heavy:    return 0.85
        }
    }
}
#endif
