#if canImport(UIKit)
import Testing
import Foundation
@testable import PaletteKit

@MainActor
@Suite("AsyncPaletteGraphicLoader")
struct AsyncPaletteGraphicLoaderTests {
    private enum LoadEvent: Sendable {
        case success(fromCache: Bool)
        case failure
    }

    @Test("initial phase is .empty")
    func initialPhase() {
        let loader = AsyncPaletteGraphicLoader()
        if case .empty = loader.phase { } else {
            Issue.record("expected .empty, got \(loader.phase)")
        }
    }

    @Test("load: cache hit returns .success(fromCache: true) without extraction")
    func cacheHitSync() async throws {
        let cache = PaletteCache(countLimit: 4)
        let palette = AsyncTestSupport.makePalette(rgb: (10, 20, 30))
        // Pre-seed cache with a known key.
        let context = ResolutionContext(
            image: .cgImage(AsyncTestSupport.makeSolidImage(rgb: (10, 20, 30))),
            options: .init(),
            cacheKey: AnyHashable("seeded-key")
        )
        cache.set(palette: palette, swatches: nil, forKey: context.storageKey)

        let loader = AsyncPaletteGraphicLoader()
        loader.load(context: context, cache: cache)

        // Cache hit is synchronous (no await needed before checking phase).
        guard case .success(let p, _, let fromCache) = loader.phase else {
            Issue.record("expected .success, got \(loader.phase)")
            return
        }
        #expect(fromCache == true)
        #expect(p.colors.first?.rgb.r == 10)
    }

    @Test("load: cache miss → .loading → .success(fromCache: false)")
    func cacheMissAsync() async throws {
        let cache = PaletteCache(countLimit: 4)
        let cgImage = AsyncTestSupport.makeSolidImage(rgb: (200, 50, 50))
        let context = ResolutionContext(
            image: .cgImage(cgImage),
            options: .init(),
            cacheKey: AnyHashable("miss-key")
        )

        let loader = AsyncPaletteGraphicLoader()
        let (events, eventContinuation) = AsyncStream<LoadEvent>.makeStream()
        loader.onSuccess = { _, _, fromCache in
            eventContinuation.yield(.success(fromCache: fromCache))
            eventContinuation.finish()
        }
        loader.onFailure = { _ in
            eventContinuation.yield(.failure)
            eventContinuation.finish()
        }
        loader.load(context: context, cache: cache)

        // Should transition to .loading immediately.
        if case .loading = loader.phase { } else {
            Issue.record("expected .loading after kick-off, got \(loader.phase)")
        }

        let event = try await AsyncTestSupport.nextEvent(
            from: events,
            waitingFor: "the cache-miss load callback"
        )
        guard case .success(let callbackFromCache) = event else {
            Issue.record("expected the success callback, got failure")
            return
        }
        #expect(callbackFromCache == false)

        guard case .success(let p, _, let fromCache) = loader.phase else {
            Issue.record("expected .success, got \(loader.phase)")
            return
        }
        #expect(fromCache == false)
        #expect(p.colors.first?.rgb.r ?? 0 > 150) // dominant red

        // Cache should now be populated for the same key.
        #expect(cache.entry(forKey: context.storageKey) != nil)
    }

    @Test("load: invalid source → .failure, onFailure called")
    func failurePath() async throws {
        let loader = AsyncPaletteGraphicLoader()
        var captured: Error?
        let (events, eventContinuation) = AsyncStream<LoadEvent>.makeStream()
        loader.onSuccess = { _, _, fromCache in
            eventContinuation.yield(.success(fromCache: fromCache))
            eventContinuation.finish()
        }
        loader.onFailure = {
            captured = $0
            eventContinuation.yield(.failure)
            eventContinuation.finish()
        }

        // 1×1 white CGImage with `.fail` fallback strategy → all pixels
        // filtered (default `ignoreWhite = true` drops the only pixel) →
        // PaletteError.allPixelsFiltered.
        let blank = AsyncTestSupport.makeSolidImage(rgb: (255, 255, 255), size: 1)
        let context = ResolutionContext(
            image: .cgImage(blank),
            options: .init(fallbackStrategy: .fail),
            cacheKey: AnyHashable("blank")
        )
        loader.load(context: context, cache: nil)

        let event = try await AsyncTestSupport.nextEvent(
            from: events,
            waitingFor: "the invalid-source failure callback"
        )
        guard case .failure = event else {
            Issue.record("expected the failure callback, got success")
            return
        }

        if case .failure = loader.phase { } else {
            Issue.record("expected .failure, got \(loader.phase)")
        }
        #expect(captured != nil)
    }

    @Test("cancel: in-flight task does not mutate state")
    func cancelMidFlight() async throws {
        let loader = AsyncPaletteGraphicLoader()
        let cgImage = AsyncTestSupport.makeSolidImage(rgb: (50, 100, 150))
        let context = ResolutionContext(
            image: .cgImage(cgImage),
            options: .init(),
            cacheKey: AnyHashable("cancel-target")
        )
        loader.load(context: context, cache: nil)
        loader.cancel()
        // Give the task a moment to observe cancellation.
        try await Task.sleep(for: .milliseconds(200))
        // Phase should remain .loading (or .empty if cancel ran before kick-off).
        switch loader.phase {
        case .empty, .loading:
            break // acceptable post-cancel phases
        case .success, .failure:
            Issue.record("phase should not advance after cancel: \(loader.phase)")
        }
    }

    @Test("ResolutionContext: same inputs produce same storageKey")
    func contextStorageKeyStable() throws {
        let url = URL(string: "https://example.com/img.jpg")!
        let a = ResolutionContext(image: .url(url), options: .init(), cacheKey: nil)
        let b = ResolutionContext(image: .url(url), options: .init(), cacheKey: nil)
        #expect(a.storageKey == b.storageKey)
        #expect(a.hashValue == b.hashValue)  // still works, derived from storageKey
    }

    @Test("ResolutionContext: different cacheKey produces different storageKey")
    func contextStorageKeySensitiveToCacheKey() throws {
        let url = URL(string: "https://example.com/img.jpg")!
        let a = ResolutionContext(image: .url(url), options: .init(), cacheKey: AnyHashable("a"))
        let b = ResolutionContext(image: .url(url), options: .init(), cacheKey: AnyHashable("b"))
        #expect(a.storageKey != b.storageKey)
    }

    @Test("ResolutionContext: storageKey contains image source discriminator")
    func contextStorageKeyHasSource() throws {
        let url = URL(string: "https://example.com/img.jpg")!
        let ctx = ResolutionContext(image: .url(url), options: .init(), cacheKey: nil)
        #expect(ctx.storageKey.hasPrefix("url:https://example.com/img.jpg"))
    }

    @Test("ResolutionContext: different quality strides produce different keys")
    func contextHashSensitiveToQuality() {
        let url = URL(string: "https://example.com/img.jpg")!
        var optsA = ExtractionOptions(); optsA.quality = .stride(10)
        var optsB = ExtractionOptions(); optsB.quality = .stride(2)
        let a = ResolutionContext(image: .url(url), options: optsA, cacheKey: nil)
        let b = ResolutionContext(image: .url(url), options: optsB, cacheKey: nil)
        #expect(a.storageKey != b.storageKey)
    }

    @Test("ResolutionContext: different fallbackStrategy produce different keys")
    func contextHashSensitiveToFallback() {
        let url = URL(string: "https://example.com/img.jpg")!
        var optsA = ExtractionOptions(); optsA.fallbackStrategy = .relax
        var optsB = ExtractionOptions(); optsB.fallbackStrategy = .fail
        let a = ResolutionContext(image: .url(url), options: optsA, cacheKey: nil)
        let b = ResolutionContext(image: .url(url), options: optsB, cacheKey: nil)
        #expect(a.storageKey != b.storageKey)
    }
}

#if canImport(SwiftUI)
import SwiftUI

@Suite("AsyncPaletteGraphic smoke")
@MainActor
struct AsyncPaletteGraphicSmokeTests {
    @Test("can instantiate with default-placeholder convenience init")
    func defaultInit() throws {
        let url = URL(string: "https://example.com/x.jpg")!
        _ = AsyncPaletteGraphic(image: .url(url))
    }

    @Test("can instantiate with explicit placeholder closure")
    func explicitPlaceholder() throws {
        let url = URL(string: "https://example.com/x.jpg")!
        _ = AsyncPaletteGraphic(image: .url(url)) {
            Color.gray.opacity(0.1)
        }
    }

    @Test("can instantiate with phase content closure")
    func phaseInit() throws {
        let url = URL(string: "https://example.com/x.jpg")!
        _ = AsyncPaletteGraphic(image: .url(url)) { phase in
            switch phase {
            case .empty, .loading: AnyView(Color.gray)
            case .success(_, _, _): AnyView(Color.blue)
            case .failure: AnyView(Color.red)
            }
        }
    }

    @Test("can instantiate convenience init without swatchStrategy parameter")
    func conveniencePostStrategyDrop() throws {
        let url = URL(string: "https://example.com/x.jpg")!
        _ = AsyncPaletteGraphic(
            image: .url(url),
            configuration: .init(swatchStrategy: .contrast)
        )
    }
}
#endif
#endif
