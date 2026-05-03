<img src="https://github.com/user-attachments/assets/95a7bc65-5171-4542-944e-af88788507c8" alt="palettekit" style="width: 100%; max-width: 100%; height: auto; display: block;" />

# PaletteKit

[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F2dubu%2FPaletteKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/2dubu/PaletteKit)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F2dubu%2FPaletteKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/2dubu/PaletteKit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[color-thief](https://github.com/lokesh/color-thief) reimagined for Apple —
a modern, iOS-native palette extractor with a built-in palette-driven
graphic primitive. Swift Package, SwiftUI- and UIKit-friendly: OKLCH
perceptual quantization, Display P3 wide-gamut support, Semantic Swatches,
async-only Sendable API.

## Quick start

### SwiftUI

```swift
import PaletteKit
import SwiftUI

let extractor = PaletteExtractor()
let palette = try await extractor.palette(from: .data(imageData))
let swatches = try await extractor.swatches(from: .data(imageData))

Rectangle()
    .fill(palette.dominant ?? .black)

Text("Hello")
    .foregroundStyle(swatches.vibrant?.titleTextColor ?? .black)
```

### UIKit

```swift
import PaletteKit
import UIKit

let extractor = PaletteExtractor()
let palette = try await extractor.palette(from: .data(imageData))
let swatches = try await extractor.swatches(from: .data(imageData))

view.backgroundColor = UIColor(palette.dominant ?? .black)
label.textColor = UIColor(swatches.vibrant?.titleTextColor ?? .black)
```

### Generate a graphic

```swift
import PaletteKit
import SwiftUI

let configuration = PaletteGraphic.Configuration(
    direction: .linear,
    colorCount: .three,
    swatchStrategy: .vibrant,
    grain: .standard
)

PaletteGraphic(palette: palette, swatches: swatches, configuration: configuration)
    .frame(width: 320, height: 320)
    .clipShape(RoundedRectangle(cornerRadius: 24))
```

UIKit gets the same renderer through `PaletteGraphicView` (`UIView`) — no
`UIHostingController` wrapper. For a static `UIImage`, call
`.makeImage(size:scale:)` on `PaletteGraphic` or `.snapshotImage(scale:)`
on `PaletteGraphicView`.

## Features

- **Async, Sendable, Swift 6 strict concurrency.** Every entry point is
  `async throws`. `PaletteExtractor` is a value type — one per call site
  or share freely across actors.
- **Palette-driven graphic primitive.** `PaletteGraphic` (SwiftUI) and
  `PaletteGraphicView` (UIKit) render gradient + grain artwork from any
  extracted palette. Pixel-equivalent across platforms via a shared Core
  Image / Core Graphics renderer; `NSCache`-memoized so repeated SwiftUI
  body invalidations return instantly. Configurable along four orthogonal
  axes (direction, color count, swatch strategy, grain).
- **Rich `PaletteColor`.** hex, HSL, OKLCH, contrast, `isDark`/`isLight`, and
  ShapeStyle conformance so it slots into any SwiftUI fill / foreground /
  background modifier directly.
- **OKLCH perceptual quantization by default.** Palettes feel evenly
  spaced to the human eye, not evenly spaced in sRGB.
- **Display P3 native.** iPhone photos keep their chroma instead of
  being clipped to sRGB.
- **CPU by default, Metal opt-in.** `MmcqQuantizer` (CPU, Accelerate)
  is the default and what `.auto` always selects. `MetalMmcqQuantizer`
  (GPU compute shader) is opt-in for raw mode on ≥4MP inputs, where
  on-device measurements show a ~5-10% quantize-stage speedup. Bring
  your own via the `Quantizer` protocol.
- **Automatic pre-downsampling.** `CGImageSourceCreateThumbnailAtIndex`
  keeps memory bounded for 12-megapixel photos.
- **Semantic swatches.** Six OKLCH roles (vibrant, muted, darkVibrant,
  darkMuted, lightVibrant, lightMuted) with accessible text-color
  recommendations.
- **EXIF auto-orientation** for real-world iPhone photos.
- **`os.Logger` + signposts** wired into Instruments' "Points of Interest".
- **Typed errors.** `PaletteError.decodingFailed / imageEmpty /
  allPixelsFiltered / cancelled / unsupportedSource / metalUnavailable`.

## Install

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/2dubu/PaletteKit", from: "1.4.0"),
]
```

Minimum iOS 17 · Swift 6.0 · Xcode 16+.

## API

```swift
extractor.dominantColor(from:)    // PaletteColor?
extractor.palette(from:)          // Palette
extractor.swatches(from:)         // SwatchMap
```

`ImageSource` cases (`.cgImage` / `.data` / `.url`) and the full
`ExtractionOptions` surface (`colorCount`, `quality`, `colorSpace`,
`downsample`, `quantizer`, …) are documented in the
[DocC reference](https://swiftpackageindex.com/2dubu/PaletteKit/documentation/palettekit).

**Tip:** Prefer `.data(...)` for HEIC/JPEG bytes you already hold in
memory or fetched over the network. PaletteKit's data path skips
file-system overhead — measured ~17% faster than `.url(...)` on
iPhone 15 Pro for a 4MP HEIC input. Use `.url(...)` when the file
lives on disk so the decoder can mmap it directly.

## Color space handling

PaletteKit detects the source color space from `CGImage.colorSpace` and
keeps palette colors in that space. Display P3 input → Display P3
output. OKLCH is used only internally during quantization for
perceptual uniformity.

```swift
let palette = try await extractor.palette(from: .url(hdrPhotoURL))
palette.colorSpaceUsed  // .displayP3 on an iPhone HEIC, .sRGB elsewhere
```

## CPU vs Metal: choose by goal, not by image size

Default (`.auto`) **always uses CPU MMCQ**. On-device measurements
(iPhone 15 Pro, 4096² photos) showed CPU and Metal within ≤4ms after
auto-downsample, so size-based routing added complexity without
measurable wins at default settings.

Metal becomes useful in a narrow band: **raw mode + ≥4MP input**, where
it shaves ~5-10% off quantize. Use `.metal` only when you've also
disabled downsampling.

| You want… | `quantizer` | `downsample` | Notes |
| --- | --- | --- | --- |
| **A palette, no fuss** | `.auto` | default | The default. CPU + auto-downsample. |
| **Maximum color accuracy** | `.cpu` | `.disabled` | Process every pixel. Slowest, most accurate. |
| **Accuracy + speed on large inputs** | `.metal` | `.disabled` | ≥4MP only. ~5-10% quantize win vs CPU raw. |
| **Ensure work runs on GPU** | `.metal` | default | Falls back to CPU if Metal is unavailable. |

```swift
// Default — CPU with auto-downsample to ~1M pixels:
try await extractor.palette(from: source)

// Maximum accuracy — every pixel, CPU MMCQ:
try await extractor.palette(from: source,
    options: ExtractionOptions(downsample: .disabled, quantizer: .cpu))

// Large-input accuracy + Metal (≥4MP raw):
try await extractor.palette(from: source,
    options: ExtractionOptions(downsample: .disabled, quantizer: .metal))
```

Metal warms up the first time `MetalContext` is touched (shader compile +
pipeline build). Subsequent calls are steady-state. In `DEBUG` builds,
PaletteKit logs a hint to the console if you select `.metal` on input
that's too small for the speedup to land.

## Instrumentation

```swift
let palette = try await extractor.palette(
    from: .url(url),
    options: ExtractionOptions(collectTimings: true)
)
palette.timings?.decode          // Duration
palette.timings?.sample          // Duration
palette.timings?.quantize        // Duration
palette.timings?.total           // Duration
palette.timings?.quantizerUsed   // "MMCQ-CPU" or "MMCQ-Metal"
```

Instruments traces are annotated via `os_signpost`
(`com.paletteKit` / pointsOfInterest). Use the "Points of Interest"
template to see decode / sample / quantize intervals.

## Documentation

Full DocC catalog ships with the package:

- `PaletteKit` reference
- `GettingStarted.md` · `Options.md` · `PerformanceTuning.md` · `Card.md`
- `AlgorithmDeepDive.md` — MMCQ, OKLCH, Swatches internals

Generate locally with `xcodebuild docbuild` or browse on
[Swift Package Index](https://swiftpackageindex.com/2dubu/PaletteKit/documentation).

## Example

`Examples/PaletteKitDemo` — a minimal SwiftUI app showing a
photo-picker → palette grid → swatches → timings flow. Tap **Generate
Graphic** on the result screen to open the **Graphic Lab** — interactive
playground for every `PaletteGraphic` configuration axis on your actual
extracted palette.

```bash
make setup       # one-time: installs xcodegen via Homebrew if missing
make demo-app    # generate PaletteKitDemo.xcodeproj and open it in Xcode
                 # pick a simulator and press ⌘R to run
```

See [`Examples/PaletteKitDemo/README.md`](./Examples/PaletteKitDemo/README.md)
for how the app is wired.

## Benchmark on your device

The demo app ships with an on-device benchmark harness. Pick a real
photo or use the synthesized fixture, vary size / quantizer /
downsample, and export per-stage timings (decode, sample, quantize)
as CSV for cross-device comparison.

```bash
make demo-app    # build & run on a connected iPhone, tap the
                 # speedometer icon in the top-right
```

Tap **Run**, watch the chart fill in, then **Export** as Raw CSV or
Summary CSV via the share sheet. Save exports under `benchmark/`
(gitignored) for local-only analysis.

This harness is primarily an internal development discipline tool
(every CPU/GPU change has to clear a measurement gate before it
lands). It ships in the demo app for transparency, but most apps
don't need to run it.

## Requirements

- iOS 17+
- Xcode 16+
- Swift 6.0 (strict concurrency)

## Roadmap

- **v1.3** ✅ shipped — SwiftUI ShapeStyle conformance + idiomatic UIKit integration.
- **v1.4** ✅ shipped — `PaletteGraphic` + `PaletteGraphicView` palette-driven graphic primitives.
- **v2.0** — `observe()` (live video / camera) and `PaletteKitInsights` (FoundationModels captions, color naming, custom instructions on iOS 26+).

Per-release notes live on [GitHub Releases](https://github.com/2dubu/PaletteKit/releases).

## Acknowledgements

Thanks to [color-thief](https://github.com/lokesh/color-thief) by
Lokesh Dhakar (MIT) for charting the way — the MMCQ algorithm family,
OKLCH-first quantization, and the six-role swatch layout shaped
PaletteKit's direction. PaletteKit reimagines those ideas for iOS with a
Metal compute histogram, Display P3 preservation, Swift 6 concurrency, and
CGImageSource-based decoding, while keeping the algorithmic core
compatible so outputs can be cross-verified against the reference.

## License

MIT. See [LICENSE](./LICENSE).
