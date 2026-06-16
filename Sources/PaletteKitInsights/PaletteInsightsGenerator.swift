import Foundation
import FoundationModels
import PaletteKit

/// Generates a name and summary for a ``Palette`` using the on-device system language model.
@available(iOS 26, macOS 26, visionOS 26, *)
public struct PaletteInsightsGenerator: Sendable {
    public init() {}

    /// Current usability of the on-device model.
    public var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    /// `true` when the model is ready to use right now.
    public var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    /// Whether the model supports the locale's language.
    /// - Parameter locale: Language to test. Defaults to the device locale.
    public func supportsLocale(_ locale: Locale = .current) -> Bool {
        SystemLanguageModel.default.supportsLocale(locale)
    }

    /// Generate a name and summary for `palette`.
    /// - Parameters:
    ///   - locale: output language (default device/app language).
    ///   - guidance: optional caller tone or style hint.
    /// - Throws: ``PaletteInsightsError`` — `.emptyPalette` for an empty palette,
    ///   `.modelUnavailable` / `.unsupportedLanguage` when the model can't be used,
    ///   or `.guardrailViolation` / `.refusal` / `.generationFailed` from generation.
    public func insights(
        for palette: Palette,
        locale: Locale = .current,
        guidance: String? = nil
    ) async throws -> PaletteInsights {
        guard !palette.isEmpty else { throw PaletteInsightsError.emptyPalette }

        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw PaletteInsightsError.modelUnavailable(model.availability)
        }
        guard model.supportsLocale(locale) else {
            throw PaletteInsightsError.unsupportedLanguage(locale)
        }

        let session = LanguageModelSession(
            instructions: Instructions(InsightsPrompt.instructionsText(for: locale))
        )
        do {
            let response = try await session.respond(
                to: InsightsPrompt.prompt(for: palette, guidance: guidance),
                generating: GeneratedInsights.self
            )
            return PaletteInsights(
                name: response.content.name,
                summary: response.content.summary
            )
        } catch {
            throw PaletteInsightsError(mapping: error)
        }
    }
}
