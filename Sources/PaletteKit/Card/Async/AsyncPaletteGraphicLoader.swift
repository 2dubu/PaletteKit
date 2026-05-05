#if canImport(UIKit)
import Foundation
import SwiftUI

/// Resolution state for ``AsyncPaletteGraphic`` / ``AsyncPaletteGraphicView``.
///
/// State transitions: `.empty` → `.loading` → `.success` | `.failure`.
/// Cache hits skip `.loading` and land directly in
/// `.success(_, _, fromCache: true)`.
enum ResolutionPhase {
    case empty
    case loading
    case success(palette: Palette, swatches: SwatchMap?, fromCache: Bool)
    case failure(any Error)
}

/// Identifies a resolution attempt by image source + extraction options +
/// optional caller-supplied cache key. Hashable for `.task(id:)` and for
/// `PaletteCache` lookups.
struct ResolutionContext: Hashable {
    let image: ImageSource
    let options: ExtractionOptions
    let cacheKey: AnyHashable?

    init(image: ImageSource, options: ExtractionOptions, cacheKey: AnyHashable?) {
        self.image = image
        self.options = options
        self.cacheKey = cacheKey
    }

    func hash(into hasher: inout Hasher) {
        switch image {
        case .url(let url):
            hasher.combine(0)
            hasher.combine(url.absoluteString)
        case .data(let data):
            hasher.combine(1)
            // Hash data identity, not contents — caller opts in to content
            // dedup via explicit cacheKey.
            hasher.combine(ObjectIdentifier(data as NSData))
        case .cgImage(let img):
            hasher.combine(2)
            hasher.combine(ObjectIdentifier(img))
        }
        // ExtractionOptions does not conform to Hashable; fold every
        // observable field manually so cache keys invalidate when any
        // option that affects the palette changes. `collectTimings` is
        // cosmetic and intentionally skipped.
        hasher.combine(options.colorCount)
        hasher.combine(options.quality.hashKey)
        hasher.combine(options.colorSpace.hashKey)
        hasher.combine(options.ignoreWhite)
        hasher.combine(options.whiteThreshold)
        hasher.combine(options.alphaThreshold)
        hasher.combine(options.minSaturation)
        hasher.combine(options.fallbackStrategy.hashKey)
        hasher.combine(options.autoOrient)
        options.downsample.combine(into: &hasher)
        hasher.combine(options.quantizer.hashKey)
        if let key = cacheKey {
            hasher.combine(key)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    /// True when caller-supplied cacheKey OR URL source enables caching.
    var isCacheable: Bool {
        if cacheKey != nil { return true }
        if case .url = image { return true }
        return false
    }
}

/// Shared loader used by both ``AsyncPaletteGraphic`` (SwiftUI) and
/// ``AsyncPaletteGraphicView`` (UIKit). Owns the in-flight `Task`,
/// integrates with ``PaletteCache``, and publishes a 4-state machine.
@MainActor
final class AsyncPaletteGraphicLoader: ObservableObject {
    @Published private(set) var phase: ResolutionPhase = .empty

    /// Telemetry callback fired on extraction failure (not on cancellation).
    var onFailure: ((any Error) -> Void)?
    /// Telemetry callback fired on successful resolution. The third
    /// parameter is `true` when the result came from ``PaletteCache``
    /// (synchronous resolution, no transition); `false` when newly
    /// extracted.
    var onSuccess: ((Palette, SwatchMap?, _ fromCache: Bool) -> Void)?

    private var task: Task<Void, Never>?
    private var lastContext: ResolutionContext?
    private let extractor = PaletteExtractor()

    /// Trigger a load. Cache hit lands in `.success` synchronously; miss
    /// transitions to `.loading` and kicks off an extraction `Task`.
    /// Cancels any in-flight `Task` for a previous context.
    func load(context: ResolutionContext, cache: PaletteCache?) {
        // Same context as last call — short-circuit unless we're in a
        // restartable phase (caller can retry .failure or .empty by
        // re-invoking load).
        if context == lastContext {
            switch phase {
            case .success, .loading:
                return
            case .empty, .failure:
                break
            }
        }

        task?.cancel()
        lastContext = context

        // Cache hit path — synchronous resolution.
        if let cache, context.isCacheable, let entry = cache.entry(forKey: context.hashValue) {
            phase = .success(palette: entry.palette, swatches: entry.swatches, fromCache: true)
            onSuccess?(entry.palette, entry.swatches, true)
            return
        }

        // Cache miss path — go async.
        phase = .loading
        let extractor = self.extractor
        let onSuccessCallback = onSuccess
        let onFailureCallback = onFailure
        task = Task { [weak self] in
            do {
                let palette = try await extractor.palette(from: context.image, options: context.options)
                let swatches = try? await extractor.swatches(from: context.image, options: context.options)
                try Task.checkCancellation()
                guard let self else { return }
                if let cache, context.isCacheable {
                    cache.set(palette: palette, swatches: swatches, forKey: context.hashValue)
                }
                self.phase = .success(palette: palette, swatches: swatches, fromCache: false)
                onSuccessCallback?(palette, swatches, false)
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                self.phase = .failure(error)
                onFailureCallback?(error)
            }
        }
    }

    /// Like ``load(context:cache:)`` but bypasses the same-context
    /// short-circuit. Use when the underlying source has changed in a
    /// way the context can't see (e.g., on-disk file rewrite for a URL
    /// that hashes the same).
    func forceLoad(context: ResolutionContext, cache: PaletteCache?) {
        lastContext = nil
        load(context: context, cache: cache)
    }

    /// Cancel any in-flight resolution. Safe to call repeatedly.
    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}

// MARK: - ColorSpace hashing helper

private extension ColorSpace {
    var hashKey: Int {
        switch self {
        case .sRGB: return 0
        case .displayP3: return 1
        case .oklch: return 2
        }
    }
}

private extension Quality {
    var hashKey: Int { strideValue }
}

private extension FallbackStrategy {
    var hashKey: Int {
        switch self {
        case .relax: return 0
        case .fail: return 1
        case .averageOnly: return 2
        }
    }
}

private extension Downsample {
    func combine(into hasher: inout Hasher) {
        switch self {
        case .disabled:
            hasher.combine(0)
        case .automatic(let maxPixels):
            hasher.combine(1)
            hasher.combine(maxPixels)
        case .maxEdge(let edge):
            hasher.combine(2)
            hasher.combine(edge)
        }
    }
}

private extension QuantizerSelection {
    /// `.custom` only contributes its case discriminant — the underlying
    /// `any Quantizer` is opaque. Callers using `.custom` should pass an
    /// explicit `cacheKey` if they need cache differentiation.
    var hashKey: Int {
        switch self {
        case .auto: return 0
        case .cpu: return 1
        case .metal: return 2
        case .custom: return 3
        }
    }
}
#endif
