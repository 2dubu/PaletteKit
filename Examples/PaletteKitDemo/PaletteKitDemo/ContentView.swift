import PaletteKit
import PhotosUI
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var uiImage: UIImage?
    @State private var palette: Palette?
    @State private var swatches: SwatchMap?
    @State private var errorMessage: String?
    @State private var isExtracting = false

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

                    if isExtracting {
                        ProgressView("Extracting palette…")
                    }

                    if let palette, let dominant = palette.dominant {
                        DominantColorView(color: dominant)
                    }

                    if let palette, !palette.isEmpty {
                        PaletteGrid(palette: palette)
                    }

                    if let swatches {
                        SwatchesView(swatches: swatches)
                    }

                    if let palette, let timings = palette.timings {
                        TimingsView(timings: timings)
                    }

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
    }

    private var photoPicker: some View {
        PhotosPicker(
            selection: $pickedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label("Pick a photo", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        isExtracting = true
        defer { isExtracting = false }
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Could not decode the selected photo."
                return
            }
            self.uiImage = image

            let options = ExtractionOptions(
                colorCount: 10,
                colorSpace: .oklch,
                quantizer: .auto,
                collectTimings: true
            )
            async let paletteResult = extractor.palette(from: .data(data), options: options)
            async let swatchesResult = extractor.swatches(from: .data(data), options: options)
            self.palette = try await paletteResult
            self.swatches = try await swatchesResult
        } catch {
            errorMessage = "Extraction failed: \(error)"
        }
    }
}

private struct DominantColorView: View {
    let color: PaletteColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dominant")
                .font(.headline)
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.swiftUI)
                    .frame(height: 80)
                VStack(alignment: .leading) {
                    Text(color.hex).font(.title3.monospaced())
                    Text(String(format: "%.0f%%", color.proportion * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct PaletteGrid: View {
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Palette").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(Array(palette.colors.enumerated()), id: \.offset) { _, color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.swiftUI)
                            .frame(height: 56)
                        Text(color.hex)
                            .font(.caption2.monospaced())
                    }
                }
            }
        }
    }
}

private struct SwatchesView: View {
    let swatches: SwatchMap

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Swatches").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(SwatchRole.allCases, id: \.self) { role in
                    SwatchCard(role: role, swatch: swatches[role])
                }
            }
        }
    }
}

private struct SwatchCard: View {
    let role: SwatchRole
    let swatch: Swatch?

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(swatch?.color.swiftUI ?? Color.gray.opacity(0.15))
            .frame(height: 90)
            .overlay(
                VStack(alignment: .leading) {
                    Text(role.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(swatch?.titleTextColor.swiftUI ?? .primary)
                    Spacer()
                    Text(swatch?.color.hex ?? "—")
                        .font(.caption2.monospaced())
                        .foregroundStyle(swatch?.bodyTextColor.swiftUI ?? .primary)
                }
                .padding(8),
                alignment: .topLeading
            )
    }
}

private struct TimingsView: View {
    let timings: ExtractionTimings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Timings").font(.headline)
            row("decode", timings.decode)
            row("sample", timings.sample)
            row("quantize", timings.quantize)
            if let swatches = timings.swatches {
                row("swatches", swatches)
            }
            row("total", timings.total)
            HStack {
                Text("engine").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(timings.quantizerUsed).font(.caption.monospaced())
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ label: String, _ duration: Duration) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(duration)").font(.caption.monospaced())
        }
    }
}
