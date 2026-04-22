import Foundation

public struct PaletteBuilder: Sendable {
    public init() {}

    public func build(
        quantized: [QuantizedColor],
        colorSpaceUsed: ColorSpace,
        timings: ExtractionTimings? = nil
    ) -> Palette {
        guard !quantized.isEmpty else {
            return Palette(colors: [], colorSpaceUsed: colorSpaceUsed, timings: timings)
        }
        let totalPopulation = quantized.reduce(0) { $0 + $1.population }
        let sorted = quantized.sorted { $0.population > $1.population }

        let colors = sorted.map { entry -> PaletteColor in
            let proportion = totalPopulation > 0
                ? Double(entry.population) / Double(totalPopulation)
                : 0
            return PaletteColor(
                rgb: RGB(r: entry.color.r, g: entry.color.g, b: entry.color.b),
                population: entry.population,
                proportion: proportion
            )
        }

        return Palette(colors: colors, colorSpaceUsed: colorSpaceUsed, timings: timings)
    }

    public func averageFallback(
        buffer: PixelBuffer,
        quality: Int,
        colorSpaceUsed: ColorSpace,
        timings: ExtractionTimings? = nil
    ) -> Palette {
        let pixelCount = buffer.pixelCount
        guard pixelCount > 0 else {
            return Palette(colors: [], colorSpaceUsed: colorSpaceUsed, timings: timings)
        }
        var rTotal = 0
        var gTotal = 0
        var bTotal = 0
        var count = 0

        buffer.data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            let stride = max(1, quality)
            var index = 0
            while index < pixelCount {
                let offset = index * 4
                rTotal += Int(base[offset])
                gTotal += Int(base[offset + 1])
                bTotal += Int(base[offset + 2])
                count += 1
                index += stride
            }
        }

        guard count > 0 else {
            return Palette(colors: [], colorSpaceUsed: colorSpaceUsed, timings: timings)
        }

        let color = PaletteColor(
            r: UInt8(min(255, rTotal / count)),
            g: UInt8(min(255, gTotal / count)),
            b: UInt8(min(255, bTotal / count)),
            population: count,
            proportion: 1
        )
        return Palette(colors: [color], colorSpaceUsed: colorSpaceUsed, timings: timings)
    }
}
