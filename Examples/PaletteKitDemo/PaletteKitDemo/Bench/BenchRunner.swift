import CoreGraphics
import Foundation
import PaletteKit

@MainActor
final class BenchRunner: ObservableObject {
    struct Configuration: Equatable {
        var includeAutoDownsample = true
        var includeRawDownsample = false
        var include8K = false
        var warmupRuns = 1
        var measuredRuns = 5
    }

    enum Phase: Equatable {
        case idle
        case running(currentIndex: Int, total: Int, currentLabel: String)
        case finished
        case failed(message: String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var samples: [BenchSample] = []
    @Published private(set) var summaries: [BenchSummary] = []
    @Published private(set) var startedAt: Date?

    private var task: Task<Void, Never>?
    private let extractor = PaletteExtractor()

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func reset() {
        cancel()
        samples = []
        summaries = []
        phase = .idle
        startedAt = nil
    }

    func run(configuration: Configuration) {
        cancel()
        let cases = Self.makeCases(configuration: configuration)
        let totalRuns = cases.count * (configuration.warmupRuns + configuration.measuredRuns)
        guard totalRuns > 0 else {
            phase = .failed(message: "No bench cases selected.")
            return
        }
        samples = []
        summaries = []
        startedAt = Date()
        phase = .running(currentIndex: 0, total: totalRuns, currentLabel: cases.first?.label ?? "")

        task = Task { [weak self] in
            guard let self else { return }
            await self.execute(cases: cases, configuration: configuration, totalRuns: totalRuns)
        }
    }

    private func execute(
        cases: [BenchCase],
        configuration: Configuration,
        totalRuns: Int
    ) async {
        var collected: [BenchSample] = []
        var globalRunIndex = 0

        for benchCase in cases {
            if Task.isCancelled { break }
            let image = BenchFixture.makePhotoLike(side: benchCase.pixelSide)
            let runs = configuration.warmupRuns + configuration.measuredRuns
            for runIndex in 0..<runs {
                if Task.isCancelled { break }
                let isWarmup = runIndex < configuration.warmupRuns
                let label = "\(benchCase.label)  run \(runIndex + 1)/\(runs)"
                phase = .running(
                    currentIndex: globalRunIndex,
                    total: totalRuns,
                    currentLabel: label
                )
                let sample = await runSingle(
                    benchCase: benchCase,
                    image: image,
                    runIndex: runIndex,
                    isWarmup: isWarmup
                )
                collected.append(sample)
                samples = collected
                globalRunIndex += 1
            }
        }

        let final = collected
        samples = final
        summaries = Self.summarize(samples: final, cases: cases)
        phase = Task.isCancelled ? .idle : .finished
        task = nil
    }

    private func runSingle(
        benchCase: BenchCase,
        image: CGImage,
        runIndex: Int,
        isWarmup: Bool
    ) async -> BenchSample {
        let options = benchCase.paletteOptions()
        let clock = ContinuousClock()
        let started = clock.now
        do {
            let palette = try await extractor.palette(
                from: .cgImage(image),
                options: options
            )
            let elapsed = started.duration(to: clock.now)
            let timings = palette.timings
            return BenchSample(
                caseId: benchCase.id,
                runIndex: runIndex,
                isWarmup: isWarmup,
                totalSeconds: durationSeconds(elapsed),
                decodeSeconds: timings.map { durationSeconds($0.decode) } ?? 0,
                sampleSeconds: timings.map { durationSeconds($0.sample) } ?? 0,
                quantizeSeconds: timings.map { durationSeconds($0.quantize) } ?? 0,
                engineUsed: timings?.quantizerUsed ?? "?",
                paletteCount: palette.colors.count,
                errorMessage: nil
            )
        } catch {
            let elapsed = started.duration(to: clock.now)
            return BenchSample(
                caseId: benchCase.id,
                runIndex: runIndex,
                isWarmup: isWarmup,
                totalSeconds: durationSeconds(elapsed),
                decodeSeconds: 0,
                sampleSeconds: 0,
                quantizeSeconds: 0,
                engineUsed: "error",
                paletteCount: 0,
                errorMessage: String(describing: error)
            )
        }
    }

    // MARK: - Cases

    static func makeCases(configuration: Configuration) -> [BenchCase] {
        var sides: [Int] = [256, 512, 1024, 2048, 4096]
        if configuration.include8K { sides.append(8192) }

        var downsampleModes: [BenchCase.DownsampleKind] = []
        if configuration.includeAutoDownsample { downsampleModes.append(.auto) }
        if configuration.includeRawDownsample { downsampleModes.append(.disabled) }
        guard !downsampleModes.isEmpty else { return [] }

        var cases: [BenchCase] = []
        for side in sides {
            for ds in downsampleModes {
                for q in BenchCase.QuantizerKind.allCases {
                    cases.append(BenchCase(pixelSide: side, quantizer: q, downsample: ds))
                }
            }
        }
        return cases
    }

    // MARK: - Summary

    static func summarize(samples: [BenchSample], cases: [BenchCase]) -> [BenchSummary] {
        var summaries: [BenchSummary] = []
        for benchCase in cases {
            let measured = samples.filter { $0.caseId == benchCase.id && !$0.isWarmup }
            guard !measured.isEmpty else { continue }
            let totalsMs = measured.map { $0.totalSeconds * 1000 }
            let quantizesMs = measured.map { $0.quantizeSeconds * 1000 }
            let engine = measured.last?.engineUsed ?? "?"
            let errorCount = measured.filter { $0.errorMessage != nil }.count
            summaries.append(
                BenchSummary(
                    id: benchCase.id,
                    benchCase: benchCase,
                    runCount: measured.count,
                    totalP50ms: percentile(totalsMs, p: 0.50),
                    totalP95ms: percentile(totalsMs, p: 0.95),
                    totalMinMs: totalsMs.min() ?? 0,
                    totalMaxMs: totalsMs.max() ?? 0,
                    quantizeP50ms: percentile(quantizesMs, p: 0.50),
                    quantizeP95ms: percentile(quantizesMs, p: 0.95),
                    engineUsed: engine,
                    errorCount: errorCount
                )
            )
        }
        return summaries
    }

    private static func percentile(_ values: [Double], p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let rank = max(0, min(sorted.count - 1, Int((Double(sorted.count - 1) * p).rounded())))
        return sorted[rank]
    }
}

private func durationSeconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) + Double(components.attoseconds) * 1e-18
}
