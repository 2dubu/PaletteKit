import CoreGraphics
import Foundation

/// The image input consumed by ``PaletteExtractor``.
///
/// Use ``cgImage(_:)`` for an image that is already decoded, ``data(_:)`` for
/// encoded bytes, and ``url(_:)`` for an image file on disk. PaletteKit does
/// not perform HTTP networking; download a remote image with your networking
/// layer and pass the resulting `Data`.
public enum ImageSource: Sendable {
    /// An image that is already decoded as a Core Graphics image.
    case cgImage(CGImage)

    /// Encoded image bytes that ImageIO can decode.
    case data(Data)

    /// The URL of an image file that ImageIO can read.
    case url(URL)
}

public struct PixelBuffer: Sendable {
    public let data: Data
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let colorSpace: ColorSpace

    public init(data: Data, width: Int, height: Int, bytesPerRow: Int, colorSpace: ColorSpace) {
        self.data = data
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.colorSpace = colorSpace
    }

    public var pixelCount: Int { width * height }
}
