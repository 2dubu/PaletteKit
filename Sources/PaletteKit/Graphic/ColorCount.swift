import Foundation

/// Number of distinct palette colors used along a gradient graphic.
///
/// Shared by ``PaletteGraphic`` and ``AnimatedPaletteGraphic``. Colors are taken
/// from the palette in population order (most prominent first).
public enum ColorCount: Int, CaseIterable, Identifiable, Sendable {
    case two = 2
    case three = 3
    case four = 4
    case five = 5

    public var id: Int { rawValue }
}
