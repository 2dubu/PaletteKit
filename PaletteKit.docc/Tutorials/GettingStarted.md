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

`dominantColor(from:)` runs a 5-color extraction and returns the most
populous one. The `PaletteColor` value carries `hex`, `hsl`, `oklch`,
`contrast`, and `textColor` without any extra calls.

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
`colorSpaceUsed` tells you whether the result lives in sRGB or Display P3.

### Get semantic swatches

```swift
let swatches = try await extractor.swatches(from: .data(imageData))
if let vibrant = swatches.vibrant {
    view.backgroundColor = vibrant.color.uiColor
    label.textColor = vibrant.titleTextColor.uiColor
}
```

Each `Swatch` also exposes `titleTextColor` and `bodyTextColor` so you can
render accessible text directly on top of the swatch.

## Next steps

- See <doc:Options> for fine-grained control over quality, color count,
  filters, and backend selection.
- See <doc:PerformanceTuning> for the Metal path and measurement tips.
