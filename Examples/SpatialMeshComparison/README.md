# Fixed-grid spatial mesh prototype

This Debug-only research example compares the unchanged palette-driven mesh
with a source-position-aware 3×3 / 4×4 mesh. It is separate from the demo app,
so it does not depend on pending Graphic Lab changes. It imports the baseline
resolver with `@testable`; build this harness in **Debug**, not Release.

The prototype is opt-in SPI, not a stable public API:

```swift
@_spi(SpatialPrototype) import PaletteKit

// Run analysis off the UI actor in a production caller.
let mesh = try SpatialMeshAnalyzer.analyze(.data(data), grid: .three)
// iOS 18+, main actor:
SpatialMeshGraphic(mesh: mesh)
let image = SpatialMeshGraphic(mesh: mesh).makeImage(width: 384, scale: 1)
```

`SpatialMesh` is Sendable data with no UIKit dependency. The SwiftUI renderer is
a separate iOS adapter. Existing `PaletteMeshGraphic`, its population allocation,
OKLCH lightness/chroma ordering, jitter, and seed are unchanged.

## Input and sampling contract

- Encoded Data and local URL inputs use ImageIO's EXIF transform, including all
  eight rotation/mirror orientations. CGImage inputs must already be oriented.
- The first frame is reduced to a maximum edge of 128 pixels without cropping.
  The original display aspect ratio is retained separately from integer thumbnail
  dimensions. The renderer fits that ratio; integer output pixels may round it.
- Core Graphics converts tagged colors to 8-bit sRGB and composites transparency
  on white. This is a prototype-specific contract; it does not change the existing
  palette loader's alpha or P3 policies. Wide-gamut colors can clip to sRGB.
- Grid points include the boundaries at 0 and 1, in top-to-bottom row-major order.
  Each point averages the clipped box extending half a grid interval on each axis.
  Pixel-center inclusion uses an exclusive right/bottom bound. Very small images
  reuse a pixel when a box would otherwise contain none.
- The averages use linear-light sRGB and are encoded back to 8-bit sRGB. White
  pixels remain in the averages. No quantization, adaptive point motion, accent
  enhancement, or ThumbHash is used.

## Reproduce the comparison

Requirements: Xcode, XcodeGen, a booted iOS 18+ simulator. From this directory:

```sh
xcrun simctl list devices booted
./run-comparison.sh SIMULATOR_UDID /absolute/path/outside/repository
# Optional user-supplied local image, never added to the project or Git:
./run-comparison.sh SIMULATOR_UDID /absolute/path/outside/repository /path/to/image.jpg
```

The script builds and runs the app, waits for `metrics.json`, and copies results.
It resets only this app's prior generated comparison folder and optional input.
The selected image and exported derivatives remain local. Do not publish private
inputs, screenshots, or their derivatives in a PR.

Four deterministic synthetic cases are generated in code: a 60:40 red/blue split,
its horizontal reflection (same color proportions), a 1% red rectangle on white,
and four asymmetric corner colors. An optional local image is the fifth case.
All are rendered for both grid sizes. No binary fixtures are committed.

Each comparison PNG shows **original / existing palette mesh / spatial mesh**.
Separate PNGs and an additional `legacy-fixed` output are exported. The latter
uses the existing resolver's colors on the new fixed points to isolate color
placement from the old jitter. Both primary methods use the same point count,
output frame, and native SwiftUI MeshGradient defaults. Output width is 384px;
height is rounded from the oriented input ratio. The displayed original uses
UIImage's orientation handling; analysis and metrics use the common thumbnail.

Both analyses receive the same oriented, white-composited sRGB thumbnail. The
baseline extracts K=10 using CPU OKLCH, stride 1, ignoreWhite=false, and no further
downsampling, then uses the existing resolver unchanged. These intentionally
controlled extraction options are not a claim about all default app settings.

The baseline uses Swift Hasher and may change jitter across launches. The export
records the actual points and colors for that run. Compare the reflected pair
within one run; do not assume byte-identical baseline PNGs across processes.

## Measurement and interpretation

`metrics.json` records each condition, grid colors/points, extraction settings,
output/sample dimensions, and per-image mean OKLab distance. Both rendered outputs
are resampled to the reference's exact width and height, including inputs smaller
than 128px. At each matching
pixel, sRGB is converted using PaletteKit's OKLCH conversion and then to OKLab
(`a=C cos(h)`, `b=C sin(h)`); the Euclidean distance is averaged over the image.
This is a positional similarity diagnostic, not perceptual preference or a
validated general-purpose image-quality score.

For the small-accent case, a pixel is red when its OKLab distance to #ff0000 is
less than **0.12**, fixed before inspecting results. The export records area
fraction and normalized pixel-center centroid. A null centroid means the accent
is absent; position error must not be interpreted as zero. Reduction to the
reference thumbnail can change its measured area slightly from the exact 1%
source area. A good whole-image mean can coexist with a missing accent.

This is a small development set. Sharp edges blur; small accents are diluted;
the local mean need not preserve distinct colors or their area. A 4×4 result
uses more control points than 3×3, so cross-grid gains are not same-budget gains.
There are no elapsed-time, memory, real-device, held-out-set, or preference claims.

## Tests and review order

```sh
swift test --filter PaletteKitTests --filter PaletteKitInsightsTests
xcodebuild test -scheme PaletteKit-Package -only-testing:PaletteKitTests \
  -destination 'id=SIMULATOR_UDID'
xcodegen generate --spec Examples/SpatialMeshComparison/project.yml
xcodebuild test -project Examples/SpatialMeshComparison/SpatialMeshComparison.xcodeproj \
  -scheme SpatialMeshComparison -destination 'id=SIMULATOR_UDID' CODE_SIGNING_ALLOWED=NO
```

Review the spatial input/sampling code and regression tests first, the iOS
comparison harness second, then these reproduction and measurement notes.
Tests cover position swaps, all EXIF orientations and the URL path, white/alpha,
linear-light averaging, tagged P3 conversion, tiny/portrait/landscape dimensions,
invalid data, and actual iOS rendered corner orientation and aspect ratio.
The comparison app's hosted tests additionally verify exact metric-raster sizes
for small square, landscape, and portrait references, plus color orientation.
