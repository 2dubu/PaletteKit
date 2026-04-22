<img src="https://github.com/user-attachments/assets/95a7bc65-5171-4542-944e-af88788507c8" alt="palettekit" style="width: 100%; max-width: 100%; height: auto; display: block;" />

# PaletteKit

[![Swift](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F2dubu%2FPaletteKit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/2dubu/PaletteKit)
[![Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2F2dubu%2FPaletteKit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/2dubu/PaletteKit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

High-performance iOS-native color palette extraction. Swift Package,
SwiftUI- and UIKit-friendly. Inspired by [color-thief](https://github.com/lokesh/color-thief)
but reimagined for Apple platforms: Metal compute histogram, OKLCH
perceptual quantization, Display P3 wide-gamut support, Semantic
Swatches, async-only Sendable API.

```swift
import PaletteKit

let extractor = PaletteExtractor()

// Dominant color
let color = try await extractor.dominantColor(from: .cgImage(image))
color?.hex        // "#e84393"
color?.isDark     // false

// Palette
let palette = try await extractor.palette(from: .url(imageURL))
for entry in palette {
    print(entry.hex, entry.proportion)
}

// Semantic swatches
let swatches = try await extractor.swatches(from: .data(imageData))
swatches.vibrant?.color.hex
```

## Features

- **Async, Sendable, Swift 6 strict concurrency.** Every entry point is
  `async throws`. `PaletteExtractor` is a value type — one per call site
  or share freely across actors.
- **Rich `PaletteColor`.** hex, HSL, OKLCH, WCAG contrast, text-color
  recommendation, `isDark`/`isLight`, population, proportion.
- **OKLCH perceptual quantization by default.** Palettes feel evenly
  spaced to the human eye, not evenly spaced in sRGB.
- **Display P3 native.** iPhone photos keep their chroma instead of
  being clipped to sRGB.
- **Two backends, same algorithm.** `MmcqQuantizer` (CPU, Accelerate)
  and `MetalMmcqQuantizer` (GPU compute shader). `.auto` routes based
  on image size. Bring your own via `Quantizer` protocol.
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
    .package(url: "https://github.com/2dubu/PaletteKit", from: "1.0.0"),
]
```

Minimum iOS 17 · Swift 6.0 · Xcode 16+.

## API at a glance

| Call | Returns |
|---|---|
| `extractor.dominantColor(from:options:)` | `PaletteColor?` |
| `extractor.palette(from:options:)` | `Palette` |
| `extractor.swatches(from:options:)` | `SwatchMap` |

| `ImageSource` case | Input |
|---|---|
| `.cgImage(CGImage)` | already-decoded image |
| `.data(Data)` | raw image data (JPEG, HEIC, PNG, …) |
| `.url(URL)` | local or remote image URL |

| `ExtractionOptions` | Default | Purpose |
|---|---|---|
| `colorCount` | 10 | palette size (2–256) |
| `quality` | `.stride(10)` | pixel stride |
| `colorSpace` | `.oklch` | quantization space |
| `ignoreWhite` | `true` | filter near-white pixels |
| `whiteThreshold` | 250 | channel threshold for "white" |
| `alphaThreshold` | 125 | drop pixels with alpha below |
| `minSaturation` | 0 | drop low-saturation pixels |
| `fallbackStrategy` | `.relax` | empty-filter recovery |
| `autoOrient` | `true` | respect EXIF orientation |
| `downsample` | `.automatic(maxPixels: 1_000_000)` | decode-time downsample |
| `quantizer` | `.auto` | `.auto` / `.cpu` / `.metal` / `.custom` |
| `collectTimings` | `false` | populate `palette.timings` |

## Color space handling

PaletteKit detects the source color space from `CGImage.colorSpace` and
keeps palette colors in that space. Display P3 input → Display P3
output. OKLCH is used only internally during quantization for
perceptual uniformity.

```swift
let palette = try await extractor.palette(from: .url(hdrPhotoURL))
palette.colorSpaceUsed  // .displayP3 on an iPhone HEIC, .sRGB elsewhere
```

## CPU vs Metal

`.auto` picks Metal once the sampled pixel count reaches **500,000** and
CPU below that. The threshold is provisional — it will be retuned after
the first round of real-device measurements feeds back into the
benchmark suite.

```swift
// Force CPU
try await extractor.palette(from: source,
    options: ExtractionOptions(quantizer: .cpu))

// Force Metal (falls back to CPU if Metal is unavailable)
try await extractor.palette(from: source,
    options: ExtractionOptions(quantizer: .metal))
```

Metal warms up the first time `MetalContext` is touched (shader compile +
pipeline build). Subsequent calls are steady-state.

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
- `GettingStarted.md` · `Options.md` · `PerformanceTuning.md`
- `AlgorithmDeepDive.md` — MMCQ, OKLCH, Swatches internals

Generate locally with `xcodebuild docbuild` or browse on
[Swift Package Index](https://swiftpackageindex.com/2dubu/PaletteKit/documentation).

## Example

`Examples/PaletteKitDemo` — a minimal SwiftUI app showing a
photo-picker → palette grid → swatches → timings flow.

```bash
make setup       # one-time: installs xcodegen via Homebrew if missing
make demo-app    # generate PaletteKitDemo.xcodeproj and open it in Xcode
                 # pick a simulator and press ⌘R to run
```

See [`Examples/PaletteKitDemo/README.md`](./Examples/PaletteKitDemo/README.md)
for how the app is wired.

## Requirements

- iOS 17+
- Xcode 16+
- Swift 6.0 (strict concurrency)

## Roadmap

- **v1.x (minor)** — progressive extraction, k-means quantizer,
  `PaletteKitCard` (palette-driven share-card graphics with three-tier
  shader strategy), macOS / watchOS / tvOS / visionOS expansion.
- **v2.0** — live video / camera `observe()`; `PaletteKitInsights`
  (FoundationModels captions, color naming, custom instructions on
  iOS 26+).

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
