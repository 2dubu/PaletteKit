#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// Palette-driven mesh gradient primitive for SwiftUI (iOS 18+).
///
/// Sibling to ``PaletteGraphic`` with the same call shape, different
/// visual character. Renders via SwiftUI's native `MeshGradient`.
///
/// ```swift
/// PaletteMeshGraphic(palette: palette)
///     .frame(width: 320, height: 320)
///     .clipShape(RoundedRectangle(cornerRadius: 24))
/// ```
@available(iOS 18.0, *)
public struct PaletteMeshGraphic: View {
    public let palette: Palette
    public let configuration: Configuration

    public init(
        palette: Palette,
        configuration: Configuration = .init()
    ) {
        self.palette = palette
        self.configuration = configuration
    }

    public var body: some View {
        let seed = PaletteMeshGraphicResolver.paletteSeed(palette: palette)
        let points = PaletteMeshGraphicResolver.resolvePoints(
            gridSize: configuration.gridSize,
            paletteSeed: seed
        )
        let colors = PaletteMeshGraphicResolver.resolveColors(
            palette: palette,
            gridSize: configuration.gridSize
        )
        return MeshGradient(
            width: configuration.gridSize.width,
            height: configuration.gridSize.height,
            points: points,
            colors: colors.map { Color(UIColor($0)) }
        )
    }

    /// Render this graphic to a `UIImage` at the given logical size.
    ///
    /// **Must be called from the main actor** (`ImageRenderer` constraint).
    /// `scale` defaults to `2.0` for predictable output regardless of caller
    /// context; pass an explicit value for device-accurate rendering.
    ///
    /// Returns `nil` if `size` or `scale` is non-positive, or if
    /// `ImageRenderer` fails to allocate the backing image.
    @MainActor
    public func makeImage(size: CGSize, scale: CGFloat = 2.0) -> UIImage? {
        guard size.width > 0, size.height > 0, scale > 0 else { return nil }
        let renderer = ImageRenderer(
            content: self.frame(width: size.width, height: size.height)
        )
        renderer.scale = scale
        return renderer.uiImage
    }
}

@available(iOS 18.0, *)
extension PaletteMeshGraphic {
    public struct Configuration: Sendable, Equatable, Hashable {
        /// Number of mesh control points per axis. Default ``GridSize/standard``.
        public var gridSize: GridSize

        public init(
            gridSize: GridSize = .standard
        ) {
            self.gridSize = gridSize
        }
    }

    /// Square grid size for mesh control points.
    ///
    /// All grids are N×N: ``compact`` (2×2), ``standard`` (3×3), ``rich`` (4×4).
    /// Larger grids read smoother but require a more color-diverse palette.
    public enum GridSize: Sendable, Equatable, Hashable {
        /// 2×2 grid — 4 colors. Minimal mesh: only corner points, so the
        /// resolver's organic jitter has no visible effect.
        case compact
        /// 3×3 grid — 9 colors. Default; balanced detail and palette identity.
        case standard
        /// 4×4 grid — 16 colors. Smoothest blend; best for color-diverse palettes.
        case rich

        /// Columns of mesh control points.
        public var width: Int {
            switch self {
            case .compact: return 2
            case .standard: return 3
            case .rich: return 4
            }
        }

        /// Rows of mesh control points.
        public var height: Int { width }

        /// Total number of colors / control points (`width * height`).
        public var colorCount: Int { width * height }
    }
}
#endif
