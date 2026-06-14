import Foundation
import FoundationModels

/// Failures from ``PaletteInsightsGenerator``.
@available(iOS 26, macOS 26, visionOS 26, *)
public enum PaletteInsightsError: Error, Sendable {
    /// The on-device model isn't usable; inspect the availability reason.
    case modelUnavailable(SystemLanguageModel.Availability)
    /// The model doesn't support the requested locale's language.
    case unsupportedLanguage(Locale)
    /// The palette had no colors.
    case emptyPalette
    /// Safety guardrails blocked the input or output.
    case guardrailViolation
    /// The model refused the request.
    case refusal
    /// Any other failure surfaced by the framework.
    case generationFailed(any Error)

    /// Maps a thrown FoundationModels error onto this type.
    init(mapping error: any Error) {
        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .guardrailViolation:
                self = .guardrailViolation
            case .refusal:
                self = .refusal
            default:
                self = .generationFailed(generation)
            }
        } else {
            self = .generationFailed(error)
        }
    }
}
