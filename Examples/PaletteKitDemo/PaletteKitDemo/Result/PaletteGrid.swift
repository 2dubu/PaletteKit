import PaletteKit
import SwiftUI

struct PaletteGrid: View {
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
