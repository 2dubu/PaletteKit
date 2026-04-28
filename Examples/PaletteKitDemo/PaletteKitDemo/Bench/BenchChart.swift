import Charts
import SwiftUI

/// Horizontal stacked-bar chart of decode/sample/quantize times per
/// BenchCase. Phone-friendly: each case is one row, time on the X axis,
/// stage breakdown is the stack — answers "where does the time go?" at
/// a glance, which numbers in a table can't.
struct BenchChart: View {
    let summaries: [BenchSummary]

    var body: some View {
        if summaries.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Stage breakdown")
                    .font(.headline)
                Text("mean per-stage ms across post-warmup runs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(stageRows) { row in
                        BarMark(
                            x: .value("ms", row.ms),
                            y: .value("case", row.caseLabel)
                        )
                        .foregroundStyle(by: .value("stage", row.stage))
                    }
                }
                .chartForegroundStyleScale([
                    "decode": Color.blue.opacity(0.85),
                    "sample": Color.green.opacity(0.85),
                    "quantize": Color.orange.opacity(0.85),
                ])
                .chartLegend(position: .top, alignment: .leading)
                .chartXAxis {
                    AxisMarks(format: Decimal.FormatStyle.number.precision(.fractionLength(0)))
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
                .frame(height: chartHeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var chartHeight: CGFloat {
        // 24pt per row works well for caption2 monospaced Y labels;
        // legend and padding need ~70pt fixed.
        max(120, CGFloat(summaries.count) * 24 + 70)
    }

    private var stageRows: [StageRow] {
        summaries.flatMap { s in
            [
                StageRow(caseLabel: s.benchCase.compactLabel, stage: "decode", ms: s.decodeMeanMs),
                StageRow(caseLabel: s.benchCase.compactLabel, stage: "sample", ms: s.sampleMeanMs),
                StageRow(caseLabel: s.benchCase.compactLabel, stage: "quantize", ms: s.quantizeMeanMs),
            ]
        }
    }

    private struct StageRow: Identifiable {
        let id = UUID()
        let caseLabel: String
        let stage: String
        let ms: Double
    }
}
