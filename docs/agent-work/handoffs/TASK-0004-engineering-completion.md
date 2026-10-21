# TASK-0004 Engineering Completion

**Status:** Engineering implementation, gated cleanup, and post-parity
documentation are recorded. Independent Delivery Auditor review remains
pending; this report is not an auditor verdict or approval.

> Post-audit (2026-10-21): Delivery Auditor review has since been completed
> with verdict **APPROVED_WITH_NOTES** — see
> `docs/agent-work/delivery-reports/TASK-0004-fogo-map-sdk.md`. The record
> corrections it required are included in
> [`TASK-0004-raster-cleanup.md`](TASK-0004-raster-cleanup.md) and
> [`TASK-0004-validation-evidence.md`](TASK-0004-validation-evidence.md).

**Authority:** canonical `ENG-0004-fogo-map-sdk.md` v2. The source spec status
is exactly `Reviewed and approved by the user on 2026-10-19`. This records user
approval of the source spec only, not Delivery Auditor approval.

## Delivered state

- `MapWorkspacePage` uses `fogo_map_sdk`; root `flutter_map` dependency/runtime
  use and the legacy raster renderer are removed.
- SDK `CustomPainter` renders local OSM cells for Marília-SP, Vera Cruz-SP,
  Garça-SP, and their corridor. The 58 cell assets and
  `assets/map/manifest.json` remain. Geographic rendering clips to exact
  manifest bounds; the map makes no runtime basemap requests.
- The app owns route/search and operational state, region controls, and
  center/zoom camera persistence. SDK owns camera/projection/gestures,
  coordinate selection, cell loading/cache, map rendering, and shared camera
  transforms for screen-pixel overlays. Pitch remains transient.
- The F.O.G.O. night palette is an approximation, not an exact Mapbox claim.
  Only valid finite positive numeric OSM `height` values extrude; there is no
  `building:levels` height inference.
- Generator instructions document local-PBF-only staging and actual
  `osmium==4.3.1` dependency in [`tool/map_data/README.md`](../../../tool/map_data/README.md).

## Phase summary

| Phase | Outcome |
|---|---|
| 0 — Discovery and safety baseline | Inspected package/data boundaries and generator; recorded exact pre-cleanup PNG inventory and checksums. |
| 1 — SDK contract and camera | Added the portable app-independent SDK API, camera/projection, events, gestures, overlays, and coordinate selection. |
| 2 — Local data and generator | Added bounded local-cell loading/clipping/error handling and numeric-height parsing/reporting. Generation used the existing local PBF only; recorded before/after SHA-256 matched `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` and manifest `sourceSha256`. The staged semantic recheck compared all 58 cells and found zero height additions (the current baseline already has seven) and only the allowed `generatedAt` manifest change. |
| 3 — Renderer and app integration | Integrated SDK `CustomPainter` into `MapWorkspacePage`; preserved app-owned region/routing/search/persistence and aligned route/marker overlays. |
| 4 — Parity and validation | Parity gate passed for engineering's cleanup decision; validation and six native Linux captures are recorded below. This is not auditor approval. |
| 5 — Gated cleanup | Removed only inventoried raster-only files and legacy renderer/dependency; preserved local cells, map manifest, PBF, and unrelated assets. |
| 6 — Post-parity documentation | Updated root README, architecture, and SDK README with the current dataset scope; added ADR-0004 and this engineering handoff. |

## Validation and parity evidence

Detailed commands, outputs, images, platform report, sizes, and semantic
comparison are in
[`TASK-0004-validation-evidence.md`](TASK-0004-validation-evidence.md).

- Formatting: 100 files checked, no changes required.
- SDK tests: 30 passed; full app tests: 84 passed; generator tests: 30 passed.
- Root `flutter analyze`: no issues. Linux debug build passed.
- SDK-host package compile checks passed on Linux, Android, and Web. Android
  check was a debug APK compile without a device; Web check was a release
  compile without browser execution. These are package checks only, not F.O.G.O.
  app Web support.
- Windows, macOS, and iOS checks were unavailable on the Debian Linux host; they
  were not failures and were not run.
- Six native Linux captures cover Marília, Vera Cruz, Garça, corridor, coverage
  edge, and outside coverage. No browser-local parity comparison was used.

## Cleanup record

Exactly **21,830 files** were deleted:

- 21,829 PNG files: 21,828 XYZ tiles plus `assets/map/tiles/blank.png`.
- 1 raster-only metadata file: `assets/map/tiles/manifest.json`.

Exact paths and pre-delete checksums are recorded in
[`TASK-0004-raster-cleanup.sha256`](TASK-0004-raster-cleanup.sha256); the
procedure, checksum inventory, retained assets, and deletion summary are in
[`TASK-0004-raster-cleanup.md`](TASK-0004-raster-cleanup.md). The cleanup also
removed 680 now-empty raster directories.

Preserved: all 58 `assets/map/cells/**` files, `assets/map/manifest.json`
(cleanup report records SHA-256
`365ea1d533e48bac4894108c51dd498966f37ee1e4436281453a35c805dc3534`), and the
existing source PBF `tool/map_data/raw/sudeste-latest.osm.pbf`. Its Phase 2
before/after hash is recorded above; cleanup evidence separately records
unchanged size, mtime, and inode, and did not rehash the PBF during cleanup.

## Known limitations and review notes

- Flutter Web `compute` executes on the same event loop; large cell decoding
  can block the Web UI. Full F.O.G.O. app Web support is not claimed.
- No native frame-time or runtime heap profile was collected. Validation notes
  a route-overlay list-identity repaint risk that remains unprofiled.
- Windows/macOS/iOS SDK package checks were unavailable. Android had compile
  smoke only (no device/runtime check); Web had compile only (no browser run).
- Selection returns a geographic coordinate, screen position, and input
  source; feature/OSM-ID identity picking was out of scope.
- Rendered OSM features are not individual screen-reader nodes; native
  announcement behavior for coverage status was not tested.
- Repository has no Git metadata, so a whole-worktree Git diff/status cannot
  be supplied. Exact raster deletion evidence is preserved in the checksum
  inventory and cleanup report.

## Files changed by this documentation phase

- `README.md`
- `docs/ARCHITECTURE.md`
- `packages/fogo_map_sdk/README.md`
- `docs/adr/ADR-0004-fogo-map-sdk.md`
- `docs/agent-work/handoffs/TASK-0004-engineering-completion.md`

`packages/fogo_map_sdk/README.md` now states the current regional data scope;
its public API and portability notes were otherwise already documented.
`ADR-0003` and historical TASK-0001/2/3 records were not edited. This handoff
does not mark the workflow approved; the next independent step is Delivery
Auditor review.
