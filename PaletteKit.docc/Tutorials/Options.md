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

### Choosing an `ImageSource`

`ImageSource` controls where pixels come from. The right case depends on
where the bytes already live:

- `.data(_)` — bytes you already hold in memory or fetched over the
  network. **Most-optimized path** for HEIC/JPEG: PaletteKit constructs
  the `CGImageSource` directly from `Data`, skipping any file-system
  hop. Measured ~17% faster than `.url(_)` on iPhone 15 Pro for a 4MP
  HEIC input.
- `.url(_)` — file on disk. The decoder can mmap the file directly,
  which is the right call when the bytes are already on disk.
- `.cgImage(_)` — you've already decoded a `CGImage` somewhere else
  (e.g. AppKit/UIKit gave you one). PaletteKit re-uses it as-is.

If you're holding `Data` and have a choice, prefer `.data(_)`.

### Choosing accuracy vs speed

There are four common goals; pick the row that matches yours.

| You want… | `quantizer` | `downsample` | Notes |
| --- | --- | --- | --- |
| **A palette, no fuss** | `.auto` | default | The default. Always CPU. |
| **Maximum color accuracy** | `.cpu` | `.disabled` | Process every pixel. Slowest, most accurate. |
| **Accuracy + speed on large inputs** | `.metal` | `.disabled` | ≥4MP only. ~5-10% quantize win vs CPU raw. |
| **Ensure work runs on GPU** | `.metal` | default | Falls back to CPU if Metal is unavailable. |

```swift
// Default — CPU MMCQ with auto-downsample to ~1M pixels:
ExtractionOptions()                                    // == .auto, default downsample

// Maximum accuracy — every pixel, CPU MMCQ:
ExtractionOptions(downsample: .disabled, quantizer: .cpu)

// Large-input accuracy + Metal (≥4MP raw):
ExtractionOptions(downsample: .disabled, quantizer: .metal)

// Custom quantizer:
ExtractionOptions(quantizer: .custom(MyQuantizer()))
```

`.auto` always picks CPU regardless of image size — on-device
measurements showed Metal didn't beat CPU at default settings. See
<doc:PerformanceTuning> for the underlying numbers.

### SwiftUI integration

`PaletteColor` conforms to `ShapeStyle` (iOS 17+), so it can be used directly
with any `ShapeStyle`-accepting modifier without an adapter call:

```swift
let palette = try await extractor.palette(from: .data(imageData))
let swatches = try await extractor.swatches(from: .data(imageData))

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
