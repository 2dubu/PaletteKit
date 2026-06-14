import PaletteKit
import PaletteKitInsights
import SwiftUI

@available(iOS 26, *)
struct InsightsLabView: View {
    let palette: Palette

    @State private var guidance = ""
    @State private var insights: PaletteInsights?
    @State private var errorText: String?
    @State private var isLoading = false

    private let generator = PaletteInsightsGenerator()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if generator.isAvailable {
                TextField("Guidance (optional)", text: $guidance)
                    .textFieldStyle(.roundedBorder)

                Button(isLoading ? "Generating…" : "Generate insights") {
                    Task { await generate() }
                }
                .disabled(isLoading)

                if let insights {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(insights.name).font(.headline)
                        Text(insights.summary).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if let errorText {
                    Text(errorText).font(.footnote).foregroundStyle(.red)
                }
            } else {
                Text("Apple Intelligence is unavailable on this device.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Insights")
    }

    private func generate() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            insights = try await generator.insights(
                for: palette,
                guidance: guidance.isEmpty ? nil : guidance
            )
        } catch {
            errorText = "\(error)"
        }
    }
}
