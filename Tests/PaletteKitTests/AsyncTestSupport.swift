#if canImport(UIKit)
import CoreGraphics
import Foundation
@testable import PaletteKit

enum AsyncTestSupport {
    private enum EventWaitError: Error, CustomStringConvertible, Sendable {
        case streamFinished(String)
        case timedOut(String, Duration)

        var description: String {
            switch self {
            case .streamFinished(let event):
                return "event stream finished before \(event)"
            case .timedOut(let event, let timeout):
                return "timed out after \(timeout) waiting for \(event)"
            }
        }
    }

    /// Await a callback-backed event without repeatedly waking the main actor.
    /// The timeout races the event itself, so an event delivered at the deadline
    /// cannot be discarded by a separate wall-clock check.
    static func nextEvent<Event: Sendable>(
        from stream: AsyncStream<Event>,
        timeout: Duration = .seconds(30),
        waitingFor eventDescription: String
    ) async throws -> Event {
        try await withThrowingTaskGroup(of: Event.self) { group in
            group.addTask {
                for await event in stream {
                    return event
                }
                throw EventWaitError.streamFinished(eventDescription)
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw EventWaitError.timedOut(eventDescription, timeout)
            }

            defer { group.cancelAll() }
            guard let event = try await group.next() else {
                throw EventWaitError.streamFinished(eventDescription)
            }
            return event
        }
    }

    /// Synthesise a small solid-color CGImage for in-memory tests
    /// (no disk / network roundtrip required).
    static func makeSolidImage(rgb: (UInt8, UInt8, UInt8), size: Int = 32) -> CGImage {
        let bytesPerRow = size * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * size)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            pixels[i + 0] = rgb.0
            pixels[i + 1] = rgb.1
            pixels[i + 2] = rgb.2
            pixels[i + 3] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: size, height: size,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    /// Hand-built tiny palette for cache fixtures.
    static func makePalette(rgb: (UInt8, UInt8, UInt8) = (200, 80, 40)) -> Palette {
        Palette(
            colors: [PaletteColor(r: rgb.0, g: rgb.1, b: rgb.2)],
            colorSpaceUsed: .oklch
        )
    }
}
#endif
