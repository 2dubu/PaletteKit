import CoreGraphics
import PhotosUI
import SwiftUI

struct BenchSuiteView: View {
    @StateObject private var runner = BenchRunner()
    @State private var selectedScenarios: Set<String> = Set(BenchRunner.Scenario.comparisonSuite.map(\.id))
    @State private var sizes: BenchRunner.SuiteSizes = .quick
    @State private var warmupRuns: Int = 1
    @State private var measuredRuns: Int = 5
    @State private var runNote: String = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: CGImage?
    @State private var photoData: Data?
    @State private var photoOriginalSize: CGSize?
    @State private var photoLoadError: String?

    private let device = DeviceInfo.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                deviceCard
                scenarioCard
                if scenariosNeedPhoto { photoCard }
                runControls
                progressBlock
                if !runner.summaries.isEmpty { summaryByScenario }
            }
            .padding()
        }
        .navigationTitle("Suite")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
    }

    // MARK: Sections

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Device").font(.caption).foregroundStyle(.secondary)
            Text(device.marketingName).font(.headline)
            Text("\(device.model) · \(device.osVersion)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var scenarioCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scenarios").font(.headline)
            ForEach(BenchRunner.Scenario.comparisonSuite) { scenario in
                Toggle(isOn: binding(for: scenario.id)) {
                    Text(scenario.label).font(.footnote)
                }
            }

            Divider()

            HStack {
                Text("Sizes").font(.footnote)
                Spacer()
                Picker("Sizes", selection: $sizes) {
                    Text("Full").tag(BenchRunner.SuiteSizes.full)
                    Text("Quick").tag(BenchRunner.SuiteSizes.quick)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Stepper(value: $warmupRuns, in: 0...3) {
                Text("Warmup runs: \(warmupRuns)").font(.footnote)
            }
            Stepper(value: $measuredRuns, in: 1...10) {
                Text("Measured runs: \(measuredRuns)").font(.footnote)
            }
            TextField("Run note (optional)", text: $runNote)
                .textFieldStyle(.roundedBorder)
                .font(.footnote)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)

            Text(estimateLabel).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(runner.isRunning)
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                photoThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    if let s = photoOriginalSize {
                        Text("\(Int(s.width))×\(Int(s.height))").font(.caption.monospaced())
                    } else {
                        Text("No photo selected").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Used for Photo / Photo Data scenarios")
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
                Text(err).font(.caption2).foregroundStyle(.red)
            }
        }
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(runner.isRunning)
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
                .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
    }

    private var runControls: some View {
        HStack(spacing: 12) {
            primaryButton
            secondaryButton
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if !runner.summaries.isEmpty && !runner.isRunning {
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
                start()
            } label: {
                Label("Run Suite", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(runner.isRunning || !canRun)
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
        } else if !runner.summaries.isEmpty {
            Menu {
                ShareLink(item: rawCSVFile()) { Label("Raw CSV", systemImage: "tablecells") }
                ShareLink(item: summaryCSVFile()) { Label("Summary CSV", systemImage: "table") }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var progressBlock: some View {
        switch runner.phase {
        case .idle:
            EmptyView()
        case .running(let i, let total, let label):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("\(i)/\(total)").font(.caption.monospaced()).foregroundStyle(.secondary)
                    ProgressView().controlSize(.mini)
                    Spacer()
                }
                Text(label)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        case .finished:
            Label("Finished", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let msg):
            Label(msg, systemImage: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private var summaryByScenario: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(orderedScenarios, id: \.self) { scenarioId in
                scenarioBlock(scenarioId: scenarioId)
            }
        }
    }

    private func scenarioBlock(scenarioId: String) -> some View {
        let rows = runner.summaries.filter { $0.scenario == scenarioId }
        let label = BenchRunner.Scenario.comparisonSuite.first { $0.id == scenarioId }?.label ?? scenarioId
        return VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("size")
                    Text("q")
                    Text("ds")
                    Text("p50").gridColumnAlignment(.trailing)
                    Text("p95").gridColumnAlignment(.trailing)
                }
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

                ForEach(rows) { s in
                    GridRow {
                        Text(s.benchCase.pixelSide == 0 ? "orig" : "\(s.benchCase.pixelSide)²")
                        Text(s.benchCase.quantizer.rawValue)
                        Text(s.benchCase.downsample.rawValue)
                        Text(fmt(s.totalP50ms)).gridColumnAlignment(.trailing)
                        Text(fmt(s.totalP95ms)).gridColumnAlignment(.trailing)
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

    // MARK: Helpers

    private var scenariosNeedPhoto: Bool {
        BenchRunner.Scenario.comparisonSuite.contains {
            selectedScenarios.contains($0.id) && $0.requiresPhoto
        }
    }

    private var canRun: Bool {
        guard !selectedScenarios.isEmpty else { return false }
        let needsImage = BenchRunner.Scenario.comparisonSuite.contains {
            selectedScenarios.contains($0.id) && $0.sourceKind == .photo
        }
        let needsData = BenchRunner.Scenario.comparisonSuite.contains {
            selectedScenarios.contains($0.id) && $0.sourceKind == .photoData
        }
        if needsImage && photoImage == nil { return false }
        if needsData && photoData == nil { return false }
        return true
    }

    private var orderedScenarios: [String] {
        BenchRunner.Scenario.comparisonSuite
            .map(\.id)
            .filter { id in runner.summaries.contains { $0.scenario == id } }
    }

    private var estimateLabel: String {
        let scenarios = BenchRunner.Scenario.comparisonSuite.filter { selectedScenarios.contains($0.id) }
        let cases = scenarios.reduce(0) { acc, sc in
            let cfg = BenchRunner.Configuration(
                includeAutoDownsample: sc.includeAuto,
                includeRawDownsample: sc.includeRaw,
                include8K: false,
                warmupRuns: warmupRuns,
                measuredRuns: measuredRuns,
                runNote: "",
                sourceKind: sc.sourceKind
            )
            return acc + BenchRunner.makeCases(configuration: cfg, suiteSides: sizes.sides).count
        }
        let runs = cases * (warmupRuns + measuredRuns)
        return "\(scenarios.count) scenarios · \(cases) cases · \(runs) runs"
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { selectedScenarios.contains(id) },
            set: { isOn in
                if isOn { selectedScenarios.insert(id) }
                else { selectedScenarios.remove(id) }
            }
        )
    }

    private func start() {
        let scenarios = BenchRunner.Scenario.comparisonSuite.filter { selectedScenarios.contains($0.id) }
        runner.runSuite(
            scenarios: scenarios,
            sizes: sizes,
            warmupRuns: warmupRuns,
            measuredRuns: measuredRuns,
            runNote: runNote,
            photoImage: photoImage,
            photoData: photoData,
            photoOriginalSize: photoOriginalSize
        )
    }

    private func performReset() {
        runner.reset()
        selectedScenarios = Set(BenchRunner.Scenario.comparisonSuite.map(\.id))
        sizes = .quick
        warmupRuns = 1
        measuredRuns = 5
        runNote = ""
        photoItem = nil
        photoImage = nil
        photoData = nil
        photoOriginalSize = nil
        photoLoadError = nil
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            photoImage = nil
            photoData = nil
            photoOriginalSize = nil
            return
        }
        photoLoadError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                photoLoadError = "Could not decode the selected photo."
                return
            }
            photoImage = cgImage
            photoData = data
            photoOriginalSize = CGSize(width: cgImage.width, height: cgImage.height)
        } catch {
            photoLoadError = "Photo load failed: \(error.localizedDescription)"
        }
    }

    private func fmt(_ ms: Double) -> String {
        if ms < 10 { return String(format: "%.2f", ms) }
        return String(format: "%.0f", ms)
    }

    private func filenameTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: runner.startedAt ?? Date())
    }

    private func rawCSVFile() -> URL {
        BenchExport.writeToTemp(
            name: "palettekit-suite-raw-\(filenameTimestamp()).csv",
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
            name: "palettekit-suite-summary-\(filenameTimestamp()).csv",
            contents: BenchExport.summaryCSV(
                device: device,
                runNote: runner.runNote,
                sourceDescription: runner.sourceDescription,
                summaries: runner.summaries
            )
        )
    }
}
