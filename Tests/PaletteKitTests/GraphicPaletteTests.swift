import Testing
@testable import PaletteKit

@Suite("GraphicPalette + SwatchStrategy")
struct GraphicPaletteTests {
    private let dominant   = PaletteColor(r: 200, g: 80,  b: 40)
    private let darkest    = PaletteColor(r: 30,  g: 20,  b: 10)
    private let lightest   = PaletteColor(r: 240, g: 230, b: 210)

    private var palette: Palette {
        Palette(
            colors: [dominant, lightest, darkest],
            colorSpaceUsed: .oklch
        )
    }

    private var fullSwatches: SwatchMap {
        let swatch = { (c: PaletteColor, role: SwatchRole) in
            Swatch(color: c, role: role, titleTextColor: .white, bodyTextColor: .white)
        }
        return SwatchMap(
            vibrant:      swatch(PaletteColor(r: 200, g: 80,  b: 40), .vibrant),
            muted:        swatch(PaletteColor(r: 150, g: 110, b: 90), .muted),
            darkVibrant:  swatch(PaletteColor(r: 90,  g: 30,  b: 10), .darkVibrant),
            darkMuted:    swatch(PaletteColor(r: 70,  g: 50,  b: 35), .darkMuted),
            lightVibrant: swatch(PaletteColor(r: 240, g: 150, b: 110), .lightVibrant),
            lightMuted:   swatch(PaletteColor(r: 230, g: 200, b: 180), .lightMuted)
        )
    }

    @Test("vibrant strategy uses vibrant + darkVibrant")
    func vibrantStrategy() {
        let cp = GraphicPalette(palette: palette, swatches: fullSwatches, strategy: .vibrant)
        #expect(cp.center.hex == "#c85028")
        #expect(cp.edge.hex == "#5a1e0a")
    }

    @Test("contrast strategy uses lightVibrant + darkMuted")
    func contrastStrategy() {
        let cp = GraphicPalette(palette: palette, swatches: fullSwatches, strategy: .contrast)
        #expect(cp.center.hex == "#f0966e")
        #expect(cp.edge.hex == "#463223")
    }

    @Test("muted strategy uses muted + darkMuted")
    func mutedStrategy() {
        let cp = GraphicPalette(palette: palette, swatches: fullSwatches, strategy: .muted)
        #expect(cp.center.hex == "#966e5a")
        #expect(cp.edge.hex == "#463223")
    }

    @Test("background uses lightMuted regardless of strategy")
    func backgroundIsStrategyIndependent() {
        for s: SwatchStrategy in [.vibrant, .contrast, .muted] {
            let cp = GraphicPalette(palette: palette, swatches: fullSwatches, strategy: s)
            #expect(cp.background.hex == "#e6c8b4")
        }
    }

    @Test("vibrant strategy falls back to dominant when vibrant swatch is nil")
    func vibrantFallback() {
        let partial = SwatchMap()
        let cp = GraphicPalette(palette: palette, swatches: partial, strategy: .vibrant)
        #expect(cp.center.hex == dominant.hex)
        #expect(cp.edge.hex == darkest.hex)
    }

    @Test("nil swatches still resolve to palette extremes")
    func nilSwatches() {
        let cp = GraphicPalette(palette: palette, swatches: nil, strategy: .vibrant)
        #expect(cp.center.hex == dominant.hex)
        #expect(cp.edge.hex == darkest.hex)
        #expect(cp.background.hex == lightest.hex)
    }

    @Test("SwatchStrategy.allCases enumerates the three strategies")
    func allCasesCount() {
        #expect(SwatchStrategy.allCases.count == 3)
    }

    @Test("GraphicPalette equality follows component equality")
    func equatableConformance() {
        let a = GraphicPalette(palette: palette, swatches: fullSwatches, strategy: .vibrant)
        let b = GraphicPalette(palette: palette, swatches: fullSwatches, strategy: .vibrant)
        let c = GraphicPalette(palette: palette, swatches: fullSwatches, strategy: .contrast)
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }
}
