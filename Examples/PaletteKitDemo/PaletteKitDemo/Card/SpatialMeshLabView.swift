@_spi(SpatialPrototype) import PaletteKit
import SwiftUI
import UIKit

/// Lets callers try the spatial path with their own picked image. The original
/// Mesh Lab remains unchanged; this comparison normalizes both inputs equally.
@available(iOS 18.0, *)
struct SpatialMeshLabView: View {
    let imageData: Data
    let originalImage: UIImage

    @State private var grid: SpatialMesh.Grid = .three
    @State private var analysis: Analysis?
    @State private var errorMessage: String?
    @State private var shareImage: UIImage?
    @State private var showShare = false

    private struct Analysis: Sendable {
        let palette: Palette
        let three: SpatialMesh
        let four: SpatialMesh
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Keep the color layout of your image. Small details may soften.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Picker("Grid size", selection: $grid) {
                    Text("3 × 3").tag(SpatialMesh.Grid.three)
                    Text("4 × 4").tag(SpatialMesh.Grid.four)
                }
                .pickerStyle(.segmented)

                if let analysis {
                    let mesh = grid == .three ? analysis.three : analysis.four
                    preview("Original") {
                        Image(uiImage: originalImage).resizable().scaledToFit()
                    }
                    preview("Palette layout") {
                        PaletteMeshGraphic(palette: analysis.palette,
                            configuration: .init(gridSize: grid == .three ? .standard : .rich))
                            .aspectRatio(mesh.aspectRatio, contentMode: .fit)
                    }
                    preview("Image layout · Experimental") {
                        SpatialMeshGraphic(mesh: mesh)
                    }
                    Button {
                        let width = min(1080, 1080 * mesh.aspectRatio)
                        shareImage = SpatialMeshGraphic(mesh: mesh).makeImage(width: width, scale: 1)
                        if shareImage != nil { showShare = true }
                        else { errorMessage = "Could not export this image." }
                    } label: {
                        Label("Share image layout", systemImage: "square.and.arrow.up")
                    }
                } else if errorMessage == nil {
                    ProgressView("Preparing comparison…")
                        .frame(maxWidth: .infinity).padding()
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }.padding()
        }
        .navigationTitle("Image Mesh")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: imageData) { await load() }
        // Capture during body evaluation so the first presentation gets the new image.
        .sheet(isPresented: $showShare) { [shareImage] in
            if let shareImage { ShareSheet(items: [shareImage]) }
        }
    }

    private func preview<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            content()
                .frame(maxWidth: .infinity, maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @MainActor
    private func load() async {
        analysis = nil
        errorMessage = nil
        let data = imageData
        let work = Task.detached(priority: .userInitiated) {
            let normalized = try SpatialMeshAnalyzer.normalizedImage(.data(data))
            let palette = try await PaletteExtractor().palette(from: .cgImage(normalized.image),
                options: ExtractionOptions(colorCount: 10, quality: .highest, colorSpace: .oklch,
                    ignoreWhite: false, downsample: .disabled, quantizer: .cpu))
            let three = try SpatialMeshAnalyzer.analyze(.data(data), grid: .three)
            let four = try SpatialMeshAnalyzer.analyze(.data(data), grid: .four)
            return Analysis(palette: palette, three: three, four: four)
        }
        do {
            let value = try await withTaskCancellationHandler {
                try await work.value
            } onCancel: {
                work.cancel()
            }
            try Task.checkCancellation()
            analysis = value
        } catch is CancellationError {
            // Leaving the screen cancels analysis and never publishes stale work.
        } catch {
            errorMessage = "Could not prepare the image comparison: \(error.localizedDescription)"
        }
    }
}
