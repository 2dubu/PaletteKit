#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI

/// SwiftUI palette-driven graphic that loads its source asynchronously.
///
/// `AsyncPaletteGraphic` is the async-loading sibling of
/// ``PaletteGraphic``: pass an ``ImageSource`` (URL, raw data, CGImage)
/// and the view extracts the palette internally before rendering.
///
/// Two init styles:
///
/// **Simple** — auto-renders ``PaletteGraphic`` on success, shows a
/// placeholder during loading and on failure:
///
/// ```swift
/// AsyncPaletteGraphic(image: .url(url)) {
///     Color.gray.opacity(0.1)  // placeholder
/// }
/// ```
///
/// **Phase-based** (mirrors `AsyncImage`) — caller renders every
/// resolution phase, enabling telemetry, secondary UI composition,
/// custom error rendering, etc:
///
/// ```swift
/// AsyncPaletteGraphic(image: .url(url)) { phase in
///     switch phase {
///     case .empty, .loading: ProgressView()
///     case .success(let palette, let swatches, _):
///         HStack {
///             PaletteGraphic(palette: palette, swatches: swatches, configuration: .init())
///             swatchChipBar(palette)
///         }
///     case .failure(let error):
///         Text(error.localizedDescription)
///     }
/// }
/// ```
///
/// For a UIKit equivalent see ``AsyncPaletteGraphicView``.
@MainActor
public struct AsyncPaletteGraphic<Content: View>: View {
    private let image: ImageSource
    private let extractionOptions: ExtractionOptions
    private let cache: PaletteCache?
    private let cacheKey: AnyHashable?
    private let onFailure: ((any Error) -> Void)?
    private let content: (AsyncPaletteGraphicPhase) -> Content

    @StateObject private var loader = AsyncPaletteGraphicLoader()
    @Environment(\.asyncPaletteGraphicTransition) private var transition

    /// Internal designated init — both public inits delegate here.
    init(
        image: ImageSource,
        extractionOptions: ExtractionOptions,
        cache: PaletteCache?,
        cacheKey: AnyHashable?,
        onFailure: ((any Error) -> Void)?,
        @ViewBuilder content: @escaping (AsyncPaletteGraphicPhase) -> Content
    ) {
        self.image = image
        self.extractionOptions = extractionOptions
        self.cache = cache
        self.cacheKey = cacheKey
        self.onFailure = onFailure
        self.content = content
    }

    /// Phase-based init. Caller renders every resolution phase. Mirrors
    /// `AsyncImage(url:scale:transaction:content:)`'s phase overload —
    /// no callback parameters (observe via the phase itself).
    public init(
        image: ImageSource,
        extractionOptions: ExtractionOptions = .init(),
        cache: PaletteCache? = .shared,
        cacheKey: AnyHashable? = nil,
        @ViewBuilder content: @escaping (AsyncPaletteGraphicPhase) -> Content
    ) {
        self.init(
            image: image,
            extractionOptions: extractionOptions,
            cache: cache,
            cacheKey: cacheKey,
            onFailure: nil,
            content: content
        )
    }

    public var body: some View {
        let context = ResolutionContext(
            image: image, options: extractionOptions, cacheKey: cacheKey
        )
        ZStack {
            content(loader.phase)
                .modifier(TransitionAnimationModifier(
                    transition: shouldAnimate ? transition : nil
                ))
        }
        .task(id: context) {
            loader.onFailure = onFailure
            loader.load(context: context, cache: cache)
        }
    }

    private var shouldAnimate: Bool {
        if case .success(_, _, let fromCache) = loader.phase {
            return !fromCache
        }
        return false
    }
}

// MARK: - Convenience init (auto-render PaletteGraphic + placeholder)

extension AsyncPaletteGraphic where Content == AnyView {
    /// Convenience init that auto-renders ``PaletteGraphic`` on success
    /// and shows ``placeholder`` during loading and on failure. Use the
    /// phase-based init when you need to observe phases or compose
    /// secondary UI alongside the resolved graphic.
    ///
    /// `swatchStrategy` is no longer a top-level parameter; set it via
    /// `configuration.swatchStrategy` on the supplied `Configuration`.
    public init<Placeholder: View>(
        image: ImageSource,
        extractionOptions: ExtractionOptions = .init(),
        configuration: PaletteGraphic.Configuration = .init(),
        cache: PaletteCache? = .shared,
        cacheKey: AnyHashable? = nil,
        onFailure: ((any Error) -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.init(
            image: image,
            extractionOptions: extractionOptions,
            cache: cache,
            cacheKey: cacheKey,
            onFailure: onFailure
        ) { phase in
            AnyView(
                Group {
                    switch phase {
                    case .success(let palette, let swatches, _):
                        PaletteGraphic(
                            palette: palette,
                            swatches: swatches,
                            configuration: configuration
                        )
                    case .empty, .loading, .failure:
                        placeholder()
                    }
                }
            )
        }
    }

    /// Convenience init with default placeholder (`Color.clear`).
    public init(
        image: ImageSource,
        extractionOptions: ExtractionOptions = .init(),
        configuration: PaletteGraphic.Configuration = .init(),
        cache: PaletteCache? = .shared,
        cacheKey: AnyHashable? = nil,
        onFailure: ((any Error) -> Void)? = nil
    ) {
        self.init(
            image: image,
            extractionOptions: extractionOptions,
            configuration: configuration,
            cache: cache,
            cacheKey: cacheKey,
            onFailure: onFailure,
            placeholder: { Color.clear }
        )
    }
}

// MARK: - Transition wrapper

/// Applies the env-derived cross-fade animation to the resolved graphic
/// only on async resolutions (cache hit → no transition).
private struct TransitionAnimationModifier: ViewModifier {
    let transition: AsyncPaletteGraphicTransition?

    func body(content: Content) -> some View {
        if let transition {
            content.transition(.opacity.animation(transition.animation))
        } else {
            content
        }
    }
}
#endif
