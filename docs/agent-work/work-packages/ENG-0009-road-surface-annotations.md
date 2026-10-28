---
id: ENG-0009
version: "1"
status: approved
source:
  user_request: "TASK-0009"
  orchestrator_task_id: TASK-0009
objective: "Implement approved world-space 3D road-name decals and traffic arrows only after CODE-0009 handoff, preserving the bool API, 2D labels, road picking, and existing worktree content."
background: "User-approved spec docs/superpowers/specs/2026-10-26-road-surface-annotations-design.md (commit 1e26dd6) defines visual behavior. CODE-0009 is mandatory and gates implementation on its root-cause/correction/integration handoff."
scope:
  included:
    - "Add compatible OSM road direction state for both, forward, and reverse; preserve existing oneway boolean behavior and callers."
    - "Generate direction arrows along cumulative road length at the approved spacing, orientation, elevation, and lane offsets."
    - "Place 2D road label candidates at cumulative path-length midpoint and keep UI labels out of the 3D view."
    - "Carry engine-independent road annotation placement through MapScene and batch arrow/decal geometry by existing spatial tile."
    - "Rasterize road text into per-tile atlases during scene upload; render world-aligned decal geometry with UVs and an unlit alpha-blended material."
    - "Pass mesh UVs through FlutterSceneAdapter and preserve base-road entity picking/raycast behavior."
    - "Add focused tests; update only directly relevant documentation if behavior makes it inaccurate."
    - "Implement only after receiving CODE-0009's evidence-backed correction/integration handoff; resolve no analyzed concern ahead of that gate."
  excluded:
    - "Change decisions settled in the approved design spec or add a Design Work Package."
    - "Change area/POI label policy, the independent 2D road painter, or add arrows to Map2DScene."
    - "Add package dependencies, palette tokens, per-arrow/per-label scene nodes, or per-frame atlas generation."
    - "Implement extruded 3D letter geometry, alter road entity identity, or change unrelated app behavior."
    - "Reset, revert, delete, or clean up pre-existing modified, deleted, or untracked worktree content."
requirements:
  functional:
    - "Resolve road text as name then ref; rasterize into per-tile atlases and align decal planes to a sufficiently straight local tangent. Fit legibly or omit."
    - "Use FogoPalette.crossing text with a dark outline, UVs, and an unlit alpha-blended material."
    - "Generate atlases during scene upload; on failure skip affected decals without blocking scene content or 2D labels."
    - "Interpret yes=forward, -1=reverse, no=both, missing roundabout=forward, explicit roundabout no=both, and other/absent values=both."
    - "Preserve RoadProperties.oneway API and meaning: true means one permitted direction. Map yes to forward/true and -1 to reverse/true; map no to both/false."
    - "A roundabout with missing oneway defaults to forward/true. Explicit roundabout oneway=no overrides default to both/false, intentionally changing the current mapper's blanket-roundabout true result for this specific input."
    - "Generate arrows every approximately 45 m of cumulative road distance, with at least one per allowed direction on shorter ways; orient to local tangents on curves."
    - "Place opposing bidirectional arrows in separate lanes offset by one quarter road width; one-way arrows follow ordered-way direction."
    - "Raise decals/arrows approximately 0.04 m and show only at close 3D LOD no farther than 1,200 m camera distance."
    - "Keep UI labels in Map2DView; anchor 2D road candidates at cumulative path-length midpoint; leave area/POI label policy and 2D road painter unchanged."
    - "Keep annotations out of Map2DScene. Annotations have no road entityId or retained CPU picking data; raycasts pass through to selectable base road."
  non_functional:
    - "Batch arrows and decals by existing spatial tile; do not create a scene node per annotation."
    - "Preserve all unrelated pre-existing worktree modifications, deletions, and untracked content; keep scoped edits minimal."
    - "Add no package dependency or palette token."
constraints:
  technical:
    - "Use existing engine, MapScene, MeshData, and FlutterSceneAdapter pipeline; pass UVs through to Flutter Scene geometry."
    - "Use existing crossing/marking palette, approximately 0.04 m offset, 45 m arrow spacing, and 1,200 m maximum camera distance."
    - "Do not create per-frame atlas work; generate during scene upload and degrade gracefully if text atlas generation fails."
    - "Preserve the distinction between missing and explicit one-way tags; explicit roundabout no overrides the roundabout default."
    - "Do not begin implementation on analyzed concerns until CODE-0009 report/handoff returns; keep open tolerances and integration conflicts explicit."
  architectural:
    - "Keep OSM parsing/road geometry in engine; keep text rasterization, atlas textures, and Flutter Scene materials in render adapter."
    - "Carry engine-independent road-label placement through MapScene and assign annotation batches to existing spatial tiles."
    - "Keep Map2DScene annotation-free and preserve base-road entity identity and picking."
  visual:
    - "The approved TASK-0009 spec is the sole visual source of truth; use specified crossing text color, dark outline, tangent-aligned planes, and existing crossing/marking arrow palette."
    - "Do not show screen-space UI labels in 3D; preserve labels in the 2D view."
  business:
    - "No new dependency, licensing surface, or user-facing map feature outside the approved road annotations."
dependencies:
  agents:
    - "engineering-lead"
  work_packages:
    - "CODE-0009"
    - "INT-0009"
  modules:
    - "Road domain and OSM feature mapping"
    - "Road mesh generation, scene annotation metadata, and mesh UV data"
    - "2D label candidate placement and 2D/3D render views"
    - "Flutter Scene adapter, texture atlas upload, and raycast selection"
assigned_agents:
  - "engineering-lead"
affected_areas:
  modules:
    - "OSM road property parsing and backward-compatible direction model"
    - "Engine road annotation geometry and MapScene spatial-tile transport"
    - "2D road-label placement and 2D/3D render-view label separation"
    - "Flutter Scene adapter UV/material/atlas upload and base-road picking"
    - "Focused engine, mapping, adapter, and map-view tests"
  packages: []
  files:
    - "lib/engine/domain/road.dart"
    - "lib/engine/domain/road_properties.dart"
    - "lib/engine/osm/osm_feature_mapper.dart"
    - "lib/engine/mesh/road_mesh_builder.dart"
    - "lib/engine/scene/map_scene.dart"
    - "lib/engine/geometry/mesh_data.dart"
    - "lib/features/map/presentation/render/label_candidates.dart"
    - "lib/features/map/presentation/render/label_overlay.dart"
    - "lib/features/map/presentation/render/fogo_scene_view.dart"
    - "lib/features/map/presentation/render/flutter_scene_adapter.dart"
    - "Focused tests under test/engine/ and test/features/map/presentation/render/"
protected_areas:
  modules:
    - "Existing RoadProperties.oneway API and caller meaning that true means one permitted direction; approved -1 and explicit-roundabout-no input mappings are clarified exceptions to old parsed results."
    - "Existing base-road entity identity and raycast selection behavior."
    - "Existing 2D area/POI label policy and separate 2D road painter."
    - "All pre-task worktree changes outside explicitly scoped implementation; preserve content and diffs."
  files:
    - "Every pre-task modified, deleted, or untracked path and its existing content; do not revert, reset, remove, or overwrite unrelated work."
deliverables:
  - "OSM direction parsing and compatible directional model for both/forward/reverse, with existing boolean callers preserved."
  - "World-space road-name decals packed into per-tile atlases and uploaded with UV-aware Flutter Scene geometry."
  - "Per-tile arrow batches following direction, road curvature, spacing, lane, elevation, and LOD requirements."
  - "Length-midpoint 2D road labels and 2D-only UI label overlay placement."
  - "Non-pickable annotation geometry with selectable base roads and graceful atlas failure behavior."
  - "Focused regression tests and completion report identifying touched files and preserved pre-existing work."
acceptance_criteria:
  - "AC-01: Named roads appear as tangent-aligned world-space asphalt decals in close 3D, use approved text/material treatment, and follow perspective."
  - "AC-02: UI labels remain only in Map2DView; 2D road candidates use cumulative path-length midpoint and existing label/painter behavior remains unchanged."
  - "AC-03: RoadProperties.oneway API remains; true means one permitted direction. yes=forward/true, -1=reverse/true, no=both/false; missing roundabout=forward/true; explicit roundabout no=both/false, intentionally overriding current blanket-roundabout true; other/absent=both/false."
  - "AC-04: Arrows repeat at approximately 45 m or cover short ways, follow curves, use approved lane offsets, and point in road direction."
  - "AC-05: Decals/arrows are approximately 0.04 m above road, batched by tile, atlas work runs during scene upload, UVs reach Flutter Scene, and LOD ends at 1,200 m."
  - "AC-06: Map2DScene receives no arrows; annotations do not intercept raycasts and base roads remain selectable."
  - "AC-07: Focused tests cover parsing/compatibility, label anchor, arrow geometry, atlas/UV upload and fallback, LOD, view separation, and selection."
  - "AC-08: dart format, flutter analyze, flutter test, and available Linux debug build pass; report exact commands and outcomes."
testing_requirements:
  - "Test the tag→direction→bool matrix: yes=forward/true, -1=reverse/true, no=both/false, missing roundabout=forward/true, explicit roundabout no=both/false, other/absent=both/false. Verify true continues to mean one permitted direction and test all existing caller effects."
  - "Test 2D road label placement against cumulative path distance on unevenly sampled/curved ways; assert area/POI and road painter behavior remains unchanged."
  - "Test arrow direction, reverse direction, bidirectional lanes, quarter-width offsets, cumulative spacing, short-way coverage, curved tangents, and 0.04 m offset."
  - "Test road text name/ref choice, fit/omission, tile batching, upload-time atlas generation, UV transfer, unlit alpha blend, and atlas failure behavior."
  - "Test 1,200 m LOD boundary, no annotations in Map2DScene, no annotation entity/picking data, and raycasts selecting the base road."
  - "Run dart format only on feature-touched Dart files, flutter analyze, flutter test, and flutter build linux --debug when toolchain is available. Record unavailable prerequisites."
documentation_requirements:
  - "Keep implementation aligned with approved TASK-0009 spec; update only documentation directly made inaccurate by scoped changes."
  - "Report exact test/build commands, outcomes, limitations, touched files, and worktree-preservation risks; do not claim unrun validation."
risks:
  - "Atlas size, UV mapping, alpha material, and tangent orientation can make decals unreadable or missing; validate upload and fallback."
  - "Annotation height or retained CPU geometry can cause z-fighting or intercept selection; test offset and raycast-through behavior."
  - "Directional enum migration can break legacy boolean callers if compatibility semantics change."
  - "Existing dirty worktree makes formatting or edits outside task scope risky."
  - "Foreshortening at low camera elevation and omission of names without a sufficiently straight segment are approved limitations."
completion_report:
  required: true
architecture:
  pattern: "Existing engine/scene/render-adapter separation; per-tile annotation batches through MapScene"
  state_management: "Existing scene upload pipeline; no new UI state model"
  ui_framework: "Flutter and Flutter Scene"
design_dependency:
  package: "docs/superpowers/specs/2026-10-26-road-surface-annotations-design.md"
  status: "User-approved; commit 1e26dd6; no Design Work Package assigned."
implementation_requirements:
  - "Follow approved behavior; do not reopen settled visual decisions."
  - "Preserve RoadProperties.oneway API and true=one-permitted-direction meaning while representing both/forward/reverse. Explicit roundabout no=false is the approved input-specific correction, not a compatibility regression to mask."
  - "Do not implement any analyzed oneway, MapScene identity/raycast, LOD, or engine/adapter concern until CODE-0009's report and correction/integration handoff have returned."
  - "Keep engine OSM parsing/geometry separate from adapter rasterization/atlas/material work; transport placement through MapScene."
  - "Use existing tile batches, upload-time atlases, UV geometry, crossing/marking palette, 0.04 m offset, 45 m spacing, and 1,200 m LOD."
  - "Keep annotations visual-only and raycast-through; selection identity remains on base road."
  - "Preserve unrelated pre-existing worktree state; do not run broad cleanup or whole-repository reformatting."
required_tests:
  - "OSM one-way parser matrix and backward-compatible boolean caller tests."
  - "Length-based 2D road-label anchor tests on unevenly sampled ways."
  - "Arrow direction, short-way coverage, spacing, separate lanes, curved tangents, and surface-height tests."
  - "Per-tile batching, upload-time atlas/UV/material, atlas-failure, and 1,200 m LOD tests."
  - "2D/3D label separation, no Map2DScene arrows, and base-road raycast/picking regression tests."
  - "Formatter on scoped Dart files, flutter analyze, flutter test, and available Linux debug build."
forbidden_changes:
  - "Do not reset, revert, delete, or overwrite unrelated pre-task worktree content; it is protected by the Master Brief."
  - "Do not remove/rename RoadProperties.oneway or change true from meaning one permitted direction; this API/meaning is protected in the Master Brief. The explicitly approved -1=true and roundabout-no=false mappings are not prohibited."
  - "Do not change base-road pickability, let annotations intercept raycasts, or alter protected 2D label behavior; these are protected in the Master Brief."
---
# Work Package ENG-0009 — Road-Surface Names and Direction Arrows

## Objective

Implement approved TASK-0009 road annotations across the OSM engine and Flutter Scene adapter. Add world-space, atlas-backed road-name decals and direction arrows; correct length-based 2D road-label anchors; preserve existing boolean callers, 2D label behavior, and base-road picking.

## Mandatory Code Analysis gate

Do not begin implementation on analyzed concerns until the Orchestrator has returned the CODE-0009 root-cause report and correction/integration handoff. Follow its evidence-backed touch list and correction plan. If the report identifies an unresolved API/identity conflict or open decision that prevents spec-compliant work, route it through the Orchestrator/Documentation Director instead of inventing a sentinel, threshold, or behavior.

## Scope and architecture

Keep OSM parsing and road geometry in the engine. Represent direction as `both`, `forward`, or `reverse` while preserving the current boolean API and semantics for callers. Carry engine-independent decal placement and tile-batch data through `MapScene`. Keep Flutter text rasterization, per-tile atlas creation, UV assignment, and Flutter Scene materials in the adapter. Build batched annotation geometry during scene upload rather than adding a scene node per mark.

Use `name` then `ref`; align a decal to an adequately straight local road tangent, fit legibly, and omit when it cannot fit. Use crossing text color with a dark outline, UVs, and an unlit alpha-blended material. Generate/pack atlases at scene upload; if atlas generation fails, skip affected decals and continue rendering the scene. Keep UI road/area/POI labels in `Map2DView` only and anchor 2D road candidates at cumulative path-length midpoint.

Interpret `yes` as forward/true, `-1` as reverse/true, `no` as both/false, missing `oneway` on a roundabout as forward/true, explicit roundabout `no` as both/false, and other/absent values as both/false. `RoadProperties.oneway` API remains; true continues to mean a single permitted direction. The false result for explicit roundabout no intentionally overrides the current mapper's blanket-roundabout true result. Test all existing bool callers after CODE-0009 handoff. Put arrows about every 45 m of cumulative road distance, with at least one per allowed direction on short ways. Follow local tangents on curved roads; bidirectional arrows oppose each other in lanes offset by one quarter of road width. Use the approved existing crossing/marking palette.

Raise decals and arrows about 0.04 m above the rendered road. Restrict both to close 3D LOD at no more than 1,200 m camera distance, distinct from the existing 3,500 m roadMarking LOD unless CODE-0009 evidence and approved scope authorize broader changes. Keep arrows out of `Map2DScene`; assign annotation batches to existing spatial tiles. Both annotation kinds must have no entity ID and no retained CPU hit geometry. Raycasts must pass through them to the selectable road beneath. Resolve the required `MapSceneObject.entityId` seam according to CODE-0009; do not invent a sentinel.

## Protected behavior and local worktree

Do not alter existing area/POI label policy or the independent 2D road painter. Preserve existing road picking and boolean caller behavior. The worktree contains extensive pre-existing changes, deletions, and untracked files; retain their contents/diffs and make only task-scoped changes. Do not reset, revert, remove, or broadly reformat unrelated files.

## Acceptance and required evidence

Meet AC-01 through AC-08 in frontmatter. Test one-way parsing and boolean compatibility, route-length label placement, arrow geometry/direction, atlas/UV upload and fallback, LOD, 2D/3D separation, and raycast-through selection. Run formatter on feature-touched Dart files, `flutter analyze`, `flutter test`, and `flutter build linux --debug` when toolchain is available. Report commands/results, touched files, unavailable prerequisites, and preserved-worktree risks.
