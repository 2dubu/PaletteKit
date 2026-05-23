#if canImport(UIKit)
import Testing
@testable import PaletteKit

@Suite("PaletteMeshGraphicResolver.SplitMix64")
struct PaletteMeshGraphic_SplitMix64Tests {
    @Test("same seed yields identical sequences")
    @available(iOS 18.0, *)
    func deterministic() {
        var a = PaletteMeshGraphicResolver.SplitMix64(seed: 0xDEAD_BEEF)
        var b = PaletteMeshGraphicResolver.SplitMix64(seed: 0xDEAD_BEEF)
        for _ in 0..<8 {
            #expect(a.next() == b.next())
        }
    }

    @Test("different seeds diverge")
    @available(iOS 18.0, *)
    func divergence() {
        var a = PaletteMeshGraphicResolver.SplitMix64(seed: 1)
        var b = PaletteMeshGraphicResolver.SplitMix64(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test("nextDouble returns values in [-1, 1)")
    @available(iOS 18.0, *)
    func doubleRange() {
        var rng = PaletteMeshGraphicResolver.SplitMix64(seed: 42)
        for _ in 0..<64 {
            let v = rng.nextDouble()
            #expect(v >= -1.0)
            #expect(v < 1.0)
        }
    }
}

@Suite("PaletteMeshGraphicResolver.paletteSeed")
struct PaletteMeshGraphic_PaletteSeedTests {
    private let paletteA = Palette(
        colors: [
            PaletteColor(r: 200, g: 80, b: 40),
            PaletteColor(r: 70, g: 50, b: 35)
        ],
        colorSpaceUsed: .oklch
    )

    private let paletteB = Palette(
        colors: [
            PaletteColor(r: 10, g: 200, b: 30),
            PaletteColor(r: 50, g: 60, b: 70)
        ],
        colorSpaceUsed: .oklch
    )

    @Test("same palette yields the same seed across calls")
    @available(iOS 18.0, *)
    func stable() {
        let s1 = PaletteMeshGraphicResolver.paletteSeed(palette: paletteA)
        let s2 = PaletteMeshGraphicResolver.paletteSeed(palette: paletteA)
        #expect(s1 == s2)
    }

    @Test("different palettes produce different seeds")
    @available(iOS 18.0, *)
    func divergence() {
        let s1 = PaletteMeshGraphicResolver.paletteSeed(palette: paletteA)
        let s2 = PaletteMeshGraphicResolver.paletteSeed(palette: paletteB)
        #expect(s1 != s2)
    }

    @Test("empty palette produces a stable, non-trapping seed")
    @available(iOS 18.0, *)
    func empty() {
        let empty = Palette(colors: [], colorSpaceUsed: .oklch)
        let s = PaletteMeshGraphicResolver.paletteSeed(palette: empty)
        // Just exercising the path; any UInt64 is fine as long as we don't crash.
        _ = s
    }
}

@Suite("PaletteMeshGraphicResolver.resolvePoints")
struct PaletteMeshGraphic_ResolvePointsTests {
    @Test("aligned base grid for .compact (2x2): all corners, no jitter")
    @available(iOS 18.0, *)
    func compactCornersOnly() {
        let pts = PaletteMeshGraphicResolver.resolvePoints(
            gridSize: .compact, paletteSeed: 1
        )
        let expected: [SIMD2<Float>] = [[0, 0], [1, 0], [0, 1], [1, 1]]
        for (i, p) in pts.enumerated() {
            #expect(abs(p.x - expected[i].x) < 1e-6)
            #expect(abs(p.y - expected[i].y) < 1e-6)
        }
    }

    @Test("corner points remain fixed (standard)")
    @available(iOS 18.0, *)
    func cornersFixed() {
        let pts = PaletteMeshGraphicResolver.resolvePoints(
            gridSize: .standard, paletteSeed: 0xC0FFEE
        )
        let corners: [(Int, SIMD2<Float>)] = [
            (0, [0, 0]), (2, [1, 0]), (6, [0, 1]), (8, [1, 1])
        ]
        for (idx, expected) in corners {
            #expect(abs(pts[idx].x - expected.x) < 1e-6)
            #expect(abs(pts[idx].y - expected.y) < 1e-6)
        }
    }

    @Test("top/bottom edge points keep y at the frame (standard)")
    @available(iOS 18.0, *)
    func topBottomEdgeAxisLocked() {
        let pts = PaletteMeshGraphicResolver.resolvePoints(
            gridSize: .standard, paletteSeed: 0xC0FFEE
        )
        #expect(abs(pts[1].y - 0) < 1e-6)
        #expect(abs(pts[7].y - 1) < 1e-6)
    }

    @Test("left/right edge points keep x at the frame (standard)")
    @available(iOS 18.0, *)
    func leftRightEdgeAxisLocked() {
        let pts = PaletteMeshGraphicResolver.resolvePoints(
            gridSize: .standard, paletteSeed: 0xC0FFEE
        )
        #expect(abs(pts[3].x - 0) < 1e-6)
        #expect(abs(pts[5].x - 1) < 1e-6)
    }

    @Test("internal points stay within their own cell bounds (rich)")
    @available(iOS 18.0, *)
    func boundedJitter() {
        let pts = PaletteMeshGraphicResolver.resolvePoints(
            gridSize: .rich, paletteSeed: 0x1234_5678
        )
        let n = PaletteMeshGraphic.GridSize.rich.width
        let denom = Float(n - 1)
        let cellSize: Float = 1.0 / denom
        // Same constants as the resolver
        let maxOffset: Float = 0.3 * 0.49 * cellSize
        for row in 1..<(n - 1) {
            for col in 1..<(n - 1) {
                let baseX = Float(col) / denom
                let baseY = Float(row) / denom
                let p = pts[row * n + col]
                #expect(abs(p.x - baseX) <= maxOffset + 1e-6)
                #expect(abs(p.y - baseY) <= maxOffset + 1e-6)
            }
        }
    }

    @Test("same seed yields identical points")
    @available(iOS 18.0, *)
    func deterministic() {
        let a = PaletteMeshGraphicResolver.resolvePoints(
            gridSize: .rich, paletteSeed: 99
        )
        let b = PaletteMeshGraphicResolver.resolvePoints(
            gridSize: .rich, paletteSeed: 99
        )
        #expect(a == b)
    }
}

@Suite("PaletteMeshGraphicResolver.resolveColors")
struct PaletteMeshGraphic_ResolveColorsTests {
    private static func palette(_ rgbWithPop: [(UInt8, UInt8, UInt8, Int)]) -> Palette {
        Palette(
            colors: rgbWithPop.map { PaletteColor(r: $0.0, g: $0.1, b: $0.2, population: $0.3) },
            colorSpaceUsed: .oklch
        )
    }

    @Test("returns exactly gridSize.colorCount colors for each grid size")
    @available(iOS 18.0, *)
    func count() {
        let p = Self.palette([
            (200, 80, 40, 100), (150, 110, 90, 80), (70, 50, 35, 50)
        ])
        for grid in [PaletteMeshGraphic.GridSize.compact, .standard, .rich] {
            let colors = PaletteMeshGraphicResolver.resolveColors(
                palette: p, gridSize: grid
            )
            #expect(colors.count == grid.colorCount)
        }
    }

    @Test("empty palette returns black slots, never crashes")
    @available(iOS 18.0, *)
    func emptyPalette() {
        let p = Palette(colors: [], colorSpaceUsed: .oklch)
        let colors = PaletteMeshGraphicResolver.resolveColors(
            palette: p, gridSize: .standard
        )
        #expect(colors.count == 9)
        #expect(colors.allSatisfy { $0.rgb == RGB(r: 0, g: 0, b: 0) })
    }

    @Test("dominant color claims more slots than minor colors")
    @available(iOS 18.0, *)
    func dominantClaimsMore() {
        // A clearly takes ~80%, B ~15%, C ~5%
        let p = Self.palette([
            (220, 30, 30, 800),
            (30, 220, 30, 150),
            (30, 30, 220, 50),
        ])
        let colors = PaletteMeshGraphicResolver.resolveColors(
            palette: p, gridSize: .standard
        )
        let countA = colors.filter { $0.rgb.r == 220 }.count
        let countB = colors.filter { $0.rgb.g == 220 }.count
        let countC = colors.filter { $0.rgb.b == 220 }.count
        #expect(countA > countB)
        #expect(countB >= countC)
        #expect(countA + countB + countC == 9)
    }

    @Test("a color with negligible population is dropped from the mesh")
    @available(iOS 18.0, *)
    func negligibleColorDropped() {
        // 99 % A, 1 % B in a 9-slot mesh → B should get 0 slots
        // (1% of 9 = 0.09, floor = 0; largest-remainder pass might assign it 0 or 1
        //  depending on other remainders. Use stronger numbers to force the drop.)
        let p = Self.palette([
            (220, 30, 30, 990),   // 99.0%
            (30, 220, 30, 10),    // 1.0%
        ])
        let colors = PaletteMeshGraphicResolver.resolveColors(
            palette: p, gridSize: .standard
        )
        let countB = colors.filter { $0.rgb.g == 220 }.count
        #expect(countB == 0, "expected the 1% color to be dropped, got \(countB) slots")
    }

    @Test("uniform palette (all populations equal) distributes evenly")
    @available(iOS 18.0, *)
    func uniformDistribution() {
        let p = Self.palette([
            (220, 30, 30, 100),
            (30, 220, 30, 100),
            (30, 30, 220, 100),
        ])
        let colors = PaletteMeshGraphicResolver.resolveColors(
            palette: p, gridSize: .standard
        )
        let countA = colors.filter { $0.rgb.r == 220 }.count
        let countB = colors.filter { $0.rgb.g == 220 }.count
        let countC = colors.filter { $0.rgb.b == 220 }.count
        // 9 slots / 3 colors = 3 each
        #expect(countA == 3)
        #expect(countB == 3)
        #expect(countC == 3)
    }

    @Test("zero-population palette falls back to equal distribution from the prefix")
    @available(iOS 18.0, *)
    func zeroPopulationFallback() {
        // No population data — every color is population 0.
        let p = Self.palette([
            (220, 30, 30, 0),
            (30, 220, 30, 0),
            (30, 30, 220, 0),
        ])
        let colors = PaletteMeshGraphicResolver.resolveColors(
            palette: p, gridSize: .standard
        )
        #expect(colors.count == 9)
        // Each of the three palette colors should appear at least once.
        let rgbs = Set(colors.map(\.rgb))
        #expect(rgbs.contains(RGB(r: 220, g: 30, b: 30)))
        #expect(rgbs.contains(RGB(r: 30, g: 220, b: 30)))
        #expect(rgbs.contains(RGB(r: 30, g: 30, b: 220)))
    }

    @Test("rows sorted by OKLCH luminance (top brighter than bottom)")
    @available(iOS 18.0, *)
    func luminanceSortRows() {
        let p = Self.palette([
            (240, 240, 240, 100), (220, 220, 220, 100), (200, 200, 200, 100),
            (160, 160, 160, 100), (120, 120, 120, 100), (100, 100, 100, 100),
            (60, 60, 60, 100),    (40, 40, 40, 100),    (20, 20, 20, 100),
        ])
        let colors = PaletteMeshGraphicResolver.resolveColors(
            palette: p, gridSize: .standard
        )
        func rowAvgL(_ row: Int) -> Double {
            let n = 3
            return (0..<n).map { colors[row * n + $0].oklch.l }.reduce(0, +) / Double(n)
        }
        #expect(rowAvgL(0) >= rowAvgL(1))
        #expect(rowAvgL(1) >= rowAvgL(2))
    }

    @Test("within a row, chroma increases left to right")
    @available(iOS 18.0, *)
    func chromaSortColumns() {
        let p = Self.palette([
            (200, 200, 200, 100),
            (255, 100, 100, 100),
            (100, 255, 100, 100),
            (160, 160, 160, 100),
            (255, 50, 50, 100),
            (50, 255, 50, 100),
            (100, 100, 100, 100),
            (200, 0, 0, 100),
            (0, 200, 0, 100),
        ])
        let colors = PaletteMeshGraphicResolver.resolveColors(
            palette: p, gridSize: .standard
        )
        let n = 3
        for row in 0..<n {
            let rowColors = (0..<n).map { colors[row * n + $0] }
            for i in 1..<rowColors.count {
                #expect(rowColors[i].oklch.c >= rowColors[i - 1].oklch.c,
                        "chroma not non-decreasing at row \(row), col \(i)")
            }
        }
    }
}
#endif
