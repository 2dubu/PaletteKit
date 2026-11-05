#if canImport(UIKit) && canImport(SwiftUI)
import Testing
import SwiftUI
import PaletteKit

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

    @Test("legacy custom duration preserves metadata and equality")
    func customAnimation() {
        let animation = Animation.easeInOut(duration: 0.42)
        let t = AsyncPaletteGraphicTransition.custom(animation, duration: 0.42)
        #expect(t.duration == 0.42)
        #expect(t.animation == animation)
        #expect(t != .custom(animation, duration: 0.20))
        #expect(t == .custom(animation, duration: 0.42))
    }

    @Test("omitting duration preserves animation and legacy defaults")
    func customAnimationDefaultDuration() {
        let animation = Animation.easeInOut(duration: 0.42)
        let t = AsyncPaletteGraphicTransition.custom(animation)
        #expect(t.duration == 0.20)
        #expect(t.animation == animation)
        #expect(t == .custom(animation, duration: 0.20))
    }

    @Test("custom factory remains an unambiguous function reference")
    func customFunctionReference() {
        let factory = AsyncPaletteGraphicTransition.custom
        let animation = Animation.linear(duration: 0.42)
        let result = factory(animation, 0.7)
        #expect(result.animation == animation)
        #expect(result.duration == 0.7)
        #expect(result == .custom(animation, duration: 0.7))
    }

    @Test("environment default is .normal")
    func envDefaultIsNormal() {
        let env = EnvironmentValues()
        #expect(env.asyncPaletteGraphicTransition?.duration == 0.20)
    }
}
#endif
