# Loading palettes asynchronously

Use ``AsyncPaletteGraphic`` (SwiftUI) and ``AsyncPaletteGraphicView`` (UIKit)
to render palette-driven graphics directly from an image source — the
view extracts the palette internally and shows a placeholder while
loading.

## Overview

The synchronous v1.4 ``PaletteGraphic`` requires the caller to extract a
``Palette`` first:

```swift
let palette = try await PaletteExtractor().palette(from: .url(url))
PaletteGraphic(palette: palette, swatches: nil, configuration: .init())
```

The async wrappers fold the extraction, lifecycle, and placeholder
handling into a single view:

```swift
AsyncPaletteGraphic(image: .url(url)) {
    Color.gray.opacity(0.1)  // placeholder during loading and on failure
}
.frame(width: 320, height: 320)
.clipShape(RoundedRectangle(cornerRadius: 24))
```

## Caching

By default the views use ``PaletteCache/shared`` — a process-wide
``PaletteCache`` with `countLimit = 32`. URL-sourced extractions are
cached automatically; pass an explicit `cacheKey` to enable caching for
`.data(_:)` or `.cgImage(_:)` sources.

```swift
AsyncPaletteGraphic(
    image: .data(data),
    cache: .shared,
    cacheKey: AnyHashable(itemId)
) { Color.clear }
```

To bypass caching entirely, pass `cache: nil`. To clear, call
``PaletteCache/clear()``.

## Transitions

Successful resolutions cross-fade by default (``AsyncPaletteGraphicTransition/normal``,
0.20s). Override per subtree with the SwiftUI modifier:

```swift
NavigationStack { cardListView }
    .asyncPaletteGraphicTransition(.slow)
```

In UIKit, set ``AsyncPaletteGraphicView/transition`` directly:

```swift
asyncView.transition = .extraSlow
```

Cache hits skip the transition (sync resolution → no animation).

## Error handling

Errors are surfaced via the optional `onFailure` callback. The placeholder
remains visible.

```swift
AsyncPaletteGraphic(image: .url(url), onFailure: { Logger.shared.error($0) }) {
    Color.gray.opacity(0.1)
}
```

For UIKit, set ``AsyncPaletteGraphicView/onFailure`` directly.

## Topics

### Async views
- ``AsyncPaletteGraphic``
- ``AsyncPaletteGraphicView``

### Cache
- ``PaletteCache``

### Transitions
- ``AsyncPaletteGraphicTransition``
- ``SwiftUI/View/asyncPaletteGraphicTransition(_:)``
