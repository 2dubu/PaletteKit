#if canImport(UIKit)
import UIKit

/// UIKit palette-driven graphic that loads its source asynchronously.
///
/// `AsyncPaletteGraphicView` is the async-loading sibling of
/// ``PaletteGraphicView``: assign an ``ImageSource`` to ``imageSource``
/// and the view extracts the palette internally before rendering. While
/// extraction is in flight (or if it fails) ``placeholderView`` is shown.
///
/// For SwiftUI consumers see ``AsyncPaletteGraphic``.
///
/// ```swift
/// let view = AsyncPaletteGraphicView(frame: .zero)
/// view.imageSource = .url(url)
/// view.placeholderView = UIView()  // your custom placeholder
/// view.onSuccess = { palette, swatches in /* analytics */ }
/// ```
///
/// When using inside `UICollectionViewCell`, call ``cancel()`` from
/// `prepareForReuse` and clear ``imageSource``.
@MainActor
public final class AsyncPaletteGraphicView: UIView {

    /// Controls the UIKit cross-fade applied when the resolved graphic
    /// appears for the first time (cache hits are never animated).
    public struct Transition: Equatable, Sendable {
        /// Duration of the cross-fade animation in seconds.
        public let duration: TimeInterval
        /// UIKit animation options applied to the transition.
        public let options: UIView.AnimationOptions

        private init(duration: TimeInterval, options: UIView.AnimationOptions) {
            self.duration = duration
            self.options = options
        }

        /// Standard 0.20 s cross-dissolve — the default.
        public static let normal: Self = .init(duration: 0.20, options: .transitionCrossDissolve)
        /// Slower 0.35 s cross-dissolve for emphasis.
        public static let slow: Self = .init(duration: 0.35, options: .transitionCrossDissolve)
        /// 0.50 s cross-dissolve for very deliberate reveals.
        public static let extraSlow: Self = .init(duration: 0.50, options: .transitionCrossDissolve)
    }

    // MARK: - Configuration

    /// The image to resolve into a palette. Setting this triggers an
    /// extraction unless the context (source + options + cacheKey) has not
    /// changed since the last load.
    public var imageSource: ImageSource? { didSet { reloadIfNeeded() } }

    /// Options forwarded to the palette extractor. Changing this re-triggers
    /// extraction when combined with a new effective context.
    public var extractionOptions: ExtractionOptions = .init() { didSet { reloadIfNeeded() } }

    /// Rendering configuration applied to the inner `PaletteGraphicView`
    /// once a palette is resolved. Safe to mutate after resolution.
    public var configuration: PaletteGraphic.Configuration = .init() {
        didSet { applyConfigurationIfResolved() }
    }

    /// Swatch strategy used when building the rendered graphic.
    /// Exposed as a top-level property for ergonomics; folded into
    /// `configuration` before constructing the inner view.
    public var swatchStrategy: SwatchStrategy = .vibrant {
        didSet { applyConfigurationIfResolved() }
    }

    /// Cache consulted before starting an extraction. Set to `nil` to
    /// bypass caching entirely. Defaults to `PaletteCache.shared`.
    public var cache: PaletteCache? = .shared

    /// Caller-supplied stable key that enables cache deduplication for
    /// non-URL sources (`.data`, `.cgImage`). Setting this re-checks the
    /// cache and may trigger a reload.
    public var cacheKey: AnyHashable? { didSet { reloadIfNeeded() } }

    /// Cross-fade applied when the resolved graphic first appears.
    /// Set to `nil` to disable animation. Cache hits are never animated
    /// regardless of this value.
    public var transition: Transition? = .normal

    /// Custom placeholder shown during loading and on failure.
    /// Set to `nil` (default) to show a clear `UIView`.
    public var placeholderView: UIView? {
        didSet { swapPlaceholderIfNeeded(old: oldValue) }
    }

    /// Called on the main actor after successful palette resolution.
    public var onSuccess: ((Palette, SwatchMap?) -> Void)?

    /// Called on the main actor when extraction fails (not on cancellation).
    public var onFailure: ((any Error) -> Void)?

    // MARK: - Internals

    private let loader = AsyncPaletteGraphicLoader()
    private var graphicView: PaletteGraphicView?
    private var defaultPlaceholder: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        return v
    }()
    private var lastContext: ResolutionContext?

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        installPlaceholder(defaultPlaceholder)
        bindLoader()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("AsyncPaletteGraphicView does not support NSCoding")
    }

    // MARK: - Public API

    /// Force re-extraction even when source is unchanged. Use after the
    /// underlying image data changes in a way the source identity can't
    /// see (e.g., on-disk file rewrite at the same URL).
    public func reload() {
        guard let imageSource else { return }
        let context = ResolutionContext(
            image: imageSource, options: extractionOptions, cacheKey: cacheKey
        )
        lastContext = context
        loader.forceLoad(context: context, cache: cache)
    }

    /// Cancel any in-flight palette extraction. Safe to call repeatedly.
    ///
    /// Call this from `UICollectionViewCell.prepareForReuse` before
    /// clearing ``imageSource`` to avoid stale callbacks.
    public func cancel() {
        loader.cancel()
    }

    // MARK: - Wiring

    private func bindLoader() {
        loader.onFailure = { [weak self] error in
            self?.onFailure?(error)
        }
        loader.onSuccess = { [weak self] palette, swatches, fromCache in
            self?.onSuccess?(palette, swatches)
            self?.handleSuccess(palette: palette, swatches: swatches, fromCache: fromCache)
        }
    }

    private func reloadIfNeeded() {
        guard let imageSource else {
            cancel()
            lastContext = nil
            return
        }
        let context = ResolutionContext(
            image: imageSource, options: extractionOptions, cacheKey: cacheKey
        )
        if context == lastContext { return }
        lastContext = context
        loader.load(context: context, cache: cache)
    }

    private func handleSuccess(palette: Palette, swatches: SwatchMap?, fromCache: Bool) {
        var cfg = configuration
        cfg.swatchStrategy = swatchStrategy
        let resolved = PaletteGraphicView(
            palette: palette, swatches: swatches, configuration: cfg
        )
        resolved.translatesAutoresizingMaskIntoConstraints = false

        let swap = { [weak self] in
            guard let self else { return }
            self.graphicView?.removeFromSuperview()
            self.installPlaceholder(self.placeholderView ?? self.defaultPlaceholder)
            self.addSubview(resolved)
            NSLayoutConstraint.activate([
                resolved.topAnchor.constraint(equalTo: self.topAnchor),
                resolved.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                resolved.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                resolved.trailingAnchor.constraint(equalTo: self.trailingAnchor)
            ])
            self.graphicView = resolved
        }

        if let transition, !fromCache {
            UIView.transition(
                with: self,
                duration: transition.duration,
                options: transition.options,
                animations: swap
            )
        } else {
            swap()
        }
    }

    private func applyConfigurationIfResolved() {
        graphicView?.configuration = {
            var cfg = configuration
            cfg.swatchStrategy = swatchStrategy
            return cfg
        }()
    }

    private func installPlaceholder(_ view: UIView) {
        for sub in subviews where sub !== graphicView { sub.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func swapPlaceholderIfNeeded(old: UIView?) {
        // Only swap visible placeholder; if a graphic is currently shown,
        // the new placeholder will be installed on the next loading transition.
        guard graphicView == nil else { return }
        old?.removeFromSuperview()
        installPlaceholder(placeholderView ?? defaultPlaceholder)
    }
}
#endif
