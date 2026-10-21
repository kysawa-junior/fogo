# ADR-0003: Offline hybrid OSM map

- Status: Accepted
- Date: 2026-10-19

## Context

F.O.G.O. needs a dark, region-specific OSM map without public raster-tile
fallbacks. Live road surfaces must retain fixed screen widths, while buildings
and labels remain toggleable. Water, green/farmland areas, boundaries, and
railways do not need live toggles and can be bundled as raster imagery.

## Decision

Use a hybrid map for the existing Marília–Garça coverage:

- At build time, render local z7–18 XYZ PNG tiles from the existing extracted
  OSM cells and `assets/map/manifest.json`. `tool/map_data/render_tiles.py`
  uses pinned Pillow tooling; it does not download tiles or read/re-fetch the
  source PBF. Tiles contain static non-road features only, clipped to the
  manifest bbox.
- At runtime, load only bundled assets through `flutter_map`'s
  `AssetTileProvider`. Use manifest `tileBounds`, `blank.png` as the local
  `#01010A` error image, and no `fallbackUrl`. Raster imagery scales from the
  nearest native level when camera zoom is below z7 or above z18.
- Keep a transparent live vector layer, clipped to exact geographic coverage,
  for roads, optional buildings, POIs, and labels. Preserve road geometry,
  filters, bridge/tunnel behavior, casing/fill order, road-label ordering, and
  fixed screen widths through z20. Raster-owned areas, waterlines, and railways
  are not drawn again by the vector layer.
- Base content outside coverage stays dark. Viewport intersection, not camera
  center, controls whether covered vector content remains visible. Routes,
  markers, controls, and `© OpenStreetMap contributors` remain UI overlays.

## Consequences

- Map tile loading has no runtime network dependency or light-map fallback.
  Search and route services remain separate network integrations.
- Bundled PNGs increase repository and application bundle size; tile count,
  bytes, build size, and build time must be measured for each delivery report.
- Static non-road styling is regenerated at build time. Roads, buildings, POIs,
  and labels remain live to preserve width behavior and existing controls.
- Future changes to the supported raster range, palette, or dynamic/static
  feature split require a new decision and approval rather than a runtime
  provider substitution.

## Alternatives considered

- Public OSM raster fallback: rejected because it adds runtime network access,
  light tiles outside local coverage, and a separate provider policy dependency.
- Rasterize all OSM features: rejected because static roads break fixed-width
  behavior, while static buildings and labels break their existing toggles.
- Render every feature as vectors: rejected because the non-road features are
  static and already suitable for deterministic local raster generation.
