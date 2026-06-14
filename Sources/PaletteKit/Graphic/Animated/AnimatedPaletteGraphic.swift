import Foundation
import simd

/// A "living gradient": renders an extracted ``Palette`` as a slowly morphing,
/// LAB-blended, multi-point gradient. Fills its frame — clip to any shape with
/// `.clipShape`.
///
/// ```swift
/// AnimatedPaletteGraphic(
///     palette: palette,
///     configuration: .init(
///         colorCount: .three,   // .two ... .five
///         speed: .regular,      // .slow / .regular / .fast
///         isAnimated: true
///     )
/// )
/// .frame(width: 320, height: 420)
/// .clipShape(RoundedRectangle(cornerRadius: 24))
/// ```
///
/// On non-UIKit platforms this is a plain value type (no rendering); the SwiftUI
/// `View` conformance and renderer are provided where UIKit is available.
public struct AnimatedPaletteGraphic {
    let palette: Palette
    let configuration: Configuration

    public init(palette: Palette, configuration: Configuration = .init()) {
        self.palette = palette
        self.configuration = configuration
    }
}

extension AnimatedPaletteGraphic {
    /// Tunable parameters for the animated gradient.
    public struct Configuration: Sendable, Equatable {
        /// How many of the palette's colors (by population) drive the gradient.
        public var colorCount: ColorCount
        /// Flow speed.
        public var speed: FlowSpeed
        /// When `false`, the gradient holds a static frame.
        public var isAnimated: Bool

        public init(
            colorCount: ColorCount = .three,
            speed: FlowSpeed = .regular,
            isAnimated: Bool = true
        ) {
            self.colorCount = colorCount
            self.speed = speed
            self.isAnimated = isAnimated
        }

        /// Fixed inverse-distance falloff exponent for the blend (matches
        /// ColorfulX's default; tuned for the smoothest look in the bake-off).
        static let power: Float = 4

        /// The chosen palette colors as CIE LAB vectors, padded/repeated to
        /// `colorCount`. Colors are taken in population order (most prominent
        /// first), since ``Palette`` is sorted that way.
        func resolveLABColors(from palette: Palette) -> [SIMD3<Float>] {
            let source = palette.colors.isEmpty ? [PaletteColor.black] : palette.colors
            return (0..<colorCount.rawValue).map { LABConversion.rgbToLAB(source[$0 % source.count].rgb) }
        }
    }
}
