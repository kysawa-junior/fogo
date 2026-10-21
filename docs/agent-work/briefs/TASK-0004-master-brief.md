# Master Brief — TASK-0004

```yaml
master_brief:
  task_id: TASK-0004
  source_request: >-
    Correct TASK-0004 planning artifacts before orchestration dispatch, based on the
    user-approved spec `docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md`.
    Create an F.O.G.O.-specific Flutter package `packages/fogo_map_sdk`; remove
    flutter_map and implement own camera/projection/gestures/CustomPainter from
    scratch; render existing regional OSM cells directly (Marília-SP, Vera
    Cruz-SP, Garça-SP, corridor); approximate Mapbox Standard night visually
    only, with no Mapbox package, hosted style/data, token, or runtime basemap
    network; keep local/offline source; preserve roads/fixed screen
    widths/filter/bridge/tunnel, Buildings/Labels toggles, POIs/labels, route
    and markers; add pitch-controlled 3D toggle and extrude only valid positive
    numeric OSM `height` (no levels inference); persist heights by updating
    generator and reprocess already-local PBF, never download PBF; SDK package
    should avoid `dart:io`/native channels/platform plugin and target
    Linux/Windows/macOS/Android/iOS/Web, but full FOGO app Web support is out of
    scope due current window_manager/dart:io shell; no browser-local visual
    comparison. New task supersedes architecture ADR-0003 after parity, updates
    README/ARCHITECTURE, removes generated 21,828 PNG raster tile assets and
    raster generator only after new SDK passes; preserve OSM geometry and all
    non-height cell/manifest content, with only the approved additive height,
    height-count/schema, and generated-output regeneration exception; preserve PBF,
    route/search services and TASK-0001/2 and prior TASK-0003 historical
    records. Repo has no Git metadata. Planning only; no implementation or
    operational sector dispatch.

  consolidated_requirements:
    functional:
      - "Create app-independent package `packages/fogo_map_sdk` with SDK-owned map view, immutable camera/controller API, style, route/marker overlays, selection, and camera/selection events; integrate it into the F.O.G.O. map workspace."
      - "Replace flutter_map camera, projection, gestures, and renderer with Web Mercator projection/inverse transforms, local OSM cell loading, selection hit-testing, and CustomPainter rendering. No flutter_map types in public SDK API."
      - "Load visible local cells, clip geometry to exact manifest bounds, render dark background for missing/empty/outside coverage, and expose controlled errors for corrupt manifest/cell data."
      - "Preserve center/zoom persistence, region/city fit controls, drag pan, pinch, double-tap zoom, mouse-wheel zoom, fling/inertia, right-click selection, and long-press selection. Keep camera gestures independent of route/selection behavior."
      - "Start at pitch 0 and add an app toggle between 0° top-down and 45° pitch."
      - "Render local water, land/farmland/boundaries, water lines, railways, roads, buildings, POIs, labels, and OSM attribution for Marília-SP, Vera Cruz-SP, Garça-SP, and corridor. Preserve road class order, filters, casing/fill, bridges/tunnels, one-way markings, fixed screen-pixel road widths, label collision, and Buildings/Labels toggles."
      - "Render caller-supplied route geometry and markers above map content using the same SDK camera transform."
      - "Use F.O.G.O.-owned dark styling with Mapbox Standard night as visual inspiration only. Do not use Mapbox packages, hosted styles/data/assets, tokens, runtime basemap networking, or claim exact equivalence."
      - "Extrude only buildings with valid positive numeric OSM `height`; missing, invalid, zero, negative, and levels-only buildings remain flat. Never infer or invent heights."
      - "Update the local map-data generator/manifest to add only validated positive numeric OSM `height` to existing building records and make only approved height-related schema/count changes, including required reporting of accepted, levels-only, rejected, or unsupported values without changing non-height counts or silently redefining existing mixed counters. Preserve all existing geometry, membership, coverage, non-height cell content, and non-height manifest fields. Regenerate generated cells/manifest directly from the existing local PBF; do not download, replace, rewrite, or otherwise modify the PBF."
      - "After parity passes, remove flutter_map runtime use/dependency and only the known generated raster PNGs, raster-only generator/metadata, and raster-only asset declarations. Preserve vector-cell geometry and non-height content, non-height manifest fields/counts, PBF, routes/search, and prior task records; only the approved additive height/schema/count regeneration exception may change generated cells/manifest."
      - "After parity, add a successor ADR explicitly superseding ADR-0003 and update README, docs/ARCHITECTURE.md, and operational map-data docs with actual SDK behavior, supported package boundary, visual approximation, and local regeneration instructions."
    non_functional:
      - "SDK must not import dart:io, use native channels/platform plugins, or make runtime basemap requests. It must use Flutter-compatible asset loading and target Linux, Windows, macOS, Android, iOS, and Web. Full-app Web support is explicitly out of scope."
      - "Use portable gzip decoding; declare required decoder as a direct package dependency. Decode off the frame path where supported, bound/prune the viewport cache, and reuse projection/surface caches."
      - "Run formatting, targeted SDK/render and full Flutter tests, analysis, Linux desktop debug build, and SDK target checks where available. Report unavailable targets, limitations, bundle size, and map-data size."
      - "Provide native app visual evidence for Marília, Vera Cruz, Garça, corridor, coverage edge, and outside coverage. Do not use browser-local visual comparison."
      - "Stage regenerated cells/manifest and compare their semantic contents before promotion. Permit only additive valid height, approved height-related schema/count changes, and generated metadata strictly required by the existing generation contract; fail closed on any unrelated delta. Record SHA-256 immediately before and after generation and require equality; manifest `sourceSha256` must match."

  doc_audit_summary:
    conflicts:
      - "Prior Master Brief and canonical ENG-0004 v1 protected cells/manifest wholesale despite the approved spec authorizing additive height/count updates and local generated-output regeneration; this correction narrows that protection consistently."
      - "Two ENG-0004 v1 files existed. The handoff-linked `docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md` is canonical; `docs/agent-work/work-packages/ENG-0004-owned-offline-map-sdk.md` is marked superseded, non-authoritative, and non-dispatchable."
      - "ADR-0003 accepts the existing flutter_map/raster hybrid and remains historical/current until parity; successor must explicitly supersede it after the gate."
      - "README.md, docs/ARCHITECTURE.md, and tool/map_data docs describe flutter_map, raster generation, and 2D-only rendering; update after migration."
      - "Current generator/manifest combine height and levels; target must update only approved height-related fields/counts and must not silently redefine existing mixed-counter semantics."
      - "Generator imports osmium, while tool/map_data/requirements.txt lists Pillow only; operational docs/dependencies are incomplete."
      - "TASK-0003 validation handoff records unresolved AC-03/AC-07 and pending auditor verdict. Preserve this historical state; do not imply approval or modify prior records."
    outdated:
      - "README map feature and raster regeneration sections."
      - "docs/ARCHITECTURE.md map strategy and evolution sections."
      - "tool/map_data/README.md raster renderer instructions."
      - "ADR-0003 status/decision after successful migration."
    missing:
      - "SDK public API and package/platform-boundary documentation."
      - "Documented cell/manifest height parsing grammar and counts."
      - "No-download PBF regeneration instructions and complete generator dependency list."
    confirmed:
      - "TASK-0001/2 history requires road continuity and fixed screen widths by class."
      - "Raster inventory is 21,828 XYZ PNGs plus blank.png; deletion must be exact and parity-gated."
      - "Keep existing OSM geometry/content, non-height cell fields, and non-height manifest values; permit only approved additive height/schema/count deltas and generated cell/manifest regeneration from the already-local PBF. `fetch_data.sh` can download if source is absent; generation must invoke the local PBF directly."
      - "Audit status corrected: source spec metadata is `Reviewed and approved by the user on 2026-10-19`, not awaiting review. This is user approval only; no Delivery Auditor verdict has been issued."
      - "Baseline only: existing local PBF SHA-256 `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` matches current manifest `sourceSha256`; this is not post-generation proof and must be rechecked immediately before/after any future generation."
      - "Repository has no Git metadata; record exact deletion inventory/checksums and report deletions."

  arch_constraints:
    - "SDK must not depend on app code, Riverpod, routing/search, or operational services. SDK owns map data loading/cache, camera, projection, gestures, selection hit-testing, painter. App owns route/search/operational state, region controls, camera persistence, and route/marker overlays."
    - "Expose immutable camera state; app persistence consumes SDK events. Keep all geographic content and caller overlays on the same camera transform."
    - "Use Web Mercator with inverse transform and exact manifest clipping; preserve required gestures, fit, selection, layers, fixed widths, and overlays."
    - "Load assets with Flutter-compatible APIs and portable gzip; no dart:io, native channels/plugins, or runtime map network. Do not rely on an undeclared transitive decoder dependency."
    - "Missing/empty cells are normal. Corrupt manifest/cell data surfaces controlled status/error without crashing app shell or camera gestures."
    - "Keep old renderer and raster assets until native parity evidence passes; only then remove exact inventoried raster-only paths/tooling/config. No broad cleanup."
    - "No full-app Web claim, generic MVT engine, or Mapbox style/data engine."
    - "Preserve existing OSM geometry, records, cell membership, coverage, all non-height cell content, all non-height manifest fields/counts, source PBF, geography, attribution, route/search services, and historical TASK-0001/2/3 records. The only cell/manifest exception is additive validated positive numeric `height` on existing building records, approved height-related schema/count changes, and regenerated generated cells/manifest from the local PBF."
    - "Stage generated outputs and verify protected semantic equality before promotion. Reject any data delta beyond the approved height/schema/count exception and generated metadata strictly required by the existing contract. Fail closed if the local PBF is absent or its before/after SHA-256 differs; manifest `sourceSha256` must match."
    - "Update README and architecture docs; create explicit successor ADR after parity."

  risks:
    - "High: camera/projection/pitch rewrite can regress gesture, selection, clipping, or overlay alignment; require round-trip, interaction, and native parity evidence before cutover."
    - "High: raster cleanup is difficult to reverse/verify without Git metadata; use exact path inventory/checksum, strict parity gate, and deletion report."
    - "High: portable compressed-asset loading and Web behavior vary by target; verify available targets and report gaps without claiming full-app Web support."
    - "Medium: OSM height grammar/units are unspecified; inspect existing PBF, define/document a narrow numeric grammar, reject/report unsupported values, and never use levels."
    - "Medium: user approval of the spec is distinct from Delivery Auditor approval; do not imply that an auditor verdict exists."
    - "Medium: broad cell/manifest protections previously contradicted the approved height work; the revised brief and canonical ENG-0004 must retain the narrow exception and semantic-diff gate."
    - "Medium: pitch persistence is unspecified; preserve current center/zoom persistence and default pitch to transient at 0° unless separately approved."

  dependencies:
    agents: [engineering-lead, delivery-auditor]
    work_packages: [ENG-0004]
    modules: [packages/fogo_map_sdk, lib/features/map, tool/map_data, assets/map, docs/adr, README.md, docs/ARCHITECTURE.md]

  team_assignment: {engineering: true, design: false, code_analysis: false}
  execution_order: [engineering, delivery-auditor]

  acceptance_criteria:
    - "Master Brief, canonical ENG-0004 v2, and TASK-0004 handoff consistently protect the source PBF and existing geometry/non-height content while allowing only additive validated positive numeric `height`, approved height-related schema/count updates, and generated cell/manifest regeneration."
    - "Canonical dispatch package is `docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md` version 2; it includes staged semantic-diff and exact before/after PBF checksum gates."
    - "`docs/agent-work/work-packages/ENG-0004-owned-offline-map-sdk.md` is marked superseded, non-authoritative, and non-dispatchable; only one ENG-0004 is dispatchable."
    - "Handoff points to canonical ENG-0004 v2, states pending orchestration dispatch and no sector dispatch/implementation, and distinguishes user approval from the absent Delivery Auditor verdict."
    - "Documentation audit records source spec status as `Reviewed and approved by the user on 2026-10-19`, not awaiting review; this is not Delivery Auditor approval."
    - "SDK exposes documented view/controller/style, overlays, selection and camera events; app uses it; flutter_map camera/rendering is removed only after parity."
    - "Projection and inverse round-trip tests pass; camera works at 0°/45°; gestures, fit, persistence and selection remain functional."
    - "Tests cover visible-cell loading, exact bounds clipping, partial/outside coverage, missing/empty cells, and controlled corrupt-data handling."
    - "Tests/native evidence verify feature and road ordering, filters, fixed pixel widths, bridge/tunnel/one-way behavior, label collision, toggles, POIs, attribution, routes, and markers."
    - "Only valid positive numeric OSM height extrudes; absent/invalid/non-positive/levels-only values remain flat."
    - "Generator persists accepted heights/counts, reports rejected formats, reads existing PBF only, downloads nothing, and leaves source PBF unchanged."
    - "Before/after PBF SHA-256 values are equal and manifest `sourceSha256` matches; staged generated outputs preserve all records, geometry, membership, coverage, non-height cell fields, and non-height manifest fields/counts, with no unrelated semantic delta."
    - "Native captures cover Marília, Vera Cruz, Garça, corridor, coverage edge, and outside coverage; no browser-local comparison."
    - "SDK package is checked on available Linux/Windows/macOS/Android/iOS/Web targets without dart:io/native plugin/channel/runtime basemap network; untested targets are named. No full-app Web claim."
    - "Record parity evidence and exact raster deletion inventory before removing flutter_map/raster-only assets/tooling. Confirm cells, manifest, PBF, services, and TASK-0001/2/3 history remain."
    - "README, docs/ARCHITECTURE.md, tool map-data docs, and successor ADR accurately document implementation, style approximation, package-vs-app Web boundary, and no-download regeneration."
    - "Formatting, targeted/full tests, analysis, and Linux debug build pass; report exact outcomes, bundle/map-data sizes, and limitations."

  protected_areas:
    - "`tool/map_data/raw/sudeste-latest.osm.pbf` is immutable/read-only: do not download, replace, rewrite, or otherwise modify it; require equal before/after SHA-256 and matching manifest `sourceSha256`."
    - "Protect existing OSM geometry, records, cell membership, coverage, every preexisting non-height cell field, and every non-height manifest field/count. Permit only additive validated positive numeric `height` on existing building records, approved height-related schema/count changes, and regenerated generated cells/manifest directly from the existing local PBF."
    - "All cell/manifest changes outside that explicit additive-height/schema/count regeneration exception are forbidden; stage and semantically diff outputs before promotion."
    - "Route/search services, route computation, operational state, OSM geography, and attribution."
    - "Historical TASK-0001, TASK-0002, and prior TASK-0003 specifications, briefs, WPs, handoffs, and reports."
    - "App shell lifecycle/platform limitations; SDK web support must not imply full app web support."
    - "All non-raster assets and any file outside the explicitly inventoried raster-only deletion set."

  affected_areas:
    - "New packages/fogo_map_sdk/**."
    - "Map workspace, current map/vector models/renderers/style/persistence callers, and focused tests."
    - "tool/map_data/build_map_data.py, generator tests/docs/dependencies, and generated cells/manifest from existing local PBF."
    - "Known assets/map/tiles raster outputs plus raster-only generator/metadata/pubspec declarations, after parity gate only."
    - "README.md, docs/ARCHITECTURE.md, tool map-data documentation, successor ADR, and TASK-0004 artifacts."

  unresolved_questions:
    - "Define supported positive numeric OSM height grammar/units from existing data; reject and report other forms."
    - "Confirm height-related manifest counter semantics without silently redefining existing mixed height-tag counters."
    - "Select and directly declare portable gzip decoder and document asset-source contract."
    - "Set/document bounded cache size and controlled corrupt-data status presentation."
    - "Preserve current center/zoom persistence; pitch defaults to 0° and transient absent explicit approval."

  routing_rationale:
    engineering: "Required for SDK, renderer replacement, data pipeline, app integration, docs, tests, and gated cleanup."
    design: "Not required: 0°/45° toggle and dark visual hierarchy are specified; reuse existing design-system controls."
    code_analysis: "Not required: approved feature replacement, not defect, regression, code-smell, performance, unsafe-code, or audit request. Engineering must still inventory current behavior and exact deletions before implementation/cleanup."
    integration_contract: "Not required because design is not assigned; engineering owns SDK/app API contract in its phased WP."
```
