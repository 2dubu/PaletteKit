import CoreGraphics
import Foundation

/// Synthesizes a deterministic photo-ish CGImage at the requested square
/// size: smooth color gradient + low-frequency noise + a few colored
/// blobs. The point is to give the quantizer a wide tonal distribution
/// rather than the trivial 2-axis ramp the unit-test fixture uses, so
/// MMCQ has real work to do.
enum BenchFixture {
    static func makePhotoLike(side: Int) -> CGImage {
        precondition(side > 0)
        let bytesPerRow = side * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * side)

        let blobs: [(cx: Double, cy: Double, r: Double, color: (Double, Double, Double))] = [
            (0.25, 0.25, 0.18, (0.92, 0.30, 0.25)),
            (0.75, 0.30, 0.22, (0.20, 0.55, 0.85)),
            (0.50, 0.70, 0.28, (0.90, 0.78, 0.20)),
            (0.20, 0.80, 0.16, (0.15, 0.70, 0.40)),
            (0.85, 0.85, 0.14, (0.55, 0.25, 0.70)),
        ]

        let dimension = Double(side)
        for row in 0..<side {
            for col in 0..<side {
                let u = Double(col) / dimension
                let v = Double(row) / dimension

                var red = 0.30 + 0.55 * u
                var green = 0.40 + 0.45 * v
                var blue = 0.50 + 0.40 * (1.0 - u)

                for blob in blobs {
                    let dx = u - blob.cx
                    let dy = v - blob.cy
                    let d = (dx * dx + dy * dy).squareRoot()
                    let weight = max(0, 1 - d / blob.r)
                    let w2 = weight * weight
                    red = red * (1 - w2) + blob.color.0 * w2
                    green = green * (1 - w2) + blob.color.1 * w2
                    blue = blue * (1 - w2) + blob.color.2 * w2
                }

                let noise = pseudoNoise(col, row)
                red = clamp01(red + noise * 0.06)
                green = clamp01(green + noise * 0.06)
                blue = clamp01(blue + noise * 0.06)

                let offset = row * bytesPerRow + col * 4
                pixels[offset] = UInt8(red * 255)
                pixels[offset + 1] = UInt8(green * 255)
                pixels[offset + 2] = UInt8(blue * 255)
                pixels[offset + 3] = 255
            }
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: side,
            height: side,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    @inline(__always)
    private static func pseudoNoise(_ x: Int, _ y: Int) -> Double {
        // Cheap deterministic hash to a [-1, 1] value. Not cryptographic,
        // not Perlin — only meant to break up flat banding so each pixel
        // sees a slightly different RGB value, which keeps the histogram
        // populated with realistic spread.
        var h = UInt64(bitPattern: Int64(x &* 374761393 + y &* 668265263))
        h ^= h >> 13
        h = h &* 1274126177
        h ^= h >> 16
        let normalized = Double(h & 0xFFFF) / 65535.0
        return normalized * 2 - 1
    }

    @inline(__always)
    private static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    /// Center-crops `source` to a square and rescales to `side × side`.
    /// Used when the bench source is a real photo: the bench grid is
    /// driven by side length, so all photos go through the same
    /// "square at size N" normalization regardless of original aspect.
    /// sRGB / premultipliedLast to match the synthesized fixture so
    /// quantize work is apples-to-apples across source kinds.
    static func resizeToSquare(_ source: CGImage, side: Int) -> CGImage {
        precondition(side > 0)
        let srcW = source.width
        let srcH = source.height
        let cropEdge = min(srcW, srcH)
        let cropX = (srcW - cropEdge) / 2
        let cropY = (srcH - cropEdge) / 2

        let cropped = source.cropping(
            to: CGRect(x: cropX, y: cropY, width: cropEdge, height: cropEdge)
        ) ?? source

        let bytesPerRow = side * 4
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return cropped
        }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: side, height: side))
        return context.makeImage() ?? cropped
    }
}
