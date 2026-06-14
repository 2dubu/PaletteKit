import Testing
@testable import PaletteKitInsights

@Suite("PaletteInsights")
struct PaletteInsightsTests {
    @Test("stores name and summary; equatable by value")
    @available(iOS 26, macOS 26, visionOS 26, *)
    func value() {
        let a = PaletteInsights(name: "Ember Harvest", summary: "Warm and golden.")
        let b = PaletteInsights(name: "Ember Harvest", summary: "Warm and golden.")
        #expect(a == b)
        #expect(a.name == "Ember Harvest")
        #expect(a.summary == "Warm and golden.")
    }
}
