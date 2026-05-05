#if canImport(UIKit)
import Testing
@testable import PaletteKit

@Suite("PaletteCache")
struct PaletteCacheTests {
    @Test("set then get returns the stored entry")
    func setThenGet() {
        let cache = PaletteCache(countLimit: 4)
        let palette = AsyncTestSupport.makePalette()
        cache.set(palette: palette, swatches: nil, forKey: "test-key")
        let entry = cache.entry(forKey: "test-key")
        #expect(entry != nil)
        #expect(entry?.palette.colors.first == palette.colors.first)
        #expect(entry?.swatches == nil)
    }

    @Test("get on empty cache returns nil")
    func getMiss() {
        let cache = PaletteCache(countLimit: 4)
        #expect(cache.entry(forKey: "missing-key") == nil)
    }

    @Test("clear removes all entries")
    func clear() {
        let cache = PaletteCache(countLimit: 4)
        cache.set(palette: AsyncTestSupport.makePalette(), swatches: nil, forKey: "key-a")
        cache.set(palette: AsyncTestSupport.makePalette(), swatches: nil, forKey: "key-b")
        cache.clear()
        #expect(cache.entry(forKey: "key-a") == nil)
        #expect(cache.entry(forKey: "key-b") == nil)
    }

    @Test("shared singleton is the same instance across calls")
    func sharedSingleton() {
        #expect(PaletteCache.shared === PaletteCache.shared)
    }

    @Test("default countLimit is 100")
    func defaultLimit() {
        let cache = PaletteCache()
        #expect(cache.countLimit == 100)
    }
}
#endif
