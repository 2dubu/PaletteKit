import CoreGraphics
import Foundation

public enum ImageSource: Sendable {
    case cgImage(CGImage)
    case data(Data)
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
