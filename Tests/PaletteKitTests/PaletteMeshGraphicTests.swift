#if canImport(SwiftUI) && canImport(UIKit)
import Testing
import SwiftUI
@testable import PaletteKit

@Suite("PaletteMeshGraphic (view)")
struct PaletteMeshGraphicViewTests {
    private let palette = Palette(
        colors: [
            PaletteColor(r: 240, g: 100, b: 100),
            PaletteColor(r: 100, g: 240, b: 100),
            PaletteColor(r: 100, g: 100, b: 240),
            PaletteColor(r: 230, g: 230, b: 30),
            PaletteColor(r: 30, g: 230, b: 230),
            PaletteColor(r: 230, g: 30, b: 230),
            PaletteColor(r: 240, g: 240, b: 240),
            PaletteColor(r: 120, g: 120, b: 120),
            PaletteColor(r: 20, g: 20, b: 20),
        ],
        colorSpaceUsed: .oklch
    )

    @Test("stores palette, configuration as passed")
    @available(iOS 18.0, *)
    func initStoresInputs() {
        let cfg = PaletteMeshGraphic.Configuration(gridSize: .rich)
        let view = PaletteMeshGraphic(palette: palette, configuration: cfg)
        #expect(view.palette.colors.count == 9)
        #expect(view.configuration == cfg)
    }

    @Test("makeImage returns a non-nil image at a reasonable size")
    @MainActor
    @available(iOS 18.0, *)
    func makeImageReturnsImage() {
        let view = PaletteMeshGraphic(palette: palette)
        let image = view.makeImage(size: CGSize(width: 64, height: 64))
        #expect(image != nil)
        #expect((image?.size.width ?? 0) > 0)
    }

    @Test("makeImage returns nil for zero size")
    @MainActor
    @available(iOS 18.0, *)
    func makeImageNilForZeroSize() {
        let view = PaletteMeshGraphic(palette: palette)
        #expect(view.makeImage(size: .zero) == nil)
        #expect(view.makeImage(size: CGSize(width: 64, height: 0)) == nil)
        #expect(view.makeImage(size: CGSize(width: 0, height: 64)) == nil)
    }

    @Test("makeImage returns nil for zero scale")
    @MainActor
    @available(iOS 18.0, *)
    func makeImageNilForZeroScale() {
        let view = PaletteMeshGraphic(palette: palette)
        #expect(view.makeImage(size: CGSize(width: 64, height: 64), scale: 0) == nil)
    }

    @Test("makeImage scale is reflected in the resulting UIImage")
    @MainActor
    @available(iOS 18.0, *)
    func makeImageRespectsScale() {
        let view = PaletteMeshGraphic(palette: palette)
        let img = view.makeImage(size: CGSize(width: 32, height: 32), scale: 3)
        #expect(abs((img?.scale ?? 0) - 3.0) < 1e-6)
    }

    @Test("makeImage is deterministic for identical inputs")
    @MainActor
    @available(iOS 18.0, *)
    func makeImageDeterministic() {
        let view = PaletteMeshGraphic(palette: palette)
        let img1 = view.makeImage(size: CGSize(width: 96, height: 96))
        let img2 = view.makeImage(size: CGSize(width: 96, height: 96))
        #expect(img1 != nil)
        #expect(img2 != nil)
        let png1 = img1?.pngData()
        let png2 = img2?.pngData()
        #expect(png1 != nil)
        #expect(png2 != nil)
        #expect(png1 == png2)
    }

    @Test("renders for all grid sizes without crashing")
    @MainActor
    @available(iOS 18.0, *)
    func rendersAllGrids() {
        for grid in [PaletteMeshGraphic.GridSize.compact, .standard, .rich] {
            let view = PaletteMeshGraphic(
                palette: palette,
                configuration: .init(gridSize: grid)
            )
            let img = view.makeImage(size: CGSize(width: 48, height: 48))
            #expect(img != nil, "grid \(grid) returned nil")
        }
    }
}
#endif
