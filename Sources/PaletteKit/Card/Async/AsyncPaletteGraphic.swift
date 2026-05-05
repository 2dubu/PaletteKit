#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI

/// SwiftUI palette-driven graphic that loads its source asynchronously.
///
/// `AsyncPaletteGraphic` is the async-loading sibling of
/// ``PaletteGraphic``: pass an ``ImageSource`` (URL, raw data, CGImage)
/// and the view extracts the palette internally before rendering. While
/// extraction is in flight (or if it fails) the placeholder slot is shown.
///
/// ```swift
/// AsyncPaletteGraphic(image: .url(url)) {
///     Color.gray.opacity(0.1)  // shown during loading and on failure
/// }
/// .frame(width: 320, height: 320)
/// .clipShape(RoundedRectangle(cornerRadius: 24))
/// ```
///
/// For a UIKit equivalent see ``AsyncPaletteGraphicView``.
@MainActor
public struct AsyncPaletteGraphic<Placeholder: View>: View {
    private let image: ImageSource
    private let extractionOptions: ExtractionOptions
    private let configuration: PaletteGraphic.Configuration
    private let swatchStrategy: SwatchStrategy
    private let cache: PaletteCache?
    private let cacheKey: AnyHashable?
    private let onFailure: ((any Error) -> Void)?
    private let placeholder: () -> Placeholder

    @StateObject private var loader = AsyncPaletteGraphicLoader()
    @Environment(\.asyncPaletteGraphicTransition) private var transition

    public init(
        image: ImageSource,
        extractionOptions: ExtractionOptions = .init(),
        configuration: PaletteGraphic.Configuration = .init(),
        swatchStrategy: SwatchStrategy = .vibrant,
        cache: PaletteCache? = .shared,
        cacheKey: AnyHashable? = nil,
        onFailure: ((any Error) -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.image = image
        self.extractionOptions = extractionOptions
        self.configuration = configuration
        self.swatchStrategy = swatchStrategy
        self.cache = cache
        self.cacheKey = cacheKey
        self.onFailure = onFailure
        self.placeholder = placeholder
    }

    public var body: some View {
        let context = ResolutionContext(
            image: image, options: extractionOptions, cacheKey: cacheKey
        )
        var resolvedConfiguration = configuration
        resolvedConfiguration.swatchStrategy = swatchStrategy
        return ZStack {
            switch loader.phase {
            case .empty, .loading, .failure:
                placeholder()
            case .success(let palette, let swatches, let fromCache):
                PaletteGraphic(
                    palette: palette,
                    swatches: swatches,
                    configuration: resolvedConfiguration
                )
                .modifier(TransitionAnimationModifier(
                    transition: fromCache ? nil : transition
                ))
            }
        }
        .task(id: context) {
            loader.onFailure = onFailure
            loader.load(context: context, cache: cache)
        }
    }
}

// MARK: - Convenience init (default placeholder = Color.clear)

extension AsyncPaletteGraphic where Placeholder == Color {
    /// Creates an `AsyncPaletteGraphic` with a transparent (`Color.clear`)
    /// placeholder. The placeholder is shown while the palette is being
    /// resolved and on failure.
    public init(
        image: ImageSource,
        extractionOptions: ExtractionOptions = .init(),
        configuration: PaletteGraphic.Configuration = .init(),
        swatchStrategy: SwatchStrategy = .vibrant,
        cache: PaletteCache? = .shared,
        cacheKey: AnyHashable? = nil,
        onFailure: ((any Error) -> Void)? = nil
    ) {
        self.init(
            image: image,
            extractionOptions: extractionOptions,
            configuration: configuration,
            swatchStrategy: swatchStrategy,
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
