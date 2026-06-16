import Foundation
import Testing
@testable import PaletteKit
@testable import PaletteKitInsights

@Suite("PaletteInsightsGenerator")
struct PaletteInsightsGeneratorTests {
    @Test("empty palette throws .emptyPalette before touching the model")
    @available(iOS 26, macOS 26, visionOS 26, *)
    func emptyPalette() async {
        let generator = PaletteInsightsGenerator()
        let empty = Palette(colors: [], colorSpaceUsed: .sRGB)
        do {
            _ = try await generator.insights(for: empty)
            Issue.record("expected emptyPalette to throw")
        } catch let error as PaletteInsightsError {
            guard case .emptyPalette = error else {
                Issue.record("expected .emptyPalette, got \(error)")
                return
            }
        } catch {
            Issue.record("expected PaletteInsightsError, got \(error)")
        }
    }
}
