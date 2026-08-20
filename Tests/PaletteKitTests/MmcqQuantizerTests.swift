import Testing
@testable import PaletteKit

@Suite("MmcqQuantizer")
struct MmcqQuantizerTests {
    @Test("single color returns that color")
    func singleColor() async throws {
        let pixels = Array(repeating: PixelTriplet(r: 255, g: 0, b: 0), count: 100)
        let quantizer = MmcqQuantizer()
        let result = try await quantizer.quantize(pixels: pixels, maxColors: 2)
        try #require(!result.isEmpty)
        let first = result[0]
        #expect(first.color.r > 200)
        #expect(first.color.g < 50)
        #expect(first.color.b < 50)
    }

    @Test("two distinct colors yield two clusters")
    func twoColors() async throws {
        var pixels: [PixelTriplet] = []
        pixels += Array(repeating: PixelTriplet(r: 255, g: 0, b: 0), count: 500)
        pixels += Array(repeating: PixelTriplet(r: 0, g: 0, b: 255), count: 500)
        let result = try await MmcqQuantizer().quantize(pixels: pixels, maxColors: 2)
        #expect(result.count == 2)
    }

    @Test("an unsplittable 5-bit bin remains one populated cluster")
    func unsplittableQuantizedBin() async throws {
        // Each group contains distinct 8-bit colors, so the exact-color fast
        // path does not apply. After MMCQ's three-bit shift, however, every
        // color in the group occupies the same histogram coordinate. Such a
        // VBox has pixel population but no valid boundary at which to split.
        let cases: [(name: String, pixels: [PixelTriplet])] = [
            (
                "lowest histogram coordinate",
                [
                    PixelTriplet(r: 0, g: 0, b: 0),
                    PixelTriplet(r: 1, g: 0, b: 0),
                    PixelTriplet(r: 2, g: 0, b: 0),
                ]
            ),
            (
                "interior histogram coordinate",
                [
                    PixelTriplet(r: 232, g: 0, b: 0),
                    PixelTriplet(r: 233, g: 0, b: 0),
                    PixelTriplet(r: 234, g: 0, b: 0),
                ]
            ),
            (
                "highest histogram coordinate",
                [
                    PixelTriplet(r: 248, g: 0, b: 0),
                    PixelTriplet(r: 249, g: 0, b: 0),
                    PixelTriplet(r: 250, g: 0, b: 0),
                ]
            ),
        ]

        for testCase in cases {
            let maxColors = 2
            let occupiedBins = Set(testCase.pixels.map(reducedHistogramIndex))
            #expect(
                Set(testCase.pixels).count > maxColors,
                "the fixture must bypass the exact-color fast path"
            )
            #expect(
                occupiedBins.count == 1,
                "the fixture must collapse into one reduced histogram bin"
            )

            let result = try await MmcqQuantizer().quantize(
                pixels: testCase.pixels,
                maxColors: maxColors
            )

            #expect(
                result.count == 1,
                "\(testCase.name) cannot produce two non-empty child boxes"
            )
            #expect(Set(result.map { reducedHistogramIndex($0.color) }) == occupiedBins)
            expectPopulationIsPreserved(result, inputCount: testCase.pixels.count)
        }
    }

    @Test("median cut falls back to an occupied axis")
    func medianCutAxisFallback() async throws {
        // The first cut separates the low-red pixel from the three high-red
        // pixels. That child retains a wide red range even though red has only
        // one occupied coordinate; green is the axis that can still split it.
        let pixels = [
            PixelTriplet(r: 0, g: 0, b: 0),
            PixelTriplet(r: 248, g: 0, b: 0),
            PixelTriplet(r: 248, g: 8, b: 0),
            PixelTriplet(r: 248, g: 16, b: 0),
        ]

        let result = try await MmcqQuantizer().quantize(pixels: pixels, maxColors: 3)

        #expect(result.count == 3)
        expectPopulationIsPreserved(result, inputCount: pixels.count)
    }

    @Test("an unsplittable high-population box does not starve splittable boxes")
    func unsplittableBoxDoesNotStarveQueue() async throws {
        // The first three RGB888 colors share one 5-bit bin, making that VBox
        // terminal and more populous than the remaining active VBox. Putting
        // it straight back into the priority queue would select it repeatedly
        // instead of splitting the two occupied bins that remain.
        let pixels = [
            PixelTriplet(r: 0, g: 0, b: 0),
            PixelTriplet(r: 1, g: 0, b: 0),
            PixelTriplet(r: 2, g: 0, b: 0),
            PixelTriplet(r: 192, g: 0, b: 0),
            PixelTriplet(r: 248, g: 0, b: 0),
        ]
        let maxColors = 3
        let occupiedBins = Set(pixels.map(reducedHistogramIndex))
        #expect(Set(pixels).count > maxColors)
        #expect(occupiedBins.count == maxColors)

        let result = try await MmcqQuantizer().quantize(
            pixels: pixels,
            maxColors: maxColors
        )

        #expect(result.count == occupiedBins.count)
        expectPopulationIsPreserved(result, inputCount: pixels.count)
    }

    @Test("unique-colors short circuit preserves counts")
    func uniqueShortCircuit() async throws {
        let pixels: [PixelTriplet] = [
            PixelTriplet(r: 10, g: 10, b: 10),
            PixelTriplet(r: 10, g: 10, b: 10),
            PixelTriplet(r: 200, g: 100, b: 50),
        ]
        let result = try await MmcqQuantizer().quantize(pixels: pixels, maxColors: 8)
        #expect(result.count == 2)
        let gray = result.first { $0.color.r == 10 }
        #expect(gray?.population == 2)
    }

    @Test("empty input returns empty")
    func emptyInput() async throws {
        let result = try await MmcqQuantizer().quantize(pixels: [], maxColors: 5)
        #expect(result.isEmpty)
    }

    @Test("Phase 1 target rounds up to match color-thief termination")
    func phase1CeilingRounding() {
        // For maxColors values where (maxColors * 0.75) is non-integer,
        // Phase 1 should terminate at ceil(maxColors * 0.75) rather than floor.
        // This matches color-thief v3, which compares an integer count
        // against a fractional target with `>=` (effectively a ceiling).
        let cases: [(maxColors: Int, expectedPhase1Target: Int)] = [
            (4, 3),    // 3.0 → 3
            (5, 4),    // 3.75 → 4
            (7, 6),    // 5.25 → 6
            (8, 6),    // 6.0 → 6
            (10, 8),   // 7.5 → 8 (default colorCount)
            (11, 9),   // 8.25 → 9
            (14, 11),  // 10.5 → 11
            (16, 12),  // 12.0 → 12
            (20, 15),  // 15.0 → 15
        ]
        for (maxColors, expected) in cases {
            let target = Int((Double(maxColors) * MmcqEngine.fractByPopulation).rounded(.up))
            #expect(target == expected, "maxColors=\(maxColors): expected Phase 1 target \(expected), got \(target)")
        }
    }

    @Test("respects cancellation")
    func cancellation() async throws {
        let pixels = (0..<50_000).map { _ in
            PixelTriplet(
                r: UInt8.random(in: 0...255),
                g: UInt8.random(in: 0...255),
                b: UInt8.random(in: 0...255)
            )
        }
        let task = Task {
            try await MmcqQuantizer().quantize(pixels: pixels, maxColors: 10)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    private func expectPopulationIsPreserved(
        _ result: [QuantizedColor],
        inputCount: Int
    ) {
        #expect(result.allSatisfy { $0.population > 0 })
        #expect(result.reduce(0) { $0 + $1.population } == inputCount)
    }

    private func reducedHistogramIndex(_ color: PixelTriplet) -> Int {
        MmcqEngine.colorIndex(
            Int(color.r) >> MmcqEngine.rShift,
            Int(color.g) >> MmcqEngine.rShift,
            Int(color.b) >> MmcqEngine.rShift
        )
    }
}
