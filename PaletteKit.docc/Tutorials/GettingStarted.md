# Getting Started

Extract dominant colors, palettes, and semantic swatches with just a few
async calls.

## Overview

`PaletteExtractor` is the entry point. It is `Sendable`, stateless, and
cheap to construct, so you can create one per call site or share one as
needed.

### Extract the dominant color

```swift
import PaletteKit
import CoreGraphics

let extractor = PaletteExtractor()

func extractDominant(cgImage: CGImage) async throws -> PaletteColor? {
    try await extractor.dominantColor(from: .cgImage(cgImage))
}
```

`dominantColor(from:)` runs palette extraction with the supplied options and
returns the most populous color. The default `colorCount` is 10; values below
the valid palette range are normalized to 5 for this convenience method. The
`PaletteColor` value carries `hex`, `hsl`, `oklch`, `contrast`, and `textColor`
without any extra calls.

### Extract a palette

```swift
let palette = try await extractor.palette(
    from: .url(imageURL),
    options: ExtractionOptions(colorCount: 8)
)

for entry in palette {
    print(entry.hex, entry.proportion)
}
```

`palette` is a `Collection<PaletteColor>` sorted by population. Its
`colorSpaceUsed` records the color space detected or selected by the extraction
pipeline; individual `PaletteColor` values do not embed a color profile. See
<doc:ColorSpaces> for details.

### Get semantic swatches

```swift
let swatches = try await extractor.swatches(from: .data(imageData))
if let vibrant = swatches.vibrant {
    view.backgroundColor = UIColor(vibrant.color)
    label.textColor = UIColor(vibrant.titleTextColor)
}
```

Each `Swatch` also exposes `titleTextColor` and `bodyTextColor` as recommended
black or white foreground colors. Validate the final combination against your
application's accessibility target.

## Using the result

`PaletteColor` and ``Swatch`` values are framework-neutral. Pick the path that matches your UI layer.

### SwiftUI

`PaletteColor` conforms to `ShapeStyle` (iOS 17+), so it slots directly into `.fill`, `.foregroundStyle`, `.background`, `.tint`, and `.border`:

```swift
let palette = try await extractor.palette(
    from: .data(imageData),
    options: ExtractionOptions(colorCount: 16)
)
let swatches = SwatchClassifier().classify(palette: palette)

VStack {
    Rectangle()
        .fill(palette.dominant ?? .black)
        .frame(height: 80)

    if let vibrant = swatches.vibrant {
        Text("Vibrant")
            .foregroundStyle(vibrant.titleTextColor)
            .padding()
            .background(vibrant.color)
    }
}
```

Internally `resolve(in:)` produces a `Color.Resolved` tagged sRGB.

### UIKit

For UIKit, use the `UIColor(_:)` convenience initializer:

```swift
let palette = try await extractor.palette(
    from: .data(imageData),
    options: ExtractionOptions(colorCount: 16)
)
let swatches = SwatchClassifier().classify(palette: palette)

if let vibrant = swatches.vibrant {
    view.backgroundColor = UIColor(vibrant.color)
    label.textColor = UIColor(vibrant.titleTextColor)
}

// For Core Graphics drawing (CALayer, CGContext) — direct, no UIColor hop:
layer.backgroundColor = palette.dominant?.cgColor
```

### Convenience lookups

For the common `<role>?.color/textColor ?? fallback` pattern, `SwatchMap`
exposes three helpers:

```swift
let titleColor = swatches.titleTextColor(for: .vibrant, fallback: .black)
let bodyColor  = swatches.bodyTextColor(for: .muted,   fallback: .black)
let accent     = swatches.color(for: .lightVibrant,    fallback: palette.dominant ?? .black)
```

The same calls work on `SwatchMap?` (e.g. `PaletteGraphic.swatches`), so
optional callsites do not need an extra unwrap:

```swift
// SwatchMap? — no extra `?` required
let textColor = swatches.titleTextColor(for: .vibrant, fallback: .black)
```

The existing `if let vibrant = swatches.vibrant { … }` pattern continues
to work; pick whichever reads better at the callsite.

## Next steps

- See <doc:ImageColorExtraction> for `UIImage`, `CGImage`, local file, and
  remote image examples.
- See <doc:ColorSpaces> for Display P3 input handling, OKLCH quantization, and
  the sRGB output boundary.
- See <doc:Options> for fine-grained control over quality, color count,
  filters, and backend selection.
- See <doc:PerformanceTuning> for the Metal path and measurement tips.
