# Generating Palette Graphics

Render a palette-driven gradient + grain graphic that callers compose into
cards, posters, share assets, or any layout.

## Overview

``PaletteGraphic`` (SwiftUI) and ``PaletteGraphicView`` (UIKit) take an
extracted ``Palette`` plus an optional ``SwatchMap`` and produce a
rectangular, palette-themed graphic. The two views share the same Core
Image / Core Graphics pipeline so output is pixel-equivalent across
SwiftUI and UIKit.

## SwiftUI

```swift
import PaletteKit
import SwiftUI

struct PaletteCard: View {
    let palette: Palette
    let swatches: SwatchMap?

    var body: some View {
        PaletteGraphic(palette: palette, swatches: swatches, configuration: .init(
            direction: .linear,
            linearStart: .bottomLeading,
            linearEnd: .topTrailing,
            colorCount: .three,
            swatchStrategy: .vibrant,
            grain: .standard
        ))
        .frame(width: 320, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}
```

For a static `UIImage` (sharing, caching), call ``PaletteGraphic/makeImage(size:scale:)``:

```swift
let image: UIImage? = PaletteGraphic(palette: palette, swatches: swatches)
    .makeImage(size: CGSize(width: 1080, height: 1080))
```

## UIKit

```swift
import PaletteKit
import UIKit

let view = PaletteGraphicView(
    palette: palette,
    swatches: swatches,
    configuration: .init(direction: .linear, colorCount: .three)
)
view.translatesAutoresizingMaskIntoConstraints = false
container.addSubview(view)
NSLayoutConstraint.activate([
    view.widthAnchor.constraint(equalToConstant: 320),
    view.heightAnchor.constraint(equalToConstant: 320),
    view.centerXAnchor.constraint(equalTo: container.centerXAnchor),
    view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
])

// Update at runtime — auto re-renders on the next layout pass.
view.configuration.colorCount = .four
view.palette = newPalette
```

## Configuration axes

- ``GradientDirection`` — `.linear` (diagonal flow with custom start/end
  anchors via `UnitPoint`) or `.radial` (concentric rings from upper-right).
- ``ColorCount`` — `.two`/`.three`/`.four`/`.five`. First and last colors
  are anchored to the strategy's resolved center / edge; middle colors are
  added cumulatively (raising the count adds one without disturbing the
  others).
- ``SwatchStrategy`` — `.vibrant` (vibrant → darkVibrant), `.contrast`
  (lightVibrant → darkMuted, max luminance range), `.muted` (muted →
  darkMuted, subdued tone).
- ``GrainStyle`` — `.none`/`.subtle`/`.standard`/`.heavy` film-grain
  intensity.

## Shape clipping

`PaletteGraphic` and `PaletteGraphicView` both render rectangular content.
Apply a non-rectangular silhouette through standard clipping:

- SwiftUI: `.clipShape(Circle())`, `.clipShape(RoundedRectangle(cornerRadius:))`,
  `.mask { … }`, or any custom `Shape`.
- UIKit: `view.layer.cornerRadius` for rounded rects;
  `view.layer.mask = CAShapeLayer()` with a `UIBezierPath` for arbitrary shapes.

## Performance

The renderer memoizes `CGImage` outputs in a bounded `NSCache`, so repeated
body invalidations with the same configuration return instantly. First
render at a new (configuration, size) pair takes approximately 10–30 ms
on contemporary devices for a 1080×1080 surface.

## Async loading

For the common case of loading from a URL, use ``AsyncPaletteGraphic``
(SwiftUI) or ``AsyncPaletteGraphicView`` (UIKit) to skip the explicit
``PaletteExtractor`` step. See <doc:AsyncLoading> for details on caching,
transitions, and error handling.

```swift
AsyncPaletteGraphic(image: .url(url)) {
    Color.gray.opacity(0.1)
}
.frame(width: 320, height: 320)
.clipShape(RoundedRectangle(cornerRadius: 24))
```
