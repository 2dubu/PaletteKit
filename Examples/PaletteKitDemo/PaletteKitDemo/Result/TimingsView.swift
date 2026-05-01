import PaletteKit
import SwiftUI

struct TimingsView: View {
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
