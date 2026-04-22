# Algorithm Deep Dive

How PaletteKit turns pixels into a palette.

## Modified Median Cut Quantization

The core algorithm is Modified Median Cut Quantization (MMCQ), the same
algorithm used by color-thief. PaletteKit ports the
`@lokesh.dhakar/quantize` reference verbatim so cross-verification stays
simple.

### Step 1: reduced histogram

Each pixel is downsampled from 8 bits per channel to 5 by right-shifting
by 3. That produces a 32,768-bin 3-D histogram that fits comfortably in
L2 cache. The ``MmcqQuantizer`` backend builds this histogram on CPU with
a single loop; the ``MetalMmcqQuantizer`` backend builds it on the GPU
with an atomic-add compute shader.

### Step 2: initial VBox

The engine finds the axis-aligned bounding box of every non-empty
histogram bin — that is the initial VBox. Its `avg()` is the average
color within it.

### Step 3: median cut

VBoxes are held in a priority queue. On each iteration we pop the "best"
box, cut it along its widest RGB axis at the bin that passes the halfway
mark in population, and push the two children back. The split chooses
the bin immediately past the midpoint and nudges the cut into the larger
half to keep both children non-empty.

### Step 4: two-phase iteration

Phase 1 keeps the priority queue sorted by population and stops at
`floor(maxColors * 0.75)` boxes. Phase 2 resorts by `count * volume` and
continues until the queue hits `maxColors`. The second metric makes sure
large-but-sparse regions keep splitting, not just the densest tiny ones.

### Step 5: readout

Every remaining VBox contributes its weighted average color and its
population. ``PaletteBuilder`` sorts by population, computes
proportions, and wraps each entry in ``PaletteColor``.

## OKLCH perceptual quantization

`colorSpace: .oklch` is the default. Pixels are converted to OKLCH,
scaled to the 0-255 integer range MMCQ expects, quantized, then mapped
back to sRGB (or Display P3 when the source image is P3). The result is
a more perceptually uniform palette — colors "feel" evenly spaced to the
eye rather than being evenly spaced in RGB.

- ``OKLCHConversion/rgbToOKLCH(_:)`` implements the Oklab M1 matrix
  + cube-root + Lab-to-LCh reduction.
- ``OKLCHConversion/displayP3ToOKLCH(_:)`` uses the P3-to-linear-sRGB
  matrix so wide-gamut chroma survives the round-trip.

## Semantic swatches

``SwatchClassifier`` ports color-thief v3's six-role OKLCH classifier.
Each role has an OKLCH target with lightness and chroma bands; each
palette entry is scored against every role using
`lightnessCloseness * 6 + chromaCloseness * 3 + populationShare * 1`.
Conflicts (two roles wanting the same color) resolve by letting the
highest-scoring role keep it and re-assigning the losers to the next
best unused color.

## Downsampling before decoding

`PixelLoader` prefers `CGImageSourceCreateThumbnailAtIndex` with
`kCGImageSourceThumbnailMaxPixelSize` so large photos are decoded and
downsampled in a single pass. The MMCQ histogram is then built from the
thumbnail rather than a full-resolution buffer.

## References

- Xiaolin Wu, "Efficient Statistical Computations for Optimal Color
  Quantization," Graphics Gems II, 1991.
- Paul Heckbert, "Color Image Quantization for Frame Buffer Display,"
  SIGGRAPH '82.
- Björn Ottosson, [A perceptual color space for image processing](https://bottosson.github.io/posts/oklab/).
- [@lokesh.dhakar/quantize](https://github.com/lokesh/quantize).
