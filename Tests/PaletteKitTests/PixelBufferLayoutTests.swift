import CoreGraphics
import Foundation
import Testing
@testable import PaletteKit

@Suite("Pixel buffer layout contracts")
struct PixelBufferLayoutTests {
    private let colors: [UInt8] = [
        200, 20, 40, 255, 30, 180, 60, 255,
        40, 60, 220, 255, 160, 100, 20, 255,
        80, 120, 160, 255, 60, 40, 100, 255,
    ]

    @Test("padding is not sampled or averaged", arguments: [1, 2, 3, 4])
    func paddedMatchesPacked(stride: Int) throws {
        let packed = buffer(padding: 0)
        let padded = buffer(padding: 8)
        let options = ExtractionOptions(quality: .stride(stride), colorSpace: .sRGB, ignoreWhite: false)
        let expected = Swift.stride(from: 0, to: 6, by: stride).map { index in
            PixelTriplet(r: colors[index * 4], g: colors[index * 4 + 1], b: colors[index * 4 + 2])
        }
        for input in [packed, padded] {
            let sampled = try PixelSampler().sample(buffer: input, options: options)
            #expect(sampled.triplets == expected)
            let average = PaletteBuilder().averageFallback(buffer: input, quality: stride, colorSpaceUsed: .sRGB)
            let color = try #require(average.dominant)
            #expect(color.rgb == RGB(
                r: UInt8(expected.reduce(0) { $0 + Int($1.r) } / expected.count),
                g: UInt8(expected.reduce(0) { $0 + Int($1.g) } / expected.count),
                b: UInt8(expected.reduce(0) { $0 + Int($1.b) } / expected.count)
            ))
            #expect(color.population == expected.count)
            #expect(color.proportion == 1)
            #expect(average.colorSpaceUsed == .sRGB)
        }
    }

    @Test("padding after the final row is optional")
    func finalPaddingOptional() throws {
        let full = buffer(padding: 8)
        let trimmed = PixelBuffer(data: full.data.dropLast(8), width: 2, height: 3,
                                  bytesPerRow: 16, colorSpace: .sRGB)
        let options = ExtractionOptions(quality: .highest, ignoreWhite: false)
        let actual = try PixelSampler().sample(buffer: trimmed, options: options)
        let expected = try PixelSampler().sample(buffer: buffer(padding: 0), options: options)
        #expect(actual.triplets == expected.triplets)
    }

    @Test("malformed layouts fail before unsafe reads")
    func invalidLayouts() {
        let invalid = [
            PixelBuffer(data: Data([1, 2, 3]), width: 1, height: 1, bytesPerRow: 4, colorSpace: .sRGB),
            PixelBuffer(data: Data(repeating: 0, count: 16), width: 2, height: 2, bytesPerRow: 4, colorSpace: .sRGB),
            PixelBuffer(data: Data(), width: -1, height: -1, bytesPerRow: 4, colorSpace: .sRGB),
            PixelBuffer(data: Data(), width: 1, height: 1, bytesPerRow: -1, colorSpace: .sRGB),
            PixelBuffer(data: Data(), width: Int.max, height: 2, bytesPerRow: Int.max, colorSpace: .sRGB),
            PixelBuffer(data: Data(), width: Int.max, height: 1, bytesPerRow: Int.max, colorSpace: .sRGB),
            PixelBuffer(data: Data(), width: 1, height: 3, bytesPerRow: Int.max, colorSpace: .sRGB),
            PixelBuffer(data: Data(), width: 1, height: 2, bytesPerRow: Int.max, colorSpace: .sRGB),
        ]
        for input in invalid {
            #expect(throws: PaletteError.self) {
                try PixelSampler().sample(buffer: input, options: .init())
            }
            #expect(PaletteBuilder().averageFallback(buffer: input, quality: 1, colorSpaceUsed: .sRGB).isEmpty)
        }
        #expect(invalid[2].pixelCount == 0)
        #expect(invalid[4].pixelCount == 0)
    }

    @Test("empty buffers remain empty")
    func emptyLayouts() throws {
        for size in [(0, 0), (0, 2), (2, 0)] {
            let input = PixelBuffer(data: Data(), width: size.0, height: size.1,
                                    bytesPerRow: size.0 * 4, colorSpace: .sRGB)
            #expect(try PixelSampler().sample(buffer: input, options: .init()).triplets.isEmpty)
            #expect(PaletteBuilder().averageFallback(buffer: input, quality: 1, colorSpaceUsed: .sRGB).isEmpty)
        }
    }

    @Test("nonpositive downsample limits return errors", arguments: [0, -1, Int.min])
    func invalidDownsample(limit: Int) async throws {
        let source = ImageSource.cgImage(try image())
        for downsample in [Downsample.automatic(maxPixels: limit), .maxEdge(limit)] {
            let options = ExtractionOptions(downsample: downsample)
            #expect(throws: PaletteError.self) { try PixelLoader().load(source: source, options: options) }
            await #expect(throws: PaletteError.self) {
                try await PaletteExtractor().palette(from: source, options: options)
            }
        }
    }

    @Test("positive limits and disabled downsampling keep a small image unchanged")
    func validDownsample() throws {
        let source = ImageSource.cgImage(try image())
        for mode in [Downsample.disabled, .automatic(maxPixels: 1), .automatic(maxPixels: Int.max), .maxEdge(1), .maxEdge(Int.max)] {
            let input = try PixelLoader().load(source: source, options: .init(downsample: mode))
            #expect(input.width == 2)
            #expect(input.height == 3)
            #expect(input.bytesPerRow == 8)
        }
    }

    private func buffer(padding: Int) -> PixelBuffer {
        var bytes = [UInt8]()
        for row in 0..<3 {
            bytes.append(contentsOf: colors[(row * 8)..<(row * 8 + 8)])
            bytes.append(contentsOf: [UInt8](repeating: 255, count: padding))
        }
        return PixelBuffer(data: Data(bytes), width: 2, height: 3, bytesPerRow: 8 + padding, colorSpace: .sRGB)
    }

    private func image() throws -> CGImage {
        let provider = try #require(CGDataProvider(data: Data(colors) as CFData))
        return try #require(CGImage(width: 2, height: 3, bitsPerComponent: 8, bitsPerPixel: 32,
                                   bytesPerRow: 8, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }
}
