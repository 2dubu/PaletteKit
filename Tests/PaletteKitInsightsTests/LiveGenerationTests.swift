import Foundation
import Testing
@testable import PaletteKit
@testable import PaletteKitInsights

@Suite("PaletteKitInsights live")
struct LiveGenerationTests {
    /// Only runs where Apple Intelligence is available; skipped otherwise so CI stays green.
    @Test(.enabled(if: PaletteInsightsGenerator().isAvailable))
    @available(iOS 26, macOS 26, visionOS 26, *)
    func generatesNameAndSummary() async throws {
        let generator = PaletteInsightsGenerator()
        let palette = Palette(
            colors: [
                PaletteColor(r: 200, g: 90, b: 40, population: 60, proportion: 0.6),
                PaletteColor(r: 240, g: 200, b: 70, population: 40, proportion: 0.4),
            ],
            colorSpaceUsed: .sRGB
        )
        let insights = try await generator.insights(for: palette, locale: Locale(identifier: "en_US"))

        #expect(!insights.name.isEmpty)
        #expect(!insights.summary.isEmpty)
        #expect(!insights.summary.contains("#"))
        #expect(insights.summary.rangeOfCharacter(from: .decimalDigits) == nil)
    }
}
