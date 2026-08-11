# ``PaletteKit``

Swift image color extraction for dominant colors, ordered palettes, and
semantic swatches, with MMCQ, OKLCH, Display P3-aware input handling, and an
optional Metal backend.

## Overview

PaletteKit is a Swift 6 image color extraction library for iOS and macOS. It
returns dominant colors, ranked palettes, and semantic swatches, with native
result adapters for SwiftUI, UIKit, and Core Graphics. PaletteKit is an
independent Swift implementation inspired by
[color-thief v3](https://github.com/lokesh/color-thief). It uses Apple-native
facilities, including `CGImageSource` thumbnail decoding, EXIF-aware
orientation, Display P3-aware conversion, OKLCH perceptual quantization, and a
Metal compute-shader histogram path.

- **Async-only, Sendable API.** Every extraction entry point is `async throws`.
  `PaletteExtractor` is a value type so you can use one per call site or
  share it freely across actors.
- **Rich `PaletteColor`.** Returns more than just RGB — hex, HSL, OKLCH,
  WCAG contrast, text color recommendations, population, proportion.
- **Strategy-pattern quantizers.** MMCQ on CPU by default, Metal for
  large images, or bring your own `Quantizer`.
- **Display P3-aware extraction.** The default path detects P3 sources and
  uses a P3-to-OKLCH conversion before quantization. Built-in UI adapters emit
  sRGB; see <doc:ColorSpaces> for the exact boundary.

## Getting Started

```swift
import PaletteKit

let extractor = PaletteExtractor()
let color = try await extractor.dominantColor(from: .cgImage(image))
print(color?.hex ?? "no dominant color")

let palette = try await extractor.palette(from: .url(fileURL))
palette.forEach { print($0.hex, $0.proportion) }

let swatches = try await extractor.swatches(from: .data(data))
swatches.vibrant?.color.hex
```

## Acknowledgements

Thanks to [color-thief](https://github.com/lokesh/color-thief) by
Lokesh Dhakar (MIT) for charting the way — the MMCQ algorithm family,
OKLCH-first quantization, and the six-role swatch layout shaped
PaletteKit's direction. PaletteKit reimagines those ideas for Apple platforms
with a Metal compute histogram, Display P3-aware input conversion, Swift 6
concurrency, and CGImageSource-based decoding. PaletteKit is an independent
Swift implementation rather than an API-compatible wrapper, so exact palette
parity is not guaranteed.

## Topics

### Start here
- <doc:GettingStarted>
- <doc:ChoosingAnExtractionResult>
- <doc:ImageColorExtraction>

### Extracting colors
- ``PaletteExtractor``
- ``ExtractionOptions``
- ``ImageSource``

### Working with color
- <doc:ColorSpaces>
- ``RGB``
- ``HSL``
- ``OKLCH``
- ``OKLCHConversion``

### Result types
- ``PaletteColor``
- ``Palette``
- ``Swatch``
- ``SwatchMap``
- ``SwatchRole``
- ``SwatchClassifier``

### Rendering palettes
- <doc:Card>
- ``PaletteGraphic``
- ``PaletteGraphicView``
- ``PaletteMeshGraphic``
- ``AnimatedPaletteGraphic``

### Async loading
- <doc:AsyncLoading>
- ``AsyncPaletteGraphic``
- ``AsyncPaletteGraphicView``
- ``PaletteCache``
- ``AsyncPaletteGraphicTransition``

### Tuning performance
- <doc:Options>
- <doc:PerformanceTuning>

### Understanding PaletteKit
- <doc:FAQ>
- <doc:AlgorithmDeepDive>

### Custom backends
- ``Quantizer``
- ``MmcqQuantizer``
- ``MetalMmcqQuantizer``
- ``QuantizerSelection``

### Errors & diagnostics
- ``PaletteError``
- ``ExtractionTimings``
