#if canImport(UIKit)
import Testing
import UIKit
@testable import PaletteKit

@MainActor
@Suite("AsyncPaletteGraphicView configuration")
struct AsyncPaletteGraphicViewConfigurationTests {
    @Test("configuration strategy reaches the resolved graphic", arguments: SwatchStrategy.allCases)
    func configurationBeforeResolution(strategy: SwatchStrategy) throws {
        let (view, source) = makeCachedView()
        view.configuration.swatchStrategy = strategy
        view.imageSource = source

        let graphic = try resolvedGraphic(in: view)
        #expect(graphic.configuration.swatchStrategy == strategy)
        #expect(view.swatchStrategy == strategy)
    }

    @Test("the latest strategy assignment wins through either public property")
    func assignmentOrder() throws {
        let (view, source) = makeCachedView()
        view.swatchStrategy = .muted
        #expect(view.configuration.swatchStrategy == .muted)
        view.configuration = .init(swatchStrategy: .contrast)
        view.imageSource = source

        let graphic = try resolvedGraphic(in: view)
        #expect(graphic.configuration.swatchStrategy == .contrast)
        #expect(view.swatchStrategy == .contrast)

        view.swatchStrategy = .vibrant
        #expect(graphic.configuration.swatchStrategy == .vibrant)
        #expect(view.configuration.swatchStrategy == .vibrant)

        view.configuration.swatchStrategy = .muted
        #expect(graphic.configuration.swatchStrategy == .muted)
        #expect(view.swatchStrategy == .muted)
        #expect(try resolvedGraphic(in: view) === graphic)
    }

    private func resolvedGraphic(in view: AsyncPaletteGraphicView) throws -> PaletteGraphicView {
        try #require(view.subviews.compactMap { $0 as? PaletteGraphicView }.first)
    }

    private func makeCachedView() -> (AsyncPaletteGraphicView, ImageSource) {
        let source = ImageSource.cgImage(AsyncTestSupport.makeSolidImage(rgb: (200, 80, 40)))
        let view = AsyncPaletteGraphicView(frame: .zero)
        let cache = PaletteCache(countLimit: 4)
        let key = "configuration-fixture"
        let context = ResolutionContext(image: source, options: .init(), cacheKey: key)
        cache.set(palette: AsyncTestSupport.makePalette(), swatches: nil, forKey: context.storageKey)
        view.cache = cache
        view.cacheKey = key
        view.transition = nil
        return (view, source)
    }
}
#endif
