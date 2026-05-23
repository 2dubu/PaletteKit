#if canImport(UIKit)
import XCTest
@testable import PaletteKit

@available(iOS 18.0, *)
final class PaletteMeshGraphicBenchmarks: XCTestCase {
    private let palette: Palette = {
        let colors: [PaletteColor] = (0..<32).map { i in
            let r = UInt8((i * 7) & 0xFF)
            let g = UInt8((i * 13) & 0xFF)
            let b = UInt8((i * 23) & 0xFF)
            return PaletteColor(r: r, g: g, b: b)
        }
        return Palette(colors: colors, colorSpaceUsed: .oklch)
    }()

    @MainActor
    func test_bench_makeImage_1080_compact() {
        let view = PaletteMeshGraphic(
            palette: palette,
            configuration: .init(gridSize: .compact)
        )
        measure {
            _ = view.makeImage(size: CGSize(width: 1080, height: 1080))
        }
    }

    @MainActor
    func test_bench_makeImage_1080_standard() {
        let view = PaletteMeshGraphic(palette: palette)
        measure {
            _ = view.makeImage(size: CGSize(width: 1080, height: 1080))
        }
    }

    @MainActor
    func test_bench_makeImage_1080_rich() {
        let view = PaletteMeshGraphic(
            palette: palette,
            configuration: .init(gridSize: .rich)
        )
        measure {
            _ = view.makeImage(size: CGSize(width: 1080, height: 1080))
        }
    }

    func test_bench_resolveColors_standard() {
        measure {
            for _ in 0..<1000 {
                _ = PaletteMeshGraphicResolver.resolveColors(
                    palette: palette, gridSize: .standard
                )
            }
        }
    }

    func test_bench_resolvePoints_rich() {
        measure {
            for _ in 0..<10_000 {
                _ = PaletteMeshGraphicResolver.resolvePoints(
                    gridSize: .rich, paletteSeed: 42
                )
            }
        }
    }
}
#endif
