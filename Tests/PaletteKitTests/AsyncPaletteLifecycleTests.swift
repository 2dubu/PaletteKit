#if canImport(UIKit)
import Testing
import UIKit
@testable import PaletteKit

@MainActor
@Suite("Async palette lifecycle")
struct AsyncPaletteLifecycleTests {
    @Test("cancelled ordinary failure does not replace the next cached success")
    func cancelledFailureDoesNotReplaceSuccess() async throws {
        let quantizer = SuspendedFailureQuantizer()
        let cache = PaletteCache(countLimit: 4)
        let loader = AsyncPaletteGraphicLoader()
        let old = ResolutionContext(
            image: .cgImage(AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))),
            options: .init(colorSpace: .sRGB, quantizer: .custom(quantizer)),
            cacheKey: "old"
        )
        let next = ResolutionContext(
            image: .cgImage(AsyncTestSupport.makeSolidImage(rgb: (40, 60, 180))),
            options: .init(), cacheKey: "next"
        )
        let expected = AsyncTestSupport.makePalette(rgb: (40, 60, 180))
        cache.set(palette: expected, swatches: nil, forKey: next.storageKey)
        var failures = 0
        loader.onFailure = { _ in failures += 1 }
        loader.load(context: old, cache: cache)
        do {
            try await AsyncTestSupport.nextEvent(from: quantizer.started, waitingFor: "suspended quantizer")
            let oldTask = try #require(loader.cancel())
            loader.load(context: next, cache: cache)
            await quantizer.resume()
            await oldTask.value
            #expect(failures == 0)
            guard case .success(let palette, _, true) = loader.phase else {
                Issue.record("cancelled request replaced the next cached success")
                return
            }
            #expect(palette.colors.map(\.rgb) == expected.colors.map(\.rgb))
        } catch {
            let task = loader.cancel()
            await quantizer.resume()
            await task?.value
            throw error
        }
    }

    @Test("cancelled context can start again")
    func cancelledContextCanRestart() async throws {
        let loader = AsyncPaletteGraphicLoader()
        let context = ResolutionContext(
            image: .cgImage(AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))),
            options: .init(), cacheKey: nil
        )
        let (events, continuation) = AsyncStream<Void>.makeStream()
        loader.onSuccess = { _, _, _ in continuation.yield(); continuation.finish() }
        loader.onFailure = { _ in continuation.finish() }
        loader.load(context: context, cache: nil)
        let cancelled = loader.cancel()
        loader.load(context: context, cache: nil)
        try await AsyncTestSupport.nextEvent(from: events, waitingFor: "restarted context")
        await cancelled?.value
        guard case .success = loader.phase else {
            Issue.record("restarted context did not resolve")
            return
        }
    }

    @Test("UIKit shows placeholder after clearing, while loading, and after failure")
    func placeholderFollowsSourceLifecycle() async throws {
        let view = AsyncPaletteGraphicView(frame: .zero)
        view.cache = nil
        view.transition = nil
        let placeholder = UIView()
        view.placeholderView = placeholder
        let image = AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))
        try await resolve(view, image: image)
        #expect(view.subviews.contains { $0 is PaletteGraphicView })

        view.imageSource = nil
        #expect(view.subviews == [placeholder])
        try await resolve(view, image: image)
        #expect(view.subviews.contains { $0 is PaletteGraphicView })

        let quantizer = SuspendedFailureQuantizer()
        let (failures, failureContinuation) = AsyncStream<Void>.makeStream()
        view.onFailure = { _ in failureContinuation.yield(); failureContinuation.finish() }
        view.extractionOptions = .init(colorSpace: .sRGB, quantizer: .custom(quantizer))
        #expect(view.subviews == [placeholder])
        do {
            try await AsyncTestSupport.nextEvent(from: quantizer.started, waitingFor: "replacement load")
            await quantizer.resume()
            try await AsyncTestSupport.nextEvent(from: failures, waitingFor: "replacement failure")
            #expect(view.subviews == [placeholder])
        } catch {
            view.cancel()
            await quantizer.resume()
            throw error
        }
    }

    @Test("UIKit success callback can clear the source without restoring the completed graphic")
    func callbackCanClearSource() async throws {
        let view = AsyncPaletteGraphicView(frame: .zero)
        view.cache = nil
        view.transition = nil
        let placeholder = UIView()
        view.placeholderView = placeholder
        let (events, continuation) = AsyncStream<Void>.makeStream()
        view.onSuccess = { _, _ in
            #expect(view.subviews.contains { $0 is PaletteGraphicView })
            view.imageSource = nil
            continuation.yield()
            continuation.finish()
        }
        view.onFailure = { _ in continuation.finish() }
        view.imageSource = .cgImage(AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40)))
        try await AsyncTestSupport.nextEvent(from: events, waitingFor: "success callback")
        #expect(view.imageSource == nil)
        #expect(view.subviews == [placeholder])
    }

    @Test("UIKit failure callback can retry the same source")
    func failureCallbackCanRetrySameSource() async throws {
        let view = AsyncPaletteGraphicView(frame: .zero)
        view.cache = nil
        view.transition = nil
        let image = ImageSource.cgImage(AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40)))
        view.extractionOptions = .init(colorSpace: .sRGB, quantizer: .custom(FailOnceQuantizer()))
        let (events, continuation) = AsyncStream<Void>.makeStream()
        var failures = 0
        view.onFailure = { _ in
            failures += 1
            #expect(!view.subviews.contains { $0 is PaletteGraphicView })
            if failures == 1 { view.imageSource = image }
            else { continuation.finish() }
        }
        view.onSuccess = { _, _ in continuation.yield(); continuation.finish() }
        view.imageSource = image
        try await AsyncTestSupport.nextEvent(from: events, waitingFor: "retry after failure")
        #expect(failures == 1)
        #expect(view.subviews.contains { $0 is PaletteGraphicView })
    }

    private func resolve(_ view: AsyncPaletteGraphicView, image: CGImage) async throws {
        let (events, continuation) = AsyncStream<Void>.makeStream()
        view.onSuccess = { _, _ in continuation.yield(); continuation.finish() }
        view.onFailure = { _ in continuation.finish() }
        view.imageSource = .cgImage(image)
        try await AsyncTestSupport.nextEvent(from: events, waitingFor: "view resolution")
    }
}

private actor SuspendedFailureQuantizer: Quantizer {
    nonisolated let name = "SuspendedFailure"
    nonisolated let started: AsyncStream<Void>
    private let entered: AsyncStream<Void>.Continuation
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    init() { (started, entered) = AsyncStream<Void>.makeStream() }
    func prepare() async throws {}

    func quantize(pixels: [PixelTriplet], maxColors: Int) async throws -> [QuantizedColor] {
        if !released {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                entered.yield()
                entered.finish()
            }
        }
        throw PaletteError.imageEmpty
    }

    func resume() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
private actor FailOnceQuantizer: Quantizer {
    nonisolated let name = "FailOnce"
    private var hasFailed = false
    func prepare() async throws {}
    func quantize(pixels: [PixelTriplet], maxColors: Int) async throws -> [QuantizedColor] {
        if !hasFailed {
            hasFailed = true
            throw PaletteError.imageEmpty
        }
        return [QuantizedColor(color: PixelTriplet(r: 40, g: 60, b: 180), population: pixels.count)]
    }
}
#endif
