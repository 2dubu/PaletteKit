# PaletteKitDemo

A minimal SwiftUI iOS app that uses PaletteKit to pick a photo, extract its
palette, and display the resulting colors alongside the six semantic swatches.

## Prerequisites

- Xcode 16+
- iOS 17 simulator or device
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (one-time install)

```bash
brew install xcodegen
```

## Generate and run

From the repo root:

```bash
cd Examples/PaletteKitDemo
xcodegen
open PaletteKitDemo.xcodeproj
```

Hit **Run** (⌘R) in Xcode. Pick a photo from the simulator/device library
and PaletteKit will extract a palette and swatches in real time.

The generated `PaletteKitDemo.xcodeproj` is **not committed** — regenerate
whenever `project.yml` or the sources change.

## What it shows

- `PhotosPicker` integration: pick any photo.
- Dominant color strip at the top.
- Top-10 palette grid sorted by population.
- Semantic swatches panel (vibrant / muted / darkVibrant / darkMuted /
  lightVibrant / lightMuted).
- Timing panel with per-stage durations when `collectTimings: true`.

## Tweaking the app

- `PaletteKitDemo/PaletteKitDemoApp.swift` — app entry point.
- `PaletteKitDemo/ContentView.swift` — all UI and extraction logic.
- `project.yml` — Xcode project spec. Bump `SWIFT_VERSION`, add frameworks,
  or change bundle ID here, then re-run `xcodegen`.

The app depends on the sibling `PaletteKit` Swift Package via the local
path declared in `project.yml`, so source-level edits to PaletteKit are
picked up on the next build.
