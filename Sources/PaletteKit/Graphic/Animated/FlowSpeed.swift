import Foundation

/// Flow speed for ``AnimatedPaletteGraphic`` — Apple-style preset object (cf.
/// `Animation.snappy`, `Material.regular`): named presets for the common cases
/// plus a public escape-hatch initializer for fine control.
public struct FlowSpeed: Sendable, Equatable, Hashable {
    /// Motion-rate multiplier (0 = still).
    public let multiplier: Double

    /// Escape hatch for a custom speed. Clamped to `>= 0`.
    public init(_ multiplier: Double) { self.multiplier = max(0, multiplier) }

    public static let slow = FlowSpeed(0.1)
    public static let regular = FlowSpeed(0.2)   // baseline
    public static let fast = FlowSpeed(0.3)
}
