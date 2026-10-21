# ADR-0004: F.O.G.O. local-cell map SDK

- Status: Implemented; independent Delivery Auditor review pending
- Date: 2026-10-20
- Supersedes: [ADR-0003 — Offline hybrid OSM map](ADR-0003-offline-hybrid-map.md)
- Source spec status: `Reviewed and approved by the user on 2026-10-19`

The source-spec status records user approval only. It is **not** Delivery Auditor
approval; no auditor verdict is recorded here. ADR-0003 remains unchanged as the
historical decision for the retired raster/`flutter_map` implementation.

## Context

The previous map combined bundled raster tiles with a live vector overlay in
`flutter_map`. TASK-0004 required replacing that path with an app-independent
renderer over existing local OSM cells, retaining exact regional coverage,
offline map rendering, camera interactions, map semantics, and host-owned route
and search behavior. Native parity evidence passed the engineering cleanup gate.

## Decision

- `MapWorkspacePage` uses `packages/fogo_map_sdk`. The SDK owns Web Mercator
  projection and inverse transforms, immutable camera state/controller,
  gestures, coordinate selection, local cell loading/cache, clipping, and
  `CustomPainter` rendering. It is a F.O.G.O.-specific regional cell renderer,
  not a generic MVT engine or Mapbox SDK.
- The app owns operational state, routes and search, region/city controls,
  center/zoom persistence, and supplies route/marker overlays. Those overlays
  share the SDK camera transform and use screen-pixel widths. Pitch supports
  0°/45° but remains transient and is not persisted.
- Runtime map content comes from the bundled 58 OSM cell assets and
  `assets/map/manifest.json`. Coverage is Marília-SP, Vera Cruz-SP, Garça-SP,
  and their corridor. Geographic content is clipped to the manifest bounds;
  empty or out-of-coverage areas use `#01010A`. No runtime basemap network is
  used. Search and routing remain separate network integrations.
- The dark night palette is F.O.G.O.-owned and only approximates the requested
  night-map direction; exact Mapbox Standard equivalence is not claimed.
- Building extrusion requires a finite, positive numeric OSM `height`.
  Missing, invalid, non-finite, zero, negative, and levels-only values remain
  flat. `building:levels` is never used to infer height. Generator grammar,
  counters, and local-PBF-only staging are documented in
  [`tool/map_data/README.md`](../../tool/map_data/README.md).
- Selection is geographic-coordinate selection; feature identity/OSM-ID
  picking is outside this task's scope.
- SDK package portability is distinct from application platform support. An
  SDK Web compile does not establish F.O.G.O. application Web support.

## Consequences

- Raster rendering and the root `flutter_map` dependency are removed. Cleanup
  deleted exactly **21,830 files**: 21,829 PNGs (21,828 XYZ tiles plus
  `blank.png`) and `assets/map/tiles/manifest.json`. The per-file inventory and
  cleanup checksums are in
  [`TASK-0004-raster-cleanup.sha256`](../agent-work/handoffs/TASK-0004-raster-cleanup.sha256)
  and the cleanup report in
  [`TASK-0004-raster-cleanup.md`](../agent-work/handoffs/TASK-0004-raster-cleanup.md).
- The 58 OSM cell assets, `assets/map/manifest.json`, and the existing local PBF
  remain. The data generator reads the existing local PBF only and uses the
  actual pinned dependency `osmium==4.3.1`; it does not download source data.
- The SDK decodes cells off the frame path where isolates are supported.
  Flutter Web's `compute` runs on the same event loop. No native frame-time or
  heap profile was collected; Windows, macOS, and iOS package checks were
  unavailable on the Debian Linux host.
- Regional map rendering works offline, but Nominatim search and OSRM routing
  still require their configured network services.

## Alternatives considered

- **Keep the raster/`flutter_map` hybrid:** rejected because the approved
  replacement and parity gate were completed; maintaining both render paths
  would retain duplicate map ownership and assets.
- **Use a generic MVT or Mapbox renderer:** rejected as outside scope and
  unnecessary for the bounded local-cell dataset; no Mapbox package, hosted
  style/data, token, or runtime basemap service is introduced.
- **Use a native map engine:** rejected for this migration because it would
  add platform-native dependencies and weaken the portable Flutter package
  boundary.

## Evidence and related documentation

- [SDK API and limitations](../../packages/fogo_map_sdk/README.md)
- [Current architecture](../ARCHITECTURE.md)
- [Parity and validation evidence](../agent-work/handoffs/TASK-0004-validation-evidence.md)
- [Engineering completion and known limitations](../agent-work/handoffs/TASK-0004-engineering-completion.md)
