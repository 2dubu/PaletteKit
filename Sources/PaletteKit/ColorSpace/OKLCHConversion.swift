import Accelerate
import Foundation

public enum OKLCHConversion {
    // sRGB and Display P3 share the same transfer function.
    private static let linearizedChannels: [Double] = (0...255).map { channel in
        let s = Double(channel) / 255
        return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
    }

    public static func srgbToLinear(_ channel: UInt8) -> Double {
        linearizedChannels[Int(channel)]
    }

    public static func linearToSRGB(_ linear: Double) -> UInt8 {
        let clamped = min(max(linear, 0), 1)
        let s = clamped <= 0.003_130_8
            ? 12.92 * clamped
            : 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
        return UInt8(min(max((s * 255).rounded(), 0), 255))
    }

    public static func rgbToOKLCH(_ rgb: RGB) -> OKLCH {
        let lr = srgbToLinear(rgb.r)
        let lg = srgbToLinear(rgb.g)
        let lb = srgbToLinear(rgb.b)
        return linearRGBToOKLCH(lr: lr, lg: lg, lb: lb)
    }

    public static func displayP3ToOKLCH(_ rgb: RGB) -> OKLCH {
        let pr = p3ToLinear(rgb.r)
        let pg = p3ToLinear(rgb.g)
        let pb = p3ToLinear(rgb.b)
        // Linear Display P3 -> XYZ D65 -> linear sRGB (CSS Color 4).
        // Keep signed and above-one channels until OKLab conversion: clipping
        // here would discard the part of Display P3 outside the sRGB gamut.
        let lr = 1.224_940_176_3 * pr - 0.224_940_176_3 * pg
        let lg = -0.042_056_954_7 * pr + 1.042_056_954_7 * pg
        let lb = -0.019_637_554_6 * pr - 0.078_636_045_6 * pg + 1.098_273_600_1 * pb
        return linearRGBToOKLCH(lr: lr, lg: lg, lb: lb)
    }

    public static func oklchToRGB(_ value: OKLCH) -> RGB {
        let hRad = value.h * .pi / 180
        let a = value.c * cos(hRad)
        let bLab = value.c * sin(hRad)
        let l3 = value.l + 0.396_337_777_4 * a + 0.215_803_757_3 * bLab
        let m3 = value.l - 0.105_561_345_8 * a - 0.063_854_172_8 * bLab
        let s3 = value.l - 0.089_484_177_5 * a - 1.291_485_548_0 * bLab

        let lP = l3 * l3 * l3
        let mP = m3 * m3 * m3
        let sP = s3 * s3 * s3

        let lr = +4.076_741_662_1 * lP - 3.307_711_591_3 * mP + 0.230_969_929_2 * sP
        let lg = -1.268_438_004_6 * lP + 2.609_757_401_1 * mP - 0.341_319_396_5 * sP
        let lb = -0.004_196_086_3 * lP - 0.703_418_614_7 * mP + 1.707_614_701_0 * sP

        return RGB(
            r: linearToSRGB(lr),
            g: linearToSRGB(lg),
            b: linearToSRGB(lb)
        )
    }

    static func p3ToLinear(_ channel: UInt8) -> Double {
        linearizedChannels[Int(channel)]
    }

    static func linearRGBToOKLCH(lr: Double, lg: Double, lb: Double) -> OKLCH {
        let lCone = 0.412_221_470_8 * lr + 0.536_332_536_3 * lg + 0.051_445_992_9 * lb
        let mCone = 0.211_903_498_2 * lr + 0.680_699_545_1 * lg + 0.107_396_956_6 * lb
        let sCone = 0.088_302_461_9 * lr + 0.281_718_837_6 * lg + 0.629_978_700_5 * lb

        let l3 = cbrt(lCone)
        let m3 = cbrt(mCone)
        let s3 = cbrt(sCone)

        let lightness = 0.210_454_255_3 * l3 + 0.793_617_785_0 * m3 - 0.004_072_046_8 * s3
        let a = 1.977_998_495_1 * l3 - 2.428_592_205_0 * m3 + 0.450_593_709_9 * s3
        let bLab = 0.025_904_037_1 * l3 + 0.782_771_766_2 * m3 - 0.808_675_766_0 * s3

        let chroma = (a * a + bLab * bLab).squareRoot()
        var hue = atan2(bLab, a) * 180 / .pi
        if hue < 0 { hue += 360 }

        return OKLCH(l: lightness, c: chroma, h: hue)
    }
}
