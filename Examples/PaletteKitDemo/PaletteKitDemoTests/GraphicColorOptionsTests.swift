import Testing
@testable import PaletteKit
@testable import PaletteKitDemo

@MainActor
@Suite("Graphic Lab color options")
struct GraphicColorOptionsTests {
    @Test("Single-color and empty palettes disable every count")
    func singleColor() {
        for colors in [[], [.black], [.white, .white]] as [[PaletteColor]] {
            let options = options(colors)
            #expect(options.availableCounts.isEmpty)
            #expect(options.isSingleColor)
            for count in ColorCount.allCases {
                #expect(options.selection(preserving: count) == .two)
            }
        }
    }

    @Test("Only achievable counts are available", arguments: 0...3)
    func candidateLimits(middleCount: Int) {
        let colors = [PaletteColor.white] + [gray(200), gray(140), gray(70)].prefix(middleCount) + [.black]
        let options = options(colors)
        #expect(options.availableCounts == Array(ColorCount.allCases.prefix(middleCount + 1)))
        #expect(!options.isSingleColor)
        for count in ColorCount.allCases {
            #expect(options.selection(preserving: count).rawValue == min(count.rawValue, middleCount + 2))
        }
    }

    @Test("Strategy changes correct unavailable selections and preserve valid ones")
    func strategyChanges() {
        let palette = Palette(colors: [.white, gray(200), gray(70), .black], colorSpaceUsed: .oklch)
        let swatches = SwatchMap(
            vibrant: swatch(.black, .vibrant),
            muted: swatch(.white, .muted),
            darkVibrant: swatch(.black, .darkVibrant),
            lightVibrant: swatch(gray(70), .lightVibrant)
        )
        let vibrant = GraphicColorOptions(palette: palette, swatches: swatches, strategy: .vibrant)
        let contrast = GraphicColorOptions(palette: palette, swatches: swatches, strategy: .contrast)
        let muted = GraphicColorOptions(palette: palette, swatches: swatches, strategy: .muted)
        #expect(vibrant.availableCounts == [])
        #expect(contrast.availableCounts == [.two])
        #expect(muted.availableCounts == [.two, .three, .four])
        var selection = ColorCount.five
        selection = muted.selection(preserving: selection)
        #expect(selection == .four)
        selection = contrast.selection(preserving: selection)
        #expect(selection == .two)
        #expect(muted.selection(preserving: selection) == .two)
        #expect(vibrant.selection(preserving: .four) == .two)
        #expect(muted.selection(preserving: .three) == .three)
    }

    @Test("Changing the image or swatches recomputes availability")
    func changedInputs() {
        let full = options([.white, gray(200), gray(140), gray(70), .black])
        let fewer = options([.white, gray(140), .black])
        #expect(full.selection(preserving: .five) == .five)
        #expect(fewer.selection(preserving: .five) == .three)
        #expect(full.selection(preserving: .three) == .three)

        let palette = Palette(colors: [.white, gray(140), .black], colorSpaceUsed: .oklch)
        let collapsed = GraphicColorOptions(palette: palette,
            swatches: SwatchMap(vibrant: swatch(.black, .vibrant)), strategy: .vibrant)
        #expect(collapsed.isSingleColor)
        #expect(collapsed.selection(preserving: .three) == .two)
    }

    private func options(_ colors: [PaletteColor]) -> GraphicColorOptions {
        GraphicColorOptions(palette: Palette(colors: colors, colorSpaceUsed: .oklch), swatches: nil, strategy: .vibrant)
    }

    private func gray(_ value: UInt8) -> PaletteColor { PaletteColor(r: value, g: value, b: value) }

    private func swatch(_ color: PaletteColor, _ role: SwatchRole) -> Swatch {
        Swatch(color: color, role: role, titleTextColor: .white, bodyTextColor: .white)
    }
}
