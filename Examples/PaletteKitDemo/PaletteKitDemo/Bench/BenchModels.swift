import Foundation
import PaletteKit

/// One benchmark cell: a size × quantizer × downsample-mode combination.
struct BenchCase: Identifiable, Hashable {
    enum QuantizerKind: String, CaseIterable, Hashable {
        case auto
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
        let sizeStr = pixelSide == 0 ? "orig" : "\(pixelSide)²"
        return "\(sizeStr) · \(quantizer.rawValue.uppercased()) · \(dsTag)"
    }

    func paletteOptions(colorCount: Int = 10) -> ExtractionOptions {
        let q: QuantizerSelection
        switch quantizer {
        case .auto: q = .auto
        case .cpu: q = .cpu
        case .metal: q = .metal
        }
        return ExtractionOptions(
            colorCount: colorCount,
            colorSpace: .oklch,
            downsample: downsample == .auto ? .default : .disabled,
            quantizer: q,
            collectTimings: true
        )
    }

    /// Short label used as a chart Y-axis label or for compact summary
    /// rows. Goal: ~16 characters, monospace-friendly.
    var compactLabel: String {
        let dsTag = downsample == .auto ? "ds" : "raw"
        let sizeStr = pixelSide == 0 ? "orig" : "\(pixelSide)²"
        return "\(sizeStr) · \(quantizer.rawValue) · \(dsTag)"
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
    /// Mean per-stage breakdown across the post-warmup runs in ms.
    /// Used for the stacked bar chart so you can see decode/sample
    /// dominance over quantize at scale.
    let decodeMeanMs: Double
    let sampleMeanMs: Double
    let quantizeMeanMs: Double
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

    /// Maps the raw hardware identifier ("iPhone16,1") to a marketing
    /// name ("iPhone 15 Pro"). Falls back to the identifier when the
    /// model is unknown so exports stay disambiguated.
    var marketingName: String {
        DeviceModel.marketingName(for: model)
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

enum DeviceModel {
    static func marketingName(for identifier: String) -> String {
        if let mapped = lookup[identifier] { return mapped }
        if identifier == "arm64" || identifier == "x86_64" {
            return "Simulator (\(identifier))"
        }
        return identifier
    }

    /// iOS-only library, so the table covers iPhone (XS+) and recent
    /// iPad models; older entries are pruned because PaletteKit
    /// requires iOS 17+. New devices can be added as they ship.
    private static let lookup: [String: String] = [
        // iPhone XS / XR
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",

        // iPhone 11
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd gen)",

        // iPhone 12
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",

        // iPhone 13
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd gen)",

        // iPhone 14
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",

        // iPhone 15
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",

        // iPhone 16
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",

        // iPad mini
        "iPad14,1": "iPad mini (6th gen)",
        "iPad14,2": "iPad mini (6th gen)",
        "iPad16,1": "iPad mini (A17 Pro)",
        "iPad16,2": "iPad mini (A17 Pro)",

        // iPad Air
        "iPad13,16": "iPad Air (5th gen)",
        "iPad13,17": "iPad Air (5th gen)",
        "iPad14,8": "iPad Air 11\" (M2)",
        "iPad14,9": "iPad Air 11\" (M2)",
        "iPad14,10": "iPad Air 13\" (M2)",
        "iPad14,11": "iPad Air 13\" (M2)",

        // iPad (regular)
        "iPad12,1": "iPad (9th gen)",
        "iPad12,2": "iPad (9th gen)",
        "iPad13,18": "iPad (10th gen)",
        "iPad13,19": "iPad (10th gen)",

        // iPad Pro
        "iPad13,4": "iPad Pro 11\" (5th gen, M1)",
        "iPad13,5": "iPad Pro 11\" (5th gen, M1)",
        "iPad13,6": "iPad Pro 11\" (5th gen, M1)",
        "iPad13,7": "iPad Pro 11\" (5th gen, M1)",
        "iPad13,8": "iPad Pro 12.9\" (5th gen, M1)",
        "iPad13,9": "iPad Pro 12.9\" (5th gen, M1)",
        "iPad13,10": "iPad Pro 12.9\" (5th gen, M1)",
        "iPad13,11": "iPad Pro 12.9\" (5th gen, M1)",
        "iPad14,3": "iPad Pro 11\" (4th gen, M2)",
        "iPad14,4": "iPad Pro 11\" (4th gen, M2)",
        "iPad14,5": "iPad Pro 12.9\" (6th gen, M2)",
        "iPad14,6": "iPad Pro 12.9\" (6th gen, M2)",
        "iPad16,3": "iPad Pro 11\" (M4)",
        "iPad16,4": "iPad Pro 11\" (M4)",
        "iPad16,5": "iPad Pro 13\" (M4)",
        "iPad16,6": "iPad Pro 13\" (M4)",
    ]
}
