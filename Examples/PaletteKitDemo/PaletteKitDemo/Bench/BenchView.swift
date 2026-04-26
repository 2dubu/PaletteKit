import SwiftUI

struct BenchView: View {
    @StateObject private var runner = BenchRunner()
    @State private var configuration = BenchRunner.Configuration()

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
                }

                if !runner.samples.isEmpty {
                    rawSamplesTable
                }
            }
            .padding()
        }
        .navigationTitle("Benchmarks")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Device").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(device.model).font(.headline.monospaced())
                Spacer()
                Text("\(device.processorCount) cores").font(.caption).foregroundStyle(.secondary)
            }
            Text(device.osVersion).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Configuration").font(.headline)
            Toggle("Auto downsample (1M cap, real-world)", isOn: $configuration.includeAutoDownsample)
            Toggle("Raw (no downsample, GPU stress)", isOn: $configuration.includeRawDownsample)
            Toggle("Include 8192² (high memory)", isOn: $configuration.include8K)
            HStack {
                Stepper(
                    "Warmup runs: \(configuration.warmupRuns)",
                    value: $configuration.warmupRuns,
                    in: 0...3
                )
            }
            HStack {
                Stepper(
                    "Measured runs: \(configuration.measuredRuns)",
                    value: $configuration.measuredRuns,
                    in: 1...10
                )
            }
            Text(estimateLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(runner.isRunning)
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            Button {
                runner.run(configuration: configuration)
            } label: {
                Label("Run Benchmarks", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(runner.isRunning)

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
                shareMenu
            }
        }
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
        .menuStyle(.borderlessButton)
    }

    @ViewBuilder
    private var progressView: some View {
        switch runner.phase {
        case .idle:
            EmptyView()
        case .running(let i, let total, let label):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: Double(i), total: Double(total))
                Text("\(i)/\(total) · \(label)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        case .finished:
            Label("Finished", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let msg):
            Label(msg, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
        }
    }

    private var summaryTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Summary (post-warmup)").font(.headline)
            HStack {
                cellHeader("size", width: 70)
                cellHeader("q", width: 50)
                cellHeader("ds", width: 50)
                cellHeader("p50", width: 70)
                cellHeader("p95", width: 70)
                cellHeader("min", width: 60)
                cellHeader("max", width: 60)
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            ForEach(runner.summaries) { s in
                HStack {
                    cell("\(s.benchCase.pixelSide)²", width: 70)
                    cell(s.benchCase.quantizer.rawValue, width: 50)
                    cell(s.benchCase.downsample.rawValue, width: 50)
                    cell(fmt(s.totalP50ms), width: 70)
                    cell(fmt(s.totalP95ms), width: 70)
                    cell(fmt(s.totalMinMs), width: 60)
                    cell(fmt(s.totalMaxMs), width: 60)
                }
                .font(.caption.monospaced())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var rawSamplesTable: some View {
        DisclosureGroup("Raw samples (\(runner.samples.count))") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(runner.samples) { s in
                    HStack(spacing: 6) {
                        if s.isWarmup {
                            Text("warm").foregroundStyle(.tertiary)
                        }
                        Text(s.caseId).lineLimit(1)
                        Spacer()
                        if let err = s.errorMessage {
                            Text(err).foregroundStyle(.red).lineLimit(1)
                        } else {
                            Text(fmt(s.totalSeconds * 1000)).monospacedDigit()
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

    private func cellHeader(_ text: String, width: CGFloat) -> some View {
        Text(text).frame(width: width, alignment: .leading)
    }

    private func cell(_ text: String, width: CGFloat) -> some View {
        Text(text).frame(width: width, alignment: .leading)
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
                samples: runner.samples
            )
        )
    }

    private func summaryCSVFile() -> URL {
        BenchExport.writeToTemp(
            name: "palettekit-bench-summary-\(filenameTimestamp()).csv",
            contents: BenchExport.summaryCSV(
                device: device,
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
