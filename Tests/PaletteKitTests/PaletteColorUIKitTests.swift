#if canImport(UIKit)
import Testing
import UIKit
@testable import PaletteKit

@Suite("UIColor(_ paletteColor:)")
struct PaletteColorUIKitInitTests {
    @Test("Black PaletteColor maps to (0, 0, 0, 1)")
    func blackUIColor() {
        let color = UIColor(PaletteColor(r: 0, g: 0, b: 0))
        var r: CGFloat = -1, g: CGFloat = -1, b: CGFloat = -1, a: CGFloat = -1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(r == 0)
        #expect(g == 0)
        #expect(b == 0)
        #expect(a == 1)
    }

    @Test("White PaletteColor maps to (1, 1, 1, 1)")
    func whiteUIColor() {
        let color = UIColor(PaletteColor(r: 255, g: 255, b: 255))
        var r: CGFloat = -1, g: CGFloat = -1, b: CGFloat = -1, a: CGFloat = -1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(r == 1)
        #expect(g == 1)
        #expect(b == 1)
        #expect(a == 1)
    }

    @Test("Mid-RGB PaletteColor maps to correct UIColor channels")
    func midUIColor() {
        let color = UIColor(PaletteColor(r: 200, g: 100, b: 50))
        var r: CGFloat = -1, g: CGFloat = -1, b: CGFloat = -1, a: CGFloat = -1
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 200.0 / 255.0) < 1e-5)
        #expect(abs(g - 100.0 / 255.0) < 1e-5)
        #expect(abs(b - 50.0 / 255.0) < 1e-5)
        #expect(a == 1)
    }
}
#endif
