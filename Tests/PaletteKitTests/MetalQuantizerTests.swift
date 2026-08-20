#if canImport(Metal)
import Metal
import Testing
@testable import PaletteKit

@Suite("MetalMmcqQuantizer")
struct MetalMmcqQuantizerTests {
    @Test("matches CPU output on the same input")
    func parityWithCPU() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else { return }

        var pixels: [PixelTriplet] = []
        for _ in 0..<2_000 { pixels.append(PixelTriplet(r: 220, g: 40, b: 40)) }
        for _ in 0..<2_000 { pixels.append(PixelTriplet(r: 40, g: 40, b: 220)) }
        for _ in 0..<1_000 { pixels.append(PixelTriplet(r: 40, g: 220, b: 40)) }

        let cpu = try await MmcqQuantizer().quantize(pixels: pixels, maxColors: 3)
        let metal = try await MetalMmcqQuantizer().quantize(pixels: pixels, maxColors: 3)

        try #require(cpu.count == metal.count)
        // Sort by full (population, r, g, b) tuple so ties resolve deterministically.
        let sortedCPU = cpu.sorted {
            ($0.population, $0.color.r, $0.color.g, $0.color.b)
                > ($1.population, $1.color.r, $1.color.g, $1.color.b)
        }
        let sortedMetal = metal.sorted {
            ($0.population, $0.color.r, $0.color.g, $0.color.b)
                > ($1.population, $1.color.r, $1.color.g, $1.color.b)
        }
        for (index, entry) in sortedCPU.enumerated() {
            #expect(abs(Int(entry.color.r) - Int(sortedMetal[index].color.r)) <= 2)
            #expect(abs(Int(entry.color.g) - Int(sortedMetal[index].color.g)) <= 2)
            #expect(abs(Int(entry.color.b) - Int(sortedMetal[index].color.b)) <= 2)
            #expect(entry.population == sortedMetal[index].population)
        }
    }

    @Test("matches CPU for reduced-histogram terminal and fallback boxes")
    func parityForReducedHistogramBoundaries() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else { return }

        // Every case has more exact RGB888 colors than maxColors, so neither
        // quantizer can take the exact-color fast path. The GPU-provided
        // histogram must therefore exercise the same median-cut behavior as
        // the CPU-built histogram.
        let cases: [(pixels: [PixelTriplet], maxColors: Int)] = [
            (
                [
                    PixelTriplet(r: 0, g: 0, b: 0),
                    PixelTriplet(r: 1, g: 0, b: 0),
                    PixelTriplet(r: 2, g: 0, b: 0),
                ],
                2
            ),
            (
                [
                    PixelTriplet(r: 0, g: 0, b: 0),
                    PixelTriplet(r: 248, g: 0, b: 0),
                    PixelTriplet(r: 248, g: 8, b: 0),
                    PixelTriplet(r: 248, g: 16, b: 0),
                ],
                3
            ),
            (
                [
                    PixelTriplet(r: 0, g: 0, b: 0),
                    PixelTriplet(r: 1, g: 0, b: 0),
                    PixelTriplet(r: 2, g: 0, b: 0),
                    PixelTriplet(r: 192, g: 0, b: 0),
                    PixelTriplet(r: 248, g: 0, b: 0),
                ],
                3
            ),
        ]

        for testCase in cases {
            let cpu = try await MmcqQuantizer().quantize(
                pixels: testCase.pixels,
                maxColors: testCase.maxColors
            )
            let metal = try await MetalMmcqQuantizer().quantize(
                pixels: testCase.pixels,
                maxColors: testCase.maxColors
            )

            #expect(canonicalized(cpu) == canonicalized(metal))
            #expect(metal.allSatisfy { $0.population > 0 })
            #expect(metal.reduce(0) { $0 + $1.population } == testCase.pixels.count)
        }
    }

    @Test("respects cancellation before GPU dispatch")
    func cancellation() async throws {
        guard MTLCreateSystemDefaultDevice() != nil else { return }
        let pixels = (0..<10_000).map { _ in
            PixelTriplet(
                r: UInt8.random(in: 0...255),
                g: UInt8.random(in: 0...255),
                b: UInt8.random(in: 0...255)
            )
        }
        let task = Task {
            try await MetalMmcqQuantizer().quantize(pixels: pixels, maxColors: 10)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }

    private func canonicalized(_ colors: [QuantizedColor]) -> [QuantizedColor] {
        colors.sorted {
            ($0.population, $0.color.r, $0.color.g, $0.color.b)
                > ($1.population, $1.color.r, $1.color.g, $1.color.b)
        }
    }
}
#endif
