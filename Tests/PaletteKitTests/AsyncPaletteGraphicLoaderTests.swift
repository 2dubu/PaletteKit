#if canImport(UIKit)
import Testing
import Foundation
@testable import PaletteKit

@MainActor
@Suite("AsyncPaletteGraphicLoader")
struct AsyncPaletteGraphicLoaderTests {
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
        cache.set(palette: palette, swatches: nil, forKey: context.hashValue)

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
        loader.load(context: context, cache: cache)

        // Should transition to .loading immediately.
        if case .loading = loader.phase { } else {
            Issue.record("expected .loading after kick-off, got \(loader.phase)")
        }

        // Wait for completion (poll with small sleeps; integration boundary).
        try await waitForSuccess(loader: loader, timeout: .seconds(5))

        guard case .success(let p, _, let fromCache) = loader.phase else {
            Issue.record("expected .success, got \(loader.phase)")
            return
        }
        #expect(fromCache == false)
        #expect(p.colors.first?.rgb.r ?? 0 > 150) // dominant red

        // Cache should now be populated for the same key.
        #expect(cache.entry(forKey: context.hashValue) != nil)
    }

    @Test("load: invalid source → .failure, onFailure called")
    func failurePath() async throws {
        let loader = AsyncPaletteGraphicLoader()
        var captured: Error?
        loader.onFailure = { captured = $0 }

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

        try await waitForFailure(loader: loader, timeout: .seconds(5))

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

    @Test("ResolutionContext: same inputs produce same hashValue")
    func contextHashStable() throws {
        let url = URL(string: "https://example.com/img.jpg")!
        let a = ResolutionContext(image: .url(url), options: .init(), cacheKey: nil)
        let b = ResolutionContext(image: .url(url), options: .init(), cacheKey: nil)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("ResolutionContext: different cacheKey produces different hashValue")
    func contextHashKeyMatters() throws {
        let url = URL(string: "https://example.com/img.jpg")!
        let a = ResolutionContext(image: .url(url), options: .init(), cacheKey: AnyHashable("a"))
        let b = ResolutionContext(image: .url(url), options: .init(), cacheKey: AnyHashable("b"))
        #expect(a.hashValue != b.hashValue)
    }

    // MARK: - Helpers

    @MainActor
    private func waitForSuccess(loader: AsyncPaletteGraphicLoader,
                                timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if case .success = loader.phase { return }
            if case .failure(let e) = loader.phase {
                Issue.record("expected .success, got .failure(\(e))")
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("timed out waiting for .success; final phase: \(loader.phase)")
    }

    @MainActor
    private func waitForFailure(loader: AsyncPaletteGraphicLoader,
                                timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if case .failure = loader.phase { return }
            if case .success = loader.phase {
                Issue.record("expected .failure, got .success")
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("timed out waiting for .failure; final phase: \(loader.phase)")
    }
}
#endif
