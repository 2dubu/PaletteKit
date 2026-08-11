# PaletteKit FAQ

Direct answers to common questions about dominant color extraction, SwiftUI,
UIKit, Display P3, OKLCH, MMCQ, Metal, and PaletteKit's relationship to
color-thief.

## What is PaletteKit?

PaletteKit is a Swift 6 package for extracting dominant colors, ordered color
palettes, and six semantic swatch roles from images on Apple platforms. Its
extraction methods are async, while the extractor and result values are
`Sendable`. Result types integrate with SwiftUI, UIKit, and Core Graphics.

## Which platforms does PaletteKit support?

The package declares iOS 17 and macOS 14 as its minimum platforms. SwiftUI
integration is available where SwiftUI can be imported; the `UIColor`
initializer and UIKit views are available on UIKit platforms.

## How do I extract the dominant color from an image in Swift?

Pass an ``ImageSource/cgImage(_:)``, ``ImageSource/data(_:)``, or local
``ImageSource/url(_:)`` value to
``PaletteExtractor/dominantColor(from:options:)``:

```swift
let color = try await PaletteExtractor().dominantColor(
    from: .cgImage(cgImage)
)
```

For `UIImage`, remote URL, palette, and semantic-swatch examples, see
<doc:ImageColorExtraction>.

## Does PaletteKit download remote images?

No. ``ImageSource/url(_:)`` is for an image file that ImageIO can read. Fetch a
remote HTTP image with `URLSession` or your networking layer, then pass the
encoded bytes as ``ImageSource/data(_:)``.

## Does PaletteKit accept UIImage or SwiftUI Image directly?

`UIImage` and SwiftUI `Image` are not ``ImageSource`` cases. For a `UIImage`
with a `CGImage` backing store, pass `image.cgImage` as `.cgImage`. For a
SwiftUI `Image`, retain the original `CGImage`, `Data`, or file URL used to
create the view and extract from that source.

## Does PaletteKit work with SwiftUI and UIKit?

Yes. ``PaletteColor`` conforms to SwiftUI `ShapeStyle`, so it can be used with
`fill`, `foregroundStyle`, and other styling APIs. UIKit code can construct a
`UIColor` with `UIColor(paletteColor)`, and ``PaletteColor/cgColor`` works with
Core Graphics and `CALayer`.

PaletteKit also includes palette-driven SwiftUI and UIKit graphic views. Start
with <doc:GettingStarted>, <doc:Card>, or <doc:AsyncLoading>.

## Does PaletteKit support Display P3 and OKLCH?

PaletteKit detects Display P3 inputs and uses a P3-aware conversion when the
default OKLCH quantization path is selected. Built-in SwiftUI and UIKit output
adapters are sRGB-tagged, so P3-aware extraction should not be confused with
end-to-end P3 rendering. See <doc:ColorSpaces> for the exact pipeline.

## What is the difference between a palette and semantic swatches?

A ``Palette`` is an ordered collection of representative colors, sorted by
population. A ``SwatchMap`` classifies palette candidates into six optional UI
roles: vibrant, muted, dark vibrant, dark muted, light vibrant, and light
muted. Use a palette for raw color choices and swatches when your UI needs
role-based accents or backgrounds.

## Does PaletteKit provide readable text colors?

Each ``PaletteColor`` exposes black-versus-white contrast ratios and a
``PaletteColor/textColor`` recommendation. Each ``Swatch`` also includes
`titleTextColor` and `bodyTextColor`. These are useful starting points, but
your application should still validate the final foreground/background pair
against its own WCAG target, font size, and presentation context.

## How is PaletteKit related to color-thief?

PaletteKit is a ground-up Swift implementation inspired by color-thief and its
MMCQ algorithm family. It is not a drop-in port of the JavaScript API. It adds
Apple-native ImageIO decoding, Swift concurrency, OKLCH-based quantization,
semantic swatches, optional Metal histogram computation, and native UI result
types. Exact palette parity is not guaranteed.

## Does PaletteKit use the GPU automatically?

No. ``QuantizerSelection/auto`` currently selects the CPU MMCQ backend. Choose
`.metal` explicitly when testing a large, non-downsampled workload. Metal has
startup costs, and device, shader, or pipeline creation failures on a
Metal-capable target are reported as extraction errors. See
<doc:PerformanceTuning> and measure with representative images.

## How does PaletteKit handle large photos?

The default downsampling policy targets up to about one million raster pixels
for `Data` and URL inputs, then the default quality setting samples every tenth
pixel. Thumbnail decoding can fall back to a full decode, and a `CGImage` is
already decoded when passed to PaletteKit. You can tune both settings through
``ExtractionOptions``. See <doc:Options> before disabling downsampling.

## Is PaletteExtractor thread-safe?

``PaletteExtractor`` is a stateless `Sendable` value type. You can construct
one per call site or share it across actors. Its public methods are
`async throws` and check for cooperative task cancellation between extraction
stages.

## Why can a semantic swatch be nil?

Each semantic role has lightness and chroma constraints. A role is `nil` when
the extracted palette has no unused candidate within that role's range. Keep a
fallback ``PaletteColor`` in UI code or use the convenience lookup methods on
``SwatchMap``.
