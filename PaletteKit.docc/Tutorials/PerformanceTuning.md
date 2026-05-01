# Performance Tuning

PaletteKit is built around the fact that the hot path lives in two
places: decoding pixels and building the MMCQ histogram.

## Decoding

The loader prefers `CGImageSourceCreateThumbnailAtIndex` with
`kCGImageSourceThumbnailMaxPixelSize`, so a 12-megapixel photo never
allocates a 48-MB RGBA buffer. Adjust the cap with `downsample`:

```swift
ExtractionOptions(downsample: .maxEdge(1024))
```

## Histogram: CPU vs Metal

MMCQ reads pixels once to fill a 32,768-bin 5-bit-per-channel histogram,
then runs median-cut on that histogram. The histogram build is
embarrassingly parallel; the median-cut phase is not.

- ``MmcqQuantizer`` builds the histogram and runs median-cut on CPU.
- ``MetalMmcqQuantizer`` dispatches the histogram as a compute shader,
  then hands the result to the same median-cut engine.

The Metal path pays a small cold-start cost the first time
``MetalContext`` is warmed up (shader compile + pipeline build). After
that, subsequent extractions are fast. The first extraction reaches steady
state after ``MetalMmcqQuantizer/prepare()`` has run once per process.

## Auto-selection

``QuantizerSelection/auto`` **always selects CPU MMCQ.** On-device
measurements (iPhone 15 Pro / A17 Pro, 4096² photos) showed CPU and
Metal within ≤4ms after auto-downsample, so size-based routing added
complexity without measurable wins at default settings.

Metal becomes useful in a narrow band — **raw mode + ≥4MP input** —
where it shaves ~5-10% off quantize. See <doc:Options> for the full
"Choosing accuracy vs speed" decision tree, or jump straight to the
overrides:

```swift
ExtractionOptions(quantizer: .cpu)    // explicit CPU
ExtractionOptions(quantizer: .metal)  // explicit Metal (degrades to CPU
                                      // if Metal is unavailable)
```

In `DEBUG` builds, PaletteKit emits a console hint when `.metal` is
selected on input that's too small to benefit (sampled pixel count
< 1M).

## Instruments

PaletteKit emits `os_signpost` events on
`com.paletteKit / pointsOfInterest`. Record an Instruments trace with the
"Points of Interest" template to see decode / sample / quantize durations
around any call.

## Measuring your own workloads

Swap in ``ExtractionOptions/collectTimings`` to get per-stage Duration
values on the returned ``Palette`` without reaching for Instruments.

```swift
let palette = try await extractor.palette(
    from: .url(url),
    options: ExtractionOptions(collectTimings: true)
)
print("decode:", palette.timings?.decode ?? .zero)
print("quantize:", palette.timings?.quantize ?? .zero)
print("engine:", palette.timings?.quantizerUsed ?? "unknown")
```
