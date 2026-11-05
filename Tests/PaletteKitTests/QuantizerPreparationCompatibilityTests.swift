import PaletteKit
import Testing

@Suite("Public quantizer preparation compatibility")
struct QuantizerPreparationCompatibilityTests {
    @Test("actor synchronous preparation works through direct and protocol calls")
    func synchronousActor() async throws {
        let quantizer = SynchronousPreparation()
        await quantizer.prepare()
        #expect(await quantizer.count == 1)
        let erased: any Quantizer = quantizer
        try await erased.prepare()
        #expect(await quantizer.count == 2)
        try await prepare(quantizer)
        #expect(await quantizer.count == 3)
    }

    @Test("actor asynchronous preparation still dispatches to its implementation")
    func asynchronousActor() async throws {
        let quantizer = AsynchronousPreparation()
        await quantizer.prepare()
        #expect(await quantizer.count == 1)
        let erased: any Quantizer = quantizer
        try await erased.prepare()
        #expect(await quantizer.count == 2)
        try await prepare(quantizer)
        #expect(await quantizer.count == 3)
    }

    @Test("synchronous throwing preparation retains errors and function references")
    func synchronousFailure() async {
        let quantizer = FailingPreparation()
        let direct = quantizer.prepare
        #expect(throws: PaletteError.imageEmpty) { try direct() }
        let erased: any Quantizer = quantizer
        await #expect(throws: PaletteError.imageEmpty) { try await erased.prepare() }
        await #expect(throws: PaletteError.imageEmpty) { try await prepare(quantizer) }
    }

    private func prepare<Q: Quantizer>(_ quantizer: Q) async throws {
        try await quantizer.prepare()
    }
}

private actor SynchronousPreparation: Quantizer {
    nonisolated let name = "SynchronousPreparation"
    var count = 0
    func prepare() { count += 1 }
    func quantize(pixels: [PixelTriplet], maxColors: Int) async throws -> [QuantizedColor] { [] }
}

private actor AsynchronousPreparation: Quantizer {
    nonisolated let name = "AsynchronousPreparation"
    var count = 0
    func prepare() async { count += 1 }
    func quantize(pixels: [PixelTriplet], maxColors: Int) async throws -> [QuantizedColor] { [] }
}

private struct FailingPreparation: Quantizer {
    let name = "FailingPreparation"
    func prepare() throws { throw PaletteError.imageEmpty }
    func quantize(pixels: [PixelTriplet], maxColors: Int) async throws -> [QuantizedColor] { [] }
}
