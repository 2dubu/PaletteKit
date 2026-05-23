# Changelog

All notable changes to PaletteKit are documented here.

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
