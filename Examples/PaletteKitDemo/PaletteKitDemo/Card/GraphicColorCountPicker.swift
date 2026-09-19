import PaletteKit
import SwiftUI
import UIKit

/// UIKit supplies per-segment disabled interaction and accessibility semantics.
/// SwiftUI's segmented Picker does not consistently honor child `.disabled`.
struct GraphicColorCountPicker: UIViewRepresentable {
    @Binding var selection: ColorCount
    let options: GraphicColorOptions

    func makeUIView(context: Context) -> UISegmentedControl {
        let control = UISegmentedControl(items: ColorCount.allCases.map { String($0.rawValue) })
        control.accessibilityLabel = "Colors"
        control.accessibilityIdentifier = "graphic.colors"
        control.addTarget(context.coordinator, action: #selector(Coordinator.selectCount(_:)), for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        for (index, count) in ColorCount.allCases.enumerated() {
            control.setEnabled(options.availableCounts.contains(count), forSegmentAt: index)
        }
        let resolved = options.selection(preserving: selection)
        control.selectedSegmentIndex = options.isSingleColor
            ? UISegmentedControl.noSegment
            : ColorCount.allCases.firstIndex(of: resolved) ?? UISegmentedControl.noSegment
        control.accessibilityHint = options.isSingleColor
            ? "The current combination produces a single color."
            : "Unavailable color counts are dimmed."
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject {
        var parent: GraphicColorCountPicker

        init(parent: GraphicColorCountPicker) { self.parent = parent }

        @objc func selectCount(_ sender: UISegmentedControl) {
            guard ColorCount.allCases.indices.contains(sender.selectedSegmentIndex) else { return }
            let count = ColorCount.allCases[sender.selectedSegmentIndex]
            guard parent.options.availableCounts.contains(count) else { return }
            parent.selection = count
        }
    }
}
