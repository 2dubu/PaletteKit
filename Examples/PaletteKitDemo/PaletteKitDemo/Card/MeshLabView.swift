import PaletteKit
import SwiftUI

@available(iOS 18.0, *)
struct MeshLabView: View {
    let palette: Palette

    @State private var gridSize: PaletteMeshGraphic.GridSize = .standard

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PaletteMeshGraphic(
                    palette: palette,
                    configuration: .init(gridSize: gridSize)
                )
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)

                gridPicker
                exportButton
            }
            .padding(.vertical)
        }
        .navigationTitle("Mesh")
    }

    private var gridPicker: some View {
        Picker("Grid size", selection: $gridSize) {
            Text("Compact (2\u{d7}2)").tag(PaletteMeshGraphic.GridSize.compact)
            Text("Standard (3\u{d7}3)").tag(PaletteMeshGraphic.GridSize.standard)
            Text("Rich (4\u{d7}4)").tag(PaletteMeshGraphic.GridSize.rich)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    @MainActor
    private var exportButton: some View {
        Button {
            let img = PaletteMeshGraphic(
                palette: palette,
                configuration: .init(gridSize: gridSize)
            ).makeImage(size: CGSize(width: 1080, height: 1080))
            if let img, let data = img.pngData() {
                let url = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("PaletteMesh-\(UUID().uuidString).png")
                try? data.write(to: url)
                print("Exported mesh to \(url.path)")
            }
        } label: {
            Label("Export as PNG", systemImage: "square.and.arrow.up")
        }
        .padding(.horizontal)
    }
}
