#if canImport(UIKit)
import Foundation
import CoreGraphics

/// In-memory cache for palettes and semantic swatches.
///
/// Async graphic views use ``shared`` by default. Supply a separate instance
/// to keep their cached results independent.
///
/// Thread-safe through `NSCache`, with automatic eviction under memory pressure.
public final class PaletteCache: @unchecked Sendable {
    /// The default cache used by async graphic views.
    public static let shared = PaletteCache(countLimit: 100)

    /// Advisory entry-count limit for NSCache; not a strict maximum.
    public let countLimit: Int

    private final class Entry {
        let palette: Palette
        let swatches: SwatchMap?
        weak var sourceImage: CGImage?
        init(palette: Palette, swatches: SwatchMap?, sourceImage: CGImage?) {
            self.palette = palette
            self.swatches = swatches
            self.sourceImage = sourceImage
        }
    }

    private enum Key: Hashable {
        case string(String)
        case resolution(ResolutionContext.StorageKey)
    }

    private final class KeyBox: NSObject {
        let value: Key
        init(_ value: Key) { self.value = value }
        override var hash: Int { value.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? KeyBox else { return false }
            return value == other.value
        }
    }

    private let store: NSCache<KeyBox, Entry>

    public init(countLimit: Int = 100) {
        self.countLimit = countLimit
        let store = NSCache<KeyBox, Entry>()
        store.countLimit = countLimit
        self.store = store
    }

    /// Look up a cached resolution by string key. Returns `nil` on miss.
    public func entry(forKey key: String) -> (palette: Palette, swatches: SwatchMap?)? {
        entry(for: .string(key))
    }

    /// Store a resolved palette + swatches under the given string key.
    public func set(palette: Palette, swatches: SwatchMap?, forKey key: String) {
        set(palette: palette, swatches: swatches, for: .string(key))
    }

    func entry(forKey key: ResolutionContext.StorageKey) -> (palette: Palette, swatches: SwatchMap?)? {
        entry(for: .resolution(key))
    }

    func set(palette: Palette, swatches: SwatchMap?, forKey key: ResolutionContext.StorageKey) {
        set(palette: palette, swatches: swatches, for: .resolution(key))
    }

    private func entry(for key: Key) -> (palette: Palette, swatches: SwatchMap?)? {
        guard let entry = store.object(forKey: KeyBox(key)) else { return nil }
        if case .resolution(let resolution) = key,
           case .cgImage(let identity) = resolution.source {
            guard let requested = identity.image, entry.sourceImage === requested else { return nil }
        }
        return (entry.palette, entry.swatches)
    }

    private func set(palette: Palette, swatches: SwatchMap?, for key: Key) {
        let sourceImage: CGImage?
        if case .resolution(let resolution) = key,
           case .cgImage(let identity) = resolution.source {
            sourceImage = identity.image
        } else {
            sourceImage = nil
        }
        store.setObject(Entry(palette: palette, swatches: swatches, sourceImage: sourceImage),
                        forKey: KeyBox(key))
    }

    /// Drop all cached entries (e.g. on sign-out, theme reset, low memory).
    public func clear() {
        store.removeAllObjects()
    }
}
#endif
