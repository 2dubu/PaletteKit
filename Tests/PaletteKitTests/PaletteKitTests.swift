import Testing
@testable import PaletteKit

@Suite("PaletteKit smoke")
struct PaletteKitSmokeTests {
    @Test("version string is exposed")
    func versionIsExposed() {
        #expect(!paletteKitVersion.isEmpty)
    }
}
