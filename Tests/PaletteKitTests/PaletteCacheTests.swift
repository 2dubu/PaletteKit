#if canImport(UIKit)
import Testing
@testable import PaletteKit

@Suite("PaletteCache")
struct PaletteCacheTests {
    @Test("set then get returns the stored entry")
    func setThenGet() {
        let cache = PaletteCache(countLimit: 4)
        let palette = AsyncTestSupport.makePalette()
        cache.set(palette: palette, swatches: nil, forKey: 42)
        let entry = cache.entry(forKey: 42)
        #expect(entry != nil)
        #expect(entry?.palette.colors.first?.rgb.r == palette.colors.first?.rgb.r)
        #expect(entry?.swatches == nil)
    }

    @Test("get on empty cache returns nil")
    func getMiss() {
        let cache = PaletteCache(countLimit: 4)
        #expect(cache.entry(forKey: 99) == nil)
    }

    @Test("clear removes all entries")
    func clear() {
        let cache = PaletteCache(countLimit: 4)
        cache.set(palette: AsyncTestSupport.makePalette(), swatches: nil, forKey: 1)
        cache.set(palette: AsyncTestSupport.makePalette(), swatches: nil, forKey: 2)
        cache.clear()
        #expect(cache.entry(forKey: 1) == nil)
        #expect(cache.entry(forKey: 2) == nil)
    }

    @Test("shared singleton is the same instance across calls")
    func sharedSingleton() {
        #expect(PaletteCache.shared === PaletteCache.shared)
    }

    @Test("default countLimit is 32")
    func defaultLimit() {
        let cache = PaletteCache()
        #expect(cache.countLimit == 32)
    }
}
#endif
