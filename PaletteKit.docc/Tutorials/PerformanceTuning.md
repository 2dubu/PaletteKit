# Performance Tuning

PaletteKit is built around the fact that the hot path lives in two
places: decoding pixels and building the MMCQ histogram.

## Decoding

For `Data` and URL sources, the loader first requests an ImageIO thumbnail with
`CGImageSourceCreateThumbnailAtIndex` and
`kCGImageSourceThumbnailMaxPixelSize`. This avoids a full-resolution decode
when thumbnail creation succeeds. ImageIO can fall back to a full decode, and
a `CGImage` source is already decoded before PaletteKit receives it. Adjust the
target with `downsample`:

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
`MetalContext` is warmed up (shader compile + pipeline build). After
that, subsequent extractions reuse the cached resources.

## Auto-selection

``QuantizerSelection/auto`` **always selects CPU MMCQ.** This keeps the default
path predictable and avoids paying Metal setup and transfer costs without a
workload-specific measurement.

Metal is available for large, non-downsampled inputs. Whether it helps depends
on the device, source image, sampling options, and call frequency. See
<doc:Options> for the full "Choosing accuracy vs speed" decision tree, or
compare the explicit overrides with `collectTimings`.

```swift
let cpu = ExtractionOptions(
    quality: .highest,
    downsample: .disabled,
    quantizer: .cpu
)
let metal = ExtractionOptions(
    quality: .highest,
    downsample: .disabled,
    quantizer: .metal
)
```

On a Metal-capable target, device, shader, or pipeline creation failures are
reported as extraction errors. Measure the path with your own representative
images before enabling it in production.

In `DEBUG` builds, PaletteKit emits a console hint when `.metal` is
selected on input that's too small to benefit (sampled pixel count
< 1M).

## Instruments

PaletteKit emits `os_signpost` events on
`com.paletteKit / pointsOfInterest`. Record an Instruments trace with the
"Points of Interest" template to see the overall `extract` interval around a
call. Use `collectTimings` for separate decode, sample, and quantize durations.

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
