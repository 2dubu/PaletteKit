import CoreGraphics
import Foundation
import PaletteKit

@MainActor
final class BenchRunner: ObservableObject {
    struct Configuration: Equatable {
        enum SourceKind: String, CaseIterable, Hashable {
            case synthesized
            case photo
            /// Pass the raw photo bytes directly via `.data(...)` so PaletteKit's
            /// ImageIO thumbnail fast-path is exercised on the user's HEIC/JPEG.
            /// Compare against `.photo` (which decodes externally and passes
            /// `.cgImage(...)`) to measure the saved decode/downsample cost.
            case photoData
        }

        var includeAutoDownsample = true
        var includeRawDownsample = false
        var include8K = false
        var warmupRuns = 1
        var measuredRuns = 5
        /// Optional human-readable note attached to the run — flows into
        /// the CSV header so cross-device / cross-condition comparisons
        /// can be tagged ("iPhone 15 Pro / quiet", "after game", etc).
        var runNote: String = ""
        /// Source for the input image at each grid size. Synthesized
        /// generates a deterministic gradient + noise + blobs scene;
        /// photo expects the caller to provide a CGImage that gets
        /// center-cropped and resized to each grid side.
        var sourceKind: SourceKind = .synthesized
    }

    enum Phase: Equatable {
        case idle
        case running(currentIndex: Int, total: Int, currentLabel: String)
        case finished
        case failed(message: String)
    }

    struct Scenario: Identifiable, Hashable {
        let id: String
        let label: String
        let sourceKind: Configuration.SourceKind
        let includeAuto: Bool
        let includeRaw: Bool

        static let comparisonSuite: [Scenario] = [
            Scenario(id: "synth-auto", label: "Synthesized · auto", sourceKind: .synthesized, includeAuto: true, includeRaw: false),
            Scenario(id: "synth-raw", label: "Synthesized · raw", sourceKind: .synthesized, includeAuto: false, includeRaw: true),
            Scenario(id: "photo-auto", label: "Photo · auto", sourceKind: .photo, includeAuto: true, includeRaw: false),
            Scenario(id: "photo-raw", label: "Photo · raw", sourceKind: .photo, includeAuto: false, includeRaw: true),
            Scenario(id: "photoData-auto", label: "Photo Data · auto", sourceKind: .photoData, includeAuto: true, includeRaw: false),
            Scenario(id: "photoData-raw", label: "Photo Data · raw", sourceKind: .photoData, includeAuto: false, includeRaw: true),
        ]

        var requiresPhoto: Bool {
            sourceKind == .photo || sourceKind == .photoData
        }
    }

    enum SuiteSizes: String, CaseIterable, Hashable {
        case full   // 256 / 512 / 1024 / 2048 / 4096
        case quick  // 1024 / 4096

        var sides: [Int] {
            switch self {
            case .full: return [256, 512, 1024, 2048, 4096]
            case .quick: return [1024, 4096]
            }
        }
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var samples: [BenchSample] = []
    @Published private(set) var summaries: [BenchSummary] = []
    @Published private(set) var startedAt: Date?
    @Published private(set) var runNote: String = ""
    /// Description of the source used (e.g. "synthesized" or
    /// "photo 4032x3024"). Persisted into CSV headers.
    @Published private(set) var sourceDescription: String = "synthesized"

    private var task: Task<Void, Never>?
    private let extractor = PaletteExtractor()

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    var failureCount: Int {
        samples.filter { !$0.isWarmup && $0.errorMessage != nil }.count
    }

    var firstFailureMessage: String? {
        samples.first(where: { $0.errorMessage != nil })?.errorMessage
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
        runNote = ""
        sourceDescription = "synthesized"
    }

    func run(
        configuration: Configuration,
        photoImage: CGImage? = nil,
        photoData: Data? = nil,
        photoOriginalSize: CGSize? = nil
    ) {
        cancel()
        switch configuration.sourceKind {
        case .synthesized:
            break
        case .photo where photoImage == nil:
            phase = .failed(message: "Photo source selected but no image was loaded.")
            return
        case .photoData where photoData == nil:
            phase = .failed(message: "Photo Data source selected but no image bytes are available.")
            return
        default:
            break
        }
        let cases = Self.makeCases(configuration: configuration)
        let totalRuns = cases.count * (configuration.warmupRuns + configuration.measuredRuns)
        guard totalRuns > 0 else {
            phase = .failed(message: "No bench cases selected.")
            return
        }
        samples = []
        summaries = []
        startedAt = Date()
        runNote = configuration.runNote.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceDescription = Self.describeSource(
            kind: configuration.sourceKind,
            originalSize: photoOriginalSize
        )
        phase = .running(currentIndex: 0, total: totalRuns, currentLabel: cases.first?.label ?? "")

        task = Task { [weak self] in
            guard let self else { return }
            await self.execute(
                cases: cases,
                configuration: configuration,
                photoImage: photoImage,
                photoData: photoData,
                totalRuns: totalRuns
            )
        }
    }

    func runSuite(
        scenarios: [Scenario],
        sizes: SuiteSizes,
        warmupRuns: Int = 1,
        measuredRuns: Int = 5,
        runNote: String = "",
        photoImage: CGImage? = nil,
        photoData: Data? = nil,
        photoOriginalSize: CGSize? = nil
    ) {
        cancel()
        guard !scenarios.isEmpty else {
            phase = .failed(message: "No scenarios selected.")
            return
        }
        let needsPhoto = scenarios.contains { $0.requiresPhoto }
        if needsPhoto {
            if scenarios.contains(where: { $0.sourceKind == .photo }), photoImage == nil {
                phase = .failed(message: "A photo is required for the selected scenarios.")
                return
            }
            if scenarios.contains(where: { $0.sourceKind == .photoData }), photoData == nil {
                phase = .failed(message: "Photo bytes are required for the Photo Data scenarios.")
                return
            }
        }

        let perScenarioCases: [(Scenario, [BenchCase])] = scenarios.map { sc in
            let config = Configuration(
                includeAutoDownsample: sc.includeAuto,
                includeRawDownsample: sc.includeRaw,
                include8K: false,
                warmupRuns: warmupRuns,
                measuredRuns: measuredRuns,
                runNote: runNote,
                sourceKind: sc.sourceKind
            )
            return (sc, Self.makeCases(configuration: config, suiteSides: sizes.sides))
        }
        let totalRuns = perScenarioCases.reduce(0) { $0 + $1.1.count } * (warmupRuns + measuredRuns)
        guard totalRuns > 0 else {
            phase = .failed(message: "No bench cases generated for this suite.")
            return
        }
        samples = []
        summaries = []
        startedAt = Date()
        self.runNote = runNote.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceDescription = scenarios.map(\.id).joined(separator: ",")
        if needsPhoto, let s = photoOriginalSize {
            sourceDescription = "suite[\(scenarios.map(\.id).joined(separator: ","))] photo \(Int(s.width))x\(Int(s.height))"
        } else {
            sourceDescription = "suite[\(scenarios.map(\.id).joined(separator: ","))]"
        }
        phase = .running(currentIndex: 0, total: totalRuns, currentLabel: scenarios.first?.label ?? "")

        task = Task { [weak self] in
            guard let self else { return }
            await self.executeSuite(
                perScenarioCases: perScenarioCases,
                warmupRuns: warmupRuns,
                measuredRuns: measuredRuns,
                photoImage: photoImage,
                photoData: photoData,
                totalRuns: totalRuns
            )
        }
    }

    private func executeSuite(
        perScenarioCases: [(Scenario, [BenchCase])],
        warmupRuns: Int,
        measuredRuns: Int,
        photoImage: CGImage?,
        photoData: Data?,
        totalRuns: Int
    ) async {
        var collected: [BenchSample] = []
        var allCases: [BenchCase] = []
        var globalRunIndex = 0

        for (scenario, cases) in perScenarioCases {
            if Task.isCancelled { break }
            allCases.append(contentsOf: cases)
            for benchCase in cases {
                if Task.isCancelled { break }
                let pseudoConfig = Configuration(sourceKind: scenario.sourceKind)
                guard let source = await makeSource(
                    for: benchCase,
                    configuration: pseudoConfig,
                    photoImage: photoImage,
                    photoData: photoData
                ) else {
                    phase = .failed(message: "\(scenario.label): source unavailable.")
                    return
                }
                let runs = warmupRuns + measuredRuns
                for runIndex in 0..<runs {
                    if Task.isCancelled { break }
                    let isWarmup = runIndex < warmupRuns
                    let label = "\(scenario.label) · \(benchCase.label)  run \(runIndex + 1)/\(runs)"
                    phase = .running(
                        currentIndex: globalRunIndex,
                        total: totalRuns,
                        currentLabel: label
                    )
                    let sample = await runSingle(
                        benchCase: benchCase,
                        source: source,
                        runIndex: runIndex,
                        isWarmup: isWarmup,
                        scenario: scenario.id
                    )
                    collected.append(sample)
                    samples = collected
                    globalRunIndex += 1
                }
            }
        }

        let final = collected
        samples = final
        summaries = Self.summarize(samples: final, cases: allCases)
        phase = Task.isCancelled ? .idle : .finished
        task = nil
    }

    private func makeSource(
        for benchCase: BenchCase,
        configuration: Configuration,
        photoImage: CGImage?,
        photoData: Data?
    ) async -> ImageSource? {
        switch configuration.sourceKind {
        case .synthesized:
            let side = benchCase.pixelSide
            return await Task.detached(priority: .userInitiated) {
                ImageSource.cgImage(BenchFixture.makePhotoLike(side: side))
            }.value
        case .photo:
            guard let photo = photoImage else { return nil }
            let side = benchCase.pixelSide
            return await Task.detached(priority: .userInitiated) {
                ImageSource.cgImage(BenchFixture.resizeToSquare(photo, side: side))
            }.value
        case .photoData:
            guard let data = photoData else { return nil }
            return .data(data)
        }
    }

    private static func describeSource(
        kind: Configuration.SourceKind,
        originalSize: CGSize?
    ) -> String {
        switch kind {
        case .synthesized:
            return "synthesized"
        case .photo:
            if let s = originalSize {
                return "photo \(Int(s.width))x\(Int(s.height))"
            }
            return "photo"
        case .photoData:
            if let s = originalSize {
                return "photoData \(Int(s.width))x\(Int(s.height))"
            }
            return "photoData"
        }
    }

    private func execute(
        cases: [BenchCase],
        configuration: Configuration,
        photoImage: CGImage?,
        photoData: Data?,
        totalRuns: Int
    ) async {
        var collected: [BenchSample] = []
        var globalRunIndex = 0

        for benchCase in cases {
            if Task.isCancelled { break }
            guard let source = await makeSource(
                for: benchCase,
                configuration: configuration,
                photoImage: photoImage,
                photoData: photoData
            ) else {
                phase = .failed(message: "Source went away mid-run.")
                return
            }
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
                    source: source,
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
        source: ImageSource,
        runIndex: Int,
        isWarmup: Bool,
        scenario: String? = nil
    ) async -> BenchSample {
        let options = benchCase.paletteOptions()
        let extractor = self.extractor
        let clock = ContinuousClock()
        let started = clock.now
        do {
            let palette = try await Task.detached(priority: .userInitiated) {
                try await extractor.palette(from: source, options: options)
            }.value
            let elapsed = started.duration(to: clock.now)
            let timings = palette.timings
            return BenchSample(
                scenario: scenario,
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
                scenario: scenario,
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

    static func makeCases(configuration: Configuration, suiteSides: [Int]? = nil) -> [BenchCase] {
        var downsampleModes: [BenchCase.DownsampleKind] = []
        if configuration.includeAutoDownsample { downsampleModes.append(.auto) }
        if configuration.includeRawDownsample { downsampleModes.append(.disabled) }
        guard !downsampleModes.isEmpty else { return [] }

        // .photoData passes the original photo bytes verbatim to PaletteKit;
        // no pre-resize step, so the size grid is meaningless. Run one case
        // per (downsample × quantizer). pixelSide=0 marks "original size".
        if configuration.sourceKind == .photoData {
            var cases: [BenchCase] = []
            for ds in downsampleModes {
                for q in BenchCase.QuantizerKind.allCases {
                    cases.append(BenchCase(pixelSide: 0, quantizer: q, downsample: ds))
                }
            }
            return cases
        }

        var sides: [Int] = suiteSides ?? [256, 512, 1024, 2048, 4096]
        if suiteSides == nil, configuration.include8K, configuration.sourceKind == .synthesized {
            sides.append(8192)
        }

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
        // Group samples by (scenario, caseId) so a suite run with multiple
        // scenarios doesn't collapse same-case rows from different scenarios.
        var summaries: [BenchSummary] = []
        var seenKeys: Set<String> = []
        for sample in samples where !sample.isWarmup {
            let key = "\(sample.scenario ?? "")|\(sample.caseId)"
            if seenKeys.contains(key) { continue }
            seenKeys.insert(key)
            guard let benchCase = cases.first(where: { $0.id == sample.caseId }) else { continue }
            let measured = samples.filter {
                $0.scenario == sample.scenario && $0.caseId == sample.caseId && !$0.isWarmup
            }
            guard !measured.isEmpty else { continue }
            let totalsMs = measured.map { $0.totalSeconds * 1000 }
            let quantizesMs = measured.map { $0.quantizeSeconds * 1000 }
            let n = Double(measured.count)
            let decodeMean = measured.reduce(0.0) { $0 + $1.decodeSeconds * 1000 } / n
            let sampleMean = measured.reduce(0.0) { $0 + $1.sampleSeconds * 1000 } / n
            let quantizeMean = measured.reduce(0.0) { $0 + $1.quantizeSeconds * 1000 } / n
            let engine = measured.last?.engineUsed ?? "?"
            let errorCount = measured.filter { $0.errorMessage != nil }.count
            summaries.append(
                BenchSummary(
                    id: key,
                    scenario: sample.scenario,
                    benchCase: benchCase,
                    runCount: measured.count,
                    totalP50ms: percentile(totalsMs, p: 0.50),
                    totalP95ms: percentile(totalsMs, p: 0.95),
                    totalMinMs: totalsMs.min() ?? 0,
                    totalMaxMs: totalsMs.max() ?? 0,
                    quantizeP50ms: percentile(quantizesMs, p: 0.50),
                    quantizeP95ms: percentile(quantizesMs, p: 0.95),
                    decodeMeanMs: decodeMean,
                    sampleMeanMs: sampleMean,
                    quantizeMeanMs: quantizeMean,
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
