import Foundation
import Testing

@testable import PaletteKit

@Suite("OKLCHConversion")
struct OKLCHConversionTests {
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
