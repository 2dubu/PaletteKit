# PaletteKitDemo

A minimal SwiftUI iOS app that uses PaletteKit to pick a photo, extract its
palette, and display the resulting colors alongside the six semantic swatches.

## Prerequisites

- macOS with Xcode 16+
- iOS 17 simulator or device

## Run it

From the **repo root**:

```bash
make demo-app
```

This generates `PaletteKitDemo.xcodeproj` from `project.yml` and opens it in
Xcode. Pick a simulator in the scheme bar and press **⌘R**.

The first run triggers `make setup`, which installs `xcodegen` via Homebrew
if it isn't already present. Subsequent runs skip that step.

## What it shows

- `PhotosPicker` integration: pick any photo.
- Dominant color strip at the top.
- Top-10 palette grid sorted by population.
- Semantic swatches panel (vibrant / muted / darkVibrant / darkMuted /
  lightVibrant / lightMuted).
- Timing panel with per-stage durations when `collectTimings: true`.

## Compare image-based meshes (iOS 18+)

After picking an image, tap **Compare Image Mesh**. This screen shows the original,
the existing palette layout, and the experimental source-positioned layout at the
same aspect ratio and grid size. Switch between 3×3 and 4×4 and use **Share image
layout** to export the new result as PNG. The existing Mesh Lab is unchanged.

This comparison uses common sRGB/white-background preprocessing for both methods,
independently of the main screen's extraction options. Analysis runs off the UI
actor and is cancelled when leaving the screen. Small details and accents can fade;
this is a fixed-grid prototype, not a photo reconstruction mode. See
[the comparison harness](../SpatialMeshComparison/README.md) for reproducible inputs,
measurement definitions, and current limitations.

## How it's wired

- `project.yml` — XcodeGen spec (iOS 17+, Swift 6 strict concurrency, local
  PaletteKit package reference).
- `PaletteKitDemo/PaletteKitDemoApp.swift` — app entry point.
- `PaletteKitDemo/ContentView.swift` — all UI and extraction logic.
- `PaletteKitDemo/Info.plist` — `NSPhotoLibraryUsageDescription` and launch
  screen.

The generated `PaletteKitDemo.xcodeproj` is **not committed**. It is
regenerated on every `make demo-app` from `project.yml`, so the source of
truth is the YAML plus the Swift/plist files in this folder.

## Graphic Lab regression tests

The demo tests cover available color counts, selection correction, and hosted
segmented-control updates using synthetic palettes. From the repo root:

```sh
xcodegen generate --spec Examples/PaletteKitDemo/project.yml
xcodebuild test \
  -project Examples/PaletteKitDemo/PaletteKitDemo.xcodeproj \
  -scheme PaletteKitDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Choose an installed simulator name or use `-destination 'id=<simulator-uuid>'`.
