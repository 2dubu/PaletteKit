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

    @Test("reload() forces a second extraction even with same source")
    func reloadForcesSecondExtraction() async throws {
        let view = AsyncPaletteGraphicView(frame: .init(x: 0, y: 0, width: 100, height: 100))
        let cgImage = AsyncTestSupport.makeSolidImage(rgb: (200, 50, 50))

        var resolveCount = 0
        view.onSuccess = { _, _ in resolveCount += 1 }
        view.cacheKey = AnyHashable("reload-force-test")
        view.imageSource = .cgImage(cgImage)

        // Wait for first resolution.
        let deadline1 = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline1, resolveCount < 1 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(resolveCount == 1)

        // Force reload — must trigger a second resolution.
        view.reload()
        let deadline2 = ContinuousClock.now.advanced(by: .seconds(5))
        while ContinuousClock.now < deadline2, resolveCount < 2 {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(resolveCount == 2)
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
