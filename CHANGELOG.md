# Changelog

All notable changes to PaletteKit are documented here.

## 2.1.0

### Added
- `PaletteKitInsights` (iOS 26+ / macOS 26+ / visionOS 26+, separate optional product): `PaletteInsightsGenerator` produces a `PaletteInsights` (`name` + `summary`) from a `Palette` via on-device FoundationModels, with optional caller `guidance` and locale-aware output.
- `PaletteInsightsError` for availability, unsupported-language, and generation failures.

## 2.0.0

### Added
- `AnimatedPaletteGraphic` (SwiftUI) and `AnimatedPaletteGraphicView` (UIKit)
  — an animated "living gradient" that renders a `Palette` as a multi-point,
  LAB-blended flow with organic, non-periodic (spring-driven) motion.
  - `Configuration`: `colorCount` (`.two`…`.five`), `speed`
    (`FlowSpeed`: `.slow` / `.regular` / `.fast`), `isAnimated`.
  - Honors Reduce Motion and Low Power Mode (holds a static frame) and
    pauses while off-screen.
  - SwiftUI and UIKit share one inline-source Metal renderer (no `.metallib`
    resource bundle); the SwiftUI view wraps the UIKit view.

### Changed
- `ColorCount` moved to its own file so it is shared by `PaletteGraphic` and
  `AnimatedPaletteGraphic`. No API change.

## 1.7.0

### Added
- Convenience lookups on `SwatchMap` for the common `<role>?.color /
  textColor ?? fallback` pattern.
  - `color(for:fallback:)`
  - `titleTextColor(for:fallback:)`
  - `bodyTextColor(for:fallback:)`
- The same convenience on `Optional<SwatchMap>` so callers holding a
  `SwatchMap?` (e.g. `PaletteGraphic.swatches`) can skip an extra
  unwrap.

## 1.6.0

### Added
- `PaletteMeshGraphic` — SwiftUI multi-color mesh gradient primitive on
  top of iOS 18+ `MeshGradient`. Sibling to `PaletteGraphic`.
  - `gridSize`: `.compact` (2×2), `.standard` (3×3, default), `.rich` (4×4)
  - `makeImage(size:scale:)`: ImageRenderer-based UIImage export
  - Color slots are allocated proportional to each palette color's
    `population`, so the mesh inherits the source photo's color dominance.
    `PaletteMeshGraphic` deliberately does **not** consume `SwatchMap` —
    callers only need a `Palette`.
