#if canImport(UIKit)
import Foundation
import simd

@available(iOS 18.0, *)
internal enum PaletteMeshGraphicResolver {
    /// Deterministic, seedable PRNG used for anchor jitter so that the
    /// same palette + configuration always produces the same mesh.
    /// Algorithm: SplitMix64 (Vigna). Internal — not part of the API.
    internal struct SplitMix64 {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z &>> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z &>> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z &>> 31)
        }

        /// Uniform value in `[-1.0, 1.0)`. Useful for symmetric jitter.
        mutating func nextDouble() -> Double {
            let raw = next() >> 11               // 53 bits
            let unit = Double(raw) / Double(1 << 53)   // [0, 1)
            return unit * 2.0 - 1.0
        }
    }

    /// Stable `UInt64` derived from the palette's color sequence. Used as a
    /// `SplitMix64` seed so the same palette produces the same jitter pattern
    /// across renders.
    static func paletteSeed(palette: Palette) -> UInt64 {
        var hasher = Hasher()
        for color in palette.colors {
            hasher.combine(color.rgb)
        }
        return UInt64(bitPattern: Int64(hasher.finalize()))
    }

    /// Returns mesh control points in row-major order
    /// (row 0 = top, x increasing left→right).
    ///
    /// Corner points stay fixed so the mesh always covers the frame;
    /// top/bottom edge points receive small X-axis jitter, left/right edge
    /// points receive Y-axis jitter, and internal points jitter on both
    /// axes. The jitter amount is fixed (~0.3 × cellSize × 0.49) — a soft
    /// organic feel without exposing a knob. `compact` (2×2) has corners
    /// only, so jitter is a no-op there.
    static func resolvePoints(
        gridSize: PaletteMeshGraphic.GridSize,
        paletteSeed: UInt64
    ) -> [SIMD2<Float>] {
        let n = gridSize.width
        let denom = Float(max(n - 1, 1))
        // Fixed organic amount. 0.49 is the cell-boundary safety factor;
        // 0.3 is the scaled portion of it.
        let cellSize: Float = denom > 0 ? 1.0 / denom : 0
        let maxOffset = Float(0.3) * 0.49 * cellSize

        var rng = SplitMix64(seed: paletteSeed)
        var pts: [SIMD2<Float>] = []
        pts.reserveCapacity(gridSize.colorCount)

        for row in 0..<n {
            for col in 0..<n {
                let baseX = Float(col) / denom
                let baseY = Float(row) / denom
                let isLeftRightEdge = (col == 0 || col == n - 1)
                let isTopBottomEdge = (row == 0 || row == n - 1)
                let isCorner = isLeftRightEdge && isTopBottomEdge

                if isCorner || maxOffset == 0 {
                    pts.append(SIMD2<Float>(baseX, baseY))
                } else if isTopBottomEdge {
                    let dx = Float(rng.nextDouble()) * maxOffset
                    pts.append(SIMD2<Float>(baseX + dx, baseY))
                } else if isLeftRightEdge {
                    let dy = Float(rng.nextDouble()) * maxOffset
                    pts.append(SIMD2<Float>(baseX, baseY + dy))
                } else {
                    let dx = Float(rng.nextDouble()) * maxOffset
                    let dy = Float(rng.nextDouble()) * maxOffset
                    pts.append(SIMD2<Float>(baseX + dx, baseY + dy))
                }
            }
        }
        return pts
    }

    /// Returns exactly `gridSize.colorCount` colors in row-major order to
    /// match ``resolvePoints``.
    ///
    /// Slots are allocated **proportional to each color's
    /// ``PaletteColor/population``** so the mesh inherits the source photo's
    /// dominance distribution. Colors with insufficient weight to claim a
    /// slot are dropped — they would not be visually present in the photo
    /// either. The chosen colors are then OKLCH-sorted onto the grid so
    /// lighter colors read toward the top, more saturated colors toward the
    /// right.
    static func resolveColors(
        palette: Palette,
        gridSize: PaletteMeshGraphic.GridSize
    ) -> [PaletteColor] {
        let slotCount = gridSize.colorCount

        // 1. Empty palette → all slots clear/black.
        guard !palette.colors.isEmpty else {
            return Array(repeating: PaletteColor(r: 0, g: 0, b: 0), count: slotCount)
        }

        // 2. Population-weighted slot allocation (largest remainder method).
        let weighted = allocateSlots(palette: palette, slotCount: slotCount)

        // 3. Materialize the slot assignments into a flat color array.
        var working: [PaletteColor] = []
        working.reserveCapacity(slotCount)
        for (color, count) in weighted {
            for _ in 0..<count {
                working.append(color)
            }
        }
        // Safety net — `allocateSlots` is supposed to return exactly slotCount,
        // but guard against rounding edge cases.
        while working.count < slotCount {
            working.append(palette.dominant ?? PaletteColor(r: 0, g: 0, b: 0))
        }
        working = Array(working.prefix(slotCount))

        // 4. Spatial ordering: OKLCH L descending into rows; within each row,
        //    OKLCH C ascending. Same shape as before — only the input differs.
        working.sort { $0.oklch.l > $1.oklch.l }

        let n = gridSize.width
        var arranged: [PaletteColor] = []
        arranged.reserveCapacity(slotCount)
        for row in 0..<n {
            let rowStart = row * n
            let rowEnd = rowStart + n
            var rowSlice = Array(working[rowStart..<rowEnd])
            rowSlice.sort { $0.oklch.c < $1.oklch.c }
            arranged.append(contentsOf: rowSlice)
        }
        return arranged
    }

    /// Largest-remainder method: allocate `slotCount` slots across the palette
    /// proportional to each color's `population`. Returns `(color, count)`
    /// pairs in palette order (population-descending). Colors with zero
    /// allocation are omitted.
    private static func allocateSlots(
        palette: Palette, slotCount: Int
    ) -> [(PaletteColor, Int)] {
        let totalPopulation = palette.colors.reduce(0) { $0 + $1.population }
        // Defensive: if all populations are 0, fall back to equal distribution
        // across the prefix of palette.colors.
        guard totalPopulation > 0 else {
            var result: [(PaletteColor, Int)] = []
            let prefix = palette.colors.prefix(slotCount)
            for c in prefix {
                result.append((c, 1))
            }
            // Pad remaining slots with the first color if palette is shorter
            // than slotCount.
            let assigned = result.reduce(0) { $0 + $1.1 }
            if assigned < slotCount, let first = palette.colors.first {
                result.append((first, slotCount - assigned))
            }
            return result
        }

        struct Bucket {
            let color: PaletteColor
            let exact: Double
            let floorCount: Int
        }
        let buckets: [Bucket] = palette.colors.map { color in
            let exact = Double(color.population) / Double(totalPopulation) * Double(slotCount)
            return Bucket(color: color, exact: exact, floorCount: Int(exact.rounded(.down)))
        }
        let floorSum = buckets.reduce(0) { $0 + $1.floorCount }
        let leftover = slotCount - floorSum

        // Indices of the top `leftover` buckets by fractional remainder.
        let remainders = buckets.enumerated()
            .map { ($0.offset, $0.element.exact - Double($0.element.floorCount)) }
            .sorted { $0.1 > $1.1 }
            .prefix(max(leftover, 0))
            .map { $0.0 }
        let bonus = Set(remainders)

        var result: [(PaletteColor, Int)] = []
        for (idx, b) in buckets.enumerated() {
            let count = b.floorCount + (bonus.contains(idx) ? 1 : 0)
            if count > 0 {
                result.append((b.color, count))
            }
        }
        return result
    }
}
#endif
