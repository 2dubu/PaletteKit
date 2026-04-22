# ``PaletteKit``

High-performance iOS-native color palette extraction with MMCQ, OKLCH
perceptual quantization, Display P3 wide-gamut support, semantic swatches,
and an optional Metal backend.

## Overview

PaletteKit extracts dominant colors, palettes, and semantic swatches from
images on iOS. It is a ground-up Swift implementation inspired by
[color-thief v3](https://github.com/lokesh/color-thief) that takes advantage
of Apple-native tooling the web port cannot reach: `CGImageSource` thumbnail
decoding, EXIF-aware orientation, Display P3 wide-gamut preservation, OKLCH
perceptual quantization, and a Metal compute-shader histogram path.

- **Async-only, Sendable API.** Every entry point is `async throws`.
  `PaletteExtractor` is a value type so you can use one per call site or
  share it freely across actors.
- **Rich `PaletteColor`.** Returns more than just RGB — hex, HSL, OKLCH,
  WCAG contrast, text color recommendations, population, proportion.
- **Strategy-pattern quantizers.** MMCQ on CPU by default, Metal for
  large images, or bring your own `Quantizer`.
- **Wide-gamut aware.** Display P3 images keep their chroma through the
  OKLCH conversion instead of being clipped to sRGB.

## Getting Started

```swift
import PaletteKit

let extractor = PaletteExtractor()
let color = try await extractor.dominantColor(from: .cgImage(image))
print(color?.hex ?? "no dominant color")

let palette = try await extractor.palette(from: .url(url))
palette.forEach { print($0.hex, $0.proportion) }

let swatches = try await extractor.swatches(from: .data(data))
swatches.vibrant?.color.hex
```

## Acknowledgements

Thanks to [color-thief](https://github.com/lokesh/color-thief) by
Lokesh Dhakar (MIT) for charting the way — the MMCQ algorithm family,
OKLCH-first quantization, and the six-role swatch layout shaped
PaletteKit's direction. PaletteKit reimagines those ideas for iOS with a
Metal compute histogram, Display P3 preservation, Swift 6 concurrency, and
CGImageSource-based decoding, while keeping the algorithmic core
compatible so outputs can be cross-verified against the reference.

## Topics

### Extracting colors
- ``PaletteExtractor``
- ``ExtractionOptions``
- ``ImageSource``

### Result types
- ``PaletteColor``
- ``Palette``
- ``Swatch``
- ``SwatchMap``
- ``SwatchRole``

### Color math
- ``RGB``
- ``HSL``
- ``OKLCH``
- ``OKLCHConversion``

### Custom backends
- ``Quantizer``
- ``MmcqQuantizer``
- ``MetalMmcqQuantizer``
- ``QuantizerSelection``

### Errors & diagnostics
- ``PaletteError``
- ``ExtractionTimings``
