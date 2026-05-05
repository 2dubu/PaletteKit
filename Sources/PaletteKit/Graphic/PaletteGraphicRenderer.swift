#if canImport(UIKit)
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

/// Internal Core Image / Core Graphics pipeline shared by ``PaletteGraphic``
/// (SwiftUI) and ``PaletteGraphicView`` (UIKit). Pixel-equivalent output
/// across both consumers.
internal enum PaletteGraphicRenderer {
    static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Memoizes the rendered `CGImage` keyed by (palette signature +
    /// configuration + pixel size). Memory-pressure safe via `NSCache`;
    /// thread-safe by design. Bounded to keep memory in check.
    nonisolated(unsafe) private static let cache: NSCache<NSNumber, CGImage> = {
        let c = NSCache<NSNumber, CGImage>()
        c.countLimit = 32
        return c
    }()

    /// Produce a `CGImage` for the given palette + configuration at the
    /// requested pixel size. Returns a memoized result when the same
    /// inputs have been rendered recently.
    static func makeCGImage(
        palette: Palette,
        swatches: SwatchMap?,
        configuration: PaletteGraphic.Configuration,
        pixelSize: CGSize
    ) -> CGImage? {
        let cacheKey = NSNumber(
            value: renderKey(palette: palette, swatches: swatches,
                             configuration: configuration, pixelSize: pixelSize)
        )
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let cardPalette = CardPalette(palette: palette, swatches: swatches,
                                      strategy: configuration.swatchStrategy)
        let stopColors = resolveStopColors(
            palette: palette, swatches: swatches,
            cardPalette: cardPalette, count: configuration.colorCount.rawValue
        )
        let extent = CGRect(origin: .zero, size: pixelSize)

        guard let gradient = makeGradient(
            extent: extent, stops: stopColors, configuration: configuration
        ) else { return nil }
        guard let grain = makeGrain(
            extent: extent,
            intensity: configuration.grain.intensity,
            seed: resolvedSeed(palette: palette)
        ) else { return nil }

        let composite = CIFilter.multiplyBlendMode()
        composite.inputImage = grain
        composite.backgroundImage = gradient
        guard let output = composite.outputImage?.cropped(to: extent) else { return nil }

        guard let cg = context.createCGImage(output, from: extent) else { return nil }
        cache.setObject(cg, forKey: cacheKey)
        return cg
    }

    /// Cumulative-bisection color stop resolution. Internal but accessed
    /// directly by tests, hence not `private`.
    static func resolveStopColors(
        palette: Palette,
        swatches: SwatchMap?,
        cardPalette: CardPalette,
        count: Int
    ) -> [PaletteColor] {
        let firstBrighter = cardPalette.center.luminance >= cardPalette.edge.luminance
        let first = firstBrighter ? cardPalette.center : cardPalette.edge
        let last  = firstBrighter ? cardPalette.edge   : cardPalette.center

        if count <= 2 {
            return [first, last]
        }

        var seen = Set<String>()
        var pool: [PaletteColor] = []
        let candidates: [PaletteColor?] = palette.colors.map { Optional($0) } + [
            swatches?.lightVibrant?.color, swatches?.vibrant?.color,
            swatches?.lightMuted?.color, swatches?.muted?.color,
            swatches?.darkMuted?.color, swatches?.darkVibrant?.color
        ]
        for case let .some(color) in candidates where seen.insert(color.hex).inserted {
            pool.append(color)
        }

        let chromaThreshold = min(first.oklch.c, last.oklch.c) * 0.5
        let middlePool = pool
            .filter { $0.hex != first.hex && $0.hex != last.hex }
            .filter { $0.luminance < first.luminance && $0.luminance > last.luminance }
            .filter { $0.oklch.c >= chromaThreshold }
            .sorted { $0.luminance > $1.luminance }

        guard !middlePool.isEmpty else { return [first, last] }

        let needed = count - 2
        let positions = bisectionPositions(count: needed)
        let luminanceSpan = first.luminance - last.luminance

        var pickedHexes = Set<String>()
        var middle: [PaletteColor] = []
        for position in positions {
            let target = first.luminance - luminanceSpan * position
            let candidate = middlePool
                .filter { !pickedHexes.contains($0.hex) }
                .min(by: { abs($0.luminance - target) < abs($1.luminance - target) })
            guard let pick = candidate else { break }
            pickedHexes.insert(pick.hex)
            middle.append(pick)
        }

        middle.sort { $0.luminance > $1.luminance }
        return [first] + middle + [last]
    }

    private static func renderKey(
        palette: Palette,
        swatches: SwatchMap?,
        configuration: PaletteGraphic.Configuration,
        pixelSize: CGSize
    ) -> Int {
        var hasher = Hasher()
        for color in palette.colors { hasher.combine(color.rgb) }
        hasher.combine(swatches?.vibrant?.color.rgb)
        hasher.combine(swatches?.lightVibrant?.color.rgb)
        hasher.combine(swatches?.darkVibrant?.color.rgb)
        hasher.combine(swatches?.muted?.color.rgb)
        hasher.combine(swatches?.lightMuted?.color.rgb)
        hasher.combine(swatches?.darkMuted?.color.rgb)
        hasher.combine(configuration.direction)
        hasher.combine(configuration.linearStart.x)
        hasher.combine(configuration.linearStart.y)
        hasher.combine(configuration.linearEnd.x)
        hasher.combine(configuration.linearEnd.y)
        hasher.combine(configuration.colorCount)
        hasher.combine(configuration.swatchStrategy)
        hasher.combine(configuration.grain)
        hasher.combine(Int(pixelSize.width.rounded()))
        hasher.combine(Int(pixelSize.height.rounded()))
        return hasher.finalize()
    }

    private static func resolvedSeed(palette: Palette) -> UInt32 {
        let rgb = palette.dominant?.rgb ?? .init(r: 0, g: 0, b: 0)
        return (UInt32(rgb.r) << 16) | (UInt32(rgb.g) << 8) | UInt32(rgb.b) | 0xA5A5_0000
    }

    private static func bisectionPositions(count: Int) -> [Double] {
        var positions: [Double] = []
        if count >= 1 { positions.append(0.5) }
        if count >= 2 { positions.append(0.25) }
        if count >= 3 { positions.append(0.75) }
        return positions
    }

    private static func makeGradient(
        extent: CGRect,
        stops: [PaletteColor],
        configuration: PaletteGraphic.Configuration
    ) -> CIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: extent.size, format: format)
        let img = renderer.image { ctx in
            let cg = ctx.cgContext
            let cgColors = stops.map { $0.cgColor } as CFArray
            let locations: [CGFloat] = (0..<stops.count).map {
                stops.count == 1 ? 0 : CGFloat($0) / CGFloat(stops.count - 1)
            }
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: cgColors, locations: locations
            ) else { return }

            switch configuration.direction {
            case .linear:
                let start = CGPoint(
                    x: configuration.linearStart.x * extent.width,
                    y: configuration.linearStart.y * extent.height
                )
                let end = CGPoint(
                    x: configuration.linearEnd.x * extent.width,
                    y: configuration.linearEnd.y * extent.height
                )
                cg.drawLinearGradient(
                    gradient, start: start, end: end,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            case .radial:
                let center = CGPoint(x: extent.width * 0.75, y: extent.height * 0.2)
                cg.drawRadialGradient(
                    gradient,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: max(extent.width, extent.height) * 1.1,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        }
        guard let cgImage = img.cgImage else { return nil }
        return CIImage(cgImage: cgImage)
    }

    private static func makeGrain(
        extent: CGRect, intensity: Double, seed: UInt32
    ) -> CIImage? {
        let random = CIFilter.randomGenerator()
        guard let raw = random.outputImage else { return nil }

        let scaledSeed = UInt64(seed) &* 2654435761
        let offset = CGAffineTransform(
            translationX: CGFloat(scaledSeed & 0xFFFF),
            y: CGFloat((scaledSeed >> 16) & 0xFFFF)
        )
        let shifted = raw.transformed(by: offset).cropped(to: extent)

        let desat = CIFilter.colorMatrix()
        desat.inputImage = shifted
        let weight = CGFloat(intensity)
        desat.rVector = CIVector(x: weight * 0.299, y: weight * 0.587, z: weight * 0.114, w: 0)
        desat.gVector = CIVector(x: weight * 0.299, y: weight * 0.587, z: weight * 0.114, w: 0)
        desat.bVector = CIVector(x: weight * 0.299, y: weight * 0.587, z: weight * 0.114, w: 0)
        desat.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        desat.biasVector = CIVector(x: 1 - weight, y: 1 - weight, z: 1 - weight, w: 0)
        return desat.outputImage?.cropped(to: extent)
    }
}
#endif
