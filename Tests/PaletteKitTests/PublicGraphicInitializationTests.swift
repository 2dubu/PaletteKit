#if canImport(UIKit) && canImport(SwiftUI)
import PaletteKit
import Testing
import UIKit

@MainActor
@Suite("Public graphic initialization")
struct PublicGraphicInitializationTests {
    @Test("omitting swatches preserves palette-only rendering in SwiftUI and UIKit")
    func paletteOnlyRendering() throws {
        let palette = Palette(colors: [.white, .black], colorSpaceUsed: .sRGB)
        let configuration = PaletteGraphic.Configuration(grain: .none)
        let size = CGSize(width: 16, height: 16)

        let basicGraphic = PaletteGraphic(palette: palette)
        #expect(basicGraphic.resolvedStopColors.map(\.rgb) == [PaletteColor.white.rgb, PaletteColor.black.rgb])
        let graphic = PaletteGraphic(palette: palette, configuration: configuration)
        let explicitGraphic = PaletteGraphic(palette: palette, swatches: nil, configuration: configuration)
        let image = try #require(graphic.makeImage(size: size, scale: 1)?.pngData())
        #expect(image == explicitGraphic.makeImage(size: size, scale: 1)?.pngData())

        let basicView = PaletteGraphicView(palette: palette)
        basicView.frame.size = size
        #expect(basicView.snapshotImage(scale: 1) != nil)
        let view = PaletteGraphicView(palette: palette, configuration: configuration)
        view.frame.size = size
        let explicitView = PaletteGraphicView(palette: palette, swatches: nil, configuration: configuration)
        explicitView.frame.size = size
        let snapshot = try #require(view.snapshotImage(scale: 1)?.pngData())
        #expect(snapshot == explicitView.snapshotImage(scale: 1)?.pngData())
        #expect(snapshot == image)
    }
}
#endif
