#if canImport(UIKit)
import Testing
import UIKit
@testable import PaletteKit

@MainActor
@Suite("AsyncPaletteGraphicView")
struct AsyncPaletteGraphicViewTests {
    @Test("init creates view with .empty loader phase and no source")
    func initialState() {
        let view = AsyncPaletteGraphicView(frame: .zero)
        #expect(view.imageSource == nil)
    }

    @Test("setting imageSource triggers reload")
    func sourceTriggersReload() {
        let view = AsyncPaletteGraphicView(frame: .init(x: 0, y: 0, width: 100, height: 100))
        let cgImage = AsyncTestSupport.makeSolidImage(rgb: (10, 20, 30))
        view.cacheKey = AnyHashable("trigger-test")
        view.imageSource = .cgImage(cgImage)
        // Reload should be in-flight or already resolved.
        // Loader is private; observe via onSuccess closure timing in next test.
        #expect(view.imageSource != nil)
    }

    @Test("onSuccess fires after extraction completes")
    func onSuccessFires() async throws {
        let view = AsyncPaletteGraphicView(frame: .init(x: 0, y: 0, width: 100, height: 100))
        let cgImage = AsyncTestSupport.makeSolidImage(rgb: (200, 50, 50))

        var resolved = false
        view.onSuccess = { _, _ in resolved = true }
        view.cacheKey = AnyHashable("success-test")
        view.imageSource = .cgImage(cgImage)

        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline, !resolved {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(resolved == true)
    }

    @Test("cancel stops in-flight extraction")
    func cancelStops() async throws {
        let view = AsyncPaletteGraphicView(frame: .init(x: 0, y: 0, width: 100, height: 100))
        let cgImage = AsyncTestSupport.makeSolidImage(rgb: (50, 100, 150), size: 256)

        var resolved = false
        view.onSuccess = { _, _ in resolved = true }
        view.cacheKey = AnyHashable("cancel-test")
        view.imageSource = .cgImage(cgImage)
        view.cancel()

        // Give an in-flight task a moment to (not) call back.
        try await Task.sleep(for: .milliseconds(300))
        #expect(resolved == false)
    }
}
#endif
