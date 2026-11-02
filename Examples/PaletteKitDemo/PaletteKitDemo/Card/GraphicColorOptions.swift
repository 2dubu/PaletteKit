import PaletteKit

/// Demo policy built from the renderer's actual stops, not its candidate rules.
struct GraphicColorOptions: Equatable {
    let availableCounts: [ColorCount]

    @MainActor
    init(palette: Palette, swatches: SwatchMap?, strategy: SwatchStrategy) {
        availableCounts = ColorCount.allCases.filter { count in
            let graphic = PaletteGraphic(
                palette: palette, swatches: swatches,
                configuration: .init(colorCount: count, swatchStrategy: strategy)
            )
            return Set(graphic.resolvedStopColors.map(\.rgb)).count == count.rawValue
        }
    }

    var isSingleColor: Bool { availableCounts.isEmpty }

    /// Preserve a valid selection; otherwise use the largest available count.
    /// Two is the rendering fallback for a single color, with no segment selected.
    func selection(preserving count: ColorCount) -> ColorCount {
        availableCounts.contains(count) ? count : availableCounts.last ?? .two
    }
}
