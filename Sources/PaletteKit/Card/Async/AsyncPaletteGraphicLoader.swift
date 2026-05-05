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
    case failure(Error)
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
        // ExtractionOptions does not currently conform to Hashable; fold
        // its observable fields manually. Update if Hashable is added.
        hasher.combine(options.colorCount)
        hasher.combine(options.colorSpace.hashKey)
        hasher.combine(options.ignoreWhite)
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
    var onFailure: ((Error) -> Void)?
    /// Telemetry callback fired on successful resolution (cache hit OR miss).
    var onSuccess: ((Palette, SwatchMap?) -> Void)?

    private var task: Task<Void, Never>?
    private var lastContext: ResolutionContext?
    private let extractor = PaletteExtractor()

    /// Trigger a load. Cache hit lands in `.success` synchronously; miss
    /// transitions to `.loading` and kicks off an extraction `Task`.
    /// Cancels any in-flight `Task` for a previous context.
    func load(context: ResolutionContext, cache: PaletteCache?) {
        // Same context as last call — no work needed unless cache was cleared.
        if context == lastContext, case .success = phase { return }

        task?.cancel()
        lastContext = context

        // Cache hit path — synchronous resolution.
        if let cache, context.isCacheable, let entry = cache.entry(forKey: context.hashValue) {
            phase = .success(palette: entry.palette, swatches: entry.swatches, fromCache: true)
            onSuccess?(entry.palette, entry.swatches)
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
                onSuccessCallback?(palette, swatches)
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                self.phase = .failure(error)
                onFailureCallback?(error)
            }
        }
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
#endif
