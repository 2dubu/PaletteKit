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

``QuantizerSelection/auto`` picks Metal once the sampled pixel count
reaches **500,000**. Below that threshold CPU is both simpler and faster
because there is no GPU round-trip. The threshold is provisional; we
tighten it as we collect more real-device numbers.

Override explicitly when you know what you want:

```swift
ExtractionOptions(quantizer: .cpu)    // always CPU
ExtractionOptions(quantizer: .metal)  // force Metal (degrades to CPU if
                                      // Metal is unavailable)
```

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
