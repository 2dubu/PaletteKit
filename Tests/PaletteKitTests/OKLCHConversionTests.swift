import Foundation
import Testing

@testable import PaletteKit

@Suite("OKLCHConversion")
struct OKLCHConversionTests {
    @Test("Display P3 matches independent XYZ and OKLab references")
    func displayP3MatchesReference() {
        // W3C CSS Color 4 (2026-11-03), section 19:
        // https://www.w3.org/TR/2026/CRD-css-color-4-20261103/#color-conversion-code
        // Calculated through lin_P3 -> lin_P3_to_XYZ -> XYZ_to_OKLab ->
        // OKLab_to_OKLCH, independently of PaletteKit's linear-sRGB path.
        // Primaries exercise signed, out-of-sRGB-gamut intermediate channels;
        // mixed colors also exercise transfer decoding before the matrix.
        let references: [(RGB, OKLCH)] = [
            (RGB(r: 255, g: 0, b: 0), OKLCH(l: 0.648574075144298, c: 0.299485286338370, h: 28.958132730804)),
            (RGB(r: 0, g: 255, b: 0), OKLCH(l: 0.848829292853246, c: 0.368527797681383, h: 145.644955586628)),
            (RGB(r: 0, g: 0, b: 255), OKLCH(l: 0.466360540395478, c: 0.323155748752855, h: 264.052022616370)),
            (RGB(r: 255, g: 255, b: 0), OKLCH(l: 0.964764119709696, c: 0.245031439040542, h: 110.229809555625)),
            (RGB(r: 255, g: 0, b: 255), OKLCH(l: 0.724979566997116, c: 0.360176499394589, h: 331.464435695764)),
            (RGB(r: 0, g: 255, b: 255), OKLCH(l: 0.892901616194442, c: 0.205667459058254, h: 193.137687751383)),
            (RGB(r: 128, g: 32, b: 192), OKLCH(l: 0.498944314304770, c: 0.243722099717081, h: 309.448059516176)),
            (RGB(r: 10, g: 128, b: 240), OKLCH(l: 0.604640475579486, c: 0.211892203188919, h: 249.003028188356)),
        ]
        for (rgb, expected) in references {
            let actual = OKLCHConversion.displayP3ToOKLCH(rgb)
            #expect(abs(actual.l - expected.l) < 0.000001)
            #expect(abs(actual.c - expected.c) < 0.000001)
            #expect(abs(actual.h - expected.h) < 0.0001)
        }
    }

    @Test("Display P3 and sRGB share the same neutral axis")
    func neutralAxisMatchesSRGB() {
        for value in UInt8.min...UInt8.max {
            let rgb = RGB(r: value, g: value, b: value)
            let p3 = OKLCHConversion.displayP3ToOKLCH(rgb)
            let srgb = OKLCHConversion.rgbToOKLCH(rgb)
            #expect(abs(p3.l - srgb.l) < 0.0000001)
            #expect(abs(p3.c - srgb.c) < 0.0000001)
            // Hue is not meaningful for achromatic colors.
        }
    }

    @Test("sRGB and Display P3 preserve the transfer function for every 8-bit channel")
    func transferFunctionMatchesReference() {
        for value in UInt8.min...UInt8.max {
            let encoded = Double(value) / 255
            let expected =
                encoded <= 0.04045
                ? encoded / 12.92
                : pow((encoded + 0.055) / 1.055, 2.4)

            #expect(OKLCHConversion.srgbToLinear(value).bitPattern == expected.bitPattern)
            #expect(OKLCHConversion.p3ToLinear(value).bitPattern == expected.bitPattern)
        }
    }

    @Test("every 8-bit channel round-trips through the transfer function")
    func transferFunctionRoundTrip() {
        for value in UInt8.min...UInt8.max {
            #expect(OKLCHConversion.linearToSRGB(OKLCHConversion.srgbToLinear(value)) == value)
            #expect(OKLCHConversion.linearToSRGB(OKLCHConversion.p3ToLinear(value)) == value)
        }
    }
}
