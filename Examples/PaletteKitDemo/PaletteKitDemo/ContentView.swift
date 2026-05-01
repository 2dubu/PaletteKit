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
            }
        }
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

private struct PhotoPickerLabel: View {
    let hasImage: Bool

    var body: some View {
        if hasImage {
            Label("Change photo", systemImage: "photo.on.rectangle")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .foregroundStyle(.tint)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.tint)
                Text("Choose a photo")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Tap to pick from your library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        Color.accentColor.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                    )
            )
        }
    }
}

private struct DominantColorView: View {
    let color: PaletteColor
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dominant")
                .font(.headline)
            Button(action: copyHex) {
                HStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.swiftUI)
                        .frame(height: 80)
                        .overlay {
                            if copied {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)
                            }
                        }
                    VStack(alignment: .leading) {
                        Text(copied ? "Copied" : color.hex)
                            .font(.title3.monospaced())
                            .foregroundStyle(copied ? .green : .primary)
                            .contentTransition(.opacity)
                        Text(String(format: "%.0f%%", color.proportion * 100))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func copyHex() {
        copyToPasteboard(color.hex, copied: $copied)
    }
}

private struct PaletteGrid: View {
    let palette: Palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Palette").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                ForEach(Array(palette.colors.enumerated()), id: \.offset) { _, color in
                    PaletteChip(color: color)
                }
            }
        }
    }
}

private struct PaletteChip: View {
    let color: PaletteColor
    @State private var copied = false

    var body: some View {
        Button {
            copyToPasteboard(color.hex, copied: $copied)
        } label: {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.swiftUI)
                    .frame(height: 56)
                    .overlay {
                        if copied {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                    }
                Text(copied ? "Copied" : color.hex)
                    .font(.caption2.monospaced())
                    .foregroundStyle(copied ? .green : .primary)
                    .contentTransition(.opacity)
            }
        }
        .buttonStyle(.plain)
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
    @State private var copied = false

    var body: some View {
        Button {
            guard let hex = swatch?.color.hex else { return }
            copyToPasteboard(hex, copied: $copied)
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(swatch?.color.swiftUI ?? Color.gray.opacity(0.15))
                .frame(height: 90)
                .overlay(
                    VStack(alignment: .leading) {
                        Text(role.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(swatch?.titleTextColor.swiftUI ?? .primary)
                        Spacer()
                        Text(copied ? "Copied" : (swatch?.color.hex ?? "—"))
                            .font(.caption2.monospaced())
                            .foregroundStyle(swatch?.bodyTextColor.swiftUI ?? .primary)
                            .contentTransition(.opacity)
                    }
                    .padding(8),
                    alignment: .topLeading
                )
                .overlay {
                    if copied {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(swatch?.bodyTextColor.swiftUI ?? .primary)
                            .shadow(radius: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(swatch == nil)
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

@MainActor
private func copyToPasteboard(_ hex: String, copied: Binding<Bool>) {
    UIPasteboard.general.string = hex
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    withAnimation(.easeInOut(duration: 0.15)) { copied.wrappedValue = true }
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.easeInOut(duration: 0.15)) { copied.wrappedValue = false }
    }
}
