# PaletteKitDemo

A minimal SwiftUI iOS app that uses PaletteKit to pick a photo, extract its
palette, and display the resulting colors alongside the six semantic swatches.

## How to run

1. Open Xcode 16+.
2. File → New → Project → App (iOS, SwiftUI, Swift).
3. Name it `PaletteKitDemo`. Set deployment target to iOS 17.
4. File → Add Package Dependencies… → Add Local… → choose this repository's
   root (the folder containing `Package.swift`).
5. Replace the generated `ContentView.swift` and `PaletteKitDemoApp.swift`
   with the files under `PaletteKitDemo/` in this folder.
6. Run.

## What it shows

- `PhotosPicker` integration: pick any photo.
- Dominant color strip at the top.
- Top-10 palette grid sorted by population.
- Semantic swatches panel (vibrant / muted / dark-vibrant / dark-muted /
  light-vibrant / light-muted).
- Timing panel displaying per-stage durations when you enable `collectTimings`.

This demo is intentionally hosted outside the Swift Package target so the
library has zero UI dependency. It can be copied verbatim into any Xcode
project.
