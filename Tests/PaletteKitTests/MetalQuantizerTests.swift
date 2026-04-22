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
        let sortedCPU = cpu.sorted { $0.population > $1.population }
        let sortedMetal = metal.sorted { $0.population > $1.population }
        for (index, entry) in sortedCPU.enumerated() {
            #expect(abs(Int(entry.color.r) - Int(sortedMetal[index].color.r)) <= 2)
            #expect(abs(Int(entry.color.g) - Int(sortedMetal[index].color.g)) <= 2)
            #expect(abs(Int(entry.color.b) - Int(sortedMetal[index].color.b)) <= 2)
            #expect(entry.population == sortedMetal[index].population)
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
}
#endif
