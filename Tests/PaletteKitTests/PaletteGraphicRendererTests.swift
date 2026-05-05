#if canImport(UIKit)
import Testing
import CoreGraphics
@testable import PaletteKit

@Suite("PaletteGraphicRenderer")
struct PaletteGraphicRendererTests {
    private let palette = Palette(
        colors: [
            PaletteColor(r: 200, g: 80, b: 40),
            PaletteColor(r: 150, g: 110, b: 90),
            PaletteColor(r: 70, g: 50, b: 35),
            PaletteColor(r: 30, g: 20, b: 10)
        ],
        colorSpaceUsed: .oklch
    )

    @Test("resolveStopColors with count=2 returns [first, last] anchors")
    func twoStopAnchors() {
        let (center, edge) = PaletteGraphicRenderer.resolveAnchors(
            palette: palette, swatches: nil, strategy: .vibrant
        )
        let stops = PaletteGraphicRenderer.resolveStopColors(
            palette: palette, swatches: nil, center: center, edge: edge, count: 2
        )
        #expect(stops.count == 2)
        #expect(stops.first?.luminance ?? 0 >= stops.last?.luminance ?? 1)
    }

    @Test("resolveStopColors monotonic luminance for any count")
    func monotonicLuminance() {
        let (center, edge) = PaletteGraphicRenderer.resolveAnchors(
            palette: palette, swatches: nil, strategy: .vibrant
        )
        for count in 2...5 {
            let stops = PaletteGraphicRenderer.resolveStopColors(
                palette: palette, swatches: nil, center: center, edge: edge, count: count
            )
            for i in 1..<stops.count {
                #expect(stops[i].luminance <= stops[i - 1].luminance,
                        "non-monotonic at count=\(count), i=\(i)")
            }
        }
    }

    @Test("cumulative bisection: count N stops are subset of count N+1 stops (anchors invariant)")
    func cumulativeProperty() {
        let (center, edge) = PaletteGraphicRenderer.resolveAnchors(
            palette: palette, swatches: nil, strategy: .vibrant
        )
        for count in 2...4 {
            let small = PaletteGraphicRenderer.resolveStopColors(
                palette: palette, swatches: nil, center: center, edge: edge, count: count
            )
            let big = PaletteGraphicRenderer.resolveStopColors(
                palette: palette, swatches: nil, center: center, edge: edge, count: count + 1
            )
            #expect(small.first?.hex == big.first?.hex)
            #expect(small.last?.hex == big.last?.hex)
        }
    }

    @Test("makeCGImage returns non-nil for a valid palette + small size")
    func makeCGImageHappyPath() {
        let configuration = PaletteGraphic.Configuration()
        let cg = PaletteGraphicRenderer.makeCGImage(
            palette: palette,
            swatches: nil,
            configuration: configuration,
            pixelSize: CGSize(width: 64, height: 64)
        )
        #expect(cg != nil)
    }

    @Test("makeCGImage returns the same CGImage instance on cache hit")
    func cacheReturnsIdentity() {
        let configuration = PaletteGraphic.Configuration()
        let size = CGSize(width: 64, height: 64)
        let first = PaletteGraphicRenderer.makeCGImage(
            palette: palette, swatches: nil,
            configuration: configuration, pixelSize: size
        )
        let second = PaletteGraphicRenderer.makeCGImage(
            palette: palette, swatches: nil,
            configuration: configuration, pixelSize: size
        )
        #expect(first === second, "expected NSCache to return same CGImage")
    }
}
#endif
