import Foundation
import PaletteKit

/// Builds the prompt string sent to the on-device model.
enum InsightsPrompt {
    /// Untrusted prompt: serialized palette + optional caller guidance.
    static func prompt(for palette: Palette, guidance: String?) -> String {
        let colors = palette.prefix(6).map { color in
            "\(color.hex) (\(Int((color.proportion * 100).rounded()))%)"
        }.joined(separator: ", ")

        var text = "Name and describe this color palette: \(colors)."
        if let guidance,
           !guidance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text += "\n\nAdditional guidance: \(guidance)"
        }
        return text
    }
}
