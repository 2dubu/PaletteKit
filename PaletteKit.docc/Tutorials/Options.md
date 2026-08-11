# Options

Tune extraction via ``ExtractionOptions``.

## Overview

Every public method on ``PaletteExtractor`` accepts an ``ExtractionOptions``.
The defaults follow color-thief v3's familiar color-count, quality, OKLCH, and
white-filter values. PaletteKit is an independent implementation, so exact
palette parity is not guaranteed.

### Quality and size

```swift
ExtractionOptions(
    colorCount: 6,
    quality: .stride(5),                       // every 5th pixel
    downsample: .automatic(maxPixels: 500_000) // CGImageSource thumbnail
)
```

- `quality` is a stride multiplier. `.stride(1)` samples every pixel;
  `.stride(10)` (the default) is typically fast enough and still
  representative.
- For `Data` and URL sources, `downsample` first asks ImageIO for a thumbnail
  through `CGImageSourceCreateThumbnailAtIndex`. ImageIO can fall back to a
  full decode if thumbnail creation fails. A `CGImage` source is already
  decoded before PaletteKit receives it and is resized when needed.

### Filtering

```swift
ExtractionOptions(
    ignoreWhite: true,
    whiteThreshold: 240,
    alphaThreshold: 50,
    minSaturation: 0.1,
    fallbackStrategy: .relax
)
```

- `fallbackStrategy: .relax` retries the filter chain with progressively
  looser settings if all pixels are removed, finally returning the image
  average. Use `.fail` to throw ``PaletteError/allPixelsFiltered`` instead.

### Color space

```swift
ExtractionOptions(colorSpace: .oklch)   // default
ExtractionOptions(colorSpace: .sRGB)    // direct RGB-space MMCQ
```

Display P3 input is auto-detected. When `colorSpace == .oklch`, sampled pixels
use the matching sRGB-to-OKLCH or Display P3-to-OKLCH conversion before
quantization. Returned `PaletteColor` values are untagged 8-bit RGB, and the
default path converts them back to sRGB. `colorSpaceUsed` can still record a P3
input; it is not an embedded output profile. The built-in SwiftUI/UIKit
adapters emit sRGB. See <doc:ColorSpaces> for the exact pipeline and output
boundary.

### Choosing an `ImageSource`

`ImageSource` controls where pixels come from. The right case depends on
where the bytes already live:

- `.data(_)` — bytes you already hold in memory or fetched over the network.
  PaletteKit constructs the `CGImageSource` directly from `Data`, skipping a
  file-system hop.
- `.url(_)` — file on disk. ImageIO reads from the file URL without requiring
  the caller to create a `Data` value first.
- `.cgImage(_)` — you've already decoded a `CGImage` somewhere else
  (e.g. AppKit/UIKit gave you one). PaletteKit re-uses it as-is.

If you're holding `Data` and have a choice, prefer `.data(_)`.

### Choosing accuracy vs speed

There are three common goals; pick the row that matches yours.

| You want… | `quality` | `quantizer` | `downsample` | Notes |
| --- | --- | --- | --- | --- |
| **A palette with defaults** | default | `.auto` | default | Samples every tenth pixel; uses CPU. |
| **Sample every source pixel** | `.highest` | `.cpu` | `.disabled` | Highest input detail and the most CPU work. |
| **Compare Metal on a large input** | `.highest` | `.metal` | `.disabled` | Measure against CPU with `collectTimings`. |

```swift
// Default — CPU MMCQ with up to about 1M raster pixels:
ExtractionOptions()                                    // == .auto, default downsample

// Every source pixel, CPU MMCQ:
ExtractionOptions(quality: .highest, downsample: .disabled, quantizer: .cpu)

// The same full-sampling workload with a Metal histogram:
ExtractionOptions(quality: .highest, downsample: .disabled, quantizer: .metal)

// Custom quantizer:
ExtractionOptions(quantizer: .custom(MyQuantizer()))
```

`.auto` always picks CPU regardless of image size. Use `collectTimings` to
compare CPU and Metal with the images and options your application uses. See
<doc:PerformanceTuning> for the measurement workflow.

On targets where the Metal framework cannot be imported, an explicit `.metal`
selection uses the CPU implementation. On Metal-capable targets, failure to
create a device, command queue, shader library, or compute pipeline is surfaced
as an error.

### SwiftUI integration

`PaletteColor` conforms to `ShapeStyle` (iOS 17+), so it can be used directly
with any `ShapeStyle`-accepting modifier without an adapter call:

```swift
let palette = try await extractor.palette(
    from: .data(imageData),
    options: ExtractionOptions(colorCount: 16)
)
let swatches = SwatchClassifier().classify(palette: palette)

Rectangle()
    .fill(palette.dominant ?? .black)

if let vibrant = swatches.vibrant {
    Text("Hello")
        .foregroundStyle(vibrant.titleTextColor)
}
```

Internally `resolve(in:)` produces a `Color.Resolved` tagged sRGB. `Color.Resolved`
is Apple's concrete RGBA value type; SwiftUI converts it into the rendering
pipeline without a context-dependent lookup.

### UIKit integration

For UIKit, use the `UIColor(_:)` convenience initializer:

```swift
let palette = try await extractor.palette(from: .data(imageData))

let label = UILabel()
label.textColor = UIColor(palette.dominant ?? .black)

// For Core Graphics drawing (CALayer, CGContext) — direct, no UIColor hop:
layer.backgroundColor = palette.dominant?.cgColor
```

### Timings

```swift
let palette = try await extractor.palette(
    from: source,
    options: ExtractionOptions(collectTimings: true)
)
palette.timings?.decode
palette.timings?.quantize
palette.timings?.quantizerUsed // "MMCQ-CPU" or "MMCQ-Metal"
```

Setting `collectTimings: true` populates ``ExtractionTimings`` on the
result. Leave it `false` in production when you do not need per-stage
durations.
