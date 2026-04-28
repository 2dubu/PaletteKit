import Foundation
import PaletteKit

enum BenchExport {
    /// Per-run rows. Useful for plotting the full distribution including
    /// warmup so we can see how big the cold-start cost actually is.
    static func rawCSV(
        device: DeviceInfo,
        startedAt: Date?,
        runNote: String,
        sourceDescription: String,
        samples: [BenchSample]
    ) -> String {
        var lines: [String] = []
        lines.append("# palettekit_version,\(paletteKitVersion)")
        lines.append("# device,\(device.model)")
        lines.append("# device_marketing,\(device.marketingName)")
        lines.append("# os,\(device.osVersion)")
        lines.append("# cpu_cores,\(device.processorCount)")
        lines.append("# source,\(escape(sourceDescription))")
        if let startedAt {
            lines.append("# started_at,\(iso8601(startedAt))")
        }
        if !runNote.isEmpty {
            lines.append("# note,\(escape(runNote))")
        }
        lines.append(
            "case_id,size_px,quantizer,downsample,run_index,is_warmup,total_ms,decode_ms,sample_ms,quantize_ms,engine,palette_count,error"
        )
        for sample in samples {
            let parts = sample.caseId.split(separator: "-")
            let size = parts.count > 0 ? String(parts[0]) : ""
            let quantizer = parts.count > 1 ? String(parts[1]) : ""
            let downsample = parts.count > 2 ? String(parts[2]) : ""
            let row: [String] = [
                sample.caseId,
                size,
                quantizer,
                downsample,
                String(sample.runIndex),
                sample.isWarmup ? "1" : "0",
                ms(sample.totalSeconds),
                ms(sample.decodeSeconds),
                ms(sample.sampleSeconds),
                ms(sample.quantizeSeconds),
                escape(sample.engineUsed),
                String(sample.paletteCount),
                escape(sample.errorMessage ?? ""),
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// One row per BenchCase with post-warmup p50/p95/min/max. This is
    /// the table you read first when comparing runs across devices.
    static func summaryCSV(
        device: DeviceInfo,
        runNote: String,
        sourceDescription: String,
        summaries: [BenchSummary]
    ) -> String {
        var lines: [String] = []
        lines.append("# palettekit_version,\(paletteKitVersion)")
        lines.append("# device,\(device.model)")
        lines.append("# device_marketing,\(device.marketingName)")
        lines.append("# os,\(device.osVersion)")
        lines.append("# source,\(escape(sourceDescription))")
        if !runNote.isEmpty {
            lines.append("# note,\(escape(runNote))")
        }
        lines.append(
            "size_px,quantizer,downsample,runs,total_p50_ms,total_p95_ms,total_min_ms,total_max_ms,quantize_p50_ms,quantize_p95_ms,decode_mean_ms,sample_mean_ms,quantize_mean_ms,engine,errors"
        )
        for s in summaries {
            let row: [String] = [
                String(s.benchCase.pixelSide),
                s.benchCase.quantizer.rawValue,
                s.benchCase.downsample.rawValue,
                String(s.runCount),
                msFromMs(s.totalP50ms),
                msFromMs(s.totalP95ms),
                msFromMs(s.totalMinMs),
                msFromMs(s.totalMaxMs),
                msFromMs(s.quantizeP50ms),
                msFromMs(s.quantizeP95ms),
                msFromMs(s.decodeMeanMs),
                msFromMs(s.sampleMeanMs),
                msFromMs(s.quantizeMeanMs),
                escape(s.engineUsed),
                String(s.errorCount),
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func writeToTemp(name: String, contents: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(name)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func ms(_ seconds: Double) -> String {
        String(format: "%.3f", seconds * 1000)
    }

    private static func msFromMs(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}
