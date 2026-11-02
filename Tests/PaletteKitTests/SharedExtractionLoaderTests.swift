#if canImport(UIKit)
import Foundation
import Testing
@testable import PaletteKit

@MainActor
@Suite("Shared extraction loader contracts")
struct SharedExtractionLoaderTests {
    private enum Event: Sendable { case success, failure }

    @Test("a swatch failure still publishes and caches the first palette")
    func secondFailureIsCachedAsSuccess() async throws {
        let quantizer = SecondCallQuantizer(fails: true)
        let cache = PaletteCache(countLimit: 4)
        let context = ResolutionContext(
            image: .cgImage(AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))),
            options: .init(colorSpace: .sRGB, quantizer: .custom(quantizer)),
            cacheKey: AnyHashable("second-failure")
        )
        let loader = AsyncPaletteGraphicLoader()
        let (events, continuation) = AsyncStream<Event>.makeStream()
        var failureCount = 0
        loader.onSuccess = { _, swatches, fromCache in
            #expect(swatches == nil)
            #expect(!fromCache)
            continuation.yield(.success)
            continuation.finish()
        }
        loader.onFailure = { _ in
            failureCount += 1
            continuation.yield(.failure)
            continuation.finish()
        }
        loader.load(context: context, cache: cache)
        let event = try await AsyncTestSupport.nextEvent(from: events, waitingFor: "the paired extraction success")
        guard case .success = event else { Issue.record("unexpected extraction failure"); return }
        #expect(failureCount == 0)
        let entry = try #require(cache.entry(forKey: context.storageKey))
        #expect(entry.palette.colors.map(\.rgb) == [RGB(r: 180, g: 60, b: 40)])
        #expect(entry.swatches == nil)
        #expect(await quantizer.requestedCounts == [10, 16])

        let cachedLoader = AsyncPaletteGraphicLoader()
        cachedLoader.load(context: context, cache: cache)
        guard case .success(_, let swatches, let fromCache) = cachedLoader.phase else {
            Issue.record("expected synchronous cached success")
            return
        }
        #expect(swatches == nil)
        #expect(fromCache)
        #expect(await quantizer.requestedCounts == [10, 16])
    }

    @Test("cancellation during swatch extraction cannot publish or cache")
    func cancelDuringSecondExtraction() async throws {
        let quantizer = SecondCallQuantizer(fails: false, suspends: true)
        let cache = PaletteCache(countLimit: 4)
        let context = ResolutionContext(
            image: .cgImage(AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))),
            options: .init(colorSpace: .sRGB, quantizer: .custom(quantizer)),
            cacheKey: AnyHashable("cancel-second")
        )
        let loader = AsyncPaletteGraphicLoader()
        var successCount = 0
        var failureCount = 0
        loader.onSuccess = { _, _, _ in successCount += 1 }
        loader.onFailure = { _ in failureCount += 1 }
        loader.load(context: context, cache: cache)
        do {
            _ = try await AsyncTestSupport.nextEvent(
                from: quantizer.secondStarted,
                waitingFor: "the suspended swatch quantization"
            )
            #expect(await quantizer.requestedCounts == [10, 16])
            let cancelled = try #require(loader.cancel())
            await quantizer.resume()
            await cancelled.value

            #expect(successCount == 0)
            #expect(failureCount == 0)
            #expect(cache.entry(forKey: context.storageKey) == nil)
            guard case .loading = loader.phase else {
                Issue.record("cancelled load changed phase")
                return
            }
        } catch {
            let cancelled = loader.cancel()
            await quantizer.resume()
            await cancelled?.value
            throw error
        }
    }
}

private actor SecondCallQuantizer: Quantizer {
    nonisolated let name = "SecondCall"
    nonisolated let secondStarted: AsyncStream<Void>
    private let entered: AsyncStream<Void>.Continuation
    private var continuation: CheckedContinuation<Void, Never>?
    private let fails: Bool
    private let suspends: Bool
    var requestedCounts: [Int] = []

    init(fails: Bool, suspends: Bool = false) {
        self.fails = fails
        self.suspends = suspends
        (secondStarted, entered) = AsyncStream<Void>.makeStream()
    }

    func prepare() async throws {}

    func quantize(pixels: [PixelTriplet], maxColors: Int) async throws -> [QuantizedColor] {
        requestedCounts.append(maxColors)
        if requestedCounts.count == 2 {
            if suspends {
                await withCheckedContinuation { continuation in
                    self.continuation = continuation
                    entered.yield(())
                    entered.finish()
                }
            }
            if fails { throw PaletteError.imageEmpty }
        }
        // Intentionally ignore cancellation here: the loader must still stop
        // before publishing even if a caller's quantizer completes normally.
        return [QuantizedColor(color: PixelTriplet(r: 180, g: 60, b: 40), population: pixels.count)]
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
#endif
