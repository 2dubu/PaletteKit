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
}
