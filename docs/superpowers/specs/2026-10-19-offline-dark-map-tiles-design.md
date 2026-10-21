# Offline Dark OSM Tiles with Fixed-Width Roads

## Goal

Use a custom dark OSM basemap around Marília, Vera Cruz-SP, and Garça without
falling back to the standard light OSM tiles, while keeping road-surface width
constant on screen during zoom.

## Findings

- `map_workspace_page.dart` selects `TileLayer` with the public OSM raster URL
  whenever `MapDataState.covered` is false. That layer is the unstyled light map;
  changing `FogoMapStyle` cannot recolor its PNG pixels.
- The project already has the Geofabrik southeastern Brazil PBF and offline
  vector cells for the current bounding box `[-50.04, -22.31, -49.59, -22.13]`.
  The bbox and generated cells include Vera Cruz-SP, so no second 822 MB download
  is needed.
- Existing road polygons are rendered separately by `FogoVectorPainter`; this
  path provides fixed screen-width roads but currently paints an opaque canvas
  and the other vector features as well.

## Approved behavior

1. Generate offline XYZ raster tiles at native zooms 7–18 from the existing OSM
   cells. Do not bulk-download raster tiles from `tile.openstreetmap.org`.
2. Tiles contain the dark background and non-toggleable OSM features: water,
   green areas, farmland, boundaries, and railways. Omit roads, buildings, and
   all labels from tile images.
3. Use the raster tile layer as the basemap and a transparent vector overlay for
   road surfaces, optional buildings, and labels. Preserve existing road
   geometry, bridges, tunnels, casing/fill order, road filters, fixed per-class
   screen widths, and the existing Buildings/Labels toggles.
4. Use `#01010A` for map background and road casing. Use `#01010E` for local
   roads and a subtle dark hierarchy for major roads:

   | Road classes | Fill |
   | --- | --- |
   | motorway | `#0E0E18` |
   | trunk | `#0B0B15` |
   | primary | `#080812` |
   | secondary | `#060610` |
   | tertiary | `#04040F` |
   | unclassified, residential, service, track, path, other | `#01010E` |

5. Keep current OSM styling for water, green areas, farmland, boundaries, and
   railways in tiles. Keep buildings and all labels dynamically rendered under
   their existing toggles, with road labels above roads. Keep route lines and
   markers above the basemap/road layers. Retain `© OpenStreetMap contributors`
   attribution.
6. Remove the public OSM raster fallback. Outside the local tile bounds, show
   only `#01010A` on the map canvas; retain the OSM attribution UI. Do not issue
   network requests for map tiles. Replace tile-failure/retry status with local
   OSM coverage/loading status. Clip raster pixels and live OSM overlays to the
   manifest bbox so extraction-margin geometry does not appear outside coverage.
7. Determine road-data visibility by viewport intersection with the offline
   region, not only by camera center, so roads remain visible when a viewport
   partially overlaps the dataset.

## Tile generation and loading

- Add a reproducible build-time renderer under `tool/map_data/` that consumes
  the existing extracted OSM cells and emits `assets/map/tiles/{z}/{x}/{y}.png`.
  Use Python/Pillow as a build-time-only renderer; no map-rendering dependency
  is added to the runtime app. Declare/pin its Python dependency with the map
  data tooling.
- Declare/load generated tiles locally with `flutter_map`'s asset tile provider;
  use `tileBounds` from the manifest and a local dark `errorImage` for absent or
  out-of-bounds coordinates. Leave `fallbackUrl` unset.
- Use z7 and z18 as native tile limits. At camera zooms below z7 or above z18,
  scale the nearest native tile level; keep live road widths fixed through z20.
- Use the existing raster tile levels z7–18. Report generated tile count, total
  bytes, and resulting Linux debug bundle size before delivery; the current bbox
  requires about 63,114 XYZ tiles in that range.
- Generated PNGs must omit roads, buildings, and labels. This prevents doubled
  roads and preserves the existing Buildings/Labels controls in the live layer.

## Out of scope

- No remote styled-tile provider or runtime network dependency for basemap.
- No change to route calculation, road data schema, OSM source region, camera
  gesture behavior, or non-road visual palette.
- No reduction of the approved z7–18 native tile range without user approval.

## Acceptance criteria

- Pixel-level tile checks verify `#01010A` background and the approved fill
  palette; generated tiles contain no roads, buildings, or labels.
- Local tiles render at z7–18 for Marília, Vera Cruz-SP, Garça, and the corridor;
  absent/out-of-bounds tiles resolve to the dark blank tile without a network
  request or light OSM fallback.
- Transparent vector overlay retains stable per-class road width at z7–20,
  correct casing/bridge/tunnel behavior, road labels above roads, existing
  building/label toggles, and no doubled road geometry over raster tiles.
- Viewports partially overlapping the offline region still render covered road
  geometry; pixels and live features beyond the exact manifest bbox remain
  dark; fully outside viewports render dark background only.
- Routes, markers, OSM attribution, road filters, Buildings/Labels toggles, and
  existing non-road styling remain intact.
- Update README and `docs/ARCHITECTURE.md` to describe offline tile generation,
  transparent live vector overlays, zoom over/underzoom behavior, and no
  runtime tile network. The old TASK-0001/2 delivery reports remain historical
  records.
- Add an ADR for the durable hybrid offline map decision and tile-generation
  boundary; no ADR directory currently exists.
- Run `dart format`, targeted and full Flutter tests, `flutter analyze`, and
  `flutter build linux --debug`; inspect captures for all three cities, region
  edge, and outside coverage.

## Tradeoffs and risks

- The raster set has about 63k tiles. App bundle growth and build time must be
  measured; report actual values. Do not substitute public OSM raster downloads.
- Local road color `#01010E` differs from background `#01010A` by only four blue
  channel levels. This low contrast is intentional; major roads use the subtle
  brighter shades above.
- The hybrid is intentional: static raster tiles scale with the camera, while
  live vector road polygons preserve the user's fixed-width requirement.
