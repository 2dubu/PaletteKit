# Choosing an Extraction Result

PaletteKit can return one dominant color, a ranked palette, or a set of
semantic swatches. Choose the smallest result that represents the UI decision
you need to make.

## Compare the results

| Result | Use it for | API |
| --- | --- | --- |
| Dominant color | One representative accent, placeholder, or background color | ``PaletteExtractor/dominantColor(from:options:)`` |
| Ranked palette | Several representative colors with population data | ``PaletteExtractor/palette(from:options:)`` |
| Semantic swatches | Optional vibrant, muted, dark, and light UI roles | ``PaletteExtractor/swatches(from:options:)`` |

All three APIs use the same image sources and ``ExtractionOptions``. They are
`async throws` and return `Sendable` values.

## Extracting one dominant color

Use a dominant color when the interface needs one representative value:

```swift
let dominant = try await PaletteExtractor().dominantColor(
    from: .data(imageData)
)
```

The result is optional because a palette can be empty, including when a custom
quantizer returns no colors. The method runs palette extraction with the
supplied options and returns the most populous ``PaletteColor``.

## Building a ranked palette

Use a ``Palette`` when the interface needs several colors or population data:

```swift
let palette = try await PaletteExtractor().palette(
    from: .data(imageData),
    options: ExtractionOptions(colorCount: 8)
)

for color in palette {
    print(color.hex, color.population, color.proportion)
}
```

Palette colors are sorted by population. ``Palette/dominant`` returns the
first color without running another extraction.

## Creating semantic swatches

Use ``SwatchMap`` when the interface needs role-based color choices:

```swift
let swatches = try await PaletteExtractor().swatches(from: .data(imageData))

let background = swatches.color(
    for: .vibrant,
    fallback: .black
)
```

The swatch classifier looks for up to six roles: vibrant, muted, dark vibrant,
dark muted, light vibrant, and light muted. Each role is optional because an
image may not contain a suitable unused color in that role's lightness and
chroma range. The swatch method raises a smaller requested color count to 16
so the classifier has enough candidates.

## Reusing one extraction

`swatches(from:options:)` performs its own palette extraction. If an interface
needs both a ``Palette`` and a ``SwatchMap``, extract at least 16 candidates and
classify that palette directly:

```swift
let palette = try await PaletteExtractor().palette(
    from: .data(imageData),
    options: ExtractionOptions(colorCount: 16)
)
let swatches = SwatchClassifier().classify(palette: palette)
```

This avoids decoding and quantizing the same image twice. PaletteKit's async
graphic views can cache URL-based rendering workflows; see <doc:AsyncLoading>.

For source-specific examples, see <doc:ImageColorExtraction>. For color-space
behavior, see <doc:ColorSpaces>.
