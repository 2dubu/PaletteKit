/// A name and one-sentence summary generated for a ``Palette``.
///
/// Values compare equal when both `name` and `summary` match.
@available(iOS 26, macOS 26, visionOS 26, *)
public struct PaletteInsights: Sendable, Hashable {
    /// Short, evocative 2–3 word name (e.g. "Faded Coastline").
    public let name: String
    /// One vivid sentence describing the palette's mood.
    public let summary: String

    public init(name: String, summary: String) {
        self.name = name
        self.summary = summary
    }
}
