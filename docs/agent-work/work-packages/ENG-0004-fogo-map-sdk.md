---
id: ENG-0004
version: "2"
status: ready_for_orchestrator
source:
  user_request: "TASK-0004"
  orchestrator_task_id: TASK-0004
objective: "Build and integrate an app-independent F.O.G.O. Flutter map SDK that replaces the current map renderer after regional parity is evidenced."
background: "The design spec `docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md` states it was reviewed and approved by the user on 2026-10-19; this is not a Delivery Auditor verdict. This v2 corrects the prior blanket cells/manifest protection while preserving existing OSM geometry and all non-height content."
scope:
  included:
    - "Create packages/fogo_map_sdk with a public API independent of F.O.G.O. app state, routing, search, and flutter_map types."
    - "Implement immutable camera boundary, Web Mercator projection and inverse transforms, gestures, selection hit testing, events, style, overlays, and local OSM-cell decode/cache."
    - "Integrate the SDK into the F.O.G.O. map workspace while keeping route and marker overlays above the map and aligned through the SDK transform."
    - "Render locally generated regional OSM data for Marília-SP, Vera Cruz-SP, Garça-SP, and their corridor, with exact manifest-bounds clipping."
    - "Update the local generator to add only validated positive numeric OSM `height` additively to existing building records. Regenerate generated cells/manifest directly from the already-local PBF; allow only approved height-related schema/count changes and strictly necessary generated metadata."
    - "Produce parity evidence, then remove flutter_map runtime use/dependency and only inventoried raster-only artifacts and declarations after the cleanup gate passes."
    - "Update successor ADR and operational docs after parity; record the source-spec user-approval status accurately without claiming auditor approval."
  excluded:
    - "A generic MVT renderer, general-purpose map engine, Mapbox integration, or exact Mapbox equivalence."
    - "Mapbox packages, styles, data, assets, tokens, hosted content, runtime basemap network, or browser-local visual comparison."
    - "Downloading, replacing, rewriting, or otherwise modifying the source PBF. Generated cells/manifest may be regenerated directly from the existing local PBF under the narrow approved data-delta gate."
    - "Full F.O.G.O. application Web support; only SDK/package portability checks target Web."
    - "Changing route/search/operational services, region controls, source geography, or app-owned camera persistence ownership."
requirements:
  functional:
    - "SDK owns the camera value boundary, view/controller/style/overlays/selection/events; the app owns route/search/operational state, region controls, camera persistence, and caller-provided overlays."
    - "Preserve center/zoom persistence, fit controls, drag, pinch, double-tap, wheel, fling, right-click and long-press selection, plus camera and selection events. Routes and gestures remain independent."
    - "Start top-down (0°); support top-down and 45° pitch. Keep pitch transient unless an approved design decision changes this; do not persist pitch by default."
    - "Support dark empty/background behavior, exact manifest-bound clipping, partial/outside-coverage views, and controlled status/errors for corrupt data."
    - "Preserve water/land/boundary, railway, roads, buildings, POIs/labels, attribution, road order/filter/casing/fill, bridges/tunnels, one-way details, fixed screen-pixel widths, label collision, and Buildings/Labels toggles."
    - "Keep caller route and marker overlays above map content and geometrically aligned using the same SDK camera transform."
    - "Use a F.O.G.O.-owned visual approximation of the specified Mapbox Standard night direction; do not claim exact equivalence."
    - "Extrude only valid positive numeric OSM height values. Missing, invalid, zero, negative, and levels-only features remain flat; never infer height from levels."
    - "Inspect actual local PBF tags, define and document a narrow accepted numeric-height grammar and units, and reject/report unsupported formats rather than guessing."
    - "Regenerate cells only from existing local PBF files; report actual generator dependencies, including osmium if used, rather than listing Pillow alone."
    - "Record the source spec status accurately as user-approved on 2026-10-19; do not imply Delivery Auditor approval or rewrite historical records."
  non_functional:
    - "SDK has no dart:io, platform channels/native plugins, runtime map network, app/Riverpod/routing/search dependency, or flutter_map types in its public API."
    - "Load assets through Flutter asset APIs and use a portable gzip decoder with any required package declared as a direct SDK dependency, not only transitively."
    - "Target SDK/package checks on Linux, Windows, macOS, Android, iOS, and Web where environments permit. Do not claim F.O.G.O. app Web support or Web background-isolate support."
    - "Keep decode work off the frame path where supported; use bounded/pruned viewport cache and reuse projection/surface caches. Record exact cache bound and tested/unavailable targets."
    - "Report SDK/app bundle and map-data sizes, performance-relevant limitations, and platform gaps."
    - "Use only `tool/map_data/raw/sudeste-latest.osm.pbf`; fail closed if it is absent. Record its SHA-256 immediately before and after generation, require equality, and require manifest `sourceSha256` to match."
    - "Stage regenerated outputs and semantically compare them before promotion. Existing geometry, cell membership, coverage, every non-height cell field, and every non-height manifest field/count must remain unchanged."
constraints:
  technical:
    - "Use the existing Flutter workspace/package conventions and existing local OSM cells and manifest."
    - "Portable asset decoding; no runtime basemap network or platform-native dependency."
    - "Preserve current renderer and all raster artifacts until native parity evidence passes."
    - "The repository has no Git metadata; inventory exact raster paths and checksums before any deletion. Current inventory is 21,828 XYZ PNGs plus blank.png (21,829 total)."
    - "Use the existing local PBF directly, not a fetch wrapper; fail if absent. Preserve its SHA-256 exactly before/after generation and match manifest `sourceSha256`."
    - "Planning baseline only: local PBF SHA-256 `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` matched current manifest `sourceSha256` at review time. This is not post-generation proof; recheck immediately before/after any generation."
    - "Generated cells/manifest may differ only by additive validated positive numeric `height` on existing building records, approved height-related schema/count fields, and metadata strictly required by the existing generation contract. Stage and reject any other semantic delta before promotion."
  architectural:
    - "Keep package app-independent; app retains operational state, region controls, persistence, and caller overlays."
    - "Use owned Web Mercator projection/inverse transforms, gestures, hit testing, and CustomPainter; do not broaden into generic MVT/Mapbox engine work."
    - "Use manifest bounds as exact clip boundary and bounded viewport data/cache behavior."
    - "Keep route/search services, region/source geography, and app overlay ownership unchanged."
  visual:
    - "Follow the approved F.O.G.O.-specific night visual direction using existing UI controls; preserve specified hierarchy and map layer/filter/label semantics."
    - "Map widths expressed as fixed screen pixels; route and marker overlays remain above the map."
    - "No browser-local visual comparison and no claim of exact Mapbox rendering."
  business:
    - "Regional coverage is limited to Marília-SP, Vera Cruz-SP, Garça-SP, and their corridor."
    - "Destructive raster cleanup is last and allowed only after parity evidence is recorded and every parity gate passes."
dependencies:
  agents:
    - "engineering-lead"
    - "Delivery Auditor validates implementation and recorded parity/cleanup evidence after engineering delivery."
  work_packages: []
  modules:
    - "Existing F.O.G.O. Flutter map workspace and package conventions"
    - "Existing local OSM cell generator, manifest, and map-data documentation"
assigned_agents: [engineering-lead]
affected_areas:
  modules:
    - "packages/fogo_map_sdk (new portable SDK)"
    - "F.O.G.O. Flutter map workspace and app-to-SDK integration"
    - "Local OSM cell generation and map-data documentation"
    - "Mapbox-direction approximation and migration documentation"
  packages:
    - "packages/fogo_map_sdk"
    - "F.O.G.O. app package containing the current map workspace"
  files:
    - "README.md"
    - "docs/ARCHITECTURE.md"
    - "docs/adr/ADR-0003 (supersede only after parity)"
    - "docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md (approved source; user approval is distinct from auditor verdict)"
    - "Existing map-data generator, manifest, and tool/map_data documentation (locate exact paths before editing)"
    - "Existing map workspace integration files (locate exact paths before editing)"
    - "Inventoried raster-only XYZ PNG tree and blank.png (exact paths recorded before gated deletion)"
protected_areas:
  modules:
    - "Existing OSM geometry, records, cell membership, coverage, all non-height cell content, and all non-height manifest fields/counts; only the explicit additive height/schema/count regeneration exception below is allowed."
    - "Source PBF `tool/map_data/raw/sudeste-latest.osm.pbf` (immutable/read-only; no download, replacement, rewrite, or other modification; exact before/after SHA-256 equality required)."
    - "Route/search services and app-owned operational state"
    - "Region/source geography"
    - "All non-raster assets"
    - "Historical TASK-0001/TASK-0002 records and prior TASK-0003 records/validation handoff"
  files:
    - "`assets/map/cells/**`: protect existing records, OSM geometry, cell membership, coverage, and every non-height field. Permit only additive validated positive numeric `height` on existing building records and approved height-related schema/count updates during generated-cell regeneration."
    - "`assets/map/manifest.json`: protect every non-height field/count and existing contract data. Permit only approved height-related schema/count changes and strictly necessary generated metadata when regenerating cells/manifest from the existing local PBF."
    - "`tool/map_data/raw/sudeste-latest.osm.pbf`: read-only source; no download, replacement, rewrite, or other modification; SHA-256 immediately before/after generation must be equal and match manifest `sourceSha256`."
    - "Historical TASK-0001/TASK-0002 documentation and prior TASK-0003 records, including unresolved AC-03/AC-07"
    - "All non-raster map and application assets"
deliverables:
  - "Portable packages/fogo_map_sdk with documented public camera, style, overlay, selection, and event API."
  - "F.O.G.O. map workspace integration with the owned renderer and independent route/marker overlays."
  - "Updated generator/manifest behavior and documented height grammar, units, rejected formats, dependencies, and local-only regeneration procedure."
  - "SDK unit/widget/render tests and generator safety tests, plus full validation outputs and platform availability report."
  - "Native parity evidence for Marília, Vera Cruz, Garça, corridor, coverage edge, and outside coverage; include test logs/screenshots and bundle/map-data size report."
  - "Exact raster inventory (all paths and checksums) before cleanup, followed by exact deletion list/count only if cleanup gate passes."
  - "Successor ADR explicitly superseding ADR-0003 after parity; updated README.md, docs/ARCHITECTURE.md, and tool/map_data docs."
  - "Completion report documenting limitations, tested/unavailable targets, cleanup gate outcome, and any retained legacy assets."
acceptance_criteria:
  - "SDK package builds without app/Riverpod/routing/search/flutter_map dependencies or dart:io/native plugins/runtime map networking; public API exposes no flutter_map types."
  - "Projection and inverse-transform tests cover round trips and top-down/45° camera behavior; camera tests cover center/zoom persistence, fit, events, and transient pitch default."
  - "Gesture/selection tests cover drag, pinch, double-tap, wheel, fling, right-click, long-press, selection hit testing, and independent route behavior."
  - "Data tests cover visible cells, exact clipping, partial-outside and empty coverage, corrupt-cell controlled status/error, and bounded/pruned cache behavior."
  - "Render tests/evidence verify layer order, road filters/casing/fill, bridge/tunnel/one-way rendering, fixed-pixel widths, label collision and toggles, POIs, attribution, buildings, and route/marker alignment above the map."
  - "Height tests prove only positive numeric values extrude; missing, invalid, zero, negative, and levels-only features stay flat. Generator persists accepted heights and updates only approved height-related cell/manifest schema/count fields; it reports accepted, levels-only, rejected, and unsupported values as required by the existing contract, without changing non-height counts. Exact grammar, units, and counter semantics remain implementation decisions within approved scope. It downloads nothing and leaves the source PBF unchanged."
  - "Before/after SHA-256 values for the local PBF are identical and manifest `sourceSha256` matches. Staged semantic diff proves no changes to geometry, membership, coverage, non-height cell content, or non-height manifest fields/counts; no unrelated delta is promoted."
  - "Native app evidence demonstrates the specified regional locations, corridor, coverage edge, and outside-coverage behavior; no browser-local visual comparison is used."
  - "Formatting, targeted SDK/render tests, full Flutter tests, analysis, and Linux desktop debug build pass; package build/check results are reported for Linux/Windows/macOS/Android/iOS/Web, including unavailable targets."
  - "Before cleanup, parity evidence is recorded and all preceding parity checks pass. If any check/evidence is missing, retain old renderer, flutter_map dependency/runtime path, and every raster artifact; report cleanup blocked."
  - "If cleanup gate passes, remove flutter_map runtime use/dependency and only exact inventoried raster-only paths/tooling/metadata/declarations; retain cells, manifest, PBF, all non-raster assets, route/search/geography, and historical records. Record exact paths and deletion count (expected starting raster count: 21,829)."
  - "After parity, successor ADR explicitly supersedes ADR-0003; README, architecture, and map-data docs explain SDK/API, local regeneration, actual dependencies, regional scope, visual approximation, and SDK-package versus app-Web boundary."
  - "Later Delivery Auditor receives and validates commands/logs, test results, native parity screenshots/evidence, platform availability, size report, exact pre-cleanup inventory/checksums, and exact cleanup diff/list or explicit blocked-gate evidence; no workflow is marked approved by engineering."
testing_requirements:
  - "Run formatter, targeted SDK/projection/gesture/data/render tests, complete Flutter test suite, static analysis, and Linux desktop debug build."
  - "Run package build/check on each available Linux, Windows, macOS, Android, iOS, and Web target; declare unavailable targets rather than inferring support."
  - "Test visible and partial/outside cells, manifest clipping, empty data, corrupt data status, and cache bounds/pruning."
  - "Test all preserved layer ordering, filters, fixed widths, bridge/tunnel/one-way semantics, label collision/toggles, POIs/attribution, and overlay alignment."
  - "Test projection/inverse transforms, 0°/45° pitch, gestures, fit, selection, camera events, center/zoom persistence, and non-persisted pitch default."
  - "Test the selected height grammar and extrusion rules; generator no-download/local-PBF behavior, exact before/after checksum equality, and manifest sourceSha256 match."
  - "Stage generated outputs and verify semantic equality for existing geometry, membership, coverage, all non-height cell fields, and non-height manifest fields/counts; allow only the explicit height/schema/count exception and required generated metadata. Fail closed on any other delta."
  - "Capture native app evidence for Marília-SP, Vera Cruz-SP, Garça-SP, corridor, coverage edge, and outside coverage; report limitations and SDK/app bundle plus map-data sizes."
  - "Do not delete raster artifacts until parity evidence is complete and the gate is satisfied; provide auditor evidence bundle and exact inventory/deletion record."
documentation_requirements:
  - "Update README.md, docs/ARCHITECTURE.md, and tool/map_data documentation with SDK/API boundaries, regional scope, local-only regeneration, actual dependencies, approximation, cache/data behavior, and package-versus-app Web support."
  - "After parity, add a successor ADR explicitly superseding ADR-0003; keep ADR-0003 intact as historical record."
  - "Record the spec status accurately as `Reviewed and approved by the user on 2026-10-19`; this is not Delivery Auditor approval. Do not edit historical TASK records or erase unresolved TASK-0003 AC-03/AC-07."
  - "Document actual numeric-height grammar/units and rejected/unsupported formats, generator dependencies (including osmium if used), and regeneration from existing local PBF only."
  - "Record exact raster paths/checksums before cleanup and exact deleted paths/count afterward; if gate fails, document retained assets and why."
risks:
  - "Camera, gesture, selection, pitch, and overlay alignment regressions versus the existing renderer."
  - "Portable gzip/assets behavior and Web package limitations may differ by target."
  - "No Git metadata increases destructive cleanup risk; exact pre-delete path/checksum inventory and gated deletion are mandatory."
  - "OSM height values may use inconsistent grammar or units; only the documented narrow accepted numeric format may extrude."
  - "Unspecified cache bound, corrupt-data status presentation, and decoder choice require implementation decisions documented in the completion report without weakening portability or controlled-error requirements."
  - "Existing docs and generator requirements may be stale; actual dependencies and operational behavior must be verified."
completion_report:
  required: true
architecture:
  pattern: "Portable Flutter package boundary with SDK-owned map camera/projection/rendering and app-owned operational state"
  state_management: "Immutable camera boundary plus controller/events; no dependency on application state management"
  ui_framework: "Flutter CustomPainter"
design_dependency:
  package: ""
  status: "No Design WP; implement the approved F.O.G.O.-specific visual direction and existing UI controls without redefining design."
implementation_requirements:
  - "Phase 0 — Verify actual package/app/generator paths, local PBF tags, cell/manifest format and dependency conventions. Decide/document narrow height grammar and units, height-counter semantics, portable gzip decoder, bounded cache limit, and corrupt-data status presentation. Record spec status as user-approved on 2026-10-19, not auditor-approved. Inventory all 21,829 raster files by exact path and checksum; do not delete."
  - "Phase 1 — Establish SDK public API and package portability boundaries; implement immutable camera model/controller/events, Web Mercator forward/inverse transforms, gestures, selection, style and overlay contracts. Keep pitch transient by default."
  - "Phase 2 — Implement local asset cell loading/decode, exact manifest clipping, controlled corrupt-data handling, bounded/pruned viewport cache and reusable projection/surface caches. Keep decode off frame path where supported."
  - "Phase 3 — Update local generator/manifest only for additive validated positive numeric height and approved height-related schema/counts. Generate directly from the existing local PBF, record SHA-256 immediately before/after and require equality plus manifest `sourceSha256` match. Stage outputs; compare semantic contents and promote only if geometry, membership, coverage, all non-height cell fields, and non-height manifest fields/counts are unchanged. Permit generated metadata only when strictly required by the existing contract. Fail closed if source is absent, checksum differs, or another semantic delta appears."
  - "Phase 4 — Integrate CustomPainter into F.O.G.O. workspace; reproduce specified content/layer semantics and night approximation; retain route/marker overlays above map using shared transform. Keep old renderer, flutter_map and all raster artifacts available."
  - "Phase 5 — Run required validation and capture native parity evidence for all required locations/coverage cases, target availability, limitations, and bundle/map-data sizes. Record evidence before any destructive cleanup."
  - "Phase 6 — Cleanup last, only if every parity gate passes and evidence is recorded: remove flutter_map runtime use/dependency and exact inventoried raster-only paths/tooling/metadata/declarations; otherwise retain them and report gate blocked. Preserve OSM geometry, membership, coverage, non-height content, non-height manifest values, source PBF, and all other protected areas; only the authorized height/schema/count regeneration exception may change cell/manifest outputs."
  - "Phase 7 — After parity, add successor ADR superseding ADR-0003 and update README/architecture/map-data docs; compile auditor evidence package and completion report."
required_tests:
  - "Projection/inverse round-trip and camera behavior at 0° and 45°."
  - "Camera persistence, fit, gesture matrix, selection hit testing/events, and route gesture independence."
  - "Cell visibility, exact clipping, partial/outside/empty coverage, corrupt-data status, and cache bounds/pruning."
  - "Rendering order, road filters/casing/fill, bridges/tunnels/one-way, fixed-pixel widths, labels/collision/toggles, POIs, attribution, buildings, and route/marker alignment."
  - "Positive numeric height extrusion only; missing/invalid/zero/negative/levels-only stay flat; test accepted/rejected/unsupported reporting and approved height-related counts without guessing grammar, units, or counter semantics."
  - "Generator makes no network requests and does not modify source PBF; verify exact SHA-256 equality immediately before/after and manifest `sourceSha256` match."
  - "Verify staged outputs preserve geometry, membership, coverage, every non-height cell field, and all non-height manifest fields/counts; fail closed for any unapproved semantic delta."
  - "Native visual evidence across Marília-SP, Vera Cruz-SP, Garça-SP, corridor, coverage edge, and outside coverage; no browser-local comparison."
  - "Formatting, targeted and full Flutter tests, analysis, Linux desktop debug build, and available-target SDK/package checks."
forbidden_changes:
  - "Do not add Mapbox packages/styles/data/assets/tokens/hosted content or runtime basemap networking; trace: Master Brief scope and binding architecture constraints."
  - "Do not broaden this work into a generic MVT/Mapbox/general-purpose map engine; trace: Master Brief scope and architecture-standards-reviewer binding constraint."
  - "Do not download, modify, or rewrite source PBF files; trace: Master Brief scope and protected source PBF area."
  - "Do not alter or delete existing OSM geometry, records, cell membership, coverage, non-height cell content, or non-height manifest fields/counts. Permit only additive validated positive numeric `height` on existing building records, approved height-related schema/count changes, regeneration from the existing local PBF, and strictly necessary generated metadata under the existing contract; trace: Master Brief protected areas and architecture-standards-reviewer constraints."
  - "Do not change route/search services, operational state, source geography/attribution, non-raster assets, or historical TASK-0001/2/3 records; trace: Master Brief protected areas."
  - "Do not claim full-application Web support; trace: Master Brief scope and architecture constraints."
  - "Do not remove the legacy renderer/flutter_map or any raster artifact before parity evidence is recorded and all parity gates pass; trace: Master Brief migration gate."
---
# Work Package ENG-0004 v2 — F.O.G.O. Map SDK

## Objective

Create and integrate a portable, app-independent F.O.G.O.-specific Flutter map package that owns projection, camera transforms, gestures, selection hit testing, local cell decoding/cache, and CustomPainter rendering. Replace the existing map path only after the regional native parity gate is evidenced. This is not a generic MVT or Mapbox engine.

## Background and boundaries

The design spec is `docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md`; its status is `Reviewed and approved by the user on 2026-10-19`. This is user approval, not a Delivery Auditor verdict. Existing documentation describes the old flutter_map/raster/2D path, and the generator's requirements may omit its actual osmium dependency.

The SDK owns its immutable camera boundary, view/controller/style/overlays/selection/events. The F.O.G.O. app continues to own operational state, route/search, region controls, camera persistence, and caller overlays. The SDK must not depend on app/Riverpod/routing/search code or expose flutter_map types. Keep route and marker overlays above map content and aligned through the SDK transform.

Coverage is limited to Marília-SP, Vera Cruz-SP, Garça-SP, and their corridor. Use local cells and exact manifest bounds. No runtime map network, Mapbox package/style/data/assets/token/hosted content, exact Mapbox parity claim, or browser-local visual comparison. Use the specified F.O.G.O.-owned night approximation and preserve the listed layers, road semantics, labels, attribution, toggles, fixed screen-pixel widths, and overlay ordering.

## Phased implementation and gates

1. **Discovery and safety baseline:** inspect actual package, map workspace, generator, manifest, dependencies and PBF tags. Specify a narrow accepted positive numeric-height grammar, units, and height-counter semantics; do not guess or silently redefine existing mixed counters. Unsupported formats are rejected/reported. Select/document portable gzip decoding, cache bound and corrupt-cell status behavior. Record exact paths/checksums for all 21,828 XYZ PNGs plus blank.png (21,829 total). No deletion.
2. **SDK contract and camera:** define package API and ownership boundaries; implement Web Mercator forward/inverse transforms, immutable camera/controller/events, gestures, fit, selection and 0°/45° pitch. Center/zoom persistence remains app-owned; pitch is transient by default. No flutter_map types in public API.
3. **Local data path:** load via Flutter asset API; decode portably; clip exactly to manifest bounds; provide controlled corrupt-data status; bound/prune viewport cache and reuse projection/surface caches. Decode off the frame path where supported. Add only validated positive numeric `height` to existing building records, with approved height-related cell/manifest schema/count changes; report accepted, levels-only, rejected, and unsupported values as required by the existing contract. Leave non-height counts unchanged and document counter semantics without guessing. Generate cells/manifest directly from `tool/map_data/raw/sudeste-latest.osm.pbf`; fail if absent and do not download or modify it. Record its SHA-256 immediately before/after; require equality and manifest `sourceSha256` match. Stage outputs and promote only after semantic diff proves geometry, membership, coverage, all non-height cell fields and non-height manifest fields/counts unchanged. Allow generated metadata only when strictly required by the existing contract; fail closed on any other delta.
4. **Renderer and integration:** implement CustomPainter rendering and integrate into the F.O.G.O. workspace. Preserve water/land/boundary, rail, roads, buildings, POIs/labels, attribution, road ordering/filter/casing/fill, bridges/tunnels/one-way, label collision/toggles and fixed-pixel widths. Keep routes/markers above the map and transform-aligned. Keep old renderer, flutter_map and all raster artifacts.
5. **Parity evidence:** pass all acceptance/tests and capture native app evidence for Marília, Vera Cruz, Garça, corridor, coverage edge and outside coverage. Record platform availability, limitations, SDK/app bundle size and map-data size. No cleanup before the evidence is recorded and every parity check passes.
6. **Cleanup — last and gated:** only after phase 5 passes, remove flutter_map runtime use/dependency and exact inventoried raster-only paths/tooling/metadata/declarations. Record exact deleted paths and count. If any parity criterion/evidence is missing, retain old renderer, dependency and every raster file, and report cleanup blocked. Preserve existing OSM geometry, membership, coverage, non-height content, non-height manifest values, source PBF, non-raster assets, services/geography and history; only the authorized height/schema/count regeneration exception may change cell/manifest outputs.
7. **Documentation and handoff:** after parity, add a successor ADR explicitly superseding ADR-0003 and update README, architecture and tool/map_data docs with API, local regeneration, real dependencies, regional scope, approximation and package-vs-app Web boundary. Provide the auditor the evidence bundle and cleanup record (or explicit blocked-gate proof).

## Validation and auditor evidence

Run formatting, targeted SDK/render tests, full Flutter tests, analysis and Linux desktop debug build. Check the package on Linux, Windows, macOS, Android, iOS and Web where available; name unavailable targets. Test projection round trips and 0°/45° behavior; camera persistence/fit/events; the full gesture and selection matrix; visible, clipped, partial, empty and corrupt cells; cache bounds; all listed rendering semantics and overlay alignment; height acceptance/rejection; no-download generation; exact source-PBF before/after SHA-256 equality and manifest `sourceSha256`; and staged semantic equality for all protected cell/manifest data.

Provide logs/commands, test outcomes, native screenshots or equivalent evidence for each required region/coverage case, limitations, platform availability, size report, exact pre-cleanup raster path/checksum inventory, and exact cleanup paths/count. Delivery Auditor independently checks this evidence after engineering delivery. Engineering must not mark workflow approved. Do not edit the historical TASK-0001/TASK-0002 records or prior TASK-0003 handoff; unresolved TASK-0003 AC-03/AC-07 remain unresolved unless separately authorized.

## Explicit unresolved implementation decisions

Height grammar/units and height-counter semantics, decoder choice, exact cache bound and corrupt-data status presentation are unspecified. Resolve and document them during discovery without silently redefining existing mixed counters, using the narrowest safe choices consistent with portability and controlled errors. Do not infer heights from levels or add unsupported-platform claims. Full application Web support remains excluded because the existing shell uses window_manager/dart:io; Web background-isolate support must not be claimed.
