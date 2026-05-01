import CoreGraphics
import PhotosUI
import SwiftUI

struct BenchView: View {
    @StateObject private var runner = BenchRunner()
    @State private var configuration = BenchRunner.Configuration()

    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: CGImage?
    @State private var photoData: Data?
    @State private var photoOriginalSize: CGSize?
    @State private var photoLoadError: String?
    @State private var isLoadingPhoto = false

    private let device = DeviceInfo.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                deviceCard

                configurationCard

                controlsRow

                progressView

                if !runner.summaries.isEmpty {
                    summaryTable
                    BenchChart(summaries: runner.summaries)
                }

                if !runner.samples.isEmpty {
                    rawSamplesTable
                }
            }
            .padding()
        }
        .navigationTitle("Benchmarks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    BenchSuiteView()
                } label: {
                    Image(systemName: "play.square.stack")
                }
                .accessibilityLabel("Run Suite")
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            photoImage = nil
            photoData = nil
            photoOriginalSize = nil
            return
        }
        isLoadingPhoto = true
        photoLoadError = nil
        defer { isLoadingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                photoLoadError = "Could not decode the selected photo."
                photoImage = nil
                photoData = nil
                photoOriginalSize = nil
                return
            }
            photoImage = cgImage
            photoData = data
            photoOriginalSize = CGSize(width: cgImage.width, height: cgImage.height)
        } catch {
            photoLoadError = "Photo load failed: \(error.localizedDescription)"
            photoImage = nil
            photoData = nil
            photoOriginalSize = nil
        }
    }

    // MARK: - Sections

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Device").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(device.marketingName).font(.headline)
                Spacer()
                Text("\(device.processorCount) cores").font(.caption).foregroundStyle(.secondary)
            }
            Text("\(device.model) · \(device.osVersion)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Configuration").font(.headline)

            sourceSection

            Divider()

            configToggle(
                "Auto downsample (1M cap, real-world)",
                isOn: $configuration.includeAutoDownsample,
                info: .autoDownsample
            )
            configToggle(
                "Raw (no downsample, GPU stress)",
                isOn: $configuration.includeRawDownsample,
                info: .rawDownsample
            )
            if configuration.sourceKind == .synthesized {
                configToggle(
                    "Include 8192² (high memory)",
                    isOn: $configuration.include8K,
                    info: .include8K
                )
            }
            configStepper(
                "Warmup runs: \(configuration.warmupRuns)",
                value: $configuration.warmupRuns,
                in: 0...3,
                info: .warmupRuns
            )
            configStepper(
                "Measured runs: \(configuration.measuredRuns)",
                value: $configuration.measuredRuns,
                in: 1...10,
                info: .measuredRuns
            )

            HStack(spacing: 6) {
                Text("Run note").font(.footnote)
                InfoButton(info: .runNote)
                Spacer()
            }
            TextField(
                "optional — e.g. \"quiet, room temp\"",
                text: $configuration.runNote
            )
            .textFieldStyle(.roundedBorder)
            .font(.footnote)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)

            Text(estimateLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(runner.isRunning)
    }

    @ViewBuilder
    private var sourceSection: some View {
        HStack(spacing: 6) {
            Text("Source").font(.footnote)
            InfoButton(info: .source)
            Spacer()
        }
        Picker("Source", selection: $configuration.sourceKind) {
            Text("Synthesized").tag(BenchRunner.Configuration.SourceKind.synthesized)
            Text("Photo").tag(BenchRunner.Configuration.SourceKind.photo)
            Text("Photo Data").tag(BenchRunner.Configuration.SourceKind.photoData)
        }
        .pickerStyle(.segmented)
        .font(.footnote)

        if configuration.sourceKind == .photo || configuration.sourceKind == .photoData {
            photoPickerRow
        }
    }

    private var photoPickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                photoThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    if let size = photoOriginalSize {
                        Text("\(Int(size.width))×\(Int(size.height))")
                            .font(.caption.monospaced())
                    } else if isLoadingPhoto {
                        Text("Loading…").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No photo selected").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("center-cropped & resized to each grid size")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                PhotosPicker(
                    selection: $photoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label(photoImage == nil ? "Pick" : "Change", systemImage: "photo")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
            }
            if let err = photoLoadError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var photoThumbnail: some View {
        if let cgImage = photoImage {
            Image(decorative: cgImage, scale: 1, orientation: .up)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.tertiary)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func configToggle(
        _ title: String,
        isOn: Binding<Bool>,
        info: BenchInfo
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 6) {
                Text(title).font(.footnote)
                InfoButton(info: info)
            }
        }
    }

    private func configStepper(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        info: BenchInfo
    ) -> some View {
        Stepper(value: value, in: range) {
            HStack(spacing: 6) {
                Text(title).font(.footnote)
                InfoButton(info: info)
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            primaryButton
            secondaryButton
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if hasResults && !runner.isRunning {
            Button(role: .destructive) {
                performReset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        } else {
            Button {
                runner.run(
                    configuration: configuration,
                    photoImage: photoImage,
                    photoData: photoData,
                    photoOriginalSize: photoOriginalSize
                )
            } label: {
                Label("Run", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(runner.isRunning || !canRun)
        }
    }

    private var canRun: Bool {
        switch configuration.sourceKind {
        case .synthesized: return true
        case .photo: return photoImage != nil
        case .photoData: return photoData != nil
        }
    }

    @ViewBuilder
    private var secondaryButton: some View {
        if runner.isRunning {
            Button(role: .destructive) {
                runner.cancel()
            } label: {
                Label("Cancel", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        } else if hasResults {
            shareMenu
        }
    }

    private var hasResults: Bool {
        !runner.samples.isEmpty
    }

    private func performReset() {
        runner.reset()
        configuration = BenchRunner.Configuration()
        photoItem = nil
        photoImage = nil
        photoData = nil
        photoOriginalSize = nil
        photoLoadError = nil
    }

    private var shareMenu: some View {
        Menu {
            ShareLink(item: rawCSVFile()) { Label("Raw CSV", systemImage: "tablecells") }
            ShareLink(item: summaryCSVFile()) { Label("Summary CSV", systemImage: "table") }
            Button(role: .destructive) {
                runner.reset()
            } label: {
                Label("Clear results", systemImage: "trash")
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var progressView: some View {
        switch runner.phase {
        case .idle:
            EmptyView()
        case .running(let i, let total, let label):
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    Text("\(i)/\(total)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    ProgressView()
                        .controlSize(.mini)
                    Spacer()
                    Text(label)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if runner.failureCount > 0 {
                    failureChip(count: runner.failureCount, message: runner.firstFailureMessage)
                }
            }
        case .finished:
            if runner.failureCount > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        "Finished with \(runner.failureCount) failure\(runner.failureCount == 1 ? "" : "s")",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    if let msg = runner.firstFailureMessage {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .padding(.leading, 28)
                    }
                }
            } else {
                Label("Finished", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .failed(let msg):
            Label(msg, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }

    private func failureChip(count: Int, message: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(
                "\(count) failed run\(count == 1 ? "" : "s") so far",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption2)
            .foregroundStyle(.orange)
            if let message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .padding(.leading, 22)
            }
        }
    }

    private var summaryTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary (post-warmup)").font(.headline)
            Text("ms · p50 = median, p95 = tail")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("size")
                    Text("q")
                    Text("ds")
                    Text("p50").gridColumnAlignment(.trailing)
                    Text("p95").gridColumnAlignment(.trailing)
                    Text("max").gridColumnAlignment(.trailing)
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

                ForEach(runner.summaries) { s in
                    GridRow {
                        HStack(spacing: 4) {
                            Text("\(s.benchCase.pixelSide)²")
                            if s.errorCount > 0 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        Text(s.benchCase.quantizer.rawValue)
                        Text(s.benchCase.downsample.rawValue)
                        Text(fmt(s.totalP50ms)).gridColumnAlignment(.trailing)
                        Text(fmt(s.totalP95ms)).gridColumnAlignment(.trailing)
                        Text(fmt(s.totalMaxMs)).gridColumnAlignment(.trailing)
                    }
                    .font(.caption2.monospaced())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var rawSamplesTable: some View {
        DisclosureGroup("Raw samples (\(runner.samples.count)) — total ms per run") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(runner.samples) { s in
                    HStack(spacing: 6) {
                        if s.isWarmup {
                            Text("w").foregroundStyle(.tertiary)
                        }
                        Text(s.caseId)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 4)
                        if let err = s.errorMessage {
                            Text(err)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            HStack(spacing: 2) {
                                Text(fmt(s.totalSeconds * 1000)).monospacedDigit()
                                Text("ms").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .font(.caption2.monospaced())
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var estimateLabel: String {
        let cases = BenchRunner.makeCases(configuration: configuration)
        let runs = cases.count * (configuration.warmupRuns + configuration.measuredRuns)
        return "\(cases.count) cases · \(runs) runs"
    }

    private func fmt(_ ms: Double) -> String {
        if ms < 10 { return String(format: "%.2f", ms) }
        return String(format: "%.0f", ms)
    }

    private func rawCSVFile() -> URL {
        BenchExport.writeToTemp(
            name: "palettekit-bench-raw-\(filenameTimestamp()).csv",
            contents: BenchExport.rawCSV(
                device: device,
                startedAt: runner.startedAt,
                runNote: runner.runNote,
                sourceDescription: runner.sourceDescription,
                samples: runner.samples
            )
        )
    }

    private func summaryCSVFile() -> URL {
        BenchExport.writeToTemp(
            name: "palettekit-bench-summary-\(filenameTimestamp()).csv",
            contents: BenchExport.summaryCSV(
                device: device,
                runNote: runner.runNote,
                sourceDescription: runner.sourceDescription,
                summaries: runner.summaries
            )
        )
    }

    private func filenameTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: runner.startedAt ?? Date())
    }
}
