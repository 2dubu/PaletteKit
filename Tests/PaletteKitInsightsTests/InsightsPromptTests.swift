import Foundation
import Testing
@testable import PaletteKit
@testable import PaletteKitInsights

@Suite("InsightsPrompt.prompt")
struct InsightsPromptTests {
    private func palette(_ colors: [PaletteColor]) -> Palette {
        Palette(colors: colors, colorSpaceUsed: .sRGB)
    }

    @Test("serializes hex + rounded percentage")
    @available(iOS 26, macOS 26, visionOS 26, *)
    func serializes() {
        let p = palette([
            PaletteColor(r: 18, g: 58, b: 143, population: 50, proportion: 0.5),
            PaletteColor(r: 242, g: 194, b: 0, population: 50, proportion: 0.5),
        ])
        let text = InsightsPrompt.prompt(for: p, guidance: nil)
        #expect(text.contains("#123a8f (50%)"))
        #expect(text.contains("#f2c200 (50%)"))
    }

    @Test("caps at six colors")
    @available(iOS 26, macOS 26, visionOS 26, *)
    func caps() {
        let many = (0..<10).map { i in
            PaletteColor(r: UInt8(i), g: 0, b: 0, population: 1, proportion: 0.1)
        }
        let text = InsightsPrompt.prompt(for: palette(many), guidance: nil)
        let count = text.components(separatedBy: "#").count - 1
        #expect(count == 6)
    }

    @Test("appends guidance when present, omits when nil or blank")
    @available(iOS 26, macOS 26, visionOS 26, *)
    func guidance() {
        let p = palette([PaletteColor(r: 10, g: 20, b: 30, population: 1, proportion: 1)])
        #expect(InsightsPrompt.prompt(for: p, guidance: "playful tone").contains("Additional guidance: playful tone"))
        #expect(!InsightsPrompt.prompt(for: p, guidance: nil).contains("Additional guidance"))
        #expect(!InsightsPrompt.prompt(for: p, guidance: "   ").contains("Additional guidance"))
    }
}
