#if canImport(SwiftUI) && canImport(UIKit)
import Testing
import SwiftUI
@testable import PaletteKit

@Suite("PaletteGraphic.Configuration + supporting enums")
struct PaletteGraphicConfigurationTests {
    @Test("default configuration matches spec")
    func defaults() {
        let cfg = PaletteGraphic.Configuration()
        #expect(cfg.direction == .linear)
        #expect(cfg.linearStart == .bottomLeading)
        #expect(cfg.linearEnd == .topTrailing)
        #expect(cfg.colorCount == .two)
        #expect(cfg.swatchStrategy == .vibrant)
        #expect(cfg.grain == .standard)
    }

    @Test("ColorCount maps to expected raw values 2..5")
    func colorCountRawValues() {
        #expect(ColorCount.two.rawValue == 2)
        #expect(ColorCount.three.rawValue == 3)
        #expect(ColorCount.four.rawValue == 4)
        #expect(ColorCount.five.rawValue == 5)
        #expect(ColorCount.allCases.count == 4)
    }

    @Test("GrainStyle.intensity matches expected weights")
    func grainIntensities() {
        #expect(GrainStyle.none.intensity == 0.0)
        #expect(GrainStyle.subtle.intensity == 0.3)
        #expect(GrainStyle.standard.intensity == 0.55)
        #expect(GrainStyle.heavy.intensity == 0.85)
    }

    @Test("GradientDirection enumerates linear + radial only")
    func gradientDirections() {
        #expect(GradientDirection.allCases == [.linear, .radial])
    }

    @Test("All enums are Sendable + Identifiable")
    func protocolConformance() {
        let _: any Sendable = ColorCount.two
        let _: any Sendable = GrainStyle.standard
        let _: any Sendable = GradientDirection.linear
        let _: any Identifiable = ColorCount.two
        let _: any Identifiable = GrainStyle.standard
        let _: any Identifiable = GradientDirection.linear
    }
}
#endif
