#if canImport(UIKit)
import Foundation
import CoreGraphics
import Testing
@testable import PaletteKit

@MainActor
@Suite("Async palette cache identity")
struct AsyncPaletteCacheIdentityTests {
    @Test("caller keys retain their type and Hashable equality")
    func typedCallerKeysRemainDistinct() {
        let keys: [AnyHashable] = [1, "1", SameDescriptionKey(value: 1), SameDescriptionKey(value: 2)]
        let cache = PaletteCache(countLimit: 8)
        let source = ImageSource.url(URL(fileURLWithPath: "/unused.png"))
        let contexts = keys.map { ResolutionContext(image: source, options: .init(), cacheKey: $0) }
        #expect(Set(contexts).count == keys.count)
        for (index, context) in contexts.enumerated() {
            cache.set(palette: AsyncTestSupport.makePalette(rgb: (UInt8(index + 10), 20, 30)),
                      swatches: nil, forKey: context.storageKey)
        }
        for (index, context) in contexts.enumerated() {
            #expect(cache.entry(forKey: context.storageKey)?.palette.colors.first?.rgb.r == UInt8(index + 10))
        }
    }

    @Test("encoded Data identity is stable and compares bytes")
    func dataUsesValueIdentity() {
        let bytes: [UInt8] = Array(repeating: 42, count: 256)
        let a = ResolutionContext(image: .data(Data(bytes)), options: .init(), cacheKey: "data")
        let b = ResolutionContext(image: .data(Data(bytes)), options: .init(), cacheKey: "data")
        let c = ResolutionContext(image: .data(Data(bytes + [43])), options: .init(), cacheKey: "data")
        #expect(a == b)
        #expect(a.storageKey == a.storageKey)
        #expect(a != c)
        let cache = PaletteCache(countLimit: 4)
        let expected = AsyncTestSupport.makePalette()
        cache.set(palette: expected, swatches: nil, forKey: a.storageKey)
        #expect(cache.entry(forKey: b.storageKey)?.palette.colors == expected.colors)
        #expect(cache.entry(forKey: c.storageKey) == nil)
    }

    @Test("caller key supplements source and options; CGImage uses reference equality")
    func callerKeyDoesNotReplaceSourceOrOptions() {
        let image = AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))
        let a = ResolutionContext(image: .cgImage(image), options: .init(), cacheKey: "same")
        let b = ResolutionContext(image: .cgImage(image), options: .init(), cacheKey: "same")
        let c = ResolutionContext(
            image: .cgImage(AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))),
            options: .init(), cacheKey: "same"
        )
        let d = ResolutionContext(image: .cgImage(image), options: .init(colorCount: 3), cacheKey: "same")
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
        #expect(!ResolutionContext(image: .cgImage(image), options: .init(), cacheKey: nil).isCacheable)
        #expect(!ResolutionContext(image: .data(Data([1])), options: .init(), cacheKey: nil).isCacheable)
    }

    @Test("cached CGImage identities do not retain decoded source images")
    func cachedSourceImageCanBeReleased() {
        let cache = PaletteCache(countLimit: 4)
        weak var releasedImage: CGImage?
        let storedKey: ResolutionContext.StorageKey = {
            let image = AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))
            releasedImage = image
            let context = ResolutionContext(image: .cgImage(image), options: .init(), cacheKey: "lifetime")
            cache.set(palette: AsyncTestSupport.makePalette(), swatches: nil, forKey: context.storageKey)
            #expect(cache.entry(forKey: context.storageKey) != nil)
            return context.storageKey
        }()
        #expect(releasedImage == nil)
        #expect(cache.entry(forKey: storedKey) == nil)
        #expect(storedKey == storedKey, "identity equality remains stable after source release")
    }

    @Test("typed entries and public string entries share clear without collisions")
    func publicStringCacheRemainsIndependent() {
        let cache = PaletteCache(countLimit: 4)
        let context = ResolutionContext(
            image: .url(URL(fileURLWithPath: "/unused.png")), options: .init(), cacheKey: "key"
        )
        let typed = AsyncTestSupport.makePalette(rgb: (10, 20, 30))
        let string = AsyncTestSupport.makePalette(rgb: (40, 50, 60))
        cache.set(palette: typed, swatches: nil, forKey: context.storageKey)
        cache.set(palette: string, swatches: nil, forKey: "key")
        #expect(cache.entry(forKey: context.storageKey)?.palette.colors == typed.colors)
        #expect(cache.entry(forKey: "key")?.palette.colors == string.colors)
        cache.clear()
        #expect(cache.entry(forKey: context.storageKey) == nil)
        #expect(cache.entry(forKey: "key") == nil)
    }

    @Test("forceLoad extracts new output and replaces the cached palette")
    func forceLoadRefreshesCache() async throws {
        let quantizer = RefreshQuantizer()
        let cache = PaletteCache(countLimit: 4)
        let loader = AsyncPaletteGraphicLoader()
        let context = ResolutionContext(
            image: .cgImage(AsyncTestSupport.makeSolidImage(rgb: (180, 60, 40))),
            options: .init(colorSpace: .sRGB, quantizer: .custom(quantizer)),
            cacheKey: "refresh"
        )
        cache.set(palette: AsyncTestSupport.makePalette(rgb: (180, 60, 40)),
                  swatches: nil, forKey: context.storageKey)
        loader.load(context: context, cache: cache)
        #expect(await quantizer.callCount == 0)
        guard case .success(_, _, true) = loader.phase else {
            Issue.record("initial load must use cache")
            return
        }
        let (events, continuation) = AsyncStream<Bool>.makeStream()
        loader.onSuccess = { _, _, fromCache in continuation.yield(fromCache); continuation.finish() }
        loader.onFailure = { _ in continuation.finish() }
        loader.forceLoad(context: context, cache: cache)
        let fromCache = try await AsyncTestSupport.nextEvent(from: events, waitingFor: "forced refresh")
        #expect(!fromCache)
        let callsAfterRefresh = await quantizer.callCount
        #expect(callsAfterRefresh > 0)
        let expected = RGB(r: 40, g: 60, b: 180)
        guard case .success(let refreshed, _, false) = loader.phase else {
            Issue.record("forced refresh must resolve with fresh output")
            return
        }
        #expect(refreshed.colors.map(\.rgb) == [expected])
        #expect(cache.entry(forKey: context.storageKey)?.palette.colors.map(\.rgb) == [expected])
        let nextLoader = AsyncPaletteGraphicLoader()
        nextLoader.load(context: context, cache: cache)
        guard case .success(let reused, _, true) = nextLoader.phase else {
            Issue.record("subsequent load must use the refreshed cache entry")
            return
        }
        #expect(reused.colors.map(\.rgb) == [expected])
        #expect(await quantizer.callCount == callsAfterRefresh)
    }
}

private struct SameDescriptionKey: Hashable, CustomStringConvertible {
    let value: Int
    var description: String { "1" }
}

private actor RefreshQuantizer: Quantizer {
    nonisolated let name = "Refresh"
    private(set) var callCount = 0
    func prepare() async throws {}
    func quantize(pixels: [PixelTriplet], maxColors: Int) async throws -> [QuantizedColor] {
        callCount += 1
        return [QuantizedColor(color: PixelTriplet(r: 40, g: 60, b: 180), population: pixels.count)]
    }
}
#endif
