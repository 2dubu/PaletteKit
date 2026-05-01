import PaletteKit
import SwiftUI

struct SwatchesView: View {
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
                .fill(backgroundStyle)
                .frame(height: 90)
                .overlay(
                    VStack(alignment: .leading) {
                        Text(role.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(titleStyle)
                        Spacer()
                        Text(copied ? "Copied" : (swatch?.color.hex ?? "—"))
                            .font(.caption2.monospaced())
                            .foregroundStyle(bodyStyle)
                            .contentTransition(.opacity)
                    }
                    .padding(8),
                    alignment: .topLeading
                )
                .overlay {
                    if copied {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(bodyStyle)
                            .shadow(radius: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(swatch == nil)
    }

    private var backgroundStyle: AnyShapeStyle {
        swatch.map { AnyShapeStyle($0.color) } ?? AnyShapeStyle(Color.gray.opacity(0.15))
    }

    private var titleStyle: AnyShapeStyle {
        swatch.map { AnyShapeStyle($0.titleTextColor) } ?? AnyShapeStyle(Color.primary)
    }

    private var bodyStyle: AnyShapeStyle {
        swatch.map { AnyShapeStyle($0.bodyTextColor) } ?? AnyShapeStyle(Color.primary)
    }
}
