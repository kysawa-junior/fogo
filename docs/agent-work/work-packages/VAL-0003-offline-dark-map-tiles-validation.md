---
id: VAL-0003
version: "1"
status: approved
source:
  user_request: TASK-0003
  orchestrator_task_id: TASK-0003
objective: Independently verify offline tile generation/loading, hybrid layer behavior, preserved map invariants, documentation, and required build/artifact evidence for TASK-0003.
background: Validate ENG-0003 against the approved offline dark map spec; the key risks are deterministic output for about 63,114 tile positions, bundle/build growth, missing-tile network fallback, dynamic-feature duplication, and viewport-edge visibility.
scope:
  included:
    - Review implementation and tests against ENG-0003 and the approved spec
    - Run generator, targeted/full Flutter, formatting, analysis, and Linux debug build checks
    - Verify local-only tile behavior, coverage, overlay controls/order, and protected existing behaviors
    - Inspect visual captures and record actual tile count/bytes, bundle size, build time, and evidence
    - Return failures, evidence, and limitations to engineering
  excluded:
    - Implementing or fixing feature changes
    - Expanding approved behavior or redefining palette/visual design
    - Re-downloading source PBF or obtaining public raster tiles
requirements:
  functional:
    - Verify generated local XYZ PNG tiles cover the current region at native z7–18 using existing cells and that no public raster/source PBF download is part of generation.
    - "Verify deterministic output, #01010A background, approved raster feature palette, and omission of roads, buildings, and all labels."
    - Verify local AssetTileProvider loading uses manifest tileBounds and local dark errorImage, leaves fallbackUrl unset, and issues no tile network request for missing/out-of-bounds tiles.
    - Verify z7–18 native loading and nearest-level under/overzoom while live road widths remain fixed through z20.
    - Verify transparent vector roads/buildings/labels preserve toggles, no duplicated roads, painter/layer ordering, filters, geometry, bridges/tunnels, casing/fill order, route/marker order, and OSM attribution.
    - Verify partially overlapping viewports retain covered roads, fully outside viewports show dark background only, and status is local coverage/loading rather than network tile failure/retry.
    - Verify README.md, docs/ARCHITECTURE.md, and ADR describe the approved behavior and historical TASK-0001/2 reports are unchanged.
    - Verify report includes actual tile count/bytes, Linux debug bundle size, build time, visual evidence, exact checks, and limitations.
  non_functional:
    - Report only checks actually run; unrun commands or unavailable visual/build checks are not passes.
    - Record exact commands, outcomes, artifact measurements, inspected views, and environment limitations.
constraints:
  technical:
    - Validate the approved spec and ENG-0003; do not implement changes or broaden scope.
    - Use existing extracted cells and source; do not download public raster tiles or re-download the PBF.
    - Treat z7–18 as the fixed native range and verify nearest-level scaling outside it.
  architectural:
    - Validate hybrid raster non-road base plus transparent live vector overlay; do not request a renderer replacement.
    - Verify local-only AssetTileProvider behavior, manifest tileBounds, dark errorImage, unset fallbackUrl, and zero tile network requests.
  visual:
    - "Inspect against approved #01010A background/casing, road palette, current non-road styling, dynamic controls, and layer order; do not redefine design."
  business:
    - Do not change routes, road data schema/source region, camera gestures, approved palette, attribution, or historical reports.
dependencies:
  agents: [engineering-lead]
  work_packages: [ENG-0003]
  modules:
    - map workspace and local basemap
    - map data coverage and viewport intersection
    - vector painter/layer composition and road rendering
    - Python map-data tooling, manifest, bundled tiles, tests, and operational documentation
assigned_agents: [quality-performance-engineer]
affected_areas:
  modules:
    - Flutter map rendering and local tile loading
    - map data generator and coverage logic
    - vector overlay and map regression tests
  packages:
    - Python / Pillow generation tooling
    - Flutter / flutter_map tests, analysis, and Linux debug build
  files:
    - tool/map_data/
    - assets/map/manifest.json
    - assets/map/tiles/{z}/{x}/{y}.png
    - lib/features/map/presentation/pages/map_workspace_page.dart
    - lib/features/map/vector/map_data_controller.dart
    - lib/features/map/vector/fogo_vector_layer.dart
    - lib/features/map/vector/vector_painter.dart
    - test/ directory for map generation, loading, coverage, and layer tests
    - pubspec.yaml
    - README.md
    - docs/ARCHITECTURE.md
    - docs/adr/ directory for new offline hybrid-map ADR
protected_areas:
  modules:
    - Route calculation and route line/marker behavior
    - Road data schema/source region and existing road geometry/filters
    - Camera gesture behavior
    - Historical TASK-0001/2 delivery reports
    - Approved non-road feature palette and OSM attribution
  files: []
deliverables:
  - Validation evidence for every acceptance criterion, including exact commands and results
  - Visual inspection evidence for Marília, Vera Cruz-SP, Garça, region edge, and outside coverage
  - Measured generated tile count/bytes, Linux debug bundle size, and build time
  - Explicit failures, gaps, and environment limitations returned to engineering
acceptance_criteria:
  - "Pixel/pipeline checks verify #01010A background and approved raster palette; tiles contain no roads, buildings, or labels."
  - Determinism and coverage tests verify stable output and expected XYZ coverage for the current region.
  - Marília, Vera Cruz-SP, Garça, and corridor load from local tiles at z7–18; absent/out-of-bounds coordinates show a dark blank without network requests or light-map fallback.
  - Under/overzoom uses the nearest native level; live road width stays fixed through z20.
  - Partially overlapping viewport displays covered roads; fully outside viewport displays only dark background.
  - Existing road geometry, filters, casing/fill order, bridge/tunnel behavior, Buildings/Labels toggles, road-label ordering, route/marker layering, non-road styling, and attribution remain intact; no doubled roads.
  - README.md, docs/ARCHITECTURE.md, and ADR accurately describe generation, hybrid layers, zoom behavior, and zero runtime tile network; TASK-0001/2 reports remain unchanged.
  - Actual tile count, generated bytes, resulting Linux debug bundle size, and build time are reported.
  - dart format, targeted and full Flutter tests, flutter analyze, and flutter build linux --debug outcomes are reported; captures cover all three cities, region edge, and outside coverage.
testing_requirements:
  - Inspect generator tests for pixel-level background/feature palette, road/building/label omission, deterministic output, and region XYZ coverage using existing cells.
  - Confirm test coverage of local tile asset loading, manifest bounds, dark missing tile, unset fallbackUrl/no network request, and nearest native-level under/overzoom.
  - Confirm viewport-intersection tests cover partial overlap and fully outside coverage; confirm overlay tests cover transparency, toggles, no road duplication, ordering, and fixed road widths through z20.
  - Review preserved road geometry/filter behavior, bridge/tunnel treatment, casing/fill order, road labels, route/marker layering, non-road styling, and attribution.
  - From project root run dart format for changed Dart files, targeted generator/map tests, full flutter test, flutter analyze, and flutter build linux --debug; record exact results and do not count unrun checks as passes.
  - Inspect captures for Marília, Vera Cruz-SP, Garça, region edge, and outside coverage; record evidence or explicitly state why unavailable.
  - Independently record generated tile count/bytes, Linux debug bundle size, and build time; compare no value against the approximately 63,114-position estimate without reporting actuals.
documentation_requirements:
  - Verify README.md and docs/ARCHITECTURE.md cover local generation, bundled loading, hybrid layers, native z7–18, nearest-level under/overzoom, dark outside coverage, and zero runtime tile network.
  - Verify the new ADR documents the durable hybrid architecture and tile-generation boundary.
  - Confirm TASK-0001/2 delivery reports were not rewritten.
  - Report exact evidence, commands/results, measurements, changed paths reviewed, failures, and limitations to engineering.
risks:
  - Approximately 63,114 tile positions may increase bundle size, repository footprint, and build time; measurements are required.
  - Automated pixel checks alone may not prove runtime layer ordering, toggle behavior, viewport-edge rendering, or absence of network requests; combine tests and visual/runtime evidence.
  - Build or visual inspection may be unavailable in the validation environment; report this explicitly rather than claiming success.
completion_report:
  required: true
---
# Work Package VAL-0003 — Offline dark map tiles validation

Independently validate `ENG-0003` against `docs/superpowers/specs/2026-10-19-offline-dark-map-tiles-design.md`. Do not implement fixes or broaden the approved behavior. Verify that generated local z7–18 XYZ tiles use existing cells, are deterministic, render the approved dark background/non-road palette, and omit roads, buildings, and every label. Confirm no public raster tiles or source PBF re-download are used.

## Validation recipe

1. Review and run generator checks for pixel palette, dynamic-feature omissions, deterministic output, and expected local XYZ coverage. Verify renderer/dependency are build-time-only and source inputs are the existing extracted cells. Record actual generated tile count and bytes.
2. Review/run runtime tests for bundled `AssetTileProvider`, manifest `tileBounds`, dark local `errorImage`, unset `fallbackUrl`, and no map-tile network requests, including missing/out-of-bounds coordinates. Verify native z7–18 behavior and nearest-level under/overzoom.
3. Verify viewport-intersection coverage for a partially overlapping viewport and dark-only rendering outside coverage. Verify transparent overlay composition, Buildings/Labels toggles, no duplicated roads, road labels above roads, routes/markers above basemap/roads, fixed per-class road widths through z20, and preserved geometry, filters, bridges/tunnels, casing/fill order, non-road styling, and attribution.
4. From project root run `dart format` on changed Dart files, targeted generator/map tests, full `flutter test`, `flutter analyze`, and `flutter build linux --debug`. Record exact commands and outcomes; unrun/unavailable checks are not passes.
5. Inspect captures for Marília, Vera Cruz-SP, Garça, region edge, and outside coverage. Measure and report Linux debug bundle size and build time. Report visual/build limitations explicitly.
6. Verify README.md and `docs/ARCHITECTURE.md` document generation, bundled loading, hybrid layers, z7–18 native zoom, nearest-level under/overzoom, dark outside coverage, and no runtime tile network; verify the ADR records the hybrid/generation-boundary decision and historical TASK-0001/2 reports remain unchanged.

Return criterion-by-criterion evidence, exact commands/results, changed paths reviewed, actual tile count/bytes, bundle/build measurements, failures, and limitations to engineering.
