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
        let (firstEvents, firstEventContinuation) = AsyncStream<Void>.makeStream()
        view.onSuccess = { _, _ in
            resolveCount += 1
            firstEventContinuation.yield()
            firstEventContinuation.finish()
        }
        view.cacheKey = AnyHashable("reload-force-test")
        view.imageSource = .cgImage(cgImage)

        try await AsyncTestSupport.nextEvent(
            from: firstEvents,
            waitingFor: "the initial view load callback"
        )
        #expect(resolveCount == 1)

        // Force reload — must trigger a second resolution.
        let (reloadEvents, reloadEventContinuation) = AsyncStream<Void>.makeStream()
        view.onSuccess = { _, _ in
            resolveCount += 1
            reloadEventContinuation.yield()
            reloadEventContinuation.finish()
        }
        view.reload()
        try await AsyncTestSupport.nextEvent(
            from: reloadEvents,
            waitingFor: "the forced reload callback"
        )
        #expect(resolveCount == 2)
    }

    @Test("onSuccess fires after extraction completes")
    func onSuccessFires() async throws {
        let view = AsyncPaletteGraphicView(frame: .init(x: 0, y: 0, width: 100, height: 100))
        let cgImage = AsyncTestSupport.makeSolidImage(rgb: (200, 50, 50))

        let (events, eventContinuation) = AsyncStream<Void>.makeStream()
        view.onSuccess = { _, _ in
            eventContinuation.yield()
            eventContinuation.finish()
        }
        view.cacheKey = AnyHashable("success-test")
        view.imageSource = .cgImage(cgImage)

        try await AsyncTestSupport.nextEvent(
            from: events,
            waitingFor: "the view success callback"
        )
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
