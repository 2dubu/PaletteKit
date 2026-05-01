import SwiftUI

struct PhotoPickerLabel: View {
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
