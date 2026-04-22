import Foundation

public enum PaletteError: Error, Sendable, Equatable {
    case decodingFailed(reason: String)
    case imageEmpty
    case allPixelsFiltered
    case cancelled
    case unsupportedSource(description: String)
    case metalUnavailable
}

extension PaletteError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .decodingFailed(let reason):
            return "Failed to decode image: \(reason)"
        case .imageEmpty:
            return "Image has no pixels to sample."
        case .allPixelsFiltered:
            return "All pixels were removed by filters (ignoreWhite, alpha, minSaturation)."
        case .cancelled:
            return "Extraction was cancelled."
        case .unsupportedSource(let description):
            return "Unsupported image source: \(description)"
        case .metalUnavailable:
            return "Metal quantizer was requested but no GPU is available on this device."
        }
    }
}
