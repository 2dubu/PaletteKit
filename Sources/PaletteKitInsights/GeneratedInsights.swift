import FoundationModels

/// Internal structured-output target. Property names + guides are English (model inputs).
@available(iOS 26, macOS 26, visionOS 26, *)
@Generable
struct GeneratedInsights {
    @Guide(description: "A short, evocative 2-3 word name for the palette")
    let name: String
    @Guide(description: "One vivid sentence describing the palette's mood")
    let summary: String
}
