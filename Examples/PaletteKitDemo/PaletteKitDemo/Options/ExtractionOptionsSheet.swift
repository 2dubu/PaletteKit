import PaletteKit
import SwiftUI

struct ExtractionOptionsSheet: View {
    let initialOptions: ExtractionOptions
    let onDone: (ExtractionOptions) -> Void

    @State private var working: ExtractionOptions
    @State private var colorSpaceKind: ColorSpaceKind
    @State private var quantizerKind: QuantizerKind
    @State private var downsampleKind: DownsampleKindUI
    @State private var downsampleMaxPixels: Int
    @State private var downsampleMaxEdge: Int

    @Environment(\.dismiss) private var dismiss

    init(initialOptions: ExtractionOptions, onDone: @escaping (ExtractionOptions) -> Void) {
        self.initialOptions = initialOptions
        self.onDone = onDone

        _working = State(initialValue: initialOptions)
        _colorSpaceKind = State(initialValue: ColorSpaceKind(initialOptions.colorSpace))
        _quantizerKind = State(initialValue: QuantizerKind(initialOptions.quantizer))

        let kind: DownsampleKindUI
        var mp = 1_000_000
        var me = 1024
        switch initialOptions.downsample {
        case .automatic(let value):
            kind = .automatic
            mp = value
        case .maxEdge(let value):
            kind = .maxEdge
            me = value
        case .disabled:
            kind = .disabled
        }
        _downsampleKind = State(initialValue: kind)
        _downsampleMaxPixels = State(initialValue: mp)
        _downsampleMaxEdge = State(initialValue: me)
    }

    var body: some View {
        NavigationStack {
            Form {
                resultSection
                samplingSection
                performanceSection
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { resetToDefaults() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { commitAndDismiss() }
                        .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var resultSection: some View {
        Section("Result") {
            Stepper(value: $working.colorCount, in: 2...20) {
                LabeledContent("Color count", value: "\(working.colorCount)")
            }
            LabeledContent {
                Picker("", selection: $colorSpaceKind) {
                    ForEach(ColorSpaceKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
            } label: {
                HelpLabel(title: "Color space", help: """
                    Where palette colors live in.

                    • OKLCH (default) — quantize in OKLCH for perceptually-even palettes; output stays in the source space (sRGB or Display P3).
                    • Display P3 — quantize in RGB; force output to wide-gamut Display P3.
                    • sRGB — quantize in RGB; force output to standard sRGB. Use for color-thief v2 parity.
                    """)
            }
        }
    }

    private var samplingSection: some View {
        Section("Sampling") {
            qualityRow
            Toggle(isOn: $working.ignoreWhite) {
                HelpLabel(
                    title: "Ignore white pixels",
                    help: "Filters out near-white pixels (above whiteThreshold) so a white background doesn't dominate the palette."
                )
            }
            minSaturationRow
        }
    }

    private var performanceSection: some View {
        Section("Performance") {
            downsampleRow
            LabeledContent {
                Picker("", selection: $quantizerKind) {
                    ForEach(QuantizerKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
            } label: {
                HelpLabel(title: "Quantizer", help: """
                    Which engine groups pixels into the final colors.

                    • Auto / CPU — MMCQ on CPU. Default and recommended.
                    • Metal — GPU compute shader. Only worth it for raw mode (downsample disabled) on ≥4MP input. Falls back to CPU if Metal is unavailable.
                    """)
            }
            if quantizerKind == .metal {
                metalHint
            }
        }
    }

    private var qualityRow: some View {
        let stride = strideValue(working.quality)
        return VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                Text("\(stride)")
            } label: {
                HelpLabel(
                    title: "Sampling stride",
                    help: "How many pixels are skipped between samples. 1 = read every pixel (slow, precise). Higher values are faster but less precise."
                )
            }
            Slider(
                value: Binding(
                    get: { Double(stride) },
                    set: { working.quality = .stride(max(1, Int($0.rounded()))) }
                ),
                in: 1...20,
                step: 1
            )
        }
    }

    private func strideValue(_ quality: Quality) -> Int {
        switch quality {
        case .stride(let value): return max(1, value)
        }
    }

    private var minSaturationRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                Text(String(format: "%.2f", working.minSaturation))
            } label: {
                HelpLabel(
                    title: "Min saturation",
                    help: "Filters out grayish pixels below this HSL saturation. 0 = keep all (default). Raise to skip muted backgrounds and keep only vivid colors."
                )
            }
            Slider(value: $working.minSaturation, in: 0...1, step: 0.05)
        }
    }

    private var downsampleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent {
                Picker("", selection: $downsampleKind) {
                    ForEach(DownsampleKindUI.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
            } label: {
                HelpLabel(title: "Downsample", help: """
                    How many pixels make it into quantization.

                    • Auto (max pixels) — bound the total pixel count (default 1MP). Best balance for typical photos.
                    • Max edge — cap longest side instead. Useful if you care about a specific resolution.
                    • Disabled — process every pixel. Slowest, most accurate.
                    """)
            }
            switch downsampleKind {
            case .automatic:
                LabeledContent("Max pixels", value: downsampleMaxPixels.formatted())
                Slider(
                    value: Binding(
                        get: { Double(downsampleMaxPixels) },
                        set: { downsampleMaxPixels = Int($0.rounded()) }
                    ),
                    in: 100_000 ... 4_000_000,
                    step: 100_000
                )
            case .maxEdge:
                LabeledContent("Max edge (px)", value: "\(downsampleMaxEdge)")
                Slider(
                    value: Binding(
                        get: { Double(downsampleMaxEdge) },
                        set: { downsampleMaxEdge = Int($0.rounded()) }
                    ),
                    in: 256 ... 4096,
                    step: 64
                )
            case .disabled:
                Text("Process every pixel — slowest, most accurate.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var metalHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
            Text("Metal helps with raw mode + ≥4MP input. At default settings the speedup is within measurement noise.")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
    }

    private func resetToDefaults() {
        let defaults = ExtractionOptions(collectTimings: working.collectTimings)
        working = defaults
        colorSpaceKind = ColorSpaceKind(defaults.colorSpace)
        quantizerKind = QuantizerKind(defaults.quantizer)
        downsampleKind = .automatic
        downsampleMaxPixels = 1_000_000
        downsampleMaxEdge = 1024
    }

    private func commitAndDismiss() {
        var out = working
        out.colorSpace = colorSpaceKind.colorSpace
        out.quantizer = quantizerKind.selection
        out.downsample = composedDownsample()
        onDone(out)
        dismiss()
    }

    private func composedDownsample() -> Downsample {
        switch downsampleKind {
        case .disabled: return .disabled
        case .automatic: return .automatic(maxPixels: downsampleMaxPixels)
        case .maxEdge: return .maxEdge(downsampleMaxEdge)
        }
    }
}

private struct HelpLabel: View {
    let title: String
    let help: String

    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Button {
                showHelp = true
            } label: {
                Image(systemName: "info.circle")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Help: \(title)")
            .popover(isPresented: $showHelp) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(help)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(width: 300, alignment: .leading)
                .presentationCompactAdaptation(.popover)
            }
        }
    }
}

enum ColorSpaceKind: String, Hashable, CaseIterable, Identifiable {
    case oklch
    case displayP3
    case sRGB

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oklch: return "OKLCH"
        case .displayP3: return "Display P3"
        case .sRGB: return "sRGB"
        }
    }

    var colorSpace: ColorSpace {
        switch self {
        case .oklch: return .oklch
        case .displayP3: return .displayP3
        case .sRGB: return .sRGB
        }
    }

    init(_ space: ColorSpace) {
        switch space {
        case .oklch: self = .oklch
        case .displayP3: self = .displayP3
        case .sRGB: self = .sRGB
        }
    }
}

enum QuantizerKind: String, Hashable, CaseIterable, Identifiable {
    case auto
    case cpu
    case metal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto (CPU)"
        case .cpu: return "CPU"
        case .metal: return "Metal"
        }
    }

    var selection: QuantizerSelection {
        switch self {
        case .auto: return .auto
        case .cpu: return .cpu
        case .metal: return .metal
        }
    }

    init(_ selection: QuantizerSelection) {
        switch selection {
        case .auto: self = .auto
        case .cpu: self = .cpu
        case .metal: self = .metal
        case .custom: self = .auto
        }
    }
}

enum DownsampleKindUI: String, Hashable, CaseIterable, Identifiable {
    case automatic
    case disabled
    case maxEdge

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "Auto (max pixels)"
        case .disabled: return "Disabled"
        case .maxEdge: return "Max edge"
        }
    }
}

#Preview("Default") {
    ExtractionOptionsSheet(initialOptions: ExtractionOptions(collectTimings: true)) { _ in }
}

#Preview("Metal selected") {
    ExtractionOptionsSheet(
        initialOptions: ExtractionOptions(quantizer: .metal, collectTimings: true)
    ) { _ in }
}
