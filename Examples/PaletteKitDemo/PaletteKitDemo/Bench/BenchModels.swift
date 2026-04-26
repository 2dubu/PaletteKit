import Foundation
import PaletteKit

/// One benchmark cell: a size × quantizer × downsample-mode combination.
struct BenchCase: Identifiable, Hashable {
    enum QuantizerKind: String, CaseIterable, Hashable {
        case cpu
        case metal
    }

    enum DownsampleKind: String, CaseIterable, Hashable {
        case auto
        case disabled
    }

    let pixelSide: Int
    let quantizer: QuantizerKind
    let downsample: DownsampleKind

    var id: String { "\(pixelSide)-\(quantizer.rawValue)-\(downsample.rawValue)" }

    var totalPixels: Int { pixelSide * pixelSide }

    var label: String {
        let dsTag = downsample == .auto ? "auto" : "raw"
        return "\(pixelSide)² · \(quantizer.rawValue.uppercased()) · \(dsTag)"
    }

    func paletteOptions(colorCount: Int = 10) -> ExtractionOptions {
        ExtractionOptions(
            colorCount: colorCount,
            colorSpace: .oklch,
            downsample: downsample == .auto ? .default : .disabled,
            quantizer: quantizer == .cpu ? .cpu : .metal,
            collectTimings: true
        )
    }
}

/// One run of one BenchCase. `runIndex == 0` is the warmup run and is
/// excluded from summary statistics.
struct BenchSample: Identifiable, Hashable {
    let id = UUID()
    let caseId: String
    let runIndex: Int
    let isWarmup: Bool
    let totalSeconds: Double
    let decodeSeconds: Double
    let sampleSeconds: Double
    let quantizeSeconds: Double
    let engineUsed: String
    let paletteCount: Int
    let errorMessage: String?
}

/// Aggregated stats for one BenchCase (post-warmup runs only).
struct BenchSummary: Identifiable, Hashable {
    let id: String
    let benchCase: BenchCase
    let runCount: Int
    let totalP50ms: Double
    let totalP95ms: Double
    let totalMinMs: Double
    let totalMaxMs: Double
    let quantizeP50ms: Double
    let quantizeP95ms: Double
    let engineUsed: String
    let errorCount: Int
}

struct DeviceInfo: Hashable {
    let model: String
    let osVersion: String
    let processorCount: Int

    static var current: DeviceInfo {
        let pi = ProcessInfo.processInfo
        return DeviceInfo(
            model: deviceModelIdentifier(),
            osVersion: pi.operatingSystemVersionString,
            processorCount: pi.activeProcessorCount
        )
    }
}

/// Returns hardware identifier like "iPhone15,3" so different chip
/// generations show up clearly in CSV exports.
private func deviceModelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let mirror = Mirror(reflecting: systemInfo.machine)
    let identifier = mirror.children.reduce("") { partial, element in
        guard let value = element.value as? Int8, value != 0 else { return partial }
        return partial + String(UnicodeScalar(UInt8(value)))
    }
    return identifier.isEmpty ? "unknown" : identifier
}
