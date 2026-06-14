import Foundation
import Testing
@testable import PaletteKit

@Suite("LABConversion")
struct LABConversionTests {
    @Test("white maps to L≈100, a≈0, b≈0")
    func white() {
        let lab = LABConversion.rgbToLAB(RGB(r: 255, g: 255, b: 255))
        #expect(abs(lab.x - 100) < 0.5)
        #expect(abs(lab.y) < 0.5)
        #expect(abs(lab.z) < 0.5)
    }

    @Test("black maps to L≈0")
    func black() {
        let lab = LABConversion.rgbToLAB(RGB(r: 0, g: 0, b: 0))
        #expect(abs(lab.x) < 0.5)
    }

    @Test("round-trips RGB -> LAB -> RGB within tolerance")
    func roundTrip() {
        for rgb in [RGB(r: 18, g: 58, b: 143), RGB(r: 242, g: 194, b: 0), RGB(r: 120, g: 90, b: 200)] {
            let back = LABConversion.labToRGB(LABConversion.rgbToLAB(rgb))
            #expect(abs(Int(back.r) - Int(rgb.r)) <= 2)
            #expect(abs(Int(back.g) - Int(rgb.g)) <= 2)
            #expect(abs(Int(back.b) - Int(rgb.b)) <= 2)
        }
    }
}
