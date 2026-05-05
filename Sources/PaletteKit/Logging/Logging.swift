import Foundation
import os

enum PaletteKitLog {
    static let subsystem = "com.paletteKit"
    static let extraction = Logger(subsystem: subsystem, category: "extraction")
    static let signposter = OSSignposter(subsystem: subsystem, category: .pointsOfInterest)
}

struct ExtractionTimingsBuilder {
    private var decode: Duration = .zero
    private var sample: Duration = .zero
    private var quantize: Duration = .zero
    private var swatches: Duration?
    private var total: Duration = .zero
    private var quantizerUsed: String = ""

    mutating func set(decode value: Duration) { decode = value }
    mutating func set(sample value: Duration) { sample = value }
    mutating func set(quantize value: Duration) { quantize = value }
    mutating func set(swatches value: Duration) { swatches = value }
    mutating func set(total value: Duration) { total = value }
    mutating func set(quantizerUsed value: String) { quantizerUsed = value }

    func build() -> ExtractionTimings {
        ExtractionTimings(
            decode: decode,
            sample: sample,
            quantize: quantize,
            swatches: swatches,
            total: total,
            quantizerUsed: quantizerUsed
        )
    }
}

@inline(__always)
func measure<T>(_ work: () throws -> T) rethrows -> (T, Duration) {
    let clock = ContinuousClock()
    let start = clock.now
    let value = try work()
    return (value, start.duration(to: clock.now))
}

@inline(__always)
func measure<T>(_ work: () async throws -> T) async rethrows -> (T, Duration) {
    let clock = ContinuousClock()
    let start = clock.now
    let value = try await work()
    return (value, start.duration(to: clock.now))
}
