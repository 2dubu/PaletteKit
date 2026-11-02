import CoreGraphics
import Foundation
import ImageIO

/// Experimental fixed grid. Coordinates are row-major, top-left (0,0) to
/// bottom-right (1,1). Colors are opaque sRGB; no UIKit state is retained.
@_spi(SpatialPrototype)
public struct SpatialMesh: Sendable {
    public enum Grid: Int, Sendable, CaseIterable {
        case three = 3
        case four = 4
    }

    public let grid: Grid
    public let colors: [PaletteColor]
    /// Display-oriented source ratio, before thumbnail rounding.
    public let aspectRatio: Double
    public let sampleWidth: Int
    public let sampleHeight: Int

    public var points: [SIMD2<Float>] {
        let n = grid.rawValue
        return (0..<(n * n)).map {
            SIMD2(Float($0 % n) / Float(n - 1), Float($0 / n) / Float(n - 1))
        }
    }
}

/// Opt-in prototype, deliberately separate from palette extraction and its
/// ignoreWhite / quantization policies. Synchronous CPU work: call off the UI
/// actor for large inputs. Data/URL honor EXIF; CGImage must already be oriented.
@_spi(SpatialPrototype)
public enum SpatialMeshAnalyzer {
    public static func analyze(
        _ source: ImageSource, grid: SpatialMesh.Grid = .three
    ) throws -> SpatialMesh {
        let input = try normalizedImage(source)
        let image = input.image
        let w = image.width, h = image.height, n = grid.rawValue
        let bytes = try rgba(image)
        let radius = 0.5 / Double(n - 1)
        var colors: [PaletteColor] = []
        for row in 0..<n {
            try Task.checkCancellation()
            for col in 0..<n {
                let x = Double(col) / Double(n - 1)
                let y = Double(row) / Double(n - 1)
                // Clipped Voronoi boxes centered on the fixed grid points.
                // Include white margins; tiny dimensions reuse a pixel if a
                // box would otherwise be empty.
                let xs = sampleRange(center: x, radius: radius, count: w)
                let ys = sampleRange(center: y, radius: radius, count: h)
                var sum = SIMD3<Double>(repeating: 0)
                for py in ys {
                    for px in xs {
                        let i = py * image.bytesPerRow + px * 4
                        sum += SIMD3(
                            OKLCHConversion.srgbToLinear(bytes[i]),
                            OKLCHConversion.srgbToLinear(bytes[i + 1]),
                            OKLCHConversion.srgbToLinear(bytes[i + 2])
                        )
                    }
                }
                let mean = sum / Double(xs.count * ys.count)
                colors.append(PaletteColor(
                    r: OKLCHConversion.linearToSRGB(mean.x),
                    g: OKLCHConversion.linearToSRGB(mean.y),
                    b: OKLCHConversion.linearToSRGB(mean.z)
                ))
            }
        }
        return SpatialMesh(grid: grid, colors: colors, aspectRatio: input.aspectRatio,
                           sampleWidth: w, sampleHeight: h)
    }

    /// Shared experimental input contract, also used by the comparison harness
    /// to feed exactly the same pixels into the palette baseline.
    public static func normalizedImage(_ source: ImageSource) throws -> (image: CGImage, aspectRatio: Double) {
        try Task.checkCancellation()
        let raw: CGImage
        let aspect: Double
        switch source {
        case .cgImage(let image):
            raw = image
            aspect = Double(image.width) / Double(image.height)
        case .data, .url:
            let decoder: CGImageSource?
            switch source {
            case .data(let data): decoder = CGImageSourceCreateWithData(data as CFData, nil)
            case .url(let url): decoder = CGImageSourceCreateWithURL(url as CFURL, nil)
            default: decoder = nil
            }
            guard let decoder else { throw PaletteError.decodingFailed(reason: "Cannot read spatial image.") }
            let properties = CGImageSourceCopyPropertiesAtIndex(decoder, 0, nil) as? [CFString: Any]
            let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue
            let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue
            let orientation = (properties?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 128,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(decoder, 0, options as CFDictionary)
            else { throw PaletteError.decodingFailed(reason: "Cannot orient spatial thumbnail.") }
            raw = thumbnail
            if let width, let height, width > 0, height > 0 {
                aspect = (5...8).contains(orientation) ? height / width : width / height
            } else {
                aspect = Double(raw.width) / Double(raw.height)
            }
        }
        let scale = min(1, 128.0 / Double(max(raw.width, raw.height)))
        let w = max(1, Int((Double(raw.width) * scale).rounded()))
        let h = max(1, Int((Double(raw.height) * scale).rounded()))
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                        | CGBitmapInfo.byteOrder32Big.rawValue)
        else { throw PaletteError.decodingFailed(reason: "Cannot allocate spatial thumbnail.") }
        // Explicit white compositing avoids treating premultiplied channels as
        // opaque colors. This policy applies only to this experimental path.
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        context.interpolationQuality = .high
        context.draw(raw, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let image = context.makeImage() else { throw PaletteError.imageEmpty }
        return (image, aspect)
    }

    private static func sampleRange(center: Double, radius: Double, count: Int) -> Range<Int> {
        // Pixel centers are (i + 0.5) / count; right boundaries are exclusive.
        let start = min(count - 1, max(0, Int(ceil((center - radius) * Double(count) - 0.5))))
        let end = max(start + 1, min(count, Int(ceil((center + radius) * Double(count) - 0.5))))
        return start..<end
    }

    private static func rgba(_ image: CGImage) throws -> [UInt8] {
        guard let data = image.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else {
            throw PaletteError.imageEmpty
        }
        // normalizedImage creates RGBA8 in top-to-bottom row order.
        return Array(UnsafeBufferPointer(start: ptr, count: image.height * image.bytesPerRow))
    }
}
