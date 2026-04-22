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
