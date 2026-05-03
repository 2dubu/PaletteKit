import PaletteKit
import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var uiImage: UIImage?
    @State private var imageData: Data?
    @State private var palette: Palette?
    @State private var swatches: SwatchMap?
    @State private var errorMessage: String?
    @State private var isExtracting = false

    @State private var options = ExtractionOptions(
        colorCount: 10,
        colorSpace: .oklch,
        quantizer: .auto,
        collectTimings: true
    )
    @State private var showOptionsSheet = false

    @State private var extractionTask: Task<Void, Never>?

    private let extractor = PaletteExtractor()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    photoPicker

                    if let uiImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    resultStack
                        .opacity(isExtracting && hasResultToShow ? 0.5 : 1.0)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                .padding()
            }
            .navigationTitle("PaletteKit Demo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showOptionsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Extraction options")
                    .disabled(isExtracting || imageData == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        BenchView()
                    } label: {
                        Image(systemName: "speedometer")
                    }
                    .accessibilityLabel("Benchmarks")
                }
            }
        }
        .onChange(of: pickedItem) { _, newValue in
            Task { await loadImage(from: newValue) }
        }
        .sheet(isPresented: $showOptionsSheet) {
            ExtractionOptionsSheet(initialOptions: options) { updated in
                options = updated
                triggerExtraction()
            }
        }
    }

    private var hasResultToShow: Bool {
        palette != nil || swatches != nil
    }

    @ViewBuilder
    private var resultStack: some View {
        if isExtracting && !hasResultToShow {
            ProgressView("Extracting palette…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else if hasResultToShow {
            VStack(alignment: .leading, spacing: 20) {
                if isExtracting {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Re-extracting…").font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let swatches {
                    SwatchesView(swatches: swatches)
                }

                if let palette, !palette.isEmpty {
                    PaletteGrid(palette: palette)
                }

                if let palette, let dominant = palette.dominant {
                    DominantColorView(color: dominant)
                }

                if let palette, let timings = palette.timings {
                    TimingsView(timings: timings)
                }

                if let palette, !palette.isEmpty {
                    cardEntry(palette: palette)
                }
            }
        }
    }

    @ViewBuilder
    private func cardEntry(palette: Palette) -> some View {
        NavigationLink {
            CardLabView(palette: palette, swatches: swatches)
        } label: {
            HStack {
                Image(systemName: "wand.and.rays")
                Text("Generate Graphic")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var photoPicker: some View {
        PhotosPicker(
            selection: $pickedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            PhotoPickerLabel(hasImage: uiImage != nil)
        }
        .disabled(isExtracting)
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not decode the selected photo."
                return
            }
            self.uiImage = image
            self.imageData = data
            triggerExtraction()
        } catch {
            errorMessage = "Could not load the selected photo: \(error)"
        }
    }

    private func triggerExtraction() {
        extractionTask?.cancel()
        extractionTask = Task { await runExtraction() }
    }

    private func runExtraction() async {
        guard let imageData else { return }
        isExtracting = true
        defer { isExtracting = false }
        errorMessage = nil

        do {
            async let paletteResult = extractor.palette(from: .data(imageData), options: options)
            async let swatchesResult = extractor.swatches(from: .data(imageData), options: options)

            let resolvedPalette = try await paletteResult
            try Task.checkCancellation()
            let resolvedSwatches = try await swatchesResult
            try Task.checkCancellation()

            self.palette = resolvedPalette
            self.swatches = resolvedSwatches
        } catch is CancellationError {
            // Superseded by a newer extraction; keep previous state visible.
        } catch {
            errorMessage = "Extraction failed: \(error)"
        }
    }
}
