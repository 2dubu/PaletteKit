import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@_spi(SpatialPrototype) @testable import PaletteKit

@Suite("Spatial mesh prototype")
struct SpatialMeshTests {
    static let red: [UInt8] = [255, 0, 0, 255]
    static let green: [UInt8] = [0, 255, 0, 255]
    static let blue: [UInt8] = [0, 0, 255, 255]
    static let yellow: [UInt8] = [255, 255, 0, 255]

    static func image(width: Int = 40, height: Int = 24,
                      pixel: (Int, Int) -> [UInt8]) throws -> CGImage {
        let data = Data((0..<height).flatMap { y in (0..<width).flatMap { pixel($0, y) } })
        return try #require(CGImage(width: width, height: height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: data as CFData)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent))
    }

    @Test("same histogram with swapped positions yields different spatial colors")
    func swappedHalves() async throws {
        let a = try Self.image { x, _ in x < 24 ? Self.red : Self.blue }
        let b = try Self.image { x, _ in x < 16 ? Self.blue : Self.red }
        let options = ExtractionOptions(colorCount: 2, quality: .highest, colorSpace: .sRGB,
                                         ignoreWhite: false, downsample: .disabled, quantizer: .cpu)
        let extractor = PaletteExtractor()
        let pa = try await extractor.palette(from: .cgImage(a), options: options)
        let pb = try await extractor.palette(from: .cgImage(b), options: options)
        #expect(pa.colors.map(\.rgb) == pb.colors.map(\.rgb))
        #expect(pa.colors.map(\.population) == pb.colors.map(\.population))
        for grid in SpatialMesh.Grid.allCases {
            let ma = try SpatialMeshAnalyzer.analyze(.cgImage(a), grid: grid)
            let mb = try SpatialMeshAnalyzer.analyze(.cgImage(b), grid: grid)
            #expect(ma.points == mb.points)
            #expect(ma.colors.first?.rgb == RGB(r: 255, g: 0, b: 0))
            #expect(mb.colors.first?.rgb == RGB(r: 0, g: 0, b: 255))
            #expect(ma.colors.map(\.rgb) == mb.colors.enumerated().map {
                mb.colors[($0.offset / grid.rawValue) * grid.rawValue + grid.rawValue - 1 - $0.offset % grid.rawValue].rgb
            })
        }
    }

    @Test("all eight EXIF orientations preserve displayed corners and aspect", arguments: 1...8)
    func orientations(_ orientation: Int) throws {
        let image = try Self.image { x, y in
            y < 12 ? (x < 20 ? Self.red : Self.green) : (x < 20 ? Self.blue : Self.yellow)
        }
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.tiff.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let mesh = try SpatialMeshAnalyzer.analyze(.data(data as Data))
        let expected = [
            [Self.red, Self.green, Self.blue, Self.yellow],
            [Self.green, Self.red, Self.yellow, Self.blue],
            [Self.yellow, Self.blue, Self.green, Self.red],
            [Self.blue, Self.yellow, Self.red, Self.green],
            [Self.red, Self.blue, Self.green, Self.yellow],
            [Self.blue, Self.red, Self.yellow, Self.green],
            [Self.yellow, Self.green, Self.blue, Self.red],
            [Self.green, Self.yellow, Self.red, Self.blue]
        ][orientation - 1].map { RGB(r: $0[0], g: $0[1], b: $0[2]) }
        #expect([0, 2, 6, 8].map { mesh.colors[$0].rgb } == expected)
        #expect(abs(mesh.aspectRatio - (orientation >= 5 ? 24.0 / 40 : 40.0 / 24)) < 0.0001)
        // Exercise the URL path with a file owned by this test, not a local fixture.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tiff")
        try (data as Data).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let fromURL = try SpatialMeshAnalyzer.analyze(.url(url))
        #expect(fromURL.colors.map(\.rgb) == mesh.colors.map(\.rgb))
    }

    @Test("white background remains; a small accent is diluted rather than promoted")
    func smallAccent() throws {
        let image = try Self.image(width: 100, height: 100) { x, y in
            (5..<15).contains(x) && (5..<15).contains(y) ? Self.red : [255, 255, 255, 255]
        }
        let mesh = try SpatialMeshAnalyzer.analyze(.cgImage(image))
        #expect(mesh.colors[0].rgb.r == 255)
        #expect(mesh.colors[0].rgb.g > 200 && mesh.colors[0].rgb.g < 255)
        #expect(mesh.colors.dropFirst().allSatisfy { $0.rgb == PaletteColor.white.rgb })
    }

    @Test("transparent and premultiplied pixels composite onto white")
    func alpha() throws {
        let image = try Self.image { x, _ in x < 20 ? [128, 0, 0, 128] : [0, 0, 0, 0] }
        let mesh = try SpatialMeshAnalyzer.analyze(.cgImage(image))
        #expect(mesh.colors[0].rgb == RGB(r: 255, g: 127, b: 127))
        #expect(mesh.colors[2].rgb == PaletteColor.white.rgb)
    }

    @Test("bounded thumbnail, fixed points, uniform and one-pixel inputs", arguments: SpatialMesh.Grid.allCases)
    func sizes(_ grid: SpatialMesh.Grid) throws {
        for size in [(1, 1), (1, 300), (1000, 400), (400, 1000)] {
            let input = try Self.image(width: size.0, height: size.1) { _, _ in Self.red }
            let mesh = try SpatialMeshAnalyzer.analyze(.cgImage(input), grid: grid)
            #expect(max(mesh.sampleWidth, mesh.sampleHeight) <= 128)
            #expect(mesh.aspectRatio == Double(size.0) / Double(size.1))
            #expect(mesh.colors.count == grid.rawValue * grid.rawValue)
            #expect(mesh.colors.allSatisfy { $0.rgb == RGB(r: 255, g: 0, b: 0) })
            #expect(mesh.points.first == SIMD2<Float>(0, 0))
            #expect(mesh.points.last == SIMD2<Float>(1, 1))
        }
    }

    @Test("invalid input throws")
    func invalidData() {
        #expect(throws: (any Error).self) { try SpatialMeshAnalyzer.analyze(.data(Data())) }
    }

    @Test("local averages use linear light, not encoded channel means")
    func linearAverage() throws {
        let image = try Self.image { x, _ in x < 20 ? [0, 0, 0, 255] : [255, 255, 255, 255] }
        let mesh = try SpatialMeshAnalyzer.analyze(.cgImage(image))
        #expect(mesh.colors[4].rgb == RGB(r: 188, g: 188, b: 188))
    }

    @Test("tagged Display P3 converts to sRGB rather than relabeling channels")
    func colorSpace() throws {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
        let sourceColor = CGColor(colorSpace: srgb, components: [0.8, 0.4, 0.2, 1])!
        let converted = try #require(sourceColor.converted(to: p3, intent: .relativeColorimetric, options: nil))
        let context = try #require(CGContext(data: nil, width: 40, height: 24,
            bitsPerComponent: 8, bytesPerRow: 160, space: p3,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.setFillColor(converted)
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 24))
        let image = try #require(context.makeImage())
        let mesh = try SpatialMeshAnalyzer.analyze(.cgImage(image))
        for color in mesh.colors {
            #expect(abs(Int(color.rgb.r) - 204) <= 2)
            #expect(abs(Int(color.rgb.g) - 102) <= 2)
            #expect(abs(Int(color.rgb.b) - 51) <= 2)
        }
    }
}

#if canImport(UIKit) && canImport(SwiftUI)
import UIKit
@Suite("Spatial mesh iOS rendering")
struct SpatialMeshRenderingTests {
    @Test("render keeps top-left colors, aspect, and deterministic pixels", arguments: SpatialMesh.Grid.allCases)
    @MainActor @available(iOS 18.0, *)
    func render(_ grid: SpatialMesh.Grid) throws {
        let image = try SpatialMeshTests.image { x, y in
            y < 12 ? (x < 20 ? SpatialMeshTests.red : SpatialMeshTests.green)
                : (x < 20 ? SpatialMeshTests.blue : SpatialMeshTests.yellow)
        }
        let mesh = try SpatialMeshAnalyzer.analyze(.cgImage(image), grid: grid)
        let view = SpatialMeshGraphic(mesh: mesh)
        let rendered = try #require(view.makeImage(width: 200, scale: 1))
        #expect(rendered.size == CGSize(width: 200, height: 120))
        #expect(rendered.pngData() == view.makeImage(width: 200, scale: 1)?.pngData())
        let buffer = try PixelLoader().load(source: .cgImage(try #require(rendered.cgImage)),
                                          options: ExtractionOptions(downsample: .disabled))
        let bytes = [UInt8](buffer.data)
        #expect(bytes[0] > 240 && bytes[1] < 20 && bytes[2] < 20)
        let bottom = (buffer.height - 1) * buffer.bytesPerRow
        #expect(bytes[bottom] < 20 && bytes[bottom + 2] > 240)
        #expect(view.makeImage(width: 0) == nil)
        #expect(view.makeImage(width: .infinity) == nil)
    }
}
#endif
