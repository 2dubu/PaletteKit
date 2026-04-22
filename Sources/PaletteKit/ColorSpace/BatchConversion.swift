import Accelerate
import Foundation

public enum BatchConversion {
    public static func pixelsToOKLCHScaled(
        _ pixels: [PixelTriplet],
        sourceSpace: ColorSpace
    ) -> [PixelTriplet] {
        guard !pixels.isEmpty else { return [] }
        var output = [PixelTriplet](repeating: PixelTriplet(r: 0, g: 0, b: 0), count: pixels.count)

        for index in 0..<pixels.count {
            let pixel = pixels[index]
            let rgb = RGB(r: pixel.r, g: pixel.g, b: pixel.b)
            let oklch: OKLCH
            switch sourceSpace {
            case .displayP3:
                oklch = OKLCHConversion.displayP3ToOKLCH(rgb)
            case .sRGB, .oklch:
                oklch = OKLCHConversion.rgbToOKLCH(rgb)
            }
            output[index] = PixelTriplet(
                r: UInt8(min(max((oklch.l * 255).rounded(), 0), 255)),
                g: UInt8(min(max((oklch.c / 0.4 * 255).rounded(), 0), 255)),
                b: UInt8(min(max((oklch.h / 360 * 255).rounded(), 0), 255))
            )
        }

        return output
    }

    public static func scaledOKLCHToRGB(
        _ quantized: [QuantizedColor]
    ) -> [QuantizedColor] {
        quantized.map { entry in
            let l = Double(entry.color.r) / 255
            let c = (Double(entry.color.g) / 255) * 0.4
            let h = (Double(entry.color.b) / 255) * 360
            let rgb = OKLCHConversion.oklchToRGB(OKLCH(l: l, c: c, h: h))
            return QuantizedColor(
                color: PixelTriplet(r: rgb.r, g: rgb.g, b: rgb.b),
                population: entry.population
            )
        }
    }
}
