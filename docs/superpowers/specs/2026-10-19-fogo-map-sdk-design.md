# F.O.G.O. Regional Flutter Map SDK

## Status

Reviewed and approved by the user on 2026-10-19.

## Goal

Replace the current `flutter_map` renderer with an F.O.G.O.-owned Dart/Flutter
map SDK. The SDK renders the existing local OSM region with a night style
visually inspired by Mapbox Standard, without loading Mapbox styles, Mapbox
tiles, or the official Mapbox SDK at runtime.

The SDK is regional and F.O.G.O.-specific. It is not a general Mapbox clone,
MVT engine, global map provider, or implementation of the Mapbox Standard
style/data service.

## Project context

- F.O.G.O. is a Flutter desktop app currently using `flutter_map` for camera,
  projection, gestures, and local raster tiles, with a custom `CustomPainter`
  for live OSM vectors.
- The local OSM cell source covers Marília-SP, Vera Cruz-SP, Garça-SP, and the
  corridor. It is already present in `assets/map/cells/` with a local manifest;
  the source PBF is already present at `tool/map_data/raw/`.
- Current live rendering includes classified road surfaces with fixed
  screen-space widths, road filters, bridges/tunnels, buildings/labels toggles,
  POIs, and route/marker overlays.
- The existing compressed-cell loader imports `dart:io` for gzip decoding.
  The new SDK data loader must not silently inherit that Web limitation.
- The latest generated raster tile package contains about 21,828 PNGs / 38.5 MB
  and is no longer needed if the SDK renders the local vector cells directly.
- The complete F.O.G.O. app currently has desktop-only window lifecycle code
  (`window_manager`, `dart:io`). SDK portability to Web does not by itself make
  the whole application Web-compatible.

## Decision

Create a small internal Flutter package at `packages/fogo_map_sdk/` with an
app-specific public API. Remove `flutter_map` from the map implementation after
the new renderer passes parity checks. Do not add `mapbox_maps_flutter`, a
Mapbox token, native platform channels, or runtime basemap network requests.

### Public SDK surface

- `FogoMapView`: Flutter widget that composes the local map, configured layers,
  and caller-supplied route/marker overlays.
- `FogoMapController`: commands and state for moving the camera, fitting
  geographic bounds, zooming, setting pitch, projecting coordinates, and
  reporting camera/selection events.
- `FogoMapStyle`: F.O.G.O.-owned night-style tokens and feature visibility
  controls. Its visual hierarchy may reference public Mapbox Standard night
  documentation, but it does not claim exact Mapbox color/style parity.
- Keep the API limited to the existing OSM cell schema and F.O.G.O. use cases;
  do not add generic arbitrary-source, MVT, or Mapbox Style JSON APIs.

`latlong2` may remain as a coordinate value dependency where it reduces
unrelated route/search migration. It is not used as a map renderer or camera.

### Runtime data flow

1. The app creates `FogoMapView` with the current local OSM manifest/source and
   a controller.
2. Camera changes compute the geographic viewport and request only intersecting
   OSM cells. The source decodes and caches cells asynchronously and prunes
   cells outside the viewport cache window.
3. The SDK projects visible coordinates with its own Web Mercator transform,
   clips rendering to the manifest bounds, and paints OSM features in a stable
   layer order.
4. The app continues to own search, routing, route optimization, and
   operational state. It passes route polylines/markers and handles
   map-selection callbacks through the SDK API.

The SDK's data/asset path must not import `dart:io`; gzip decoding and asset
loading must work on Flutter-supported targets. This target includes Linux,
Windows, macOS, Android, iOS, and Web at the SDK package boundary. Integration
of the complete F.O.G.O. app into Web is explicitly out of scope.

### Camera and interactions

- Implement camera center, zoom, and pitch with a custom EPSG:3857/Web Mercator
  projection and inverse screen-to-coordinate transform.
- Preserve drag-pan, pinch zoom, double-tap zoom, mouse-wheel zoom, fling/inertia,
  region/city fit, right-click map selection, and long-press map selection.
- Start at pitch 0. Expose pitch through the SDK controller and a simple app
  `3D` toggle (top-down ↔ 45° pitch). Keep camera gesture changes independent
  from routing/selection behavior.
- Keep road surface width stable in screen pixels across zoom. Maintain exact
  manifest-bounds clipping for all local OSM geometry.

### Rendered content and style

- Render local OSM vectors directly: background, water/green/farmland/boundary
  areas, water lines, railways, roads, buildings, POIs, and labels.
- Preserve road class ordering, filters, casing/fill, bridges/tunnels, one-way
  markings, label collision, and existing Buildings/Labels toggles.
- Render route geometry and route markers above the map content. Preserve
  `© OpenStreetMap contributors` attribution as a UI overlay.
- Use a F.O.G.O.-owned dark palette and restrained hierarchy inspired by the
  Mapbox Standard `night` appearance. The current `FogoMapStyle` is the starting
  palette; Mapbox's hosted style, colors, data, and assets are not copied or
  bundled. Exact visual equivalence to Mapbox Standard is not a requirement.
  Keep the hierarchy legible through a near-black canvas, blue-black water,
  low-saturation green/farmland areas, subdued class-based roads, and pale
  labels with a dark halo.
- Keep a 2D overview by default. When pitch is enabled, extrude a building only
  when OSM provides a valid positive numeric `height` value. Do not infer height
  from `building:levels` or invent missing values. Buildings without numeric
  `height` remain flat.

### OSM height data

Current cell building records do not persist height, even though the existing
pipeline counts `height`/`building:levels` tags. Extend the local data pipeline
to persist only validated numeric OSM `height` values and regenerate the cells
from the PBF already on disk. Do not download a new PBF. Update manifest counts
to distinguish explicit numeric heights from level-only tags. Unsupported or
invalid height formats remain unextruded and are reported by the generator.

## Migration and cleanup

1. Implement the SDK package and focused tests while the existing app renderer
   remains available for parity checks.
2. Integrate the SDK into `MapWorkspacePage`; port route/marker layers, camera
   persistence, region controls, layer toggles, and selection callbacks.
3. Validate visual and behavioral parity on the native Flutter app and run
   available SDK-target checks.
4. Only after the new renderer passes, remove `flutter_map` imports/dependency,
   the unused generated raster PNG tile tree and its raster-only generator,
   metadata, and large per-directory asset declarations. Preserve OSM vector
   cells, the existing PBF, route/search services, historical TASK-0001/2
   reports, and attribution.
5. Supersede ADR-0003 and update README/`docs/ARCHITECTURE.md` to describe the
   F.O.G.O. SDK, region, platform boundary, style approximation, and data
   regeneration steps.

Do not remove the old implementation before the new SDK is integrated and
validated. The workspace has no Git metadata, so generated asset removal must
be limited to the known raster outputs named above and reported explicitly.

## Error handling and performance

- Missing/empty OSM cells are normal and render only the dark background.
- Corrupt manifest/cell data must surface a controlled map-data error; it must
  not crash camera gestures or the application shell.
- Decode data off the frame path where the target supports background compute;
  retain a bounded viewport cell cache and reuse projection/surface caches.
- No tile network fallback exists. Search/geocoding and routing retain their
  separate existing service behavior.
- Keep the renderer package free of platform channels and platform-specific
  map plugins. Verify no `dart:io` dependency leaks into the SDK.

## Out of scope

- Reproducing the complete Mapbox renderer, Mapbox Standard style JSON, global
  Mapbox/OSM coverage, MVT source ingestion, Mapbox account/token integration,
  navigation SDK, traffic, or hosted services.
- Making the complete F.O.G.O. desktop shell run as a Flutter Web app.
- Changing route computation, geocoding/routing providers, operational state,
  or OSM source geography.
- Inferring building heights from levels or other surrounding features.

## Acceptance criteria

### SDK and renderer

- A separate `fogo_map_sdk` Flutter package exposes the documented widget,
  controller, style, overlay, and selection APIs; the app uses it for map
  rendering.
- `flutter_map` is absent from the runtime dependency graph and map source after
  migration. The official Mapbox SDK, Mapbox token, Mapbox tiles, and runtime
  basemap network requests are absent.
- Projection/viewport and inverse coordinate transforms pass round-trip and
  edge tests. Camera pan, zoom, fit-bounds, pitch, screen selection, and
  persistence work without `flutter_map`.
- Missing/empty cells render dark without noisy missing-raster-asset errors;
  partially overlapping viewports show only covered OSM content; fully outside
  viewports show the map background only.
- Pixel tests and native app captures verify the dark Standard-night-inspired
  hierarchy, OSM feature order, label visibility, and exact bbox clipping.
- Road widths remain stable across tested zoom levels; road classes, filters,
  casing/fill order, bridges, tunnels, one-way markings, route/marker order, and
  Buildings/Labels toggles remain correct.
- Pitch renders only explicit-height OSM buildings as extrusions; levels-only
  and missing-height buildings stay flat. No synthetic heights are introduced.

### Portability, data, and delivery

- The SDK package contains no `dart:io`, native plugin, or platform channel and
  passes package tests/build checks for targets available in the environment;
  report every target not actually tested. Full app Web support is not claimed.
- The PBF is not re-downloaded. The pipeline persists explicit numeric heights
  from the existing PBF, and regenerated cell/manifest counts are consistent.
- Linux desktop debug build, full Flutter tests, targeted SDK/render tests,
  analysis, and formatting pass. Report bundle size and map-data size after
  raster assets are removed.
- Native captures inspect Marília, Vera Cruz-SP, Garça, the corridor, the
  coverage edge, and outside coverage. Do not use browser-local comparisons.
- README, architecture documentation, and ADR match the implementation;
  historical TASK-0001/2 delivery reports remain untouched.

## Risks and trade-offs

- This is a map-engine rewrite, not a drop-in dependency swap. Camera transforms,
  gestures, pitch, labels, and culling need direct regression coverage.
- A regional vector renderer can approximate the visual hierarchy of Mapbox
  Standard night but cannot reproduce Mapbox's hosted data or exact style.
- Only a small fraction of local buildings have an explicit numeric height, so
  visible 3D coverage will be sparse. Reprocessing the existing PBF is needed to
  retain those tags; the PBF is large but already local.
- Web portability is a property of the SDK package; app-shell dependencies still
  prevent claiming full F.O.G.O. Web support.
- Raster PNG assets may be removed only after successful parity validation.

## Reference documentation

These public references inform platform boundaries, camera/layer concepts, and
the visual target. They are not runtime dependencies, and no Mapbox renderer,
hosted style JSON, or Mapbox map data is copied into the SDK.

- [Mapbox Maps Flutter repository](https://github.com/mapbox/mapbox-maps-flutter)
- [Federated plugin migration guide](https://github.com/mapbox/mapbox-maps-flutter/blob/main/mapbox_maps_flutter/MIGRATION.md)
- [Mapbox Flutter Web implementation](https://github.com/mapbox/mapbox-maps-flutter/tree/main/mapbox_maps_flutter_web)
- [Mapbox Standard style reference](https://docs.mapbox.com/map-styles/reference/standard/)
- [Mapbox Flutter style layers guide](https://docs.mapbox.com/flutter/maps/guides/styles/work-with-layers/)
