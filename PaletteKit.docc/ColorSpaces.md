# Display P3 and OKLCH Color Extraction

Understand how PaletteKit detects Display P3 images, uses OKLCH for
perceptual quantization, and returns colors to SwiftUI and UIKit.

## Does PaletteKit support Display P3 images?

PaletteKit supports Display P3-aware input analysis. It does not preserve a P3
output profile through the default pipeline. PaletteKit detects sRGB and
Display P3 `CGImage` color spaces while it decodes an image. With the default
`colorSpace: .oklch` option, it applies the matching sRGB-to-OKLCH or Display
P3-to-OKLCH conversion before quantization. This avoids treating Display P3
channel values as if they were sRGB during perceptual clustering.

The resulting ``Palette/colorSpaceUsed`` value records the detected source
space when the default OKLCH pipeline is used.

> Important: The default OKLCH path converts representative colors back to
> sRGB and clamps channels to the sRGB range. ``PaletteColor`` stores that
> untagged 8-bit RGB triple, and its SwiftUI `ShapeStyle`, `UIColor`, and
> ``PaletteColor/cgColor`` adapters emit sRGB-tagged colors. A
> `colorSpaceUsed` value of `.displayP3` records the detected input in this
> mode; it does not make the returned RGB values Display P3 coordinates.

## Why does PaletteKit use OKLCH?

RGB channel distance is not perceptually uniform: two equally sized numeric
changes can look very different to a person. OKLCH separates lightness,
chroma, and hue, so PaletteKit can run MMCQ over a space that better reflects
visible differences between colors.

The default pipeline is:

1. Decode and rasterize the image in its detected sRGB or Display P3 space.
2. Filter and sample pixels according to ``ExtractionOptions``.
3. Convert sampled pixels to scaled OKLCH coordinates.
4. Quantize those coordinates with the selected MMCQ backend.
5. Convert representative colors to clamped, 8-bit sRGB ``PaletteColor``
   values.

See <doc:AlgorithmDeepDive> for the histogram and median-cut details.

## Which color-space option should I choose?

| Option | Behavior | Use it when |
| --- | --- | --- |
| ``ColorSpace/oklch`` | Uses source-aware OKLCH conversion before MMCQ | You want the recommended perceptual palette extraction path |
| ``ColorSpace/sRGB`` | Quantizes rasterized channel values directly in RGB space | You need direct RGB-space MMCQ behavior |
| ``ColorSpace/displayP3`` | Quantizes rasterized channel values directly and sets `colorSpaceUsed` to Display P3 | You know the source is P3 and will interpret raw channels yourself |

For most applications, keep the default `.oklch` setting.

> Note: Selecting `.sRGB` or `.displayP3` does not convert channel values from
> one RGB color space into the other. Only use a direct RGB mode when the
> source space is known and matches the interpretation your application will
> apply to the raw channels.

```swift
let palette = try await PaletteExtractor().palette(
    from: .data(imageData),
    options: ExtractionOptions(colorSpace: .oklch)
)
```

## How do I check whether the source was Display P3?

With the default `.oklch` mode, inspect ``Palette/colorSpaceUsed`` to see the
detected source space:

```swift
switch palette.colorSpaceUsed {
case .displayP3:
    print("Display P3 source")
case .sRGB:
    print("sRGB source")
case .oklch:
    print("Custom OKLCH metadata")
}
```

In direct `.sRGB` or `.displayP3` mode, `colorSpaceUsed` records the selected
mode instead. It is extraction metadata, not a color profile embedded in each
``PaletteColor``.

The computed ``PaletteColor/oklch`` property also interprets the stored RGB
channels as sRGB.

## Do SwiftUI and UIKit preserve Display P3 output?

Not through the built-in convenience adapters. `PaletteColor.resolve(in:)`,
`UIColor(_:)`, and ``PaletteColor/cgColor`` all interpret the returned RGB
channels as sRGB. This makes their behavior deterministic across UI layers.

The default `.oklch` result cannot be reinterpreted as Display P3 by combining
`colorSpaceUsed` with the raw channels; those channels have already been
converted to sRGB. If your application requires P3 output, PaletteKit does not
currently provide an end-to-end color-managed convenience path.

An advanced caller that knows the input is genuinely Display P3 can select
`.displayP3`, quantize those rasterized channels directly, and construct a P3
platform color without using the built-in adapters. This mode does not verify
or convert the source space, so validate the full path with representative
wide-gamut assets.
