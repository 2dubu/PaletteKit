import Foundation
import simd

/// Internal CIE LAB (D65) conversion. LAB blending avoids the muddy mid-tones
/// that sRGB averaging produces between complementary colors.
enum LABConversion {
    /// sRGB (8-bit) → CIE LAB (D65). `x` = L, `y` = a, `z` = b.
    static func rgbToLAB(_ rgb: RGB) -> SIMD3<Float> {
        func toLinear(_ c: Double) -> Double {
            c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92
        }
        let r = toLinear(Double(rgb.r) / 255)
        let g = toLinear(Double(rgb.g) / 255)
        let b = toLinear(Double(rgb.b) / 255)
        let x = (r * 0.4124 + g * 0.3576 + b * 0.1805) * 100
        let y = (r * 0.2126 + g * 0.7152 + b * 0.0722) * 100
        let z = (r * 0.0193 + g * 0.1192 + b * 0.9505) * 100
        func f(_ t: Double) -> Double { t > 0.008856 ? pow(t, 1.0 / 3.0) : (7.787 * t + 16.0 / 116.0) }
        let fx = f(x / 95.047), fy = f(y / 100.0), fz = f(z / 108.883)
        return SIMD3(Float(116 * fy - 16), Float(500 * (fx - fy)), Float(200 * (fy - fz)))
    }

    /// CIE LAB (D65) → sRGB (8-bit), clamped.
    static func labToRGB(_ lab: SIMD3<Float>) -> RGB {
        let l = Double(lab.x), a = Double(lab.y), bb = Double(lab.z)
        let fy = (l + 16) / 116, fx = a / 500 + fy, fz = fy - bb / 200
        func inv(_ t: Double) -> Double {
            let t3 = t * t * t
            return t3 > 0.008856 ? t3 : (t - 16.0 / 116.0) / 7.787
        }
        let x = 95.047 * inv(fx) / 100, y = 100.0 * inv(fy) / 100, z = 108.883 * inv(fz) / 100
        func toSRGB(_ c: Double) -> Double { c > 0.0031308 ? 1.055 * pow(c, 1 / 2.4) - 0.055 : 12.92 * c }
        let r = toSRGB(x * 3.2406 + y * -1.5372 + z * -0.4986)
        let g = toSRGB(x * -0.9689 + y * 1.8758 + z * 0.0415)
        let b = toSRGB(x * 0.0557 + y * -0.2040 + z * 1.0570)
        func u8(_ v: Double) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
        return RGB(r: u8(r), g: u8(g), b: u8(b))
    }
}
