#if canImport(UIKit) && canImport(SwiftUI)
import Testing
import SwiftUI
@testable import PaletteKit

@Suite("AsyncPaletteGraphicTransition")
struct AsyncPaletteGraphicTransitionTests {
    @Test(".normal preset has 0.20s duration")
    func normalDuration() {
        #expect(AsyncPaletteGraphicTransition.normal.duration == 0.20)
    }

    @Test(".slow preset has 0.35s duration")
    func slowDuration() {
        #expect(AsyncPaletteGraphicTransition.slow.duration == 0.35)
    }

    @Test(".extraSlow preset has 0.50s duration")
    func extraSlowDuration() {
        #expect(AsyncPaletteGraphicTransition.extraSlow.duration == 0.50)
    }

    @Test(".custom honors explicit duration parameter")
    func customAnimation() {
        let t = AsyncPaletteGraphicTransition.custom(.easeInOut(duration: 0.42), duration: 0.42)
        #expect(t.duration == 0.42)
    }

    @Test(".custom defaults duration to 0.20 when omitted")
    func customAnimationDefaultDuration() {
        let t = AsyncPaletteGraphicTransition.custom(.easeInOut(duration: 0.42))
        #expect(t.duration == 0.20)
    }

    @Test("environment default is .normal")
    func envDefaultIsNormal() {
        let env = EnvironmentValues()
        #expect(env.asyncPaletteGraphicTransition?.duration == 0.20)
    }
}
#endif
