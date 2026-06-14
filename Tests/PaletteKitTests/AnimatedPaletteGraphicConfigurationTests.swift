import Foundation
import Testing
@testable import PaletteKit

@Suite("AnimatedPaletteGraphic.Configuration")
struct AnimatedPaletteGraphicConfigurationTests {
    @Test("defaults: three colors, regular speed, animated")
    func defaults() {
        let c = AnimatedPaletteGraphic.Configuration()
        #expect(c.colorCount == .three)
        #expect(c.speed == .regular)
        #expect(c.isAnimated)
    }

    @Test("FlowSpeed presets")
    func speeds() {
        #expect(FlowSpeed.slow.multiplier == 0.1)
        #expect(FlowSpeed.regular.multiplier == 0.2)
        #expect(FlowSpeed.fast.multiplier == 0.3)
        #expect(FlowSpeed(-5).multiplier == 0)   // clamps
    }

    @Test("power is fixed at 4")
    func power() {
        #expect(AnimatedPaletteGraphic.Configuration.power == 4)
    }

    @Test("resolves LAB colors padded to colorCount, population order")
    func resolveColors() {
        let palette = Palette(colors: [
            PaletteColor(r: 18, g: 58, b: 143),
            PaletteColor(r: 242, g: 194, b: 0),
        ], colorSpaceUsed: .sRGB)

        let three = AnimatedPaletteGraphic.Configuration(colorCount: .three).resolveLABColors(from: palette)
        #expect(three.count == 3)
        // First resolved color is the palette's first (dominant), in LAB.
        #expect(three[0] == LABConversion.rgbToLAB(palette.colors[0].rgb))

        let five = AnimatedPaletteGraphic.Configuration(colorCount: .five).resolveLABColors(from: palette)
        #expect(five.count == 5)
    }
}
