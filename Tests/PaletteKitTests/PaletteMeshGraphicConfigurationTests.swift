#if canImport(SwiftUI) && canImport(UIKit)
import Testing
@testable import PaletteKit

@Suite("PaletteMeshGraphic.GridSize")
struct PaletteMeshGraphicGridSizeTests {
    @Test("GridSize.compact has 2x2 dimensions and 4 colors")
    @available(iOS 18.0, *)
    func compact() {
        let s = PaletteMeshGraphic.GridSize.compact
        #expect(s.width == 2)
        #expect(s.height == 2)
        #expect(s.colorCount == 4)
    }

    @Test("GridSize.standard has 3x3 dimensions and 9 colors")
    @available(iOS 18.0, *)
    func standard() {
        let s = PaletteMeshGraphic.GridSize.standard
        #expect(s.width == 3)
        #expect(s.height == 3)
        #expect(s.colorCount == 9)
    }

    @Test("GridSize.rich has 4x4 dimensions and 16 colors")
    @available(iOS 18.0, *)
    func rich() {
        let s = PaletteMeshGraphic.GridSize.rich
        #expect(s.width == 4)
        #expect(s.height == 4)
        #expect(s.colorCount == 16)
    }
}

@Suite("PaletteMeshGraphic.Configuration")
struct PaletteMeshGraphicConfigurationTests {
    @Test("default Configuration uses standard grid")
    @available(iOS 18.0, *)
    func defaults() {
        let c = PaletteMeshGraphic.Configuration()
        #expect(c.gridSize == .standard)
    }

    @Test("Configuration is Equatable")
    @available(iOS 18.0, *)
    func equality() {
        let a = PaletteMeshGraphic.Configuration(gridSize: .compact)
        let b = PaletteMeshGraphic.Configuration(gridSize: .compact)
        let c = PaletteMeshGraphic.Configuration(gridSize: .standard)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Configuration is Hashable")
    @available(iOS 18.0, *)
    func hashable() {
        let a = PaletteMeshGraphic.Configuration(gridSize: .compact)
        let b = PaletteMeshGraphic.Configuration(gridSize: .compact)
        #expect(a.hashValue == b.hashValue)
    }
}
#endif
