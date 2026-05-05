#if canImport(UIKit)
import Foundation

/// Process-wide memoization cache for resolved palettes.
///
/// `AsyncPaletteGraphic` and `AsyncPaletteGraphicView` consult this cache
/// before triggering an extraction. Use ``PaletteCache/shared`` for the
/// default cross-app store, or construct your own instance for tests / DI
/// boundaries.
///
/// Thread-safe via the underlying `NSCache`. Eviction is automatic under
/// memory pressure; the explicit ``countLimit`` upper bound matches
/// `PaletteGraphicRenderer`'s internal cache.
public final class PaletteCache: @unchecked Sendable {
    /// Process-wide shared cache used as the default for
    /// ``AsyncPaletteGraphic`` and ``AsyncPaletteGraphicView``.
    public static let shared = PaletteCache(countLimit: 32)

    /// Maximum number of cached entries before NSCache starts evicting.
    public let countLimit: Int

    /// Boxed entry — NSCache requires class types as values.
    private final class Entry {
        let palette: Palette
        let swatches: SwatchMap?
        init(palette: Palette, swatches: SwatchMap?) {
            self.palette = palette
            self.swatches = swatches
        }
    }

    private let store: NSCache<NSNumber, Entry>

    public init(countLimit: Int = 32) {
        self.countLimit = countLimit
        let store = NSCache<NSNumber, Entry>()
        store.countLimit = countLimit
        self.store = store
    }

    /// Look up a cached resolution by hashed key. Returns `nil` on miss.
    public func entry(forKey key: Int) -> (palette: Palette, swatches: SwatchMap?)? {
        guard let entry = store.object(forKey: NSNumber(value: key)) else { return nil }
        return (entry.palette, entry.swatches)
    }

    /// Store a resolved palette + swatches under the given hashed key.
    public func set(palette: Palette, swatches: SwatchMap?, forKey key: Int) {
        store.setObject(Entry(palette: palette, swatches: swatches),
                        forKey: NSNumber(value: key))
    }

    /// Drop all cached entries (e.g. on sign-out, theme reset, low memory).
    public func clear() {
        store.removeAllObjects()
    }
}
#endif
