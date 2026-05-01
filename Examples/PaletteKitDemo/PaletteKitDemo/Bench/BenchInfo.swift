import SwiftUI

struct BenchInfo {
    let title: String
    let description: String
    let guidance: String

    static let autoDownsample = BenchInfo(
        title: "Auto downsample",
        description: """
PaletteKit's default behavior. Inputs above 1,000,000 pixels (≈1024²) \
are scaled down before quantization, so latency stays roughly flat \
regardless of input size. This is what your end users actually experience \
when calling palette(from:) without overrides.
""",
        guidance: "Enable to measure real-world user-facing latency."
    )

    static let rawDownsample = BenchInfo(
        title: "Raw (no downsample)",
        description: """
Disables auto-downsample so the full input pixel buffer is fed straight \
to the quantizer. Reveals the true cost of the CPU vs Metal histogram \
path at the actual pixel count — useful for validating the auto-gating \
threshold or comparing quantizer engines on raw work.
""",
        guidance: "Not a real-world UX scenario. Enable when comparing engines or stress-testing."
    )

    static let include8K = BenchInfo(
        title: "Include 8192²",
        description: """
Adds an 8K (67M pixel) row to every quantizer × downsample combination. \
Each run holds ≈256 MB of raw pixel memory before downsampling.
""",
        guidance: "Recommended only on devices with 8 GB+ RAM (iPhone 15 Pro and up, iPad M-series)."
    )

    static let warmupRuns = BenchInfo(
        title: "Warmup runs",
        description: """
Runs to discard before measurement begins. The first call to a Metal \
quantizer compiles the shader and builds pipeline state — that one-time \
cost would pollute steady-state numbers if measured. CPU has smaller \
cold-cache effects on its first call too.
""",
        guidance: "1 is right for most cases. Set to 0 to include cold-start cost in samples."
    )

    static let measuredRuns = BenchInfo(
        title: "Measured runs",
        description: """
Runs collected after warmup, used to compute p50, p95, min, and max. \
Five is enough for a stable median; more gives smoother percentiles but \
exposes thermal throttling on long sessions.
""",
        guidance: "3 = quick check, 5 = normal, 10 = exposes thermal effects."
    )

    static let source = BenchInfo(
        title: "Source image",
        description: """
What gets fed to the quantizer.

Synthesized — a deterministic image (gradient + 5 colored blobs + \
per-pixel noise) generated in memory at each grid size. Same content \
on every run. No file decode is exercised.

Photo — a photo you pick from your library, decoded externally and \
center-cropped & resized to each grid size before being passed to \
PaletteKit as a CGImage. Measures the quantizer on real color \
distributions; bypasses the library's ImageIO decode path.

Photo Data — same picked photo, but the raw HEIC/JPEG bytes are \
passed straight to PaletteKit. The library's ImageIO thumbnail \
fast-path runs on the original file. Compare against Photo to see \
how much that fast-path saves.
""",
        guidance: "Synthesized = reproducible cross-device comparisons. Photo = realistic quantizer cost on a known size. Photo Data = realistic end-to-end latency (decode + downsample + quantize) for a typical user call."
    )

    static let runNote = BenchInfo(
        title: "Run note",
        description: """
Free-text label attached to the run. It shows up in the CSV header so \
that exports from the same device under different conditions stay \
distinguishable when you collect them later.
""",
        guidance: "Examples: \"quiet, room temp\", \"after a 10-min game\", \"low-power mode on\"."
    )
}

/// Tappable info chip used next to a Configuration row label.
/// Shows the explanation as a popover (compact-adapted on iPhone).
struct InfoButton: View {
    let info: BenchInfo
    @State private var presented = false

    var body: some View {
        Button {
            presented = true
        } label: {
            Image(systemName: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $presented) {
            VStack(alignment: .leading, spacing: 12) {
                Text(info.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(info.description)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                Text(info.guidance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(width: 300, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
}
