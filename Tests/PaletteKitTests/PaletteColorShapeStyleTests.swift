#if canImport(SwiftUI)
import Testing
import SwiftUI
@testable import PaletteKit

@Suite("PaletteColor: ShapeStyle")
struct PaletteColorShapeStyleTests {
    @Test("Black resolves to (0, 0, 0, 1)")
    func resolveBlack() {
        let color = PaletteColor(r: 0, g: 0, b: 0)
        let resolved = color.resolve(in: EnvironmentValues())
        #expect(resolved.red == 0)
        #expect(resolved.green == 0)
        #expect(resolved.blue == 0)
        #expect(resolved.opacity == 1)
    }

    @Test("White resolves to (1, 1, 1, 1)")
    func resolveWhite() {
        let color = PaletteColor(r: 255, g: 255, b: 255)
        let resolved = color.resolve(in: EnvironmentValues())
        #expect(resolved.red == 1)
        #expect(resolved.green == 1)
        #expect(resolved.blue == 1)
        #expect(resolved.opacity == 1)
    }

    @Test("Mid-RGB PaletteColor resolves to scaled 0-1 channels")
    func resolveMidRGB() {
        let color = PaletteColor(r: 200, g: 100, b: 50)
        let resolved = color.resolve(in: EnvironmentValues())
        #expect(abs(resolved.red - 200.0 / 255.0) < 1e-5)
        #expect(abs(resolved.green - 100.0 / 255.0) < 1e-5)
        #expect(abs(resolved.blue - 50.0 / 255.0) < 1e-5)
        #expect(resolved.opacity == 1)
    }

    @Test("linearRed reflects Apple's sRGB → linear conversion")
    func resolveLinearGamma() {
        // sRGB 128/255 ≈ 0.502 → linear ≈ 0.2159 (gamma decode)
        let color = PaletteColor(r: 128, g: 128, b: 128)
        let resolved = color.resolve(in: EnvironmentValues())
        let expectedLinear: Float = 0.2159
        #expect(abs(resolved.linearRed - expectedLinear) < 0.005)
        #expect(abs(resolved.linearGreen - expectedLinear) < 0.005)
        #expect(abs(resolved.linearBlue - expectedLinear) < 0.005)
    }
}
#endif
