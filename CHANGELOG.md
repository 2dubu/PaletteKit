# Changelog

All notable changes to PaletteKit are documented here.

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
