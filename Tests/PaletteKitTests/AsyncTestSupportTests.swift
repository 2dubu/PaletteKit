#if canImport(UIKit)
import Foundation
import Testing

@Suite("Async test event waiting")
struct AsyncTestSupportTests {
    @Test("returns a callback event without polling")
    func returnsEvent() async throws {
        let (events, continuation) = AsyncStream<Int>.makeStream()
        continuation.yield(42)
        continuation.finish()

        let event = try await AsyncTestSupport.nextEvent(
            from: events,
            timeout: .seconds(1),
            waitingFor: "a test event"
        )

        #expect(event == 42)
    }

    @Test("timeout cancels the pending event wait")
    func timesOut() async {
        let (events, continuation) = AsyncStream<Void>.makeStream()
        defer { continuation.finish() }

        do {
            try await AsyncTestSupport.nextEvent(
                from: events,
                timeout: .milliseconds(10),
                waitingFor: "an event that is never sent"
            )
            Issue.record("expected the event wait to time out")
        } catch {
            // The timeout is the expected result. Reaching this catch also
            // proves cancellation released the pending AsyncStream iterator.
        }
    }
}
#endif
