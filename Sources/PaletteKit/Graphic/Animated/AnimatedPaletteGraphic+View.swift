#if canImport(UIKit)
import SwiftUI

extension AnimatedPaletteGraphic: View {
    public var body: some View {
        Representable(palette: palette, configuration: configuration)
    }

    private struct Representable: UIViewRepresentable {
        let palette: Palette
        let configuration: Configuration

        func makeUIView(context: Context) -> AnimatedPaletteGraphicView {
            AnimatedPaletteGraphicView(palette: palette, configuration: configuration)
        }

        func updateUIView(_ view: AnimatedPaletteGraphicView, context: Context) {
            view.update(palette: palette, configuration: configuration)
        }
    }
}
#endif
