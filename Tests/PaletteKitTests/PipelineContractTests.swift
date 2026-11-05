import CoreGraphics
import Foundation
import Testing
@testable import PaletteKit

@Suite("Internal pipeline behavior contracts")
struct PipelineContractTests {
    @Test("full decode honors orientation and the opt-out")
    func fullDecodeOrientation() throws {
        let original = try RealFileFixtures.writeTwoSideJPEG(
            left: (200, 30, 30), right: (30, 30, 200), width: 64, height: 48, orientation: 1
        )
        let tagged = try RealFileFixtures.writeTwoSideJPEG(
            left: (200, 30, 30), right: (30, 30, 200), width: 64, height: 48, orientation: 6
        )
        defer {
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.removeItem(at: tagged)
        }
        let loader = PixelLoader()
        let normal = try loader.load(source: .url(original), options: .init(downsample: .disabled))
        let ignored = try loader.load(source: .url(tagged), options: .init(autoOrient: false, downsample: .disabled))
        let rotated = try loader.load(source: .url(tagged), options: .init(autoOrient: true, downsample: .disabled))
        #expect(normal.width == 64 && normal.height == 48)
        #expect(ignored.width == normal.width && ignored.height == normal.height)
        #expect(ignored.data == normal.data)
        #expect(rotated.width == 48 && rotated.height == 64)
        let cornerA = rgb(in: rotated, x: 4, y: 4)
        let cornerB = rgb(in: rotated, x: 4, y: rotated.height - 5)
        #expect((cornerA.r > 150 && cornerA.b < 80 && cornerB.b > 150 && cornerB.r < 80)
                || (cornerA.b > 150 && cornerA.r < 80 && cornerB.r > 150 && cornerB.b < 80))
    }

    @Test("average fallback preserves stride, population, metadata and optional timing", arguments: [false, true])
    func fallbackContracts(collectTimings: Bool) async throws {
        let pixels: [UInt8] = [40, 40, 40, 255, 80, 80, 80, 255, 120, 120, 120, 255, 160, 160, 160, 255]
        let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
        let image = try #require(CGImage(
            width: 4, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 16,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        ))
        let options = ExtractionOptions(quality: .stride(2), colorSpace: .displayP3,
                                        minSaturation: 1, fallbackStrategy: .averageOnly,
                                        downsample: .disabled, collectTimings: collectTimings)
        let palette = try await PaletteExtractor().palette(from: .cgImage(image), options: options)
        let color = try #require(palette.dominant)
        #expect(color.rgb == RGB(r: 80, g: 80, b: 80))
        #expect(color.population == 2)
        #expect(color.proportion == 1)
        #expect(palette.colorSpaceUsed == .displayP3)
        #expect((palette.timings != nil) == collectTimings)
        if let timings = palette.timings {
            #expect(timings.quantize == .zero)
            #expect(timings.quantizerUsed.isEmpty)
            #expect(timings.swatches == nil)
            #expect(timings.total >= timings.decode + timings.sample)
        }
    }

    private func rgb(in buffer: PixelBuffer, x: Int, y: Int) -> RGB {
        let offset = y * buffer.bytesPerRow + x * 4
        return RGB(r: buffer.data[offset], g: buffer.data[offset + 1], b: buffer.data[offset + 2])
    }
}
