import PaletteKit
import SwiftUI

struct DominantColorView: View {
    let color: PaletteColor
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dominant")
                .font(.headline)
            Button {
                copyToPasteboard(color.hex, copied: $copied)
            } label: {
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
}
