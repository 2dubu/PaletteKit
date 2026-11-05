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

/// Interleaved 8-bit RGBA pixels, with optional padding between rows.
///
/// `bytesPerRow` must be at least `width * 4`, and data must contain every
/// pixel. Padding after the last row is optional.
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

    /// Number of pixels, or zero for negative or overflowing dimensions.
    public var pixelCount: Int {
        guard width >= 0, height >= 0 else { return 0 }
        let (count, overflow) = width.multipliedReportingOverflow(by: height)
        return overflow ? 0 : count
    }

    func validateRGBA8Layout() throws {
        func invalidLayout() -> PaletteError {
            .decodingFailed(reason: "Invalid RGBA pixel buffer dimensions, row stride, or data length.")
        }
        guard width >= 0, height >= 0, bytesPerRow >= 0 else { throw invalidLayout() }
        let (_, countOverflow) = width.multipliedReportingOverflow(by: height)
        guard !countOverflow else { throw invalidLayout() }
        guard width > 0, height > 0 else { return }
        let (rowBytes, rowOverflow) = width.multipliedReportingOverflow(by: 4)
        guard !rowOverflow, bytesPerRow >= rowBytes else { throw invalidLayout() }
        let (lastRowOffset, offsetOverflow) = (height - 1).multipliedReportingOverflow(by: bytesPerRow)
        guard !offsetOverflow else { throw invalidLayout() }
        let (requiredBytes, lengthOverflow) = lastRowOffset.addingReportingOverflow(rowBytes)
        guard !lengthOverflow, data.count >= requiredBytes else { throw invalidLayout() }
    }

    /// Requires a validated layout and an in-bounds logical pixel index.
    @inline(__always)
    func byteOffset(ofPixel index: Int) -> Int {
        if bytesPerRow == width * 4 { return index * 4 }
        return (index / width) * bytesPerRow + (index % width) * 4
    }
}
