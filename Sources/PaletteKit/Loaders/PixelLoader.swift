import CoreGraphics
import Foundation
import ImageIO

public struct PixelLoader: Sendable {
    public init() {}

    public func load(
        source: ImageSource,
        options: ExtractionOptions
    ) throws -> PixelBuffer {
        let cgImage = try resolveCGImage(from: source, options: options)
        try Task.checkCancellation()
        return try rasterize(cgImage: cgImage, options: options)
    }

    private func resolveCGImage(
        from source: ImageSource,
        options: ExtractionOptions
    ) throws -> CGImage {
        switch source {
        case .cgImage(let cgImage):
            return try maybeDownsample(cgImage: cgImage, options: options)
        case .data(let data):
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw PaletteError.decodingFailed(reason: "CGImageSource could not read Data.")
            }
            return try decode(imageSource: imageSource, options: options)
        case .url(let url):
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                throw PaletteError.decodingFailed(reason: "CGImageSource could not read URL: \(url.path).")
            }
            return try decode(imageSource: imageSource, options: options)
        }
    }

    private func decode(
        imageSource: CGImageSource,
        options: ExtractionOptions
    ) throws -> CGImage {
        guard CGImageSourceGetCount(imageSource) > 0 else {
            throw PaletteError.imageEmpty
        }
        let orientation = options.autoOrient
            ? (imageOrientation(in: imageSource) ?? .up)
            : .up

        if let targetPixels = thumbnailTargetPixels(options: options) {
            let opts: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: targetPixels,
                kCGImageSourceCreateThumbnailWithTransform: options.autoOrient,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, opts as CFDictionary) {
                return cgImage
            }
        }

        guard let raw = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw PaletteError.decodingFailed(reason: "CGImageSource could not decode image.")
        }
        return try applyOrientation(orientation, to: raw, respect: options.autoOrient)
    }

    private func thumbnailTargetPixels(options: ExtractionOptions) -> Int? {
        switch options.downsample {
        case .disabled:
            return nil
        case .automatic(let maxPixels):
            let edge = Int(Double(maxPixels).squareRoot().rounded())
            return max(edge, 64)
        case .maxEdge(let edge):
            return max(edge, 64)
        }
    }

    private func maybeDownsample(
        cgImage: CGImage,
        options: ExtractionOptions
    ) throws -> CGImage {
        guard let targetEdge = thumbnailTargetPixels(options: options) else { return cgImage }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { throw PaletteError.imageEmpty }
        let longestEdge = max(width, height)
        guard longestEdge > targetEdge else { return cgImage }

        let scale = Double(targetEdge) / Double(longestEdge)
        let newWidth = max(1, Int((Double(width) * scale).rounded()))
        let newHeight = max(1, Int((Double(height) * scale).rounded()))

        guard
            let colorSpace = cgImage.colorSpace,
            let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: newWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return cgImage
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage() ?? cgImage
    }

    private func rasterize(
        cgImage: CGImage,
        options _: ExtractionOptions
    ) throws -> PixelBuffer {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { throw PaletteError.imageEmpty }

        let detectedSpace: ColorSpace = {
            guard let cs = cgImage.colorSpace else { return .sRGB }
            if let name = cs.name {
                let named = name as String
                if named.contains("P3") { return .displayP3 }
                if named.contains("sRGB") { return .sRGB }
            }
            return .sRGB
        }()

        let bytesPerRow = width * 4
        let total = bytesPerRow * height
        var buffer = Data(count: total)

        let targetColorSpace = detectedSpace == .displayP3
            ? CGColorSpace(name: CGColorSpace.displayP3)!
            : CGColorSpace(name: CGColorSpace.sRGB)!

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        let success = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            guard let context = CGContext(
                data: base,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: targetColorSpace,
                bitmapInfo: bitmapInfo
            ) else {
                return false
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard success else {
            throw PaletteError.decodingFailed(reason: "Could not rasterize into an 8-bit RGBA context.")
        }

        return PixelBuffer(
            data: buffer,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            colorSpace: detectedSpace
        )
    }

    private func imageOrientation(in imageSource: CGImageSource) -> CGImagePropertyOrientation? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let raw = properties[kCGImagePropertyOrientation] as? UInt32 else { return nil }
        return CGImagePropertyOrientation(rawValue: raw)
    }

    private func applyOrientation(
        _ orientation: CGImagePropertyOrientation,
        to cgImage: CGImage,
        respect: Bool
    ) throws -> CGImage {
        guard respect, orientation != .up else { return cgImage }
        let width = cgImage.width
        let height = cgImage.height
        let rotated: (Int, Int) = {
            switch orientation {
            case .left, .leftMirrored, .right, .rightMirrored:
                return (height, width)
            default:
                return (width, height)
            }
        }()
        guard
            let colorSpace = cgImage.colorSpace,
            let context = CGContext(
                data: nil,
                width: rotated.0,
                height: rotated.1,
                bitsPerComponent: 8,
                bytesPerRow: rotated.0 * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return cgImage
        }

        context.concatenate(transform(for: orientation, size: CGSize(width: rotated.0, height: rotated.1)))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? cgImage
    }

    private func transform(
        for orientation: CGImagePropertyOrientation,
        size: CGSize
    ) -> CGAffineTransform {
        switch orientation {
        case .up:
            return .identity
        case .upMirrored:
            return CGAffineTransform(translationX: size.width, y: 0).scaledBy(x: -1, y: 1)
        case .down:
            return CGAffineTransform(translationX: size.width, y: size.height).rotated(by: .pi)
        case .downMirrored:
            return CGAffineTransform(translationX: 0, y: size.height).scaledBy(x: 1, y: -1)
        case .left:
            return CGAffineTransform(translationX: 0, y: size.height).rotated(by: -.pi / 2)
        case .leftMirrored:
            return CGAffineTransform(translationX: size.width, y: size.height)
                .scaledBy(x: -1, y: 1)
                .rotated(by: -.pi / 2)
        case .right:
            return CGAffineTransform(translationX: size.width, y: 0).rotated(by: .pi / 2)
        case .rightMirrored:
            return CGAffineTransform(scaleX: -1, y: 1)
                .rotated(by: .pi / 2)
        }
    }
}
