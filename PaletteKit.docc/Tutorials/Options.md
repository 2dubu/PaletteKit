# Options

Tune extraction via ``ExtractionOptions``.

## Overview

Every public method on ``PaletteExtractor`` accepts an ``ExtractionOptions``.
The defaults mirror color-thief's (colorCount=10, quality=10, OKLCH,
ignoreWhite=true) so results are predictable if you are porting over.

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
- `downsample` routes through `CGImageSourceCreateThumbnailAtIndex` so a
  large photo never allocates a full RGBA buffer.

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
ExtractionOptions(colorSpace: .sRGB)    // color-thief v2 parity
```

Display P3 input is auto-detected. When `colorSpace == .oklch` the
resulting palette stays in the source color space — the OKLCH conversion
is used only inside the quantization step for perceptual uniformity.

### Choosing the backend

```swift
ExtractionOptions(quantizer: .auto)
ExtractionOptions(quantizer: .metal)
ExtractionOptions(quantizer: .cpu)
ExtractionOptions(quantizer: .custom(KMeansQuantizer()))
```

`.auto` dispatches to Metal for sampled pixel counts at or above 500,000
and CPU below that. See <doc:PerformanceTuning>.

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
