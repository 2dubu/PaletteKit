import SwiftUI
import UIKit
import CoreGraphics
// Debug-only research harness: inspect the unmodified baseline resolver.
@_spi(SpatialPrototype) @testable import PaletteKit

@main
struct ComparisonApp: App {
    @State private var sheets: [URL] = []
    @State private var message = "Rendering on this iOS Simulator…"
    var body: some Scene {
        WindowGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Spatial mesh comparison").font(.title2.bold())
                    Text(message).font(.caption)
                    ForEach(sheets, id: \.self) { url in
                        if let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image).resizable().scaledToFit()
                        }
                    }
                }.padding()
            }.task {
                do {
                    sheets = try await Comparison.run()
                    message = "Exported \(sheets.count) comparisons. Original / palette / spatial."
                } catch { message = String(describing: error) }
            }
        }
    }
}

@MainActor
enum Comparison {
    static let outputWidth = 384.0
    static let red: [UInt8] = [255, 0, 0, 255]
    static let blue: [UInt8] = [0, 0, 255, 255]
    static let white: [UInt8] = [255, 255, 255, 255]

    static func fixture(_ pixel: (Int, Int) -> [UInt8]) -> CGImage {
        let width = 320, height = 200
        let data = Data((0..<height).flatMap { y in (0..<width).flatMap { pixel($0, y) } })
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: data as CFData)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent)!
    }

    static func run() async throws -> [URL] {
        let documents = URL.documentsDirectory
        let folder = documents.appendingPathComponent("SpatialComparison", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var inputs: [(String, ImageSource, UIImage)] = []
        let fixtures: [(String, CGImage)] = [
            ("01-red-left", fixture { x, _ in x < 192 ? red : blue }),
            ("02-red-right", fixture { x, _ in x < 128 ? blue : red }),
            ("03-small-accent", fixture { x, y in
                (16..<48).contains(x) && (10..<30).contains(y) ? red : white
            }),
            ("04-quadrants", fixture { x, y in
                y < 100 ? (x < 160 ? red : [0, 255, 0, 255])
                    : (x < 160 ? blue : [255, 255, 0, 255])
            })
        ]
        for (name, image) in fixtures { inputs.append((name, .cgImage(image), UIImage(cgImage: image))) }
        // Optional, explicitly supplied local input; never bundled or uploaded.
        let photo = documents.appendingPathComponent("input.jpg")
        if FileManager.default.fileExists(atPath: photo.path) {
            let data = try Data(contentsOf: photo)
            guard let image = UIImage(data: data) else { throw HarnessError.image }
            inputs.append(("05-user-image", .data(data), image))
        }
        var rows: [[String: Any]] = []
        var sheets: [URL] = []
        for (name, source, original) in inputs {
            let normalized = try SpatialMeshAnalyzer.normalizedImage(source)
            let options = ExtractionOptions(colorCount: 10, quality: .highest, colorSpace: .oklch,
                ignoreWhite: false, downsample: .disabled, quantizer: .cpu)
            let palette = try await PaletteExtractor().palette(from: .cgImage(normalized.image), options: options)
            for grid in SpatialMesh.Grid.allCases {
                let mesh = try SpatialMeshAnalyzer.analyze(source, grid: grid)
                let legacyGrid: PaletteMeshGraphic.GridSize = grid == .three ? .standard : .rich
                let size = CGSize(width: outputWidth, height: (outputWidth / mesh.aspectRatio).rounded())
                guard let legacy = PaletteMeshGraphic(palette: palette, configuration: .init(gridSize: legacyGrid))
                    .makeImage(size: size, scale: 1) else { throw HarnessError.image }
                // Equal frame sizes, points and default MeshGradient interpolation.
                let spatialRenderer = ImageRenderer(content: SpatialMeshGraphic(mesh: mesh)
                    .frame(width: size.width, height: size.height))
                spatialRenderer.scale = 1
                guard let spatial = spatialRenderer.uiImage else { throw HarnessError.image }
                let colors = PaletteMeshGraphicResolver.resolveColors(palette: palette, gridSize: legacyGrid)
                let fixedRenderer = ImageRenderer(content:
                    MeshGradient(width: grid.rawValue, height: grid.rawValue,
                        points: mesh.points, colors: colors.map { Color(UIColor($0)) })
                        .frame(width: size.width, height: size.height))
                fixedRenderer.scale = 1
                guard let fixed = fixedRenderer.uiImage else { throw HarnessError.image }
                let reference = renderOriginal(original, size: size)
                let prefix = "\(name)-\(grid.rawValue)x\(grid.rawValue)"
                for (suffix, image) in [("original", reference), ("legacy", legacy),
                                        ("spatial", spatial), ("legacy-fixed", fixed)] {
                    try image.pngData()!.write(to: folder.appendingPathComponent("\(prefix)-\(suffix).png"))
                }
                let sheet = triptych(name: prefix, images: [reference, legacy, spatial], size: size)
                let sheetURL = folder.appendingPathComponent("\(prefix)-comparison.png")
                try sheet.pngData()!.write(to: sheetURL)
                sheets.append(sheetURL)
                let target = try pixels(normalized.image)
                var row: [String: Any] = [
                    "case": name, "grid": grid.rawValue,
                    "outputPixels": [legacy.cgImage!.width, legacy.cgImage!.height],
                    "samplePixels": [normalized.image.width, normalized.image.height],
                    "aspectRatio": mesh.aspectRatio,
                    "palette": palette.colors.map { ["hex": $0.hex, "population": $0.population] },
                    "legacyColors": colors.map(\.hex), "spatialColors": mesh.colors.map(\.hex),
                    "legacyPoints": PaletteMeshGraphicResolver.resolvePoints(gridSize: legacyGrid,
                        paletteSeed: PaletteMeshGraphicResolver.paletteSeed(palette: palette)).map { [$0.x, $0.y] },
                    "spatialPoints": mesh.points.map { [$0.x, $0.y] }
                ]
                for (key, image) in [("legacy", legacy), ("spatial", spatial), ("legacyFixed", fixed)] {
                    let sampled = try resample(image.cgImage!, matching: normalized.image)
                    let actual = try pixels(sampled)
                    guard actual.count == target.count else { throw HarnessError.dimensions }
                    row[key + "MeanOKLabDistance"] = zip(actual, target).map { distance($0, $1) }.reduce(0, +) / Double(target.count)
                    if name == "03-small-accent" {
                        row[key + "Accent"] = accent(actual, width: sampled.width, height: sampled.height)
                    }
                }
                if name == "03-small-accent" {
                    row["referenceAccent"] = accent(target, width: normalized.image.width, height: normalized.image.height)
                }
                rows.append(row)
            }
        }
        let manifest: [String: Any] = [
            "environment": UIDevice.current.systemName + " " + UIDevice.current.systemVersion,
            "reference": "EXIF-oriented, aspect-preserving max-edge 128, opaque sRGB on white; no crop",
            "metric": "mean Euclidean OKLab distance at matching thumbnail pixels; no preference or speed claim",
            "accentRule": "OKLab distance to sRGB #ff0000 < 0.12; pixel centers normalized; null centroid means absent",
            "baseline": "Unmodified palette resolver; CPU OKLCH K=10, stride 1, ignoreWhite=false, no further downsample. legacyFixed uses same colors with spatial fixed points.",
            "rows": rows
        ]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("metrics.json"))
        return sheets
    }

    static func renderOriginal(_ image: UIImage, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    static func triptych(name: String, images: [UIImage], size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let gap = 16.0, margin = 20.0, header = 68.0
        let canvas = CGSize(width: size.width * 3 + gap * 2 + margin * 2, height: size.height + header + margin)
        return UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: canvas))
            (name as NSString).draw(at: CGPoint(x: margin, y: 10), withAttributes: [
                .font: UIFont.systemFont(ofSize: 19, weight: .semibold), .foregroundColor: UIColor.black])
            for i in 0..<3 {
                let x = margin + Double(i) * (size.width + gap)
                (["Original", "Palette mesh (existing)", "Spatial mesh (prototype)"][i] as NSString)
                    .draw(at: CGPoint(x: x, y: 40), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 16), .foregroundColor: UIColor.darkGray])
                images[i].draw(in: CGRect(x: x, y: header, width: size.width, height: size.height))
            }
        }
    }

    static func pixels(_ image: CGImage) throws -> [SIMD3<Double>] {
        let buffer = try PixelLoader().load(source: .cgImage(image), options: ExtractionOptions(downsample: .disabled))
        let data = [UInt8](buffer.data)
        return (0..<buffer.height).flatMap { y in
            (0..<buffer.width).map { x in
                let i = y * buffer.bytesPerRow + x * 4
                let lch = OKLCHConversion.rgbToOKLCH(RGB(r: data[i], g: data[i + 1], b: data[i + 2]))
                let angle = lch.h * .pi / 180
                return SIMD3(lch.l, lch.c * cos(angle), lch.c * sin(angle))
            }
        }
    }

    /// Metrics must use the reference's exact raster, even when its edge is
    /// smaller than 128. Independently applying a maximum edge would enlarge
    /// only the rendered side of a small-input comparison.
    static func resample(_ image: CGImage, matching reference: CGImage) throws -> CGImage {
        let width = reference.width, height = reference.height
        guard let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        else { throw HarnessError.image }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
        guard let sampled = context.makeImage() else { throw HarnessError.image }
        return sampled
    }

    static func distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let d = a - b; return sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
    }

    static func accent(_ pixels: [SIMD3<Double>], width: Int, height: Int) -> [String: Any] {
        let red = OKLCHConversion.rgbToOKLCH(RGB(r: 255, g: 0, b: 0))
        let target = SIMD3(red.l, red.c * cos(red.h * .pi / 180), red.c * sin(red.h * .pi / 180))
        let indices = pixels.indices.filter { distance(pixels[$0], target) < 0.12 }
        let center: Any = indices.isEmpty ? NSNull() : [
            indices.map { (Double($0 % width) + 0.5) / Double(width) }.reduce(0, +) / Double(indices.count),
            indices.map { (Double($0 / width) + 0.5) / Double(height) }.reduce(0, +) / Double(indices.count)
        ]
        return ["areaFraction": Double(indices.count) / Double(pixels.count), "centroid": center]
    }
    enum HarnessError: Error { case image, dimensions }
}
