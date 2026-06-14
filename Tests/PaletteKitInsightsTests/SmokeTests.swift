import Testing
@testable import PaletteKitInsights

@Suite("PaletteKitInsights smoke")
struct SmokeTests {
    @Test("module builds")
    func builds() {
        #expect(true)
    }
}
