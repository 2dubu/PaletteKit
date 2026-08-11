# Extracting Image Colors in Swift

Use PaletteKit to extract a dominant color, an ordered color palette, or
semantic swatches from `CGImage`, image `Data`, and local image URLs in Swift.

## Overview

``PaletteExtractor`` is PaletteKit's async, `Sendable` entry point for image
color extraction on iOS and macOS. Choose the result that matches the UI you
are building:

| Goal | API | Result |
| --- | --- | --- |
| Find one representative image color | ``PaletteExtractor/dominantColor(from:options:)`` | ``PaletteColor``? |
| Extract several colors ordered by population | ``PaletteExtractor/palette(from:options:)`` | ``Palette`` |
| Find vibrant, muted, dark, and light roles | ``PaletteExtractor/swatches(from:options:)`` | ``SwatchMap`` |

All three methods are `async throws`, honor task cancellation, and accept the
same ``ExtractionOptions``.

For help choosing between these result types, see
<doc:ChoosingAnExtractionResult>.

## Extracting the dominant color from a UIImage

Convert a `UIImage` that has a `CGImage` backing store to
``ImageSource/cgImage(_:)``:

```swift
import PaletteKit
import UIKit

func dominantColor(in image: UIImage) async throws -> PaletteColor? {
    guard let cgImage = image.cgImage else { return nil }
    return try await PaletteExtractor().dominantColor(from: .cgImage(cgImage))
}
```

Some `UIImage` values, including images backed only by `CIImage`, do not expose
`cgImage`. In that case, render a `CGImage` first or pass the original encoded
bytes through ``ImageSource/data(_:)``.

## Extracting a palette from a CGImage

Call `palette(from:options:)` and choose the maximum number of representative
colors with ``ExtractionOptions/colorCount``:

```swift
import CoreGraphics
import PaletteKit

func imagePalette(from image: CGImage) async throws -> Palette {
    try await PaletteExtractor().palette(
        from: .cgImage(image),
        options: ExtractionOptions(colorCount: 8)
    )
}
```

The returned ``Palette`` is a collection sorted by population. Its
``Palette/dominant`` property is the first, most populous color, and each
``PaletteColor`` includes `hex`, `hsl`, `oklch`, `population`, and
`proportion` values.

## Loading a local or remote image

Use ``ImageSource/url(_:)`` for an image file that is already on disk:

```swift
let palette = try await PaletteExtractor().palette(from: .url(fileURL))
```

For a remote HTTP URL, download the bytes with your networking layer and pass
them as `Data`. This keeps networking policy, authentication, caching, and
retry behavior outside the extraction library:

```swift
let (data, _) = try await URLSession.shared.data(from: remoteURL)
let palette = try await PaletteExtractor().palette(from: .data(data))
```

## Rendering extracted colors in SwiftUI

``PaletteColor`` conforms to `ShapeStyle`, so it works directly with common
SwiftUI styling modifiers:

```swift
import PaletteKit
import SwiftUI

struct PaletteStrip: View {
    let palette: Palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(palette.prefix(5)), id: \.self) { color in
                Rectangle().fill(color)
            }
        }
    }
}
```

The built-in `ShapeStyle` conformance resolves the color as sRGB. See
<doc:ColorSpaces> for the distinction between Display P3-aware extraction and
UI rendering.

## Rendering extracted colors in UIKit

Create a `UIColor` with PaletteKit's convenience initializer, or use
``PaletteColor/cgColor`` for Core Graphics and `CALayer`:

```swift
let swatches = try await PaletteExtractor().swatches(from: .data(imageData))

if let vibrant = swatches.vibrant {
    view.backgroundColor = UIColor(vibrant.color)
    label.textColor = UIColor(vibrant.titleTextColor)
}
```

The UIKit and Core Graphics adapters produce sRGB-tagged colors.

## Tuning extraction for large photos

The default ``Downsample/automatic(maxPixels:)`` setting targets up to about
one million raster pixels, and the default ``Quality/default`` samples every
tenth pixel. For `Data` and URL inputs, PaletteKit asks ImageIO for a thumbnail
first; ImageIO can fall back to a full decode. A `CGImage` is already decoded
before extraction begins. Adjust either value when your workload favors more
detail or less work:

```swift
let options = ExtractionOptions(
    quality: .stride(5),
    downsample: .automatic(maxPixels: 500_000)
)

let palette = try await PaletteExtractor().palette(
    from: .data(imageData),
    options: options
)
```

For backend selection and measurement guidance, see <doc:Options> and
<doc:PerformanceTuning>.
