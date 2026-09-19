#if canImport(UIKit)
import Testing
@testable import PaletteKit

@MainActor
@Suite("PaletteGraphic resolved stops")
struct PaletteGraphicResolvedStopsTests {
    @Test("Repeated RGB anchors remain two stops but represent one color", arguments: ColorCount.allCases)
    func singleColor(count: ColorCount) {
        let color = PaletteColor(r: 90, g: 60, b: 30, population: 8)
        let duplicate = PaletteColor(rgb: color.rgb, population: 1)
        let graphic = makeGraphic([color, duplicate], count: count)
        #expect(graphic.resolvedStopColors.map(\.rgb) == [color.rgb, color.rgb])
        #expect(Set(graphic.resolvedStopColors.map(\.rgb)).count == 1)
    }

    @Test("Empty input exposes the renderer's black fallback", arguments: ColorCount.allCases)
    func emptyPalette(count: ColorCount) {
        #expect(makeGraphic([], count: count).resolvedStopColors.map(\.rgb) == [.init(r: 0, g: 0, b: 0), .init(r: 0, g: 0, b: 0)])
    }

    @Test("No, some, and enough middle colors cap actual stops", arguments: 0...3)
    func availableCandidates(middleCount: Int) {
        let middle = [gray(200), gray(140), gray(70)].prefix(middleCount)
        let colors = [PaletteColor.white] + middle + [.black]
        for count in ColorCount.allCases {
            let stops = makeGraphic(colors, count: count).resolvedStopColors
            #expect(stops.count == min(count.rawValue, middleCount + 2))
            #expect(Set(stops.map(\.rgb)).count == stops.count)
            #expect(stops.first?.rgb == PaletteColor.white.rgb)
            #expect(stops.last?.rgb == PaletteColor.black.rgb)
            #expect(stops.map(\.luminance) == stops.map(\.luminance).sorted(by: >))
        }
    }

    @Test("Inspection matches existing resolution for every strategy and request",
          arguments: SwatchStrategy.allCases, ColorCount.allCases)
    func sharedResolution(strategy: SwatchStrategy, count: ColorCount) {
        let palette = Palette(colors: [.white, gray(200), gray(140), gray(70), .black], colorSpaceUsed: .oklch)
        let swatches = SwatchMap(
            vibrant: swatch(.black, .vibrant),
            muted: swatch(.white, .muted),
            darkVibrant: swatch(.black, .darkVibrant),
            lightVibrant: swatch(gray(70), .lightVibrant)
        )
        let graphic = PaletteGraphic(palette: palette, swatches: swatches,
                                     configuration: .init(colorCount: count, swatchStrategy: strategy))
        let anchors = PaletteGraphicRenderer.resolveAnchors(palette: palette, swatches: swatches, strategy: strategy)
        let expected = PaletteGraphicRenderer.resolveStopColors(
            palette: palette, swatches: swatches, center: anchors.center, edge: anchors.edge, count: count.rawValue
        )
        #expect(graphic.resolvedStopColors == expected)
        let distinctCount = Set(graphic.resolvedStopColors.map(\.rgb)).count
        switch strategy {
        case .vibrant: #expect(distinctCount == 1)
        case .contrast: #expect(distinctCount == 2)
        case .muted: #expect(distinctCount == count.rawValue)
        }
    }

    @Test("Ineligible colors and duplicate swatches do not inflate the result")
    func filteredCandidates() {
        let bright = PaletteColor(r: 255, g: 120, b: 0)
        let dark = PaletteColor(r: 80, g: 20, b: 0)
        let palette = Palette(colors: [.white, gray(130), .black], colorSpaceUsed: .oklch)
        let swatches = SwatchMap(vibrant: swatch(bright, .vibrant), darkVibrant: swatch(dark, .darkVibrant))
        let graphic = PaletteGraphic(palette: palette, swatches: swatches, configuration: .init(colorCount: .five))
        #expect(graphic.resolvedStopColors.map(\.rgb) == [bright.rgb, dark.rgb])
    }

    private func makeGraphic(_ colors: [PaletteColor], count: ColorCount) -> PaletteGraphic {
        PaletteGraphic(palette: Palette(colors: colors, colorSpaceUsed: .oklch), swatches: nil,
                       configuration: .init(colorCount: count))
    }

    private func gray(_ value: UInt8) -> PaletteColor { PaletteColor(r: value, g: value, b: value) }

    private func swatch(_ color: PaletteColor, _ role: SwatchRole) -> Swatch {
        Swatch(color: color, role: role, titleTextColor: .white, bodyTextColor: .white)
    }
}
#endif
