---
id: ENG-0004
version: "1"
status: superseded
source:
  user_request: TASK-0004
  orchestrator_task_id: TASK-0004
objective: "Superseded duplicate; non-authoritative and non-dispatchable. Use canonical ENG-0004 v2 at docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md."
superseded_by: "docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md (ENG-0004 v2)"
background: The user-approved replacement reuses local regional OSM data. Keep old renderer and raster assets until native parity evidence passes; Mapbox Standard night is inspiration only.
scope:
  included:
    - Implement packages/fogo_map_sdk with widget/controller/style, immutable camera/events, local-cell loading/cache, projection, gestures, selection, painter, geographic overlays, and API documentation.
    - Integrate SDK into map workspace while keeping routes/search/operational state, region controls, persistence, and caller overlays in app.
    - Preserve local OSM rendering, layer/road/label contracts, attribution, selection, coverage, camera persistence, and overlay alignment.
    - Add 0/45-degree pitch, default 0; extrude buildings only from valid positive numeric OSM height.
    - Update and test local height generation using existing local PBF only.
    - Capture native parity, then remove flutter_map runtime use and exact inventoried raster-only outputs/tooling/declarations after gate.
    - Update README.md, docs/ARCHITECTURE.md, tool/map_data docs, and successor ADR superseding ADR-0003 after parity.
    - Run required project and SDK checks; report evidence, sizes, targets, and limitations.
  excluded:
    - Design work or redefinition of approved pitch, style, or behavior.
    - Generic MVT/Mapbox/general map engine, Mapbox package/style/data/assets/token/hosted content, or runtime basemap networking.
    - Full-app Web support; only standalone SDK package has Web target boundary.
    - Changes to route computation, search, operational services/state, OSM geography/attribution, or protected history.
    - Downloading, replacing, or modifying existing local PBF.
    - Raster cleanup before native parity and inventory/checksum gates.
requirements:
  functional:
    - SDK owns local-cell decoding/cache, camera, Web Mercator/inverse transforms, gestures, selection hit-testing, CustomPainter rendering, geographic overlays, and camera/selection events.
    - SDK is independent of app code, Riverpod, routing, search, and operational services. Camera state is immutable; no flutter_map types leak through public API.
    - App owns routing/search/operational state, region/city fit, center/zoom persistence, and caller routes/markers. All geographic content shares SDK camera transform.
    - Load visible local cells, clip exactly to manifest bounds, render dark outside coverage, treat missing/empty cells as normal, and surface corrupt data through controlled SDK status/error.
    - Preserve pan, pinch, double-tap, wheel zoom, fling, right-click/long-press selection, fit, camera movement, zoom, projection, and selection. Routing/selection remains independent of camera gestures.
    - Preserve center/zoom persistence. Pitch defaults to 0 degrees and remains transient unless separately approved.
    - Add app-level 0/45-degree toggle; map content and caller overlays share transform, with inverse transform and selection working at both pitches.
    - Render local content for Marília-SP, Vera Cruz-SP, Garça-SP, and corridor. Preserve water/land/boundaries, rail, roads, buildings, POIs, labels, layer/class order, filters, casing/fill, bridges/tunnels, one-way markings, label collision, toggles, and attribution.
    - Keep road widths fixed in screen pixels. Routes and markers remain above map content and aligned under shared transform.
    - Extrude only buildings with valid positive numeric OSM height. Missing, invalid, unsupported, zero, negative, and levels-only values stay flat; never infer from building:levels.
    - Inspect local PBF formats, choose/document narrow numeric height grammar, persist accepted heights, distinguish valid numeric-height and levels-only counts, and report rejected/unsupported formats. Generate directly from existing PBF without downloading or modifying it.
    - Keep style F.O.G.O.-owned and dark, inspired by Mapbox Standard night only; make no exact Mapbox parity claim.
    - After native parity remove flutter_map runtime/dependency, known raster outputs (21,828 XYZ PNGs plus blank.png), and only confirmed raster-only tooling/metadata/declarations. Preserve vector cells, manifest, PBF, routes/search, and TASK-0001/2/3 history.
    - Update README.md, docs/ARCHITECTURE.md, tool/map_data docs, and successor ADR with actual API/platform boundary, style approximation, local regeneration, and app-vs-SDK Web scope. Correct stale approved-spec status metadata when documenting delivery; retain prior task records.
  non_functional:
    - SDK imports no dart:io, uses no native channels/plugins, and makes no runtime basemap network requests. Package targets Linux, Windows, macOS, Android, iOS, and Web; do not claim full-app Web.
    - Use Flutter asset APIs and portable gzip. Declare a decoder directly if needed; do not rely on transitive archive dependency.
    - Decode off frame path where supported; use bounded/pruned viewport cache and reusable projection/surface caches.
    - Run formatting, targeted SDK/render tests, full Flutter tests, analysis, Linux debug build, and available SDK target checks. Report actual results, untested targets, bundle/map-data sizes, and limits.
    - Provide native captures for named cities, corridor, coverage edge, and outside coverage. Browser-local comparison is not parity evidence.
constraints:
  technical:
    - Use Web Mercator and inverse screen-to-coordinate transforms; map and geographic overlays share one camera transform.
    - Use existing local OSM data and manifest bounds; missing/empty cells are normal and corrupt data yields controlled status/error.
    - Use Flutter asset APIs and portable gzip; no dart:io, native channel/plugin, runtime basemap network, or flutter_map type in SDK API.
    - Bound/prune cache and reuse projection/surface caches; report implementation-defined cache size and target limits.
    - Do not download or modify local PBF. Run generation directly against present PBF, not a fetch wrapper.
    - Before cleanup enumerate exact raster paths and record counts/checksums. With no Git metadata, inventory is destructive-change record; delete only approved raster whitelist.
    - Keep old renderer/dependency and raster assets until native parity evidence passes; cleanup is final gated phase.
  architectural:
    - SDK owns decoding/cache, camera, projection, gestures, selection hit-testing, and painter. App owns routing/search/operational state, region controls, persistence, and caller overlays.
    - SDK has no app/Riverpod/routing/search/operational dependency. Camera API is immutable and emits persistence events.
    - SDK package target boundary is Linux, Windows, macOS, Android, iOS, and Web; full-app Web is out of scope due to existing shell limitations.
    - Preserve behavior/layer contracts; do not add generic MVT or Mapbox engine scope.
    - ADR-0003 remains current/history until parity; successor ADR supersedes it only after parity.
  visual:
    - Preserve F.O.G.O.-owned dark hierarchy and current layer order, road filters/widths/casing/fill/bridges/tunnels/one-way markings, labels/collision/toggles, POIs, attribution, and overlays.
    - Implement only approved 0/45-degree pitch. Mapbox Standard night is inspiration only; do not copy assets/data or claim exact parity.
    - Extrude only buildings with valid positive numeric OSM height; never infer from levels.
  business:
    - Reuse regional OSM cells and local PBF; do not download, replace, or alter PBF.
    - Preserve routes, search, operational workflows, OSM geography/attribution, and prior TASK-0001/2/3 records.
    - Preserve non-raster assets. Raster deletion is gated, inventoried, checksummed, and limited to confirmed raster-only paths.
dependencies:
  agents: [engineering-lead]
  work_packages: []
  modules:
    - packages/fogo_map_sdk
    - lib/features/map
    - tool/map_data
    - assets/map manifest/cell generation boundary
    - README.md, docs/ARCHITECTURE.md, docs/adr, and tool/map_data docs
assigned_agents: [engineering-lead]
affected_areas:
  modules:
    - New SDK package and tests/docs
    - Map workspace, camera persistence callers, region controls, and map tests
    - Local generator, generated-height schema, manifest handling, and tests
    - Raster-only cleanup candidates and pubspec declarations after parity
    - Architecture, operations, and ADR docs
  packages:
    - Flutter/Dart SDK package targeting Linux, Windows, macOS, Android, iOS, and Web
    - Existing Flutter app for native parity/build; no full-app Web claim
    - Existing Python map-data tooling and directly declared gzip decoder if needed
  files:
    - packages/fogo_map_sdk/**
    - lib/features/map/**
    - tool/map_data/**
    - assets/map/manifest.json and assets/map/cells/** subject to protected-area gate
    - assets/map/tiles/** raster-only cleanup whitelist after parity
    - pubspec.yaml and package manifests
    - README.md and docs/ARCHITECTURE.md
    - docs/adr/ADR-0003 and successor ADR
    - docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md approval metadata only, if corrected
    - SDK, generator, and app tests
protected_areas:
  modules:
    - Route calculation and route/search services
    - Operational state and workflows
    - OSM source geography and attribution
    - Existing app-shell lifecycle/platform limitations; no full-app Web claim
    - Historical TASK-0001/2/3 specs, briefs, WPs, handoffs, and reports
    - All non-raster assets and files outside exact raster-only deletion whitelist
  files:
    - assets/map/cells/** existing vector cells; do not edit, replace, or delete without Director-approved clarification
    - assets/map/manifest.json existing manifest; do not edit or replace without Director-approved clarification
    - Existing local OSM PBF; discover exact path and record checksum; do not edit, replace, or download
    - Route/search service files and historical TASK-0001/2/3 records
deliverables:
  - Portable SDK with documented widget/controller/style, immutable camera/events, local data/cache, overlays, selection, projection, and platform contracts.
  - Integrated map workspace with preserved behavior, routes/markers, region controls, center/zoom persistence, and transient 0/45-degree toggle.
  - Focused transform, pitch, clipping, cell loading/error, gesture, selection, ordering, width, label, overlay, and toggle tests.
  - Generator changes/tests for height parsing/persistence/counts/rejections, local-only regeneration, and unchanged-PBF verification.
  - Pre-cleanup native parity evidence for named cities, corridor, coverage edge, and outside coverage.
  - Exact raster/tool/declaration inventory, SHA-256 checksums/counts, and deletion report; cleanup only after parity and limited to approved whitelist.
  - Updated README, architecture/tool docs, and successor ADR after parity; stale spec approval metadata corrected if needed.
  - Completion report with paths, gates/evidence, exact checks, targets, captures, post-cleanup sizes, build time where measurable, and limitations.
acceptance_criteria:
  - SDK API is documented and app-independent; no flutter_map types leak into it. No dart:io, native channel/plugin, or runtime basemap networking; gzip decoder is directly declared if needed.
  - App uses SDK camera/rendering and no flutter_map camera/projection/gesture/CustomPainter runtime path remains after cutover. Geographic overlays align under shared transform.
  - Projection/inverse round-trips and 0/45-degree transforms pass tests; camera movement/fit/zoom/pitch, gestures, selection, center/zoom persistence, and route independence pass.
  - Visible-cell loading, exact clipping, partial/outside coverage, normal missing/empty cells, and controlled corrupt-data status/error pass tests.
  - Native evidence shows preserved road classes/filters/order/fixed pixel widths/bridges/tunnels/one-way markings, labels/collision/toggles, POIs, attribution, routes, and markers.
  - 0/45-degree toggle works; only valid positive numeric OSM heights extrude; invalid/missing/unsupported/nonpositive/levels-only remain flat.
  - Generator tests verify height persistence, distinct numeric-height/levels-only counts, rejected-format reporting, local-only operation, and unchanged PBF checksum.
  - SDK checks run on available Linux, Windows, macOS, Android, iOS, and Web targets; untested targets are reported. Full-app Web is not claimed.
  - Parity evidence predates cleanup. Thereafter remove flutter_map and only exact inventoried raster-only outputs/tooling/declarations; keep vector cells, manifest, PBF, routes/search, and history.
  - README, docs/ARCHITECTURE, tool docs, and successor ADR describe actual API/platform/style/local-regeneration boundaries; ADR-0003 is superseded only after parity.
  - Report exact formatting, targeted/full tests, analysis, Linux debug build, available target checks, native evidence, post-cleanup sizes, build time where measurable, and limitations. Unrun checks are not passes.
testing_requirements:
  - Test Web Mercator forward/inverse projection, 0/45-degree camera round-trips, clipping, visible-cell selection, cache pruning, missing/empty/corrupt data, and controlled status.
  - Test required gestures, fit/zoom/events, selection hit-testing, persistence events, and route independence from camera gestures.
  - Test painter/layer order, road filters/widths/casing/fill/bridges/tunnels/one-way, labels/collision/toggles, POIs, attribution, and overlay alignment at both pitches.
  - Test accepted height forms selected after PBF inspection and missing/invalid/unsupported/zero/negative/levels-only values; only positive numeric values extrude.
  - Test generator persistence/counts/rejection reporting, local-only operation, no download, and unchanged PBF checksum.
  - Check no dart:io/native channel/plugin/runtime basemap network; run available SDK targets and list unavailable ones.
  - Before cleanup record exact paths/counts/SHA-256 for 21,828 XYZ PNGs plus blank.png and each confirmed raster-only tool/declaration. Verify parity and each deletion against whitelist.
  - Run dart format, targeted SDK/render/generator tests, full flutter test, flutter analyze, flutter build linux --debug, and available SDK target checks; record commands/results and unrun checks.
  - Inspect native captures for Marília-SP, Vera Cruz-SP, Garça-SP, corridor, edge, and outside before cleanup. Browser-local screenshots do not qualify.
  - Measure/report post-cleanup bundle/map-data sizes and build time where measurable, with method, target, and limitations.
documentation_requirements:
  - Document SDK setup/API/data/camera/events, local cells/manifest and height parsing, platform boundary, local-only runtime, cache/error behavior, overlays, and selection.
  - Update README and docs/ARCHITECTURE with ownership, actual renderer/style approximation, integration, pitch/height rules, local-PBF regeneration, and app-vs-SDK Web boundary.
  - Update tool/map_data docs/dependency notes with actual imports, local-only command, accepted height grammar/counts/rejections, and no-download behavior.
  - After parity add successor ADR explicitly superseding ADR-0003; preserve old record and correct stale approved-spec metadata if needed.
  - Leave historical TASK-0001/2/3 records unchanged; report paths, evidence, checksums/deletions, measurements, clarifications, and limitations.
risks:
  - High: rewrite risks transform/gesture/selection/clipping/overlay regressions; require round-trip, interaction, and native parity before cutover/cleanup.
  - High: no Git metadata makes raster cleanup hard to reverse/audit; require exact inventory/checksums, whitelist, and parity gate.
  - High: protected-area wording forbids editing cells/manifest while another requirement requests regenerated height data/manifest. Resolve before promotion; stage candidates outside protected paths until then.
  - Medium: OSM height grammar/units are unspecified; inspect PBF, document narrow grammar, reject/report unsupported forms, and never infer from levels.
  - Medium: portable asset/gzip and off-frame decode vary by target; verify available targets and report limits.
  - Medium: corrupt-data status, cache bound, and pitch math are bounded implementation clarifications; define/test without broadening scope.
  - Medium: approved-spec metadata is stale; user approval controls. Correct only stale status and preserve history.
completion_report:
  required: true
architecture:
  pattern: F.O.G.O.-owned portable Flutter map SDK with phased integration and local OSM cell renderer
  state_management: Immutable SDK camera snapshots/events; app retains existing state management for persistence and operational state
  ui_framework: Flutter/Dart
design_dependency:
  package: docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md
  status: User-confirmed approved source of truth; correct stale status metadata when documenting delivery.
implementation_requirements:
  - Implement app-independent SDK. SDK owns data/camera/projection/gesture/selection/painter; app owns routing/search/operations/region controls/persistence/caller overlays.
  - Publish immutable camera state/events; keep flutter_map types out of API and use shared geographic transform.
  - Implement visible-cell loading, exact clipping, dark outside coverage, normal missing/empty cells, controlled corrupt status, bounded cache, and reusable projection/surface caching.
  - Preserve named behavior/rendering contracts; add only approved 0/45-degree pitch and valid-positive-height extrusion.
  - Inspect PBF before choosing narrow height grammar. Document accepted forms/units; reject/report unsupported values; levels-only buildings stay flat.
  - Retain old renderer/assets until native parity. Inventory/checksum before removing exact confirmed raster-only paths.
  - Stage generator candidates outside protected cells/manifest paths; do not promote without Director-approved clarification resolving protection conflict.
  - Update docs and add successor ADR only after parity; preserve historical task records.
required_tests:
  - SDK projection/camera round-trip and 0/45-degree transform tests.
  - Visible-cell/bounds/missing-empty-corrupt tests; gesture, fit, selection, persistence-event, route-independence tests.
  - Painter/order/road-width/class/bridge-tunnel/one-way/label/toggle/POI/attribution/route-marker parity tests.
  - Height grammar/extrusion tests for positive numeric, missing, invalid, unsupported, nonpositive, and levels-only; generator persistence/count/report tests.
  - Local-only regeneration and unchanged-PBF checksum verification.
  - SDK target checks and static review for no dart:io, native plugins/channels, or runtime basemap networking.
  - Pre-cleanup native captures and post-parity inventory/checksum-gated deletion review.
  - Formatting, targeted/full tests, analysis, Linux debug build, available target checks, post-cleanup measurements, and limitation report.
forbidden_changes:
  - "Do not modify, replace, or delete existing vector cells (Master Brief protected area: assets/map/cells/**); stage candidates until Director-approved clarification resolves conflict."
  - "Do not modify or replace existing manifest (Master Brief protected area: assets/map/manifest.json) without Director-approved clarification resolving the height-generation conflict."
  - "Do not edit, replace, or download existing source PBF (Master Brief protected area: existing local OSM source PBF)."
  - "Do not change route calculation, route/search behavior, or operational state (Master Brief protected areas: route/search services and operational state/workflows)."
  - "Do not change OSM geography or remove/change attribution (Master Brief protected area: OSM source geography and attribution)."
  - "Do not claim full-app Web support or change app-shell platform boundary (binding architecture constraint: full application Web support is out of scope due to existing shell limitations)."
  - "Do not delete old renderer/dependency/assets before parity and inventory/checksum gate (binding architecture constraint: retain until native parity)."
  - "Do not delete non-raster assets/files or paths outside exact approved whitelist (Master Brief protected area: all non-raster assets/files outside raster-only whitelist)."
  - "Do not rewrite historical TASK-0001/2/3 records (Master Brief protected area: historical task records)."
  - "Do not implement generic MVT/Mapbox engine, Mapbox package/style/data/assets/token/hosted content, or runtime map network (binding architecture constraint: local F.O.G.O.-owned renderer only)."
---
# Superseded ENG-0004 duplicate — DO NOT DISPATCH

> This v1 file is retained only as an archival duplicate. It is non-authoritative and non-dispatchable; ignore all remaining v1 instructions below. The sole canonical dispatch package is `docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md` (ENG-0004 v2), which resolves the cells/manifest protection conflict.

Deliver the approved replacement as one phased engineering effort. Implement `packages/fogo_map_sdk` first with documented app-independent API, then integrate it into the existing workspace. SDK owns local-cell decode/cache, immutable camera/events, Web Mercator projection/inverse transforms, gestures, selection hit-testing, painter, and shared geographic transforms. App keeps routing/search/operational state, region controls, center/zoom persistence, and caller routes/markers. Keep `flutter_map` types out of SDK API.

Preserve local OSM behavior, layer order, road filters/fixed screen-pixel widths, bridges/tunnels/one-way markings, labels/collision/toggles, POIs, attribution, routes, markers, selection, and center/zoom persistence. Add only approved 0/45-degree toggle, default 0 and transient unless separately approved. Extrude only buildings with valid positive numeric OSM `height`; never infer from `building:levels`.

Use visible local cells and exact manifest bounds. Missing/empty cells are normal; outside coverage remains dark; corrupt data produces controlled SDK status/error. SDK must not use `dart:io`, native channels/plugins, or runtime basemap networking. Use Flutter asset APIs and portable gzip; declare a decoder dependency directly if needed. Bound/prune cache, reuse projection/surface caches, and decode off-frame where supported. SDK package targets are Linux, Windows, macOS, Android, iOS, and Web; full-app Web is out of scope.

Inspect local PBF before selecting/documenting a narrow height grammar. Generator changes persist accepted numeric heights, separate numeric-height and levels-only counts, report rejected/unsupported values, use local PBF directly, and leave its checksum unchanged. **Protected-output clarification:** the brief requires regenerated height data but also protects `assets/map/cells/**` and `assets/map/manifest.json`. Stage candidates outside protected paths; do not promote/replace protected assets without Director-approved scope clarification. Report any resulting block rather than overriding protection.

## Phases and gates

1. **Contract/data reconnaissance:** inspect cell/manifest schema and PBF height formats; document API and bounded parser/unit, gzip, corrupt-data status, cache, and pitch decisions. Record PBF checksum. Resolve protected cells/manifest conflict before output promotion.
2. **SDK core:** implement package/tests for transforms, visible-cell loading, bounds, missing/empty/corrupt data, camera/events, gestures, hit-testing, painter/layer order, overlays, and pitch.
3. **Integration/parity:** wire workspace, fit controls, persistence, routes/markers, selection, toggles, and attribution. Capture native evidence for Marília-SP, Vera Cruz-SP, Garça-SP, corridor, edge, and outside coverage. No cutover/cleanup before demonstrated parity.
4. **Generator/docs:** implement/test local-only height generation; update README, `docs/ARCHITECTURE.md`, `tool/map_data` docs, and SDK docs. After parity add successor ADR explicitly superseding ADR-0003 and correct stale approved-spec status if needed.
5. **Gated cleanup/final checks:** enumerate exact raster PNG/tool/metadata/declaration paths and record counts/SHA-256 before deletion. Delete only confirmed raster-only paths: 21,828 generated XYZ PNGs plus `blank.png` and exact raster-only tools/declarations. Keep cells, manifest, PBF, routes/search, and history. Report deletion list, post-cleanup sizes, checks, and limitations.

Run formatting, targeted SDK/render/generator tests, full `flutter test`, `flutter analyze`, `flutter build linux --debug`, and available SDK target checks. Record exact commands/results; unrun checks are not passes. Native captures are required for parity; browser-local comparison does not qualify. No out-of-scope changes or deletion before the gate.
