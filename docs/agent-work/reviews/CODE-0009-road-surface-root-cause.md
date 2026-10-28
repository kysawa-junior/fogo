# CODE-0009 — Road-Surface Annotation Root-Cause Report

**Task:** TASK-0009  
**Work package:** CODE-0009  
**Status:** Report-only analysis complete; Engineering gate remains closed pending handoff.  
**Scope:** Read-only. No source, test, README, approved spec, or existing documentation was edited. Only this required report was created.

## Executive summary

The current engine reduces OSM one-way semantics to one boolean, so it cannot
retain forward versus reverse direction; the roundabout shortcut also overrides
explicit `oneway=no`. Road labels use equal-weight vertex averages and the UI
overlay is mounted in both 2D and 3D. The scene model requires every render
object to claim a cartographic `entityId`, while adapter picking maps the nearest
ray hit directly back to such an ID. That model cannot represent the approved
visual-only, no-ID annotations safely. `MeshData` carries UVs but the adapter
drops them. Existing road markings use 3,500 m LOD, and there is no distinct
annotation kind for the approved maximum of 1,200 m. The current LOD visibility
branch also has a deterministic near-threshold false/true/false transition.

**Implementation gate:** ENG-0009 must wait for this report/handoff. Do not use
an `entityId` sentinel, reverse stored road geometry to encode `oneway=-1`,
change the 3,500 m road-marking policy silently, or invent any open thresholds.

## Evidence and caller inventory

### One-way mapping contract

`RoadProperties.oneway` defaults to `false` and is a `final bool`
(`lib/engine/domain/road_properties.dart:6-15,24-26`). Its comment says it comes
from the OSM tag and distinguishes geometric point order from traffic direction
(`:24-26`). The mapper iterates `way.nodeRefs` in input order
(`lib/engine/osm/osm_feature_mapper.dart:448`), appends matching points and
references (`:465-466`), and stores the paired lists without reversal
(`:417-420`). The current mapper sets the bool with
`tags['oneway'] == 'yes' || tags['junction'] == 'roundabout'`
(`lib/engine/osm/osm_feature_mapper.dart:405-413`). The defect is lost direction
metadata, not an established need to mutate that geometry order.

| OSM input | Current bool result | Approved direction / bool | Result |
|---|---:|---|---|
| `oneway=yes` | `true` | forward / `true` | Boolean matches; direction is not represented |
| `oneway=-1`, not roundabout | `false` | reverse / `true` | Incorrect; reverse is lost |
| `oneway=-1`, roundabout | `true` | reverse / `true` | Bool matches; reverse direction is lost |
| `oneway=no`, not roundabout | `false` | both / `false` | Matches |
| `oneway` absent, not roundabout | `false` | both / `false` | Matches |
| `oneway` absent, roundabout | `true` | forward / `true` | Matches bool; direction is not represented |
| `oneway=no`, roundabout | `true` | both / `false` | Incorrect; explicit `no` is overridden |
| other value, not roundabout (e.g. `reversible`) | `false` | both / `false` | Matches bool |
| other value, roundabout | `true` | both / `false` | Incorrect; roundabout shortcut overrides explicit value |

Required compatibility remains: `true` means exactly one permitted direction;
both `forward` and `reverse` therefore retain `oneway=true`, while `both` has
`false`. Add an explicit direction value (`both`/`forward`/`reverse`) without
removing or changing the existing bool contract. Parse explicit recognized
values before the missing-tag roundabout default. Keep way points and `nodeRefs`
ordered as imported; arrow direction should use the direction value relative to
that order. Do not reverse the road geometry as a substitute for directional
metadata.

### Every in-scope bool consumer

| API / caller | Behavior and evidence |
|---|---|
| `RoadProperties` producer/contract | Bool default and declaration: `lib/engine/domain/road_properties.dart:7-10,24-26`. Producer mapping: `lib/engine/osm/osm_feature_mapper.dart:405-413`. |
| Selection details | The only direct `RoadProperties.oneway` read found in `lib/` displays `sim`/`não`; it does not expose forward vs reverse: `lib/features/map/presentation/selection_details.dart:26-43` (read at `:37`). Corrected `-1` remains `sim` because bool still means one permitted direction. |
| Separate vector-tile `MapRoad` model | `MapRoad.oneway` is a required bool and documented as the 2D map arrow flag: `lib/features/map/vector/vector_data/features.dart:3-20`. It is not `RoadProperties` and no inspected path connected it to `OsmFeatureMapper`. |
| Vector-cell decoder | Reads integer `o`; missing defaults to `0`, and only `1` becomes true: `lib/features/map/vector/vector_data/cell_data.dart:24-35`. This format carries no `forward`/`reverse` distinction. Keep the separate 2D road path unchanged unless separately authorized. |
| Vector road join | `MapRoad.oneway` is part of style equality (`road_join.dart:45-51`); one-way joins require endpoint orientation to preserve direction (`:76-77`); joined road copies the bool (`:98-105`). |
| Vector road deduplication | Bool is in hash/equality, and only bidirectional ways are considered in reverse (`road_deduplication.dart:9-27,45-66`). This behavior must not be conflated with the engine enum change. |

Existing regression evidence is narrow: `test/engine/osm_reader_mapper_test.dart:173-176`
asserts a true mapper case; it does not cover `-1`, ordinary `no`, other values,
roundabout default, or explicit roundabout `no`. `test/road_geometry_merger_test.dart:66-109`
exercises the separate vector `MapRoad` bool behavior. `test/map_selection_filters_test.dart:180-185`
checks vector-cell `o=1` decoding, not engine tag mapping.

### Label placement and 2D/3D view mounts

`Road.name` chooses `tags['name'] ?? tags['ref']`
(`lib/engine/domain/road.dart:26`). `extractLabelCandidates` then skips null or
empty names and assigns every vertex equal weight before dividing by point
count (`lib/features/map/presentation/render/label_candidates.dart:28-42`).
For unevenly sampled routes this is not the route-length midpoint; on curved
routes an arithmetic coordinate mean can lie away from the mapped line. The
overlay projects world positions through a `PerspectiveCamera.worldToScreen`
(`label_overlay.dart:35-59`) and paints screen-space widgets
(`:103-128`).

`Map2DView` mounts `LabelOverlay` over its `CustomPaint`
(`render/map_2d/map_2d_view.dart:219-245`), and `FogoSceneView` also mounts it
over `SceneView` (`render/fogo_scene_view.dart:230-245`). The page passes the
same candidates to both views in a persistent cross-fade stack
(`pages/map_3d_page/map_3d_page.dart:269-332`). At settled 3D the overlay is
visible; during transitions both may paint. `LabelOverlay` uses `IgnorePointer`
(`label_overlay.dart:103-105`), so it does not itself capture pointer input.

One edge case: an empty `name` value wins the null-coalescing fallback in
`Road.name` and is then rejected by `label_candidates.dart:30-32`, so a
non-empty `ref` is not used. Add focused `name`/`ref` tests and treat blank
values consistently with the approved name-then-ref behavior.

### Scene identity, tile ownership, LOD, camera distance, and picking

`MapSceneObject` requires `entityId`, `tileId`, mesh, color, and kind; the
identity is documented as a cartographic entity ID, not a graphics-node ID
(`lib/engine/scene/map_scene.dart:6-21`). `SceneObjectKind` has no annotation
kind (`:33-47`). `FogoEngine` creates road objects with `road.id`
(`lib/engine/fogo_engine.dart:147-182`), and existing pavement markings use
`SceneObjectKind.roadMarking` with their own feature ID (`:412-458`).

Tile ownership is entity-keyed: `TileManager.ownerTileByEntity` maps entity ID
to one tile (`lib/engine/spatial/spatial_partitioner.dart:93-107`); `assign`
registers intersecting tiles and chooses the centroid owner, with a nearest
tile fallback for out-of-grid centers (`:105-136`). `tileOfPoint` can resolve
a tile from a center without an entity ID (`:138-142`). Engine partitioning
assigns each mesh using `obj.entityId` and its bounds center, then later looks
up `ownerTileOf(obj.entityId)` to repackage it (`lib/engine/fogo_engine.dart:672-718`).
The junction pad uses `priority.road.id` (`:653-665`), the same identity as its
base road. Thus multiple render meshes with one entity ID can overwrite the
entity-keyed owner entry; if their centers differ, the later owner is applied
to both. This is an integration hazard for render batches, not a measured
visual failure in this report.

Adapter upload creates one node/geometry/material per `MapSceneObject` and
registers it in entity maps (`lib/features/map/presentation/render/flutter_scene_adapter.dart:111-176`).
Node names, `_nodesByEntity`, `_entityByNode`, highlight materials, and base
colors all use `entityId` (`:30-34,155-170`). `pickEntity` calls one nearest-hit
`_scene.raycast(ray)` and returns `_entityByNode[hit.node]`
(`:317-329`). Consequently, simply omitting an annotation from the entity map
is insufficient: a retained annotation mesh could be the nearest hit and make
the picker return null instead of continuing to the road.

The installed `flutter_scene 0.24.3` API provides a direct no-hit route:
`MeshGeometry.fromArrays` accepts `retainCpuData` and documents `false` for
meshes that do not need raycasting
(`/home/kysawa/.pub-cache/hosted/pub.dev/flutter_scene-0.24.3/lib/src/geometry/mesh_geometry.dart:70-98,538-551,585-598`);
raycast code skips meshes without retained CPU vertex data
(`/home/kysawa/.pub-cache/hosted/pub.dev/flutter_scene-0.24.3/lib/src/raycast.dart:186-205`). `Node.raycastable` is configurable
and defaults to true (`/home/kysawa/.pub-cache/hosted/pub.dev/flutter_scene-0.24.3/lib/src/node.dart:237-243`).
`Scene.raycast` returns the nearest hit
(`/home/kysawa/.pub-cache/hosted/pub.dev/flutter_scene-0.24.3/lib/src/scene.dart:484-506`;
implementation: `/home/kysawa/.pub-cache/hosted/pub.dev/flutter_scene-0.24.3/lib/src/raycast.dart:84-99`);
`raycastAll` returns hits sorted nearest-first
(`/home/kysawa/.pub-cache/hosted/pub.dev/flutter_scene-0.24.3/lib/src/scene.dart:508-523`).
Raycast traversal honors `raycastable` and `where`
(`/home/kysawa/.pub-cache/hosted/pub.dev/flutter_scene-0.24.3/lib/src/raycast.dart:122-149`). Prefer both `retainCpuData: false` and
`node.raycastable = false` for annotation nodes, omit entity name/highlight/pick
maps, and test that the base road remains selectable. These are package
capabilities already installed; no dependency change is indicated.

**Required identity correction:** do not put annotations through
`MapSceneObject` with an invented sentinel. Keep selectable cartographic
objects on the existing entity-identity path. Carry annotation placement or
render batches through a distinct, engine-independent `MapScene` record with
an explicit `tileId` and no `entityId`; adapter-created annotation nodes then
have no selectable identity. Directly assign annotation batches to existing
spatial tile IDs rather than calling entity-keyed ownership with a fabricated
ID. Ensure tile bounds/culling include the actual annotation batch bounds.
Exact record shape belongs to ENG-0009; tile-edge/atlas ownership remains open.

### UV/material and batching seam

`MeshData` accepts optional `texCoords` and stores them
(`lib/engine/geometry/mesh_data.dart:10-17,45-53`). Adapter conversion passes
positions, normals, optional colors, and indices but omits `texCoords`
(`flutter_scene_adapter.dart:147-154`). The adapter's current materials set a
color factor only (`:126-139`); no atlas texture is uploaded. Installed
Flutter Scene supports UV input on `MeshGeometry.fromArrays`
(`.../geometry/mesh_geometry.dart:54-98`) and textured unlit materials with
`colorTexture`, `baseColorTexture`, and `AlphaMode.blend`
(`.../material/unlit_material.dart:16-21,29-64`). The engine/adapter boundary
therefore has a concrete UV omission and an unimplemented atlas/material path.

The adapter's 400-object loop yields to the event loop (`flutter_scene_adapter.dart:111-116,172-175`)
but still builds one material, geometry, and node per object (`:126-166`); it
does not merge annotation geometry. ENG-0009 must batch annotation quads/arrows
by tile at scene upload, not treat these cooperative upload chunks as draw-call
or geometry batching. Engine owns OSM parsing and engine-independent direction/
placement; adapter owns text rasterization, per-tile atlas, UV/material setup,
and Flutter Scene upload per INT-0009. Atlas work must be upload-time and
failure must skip affected decals without blocking the rest of the scene.

`FogoEngine` creates a separate `Map2DScene` from 2D strokes/fills
(`lib/engine/fogo_engine.dart:140-145,164-170,197-205,720-733`). Existing
road-marking objects enter the 3D `objects` list (`:448-455`); no annotation
data is passed to `Map2DScene`. Keep arrows out of `Map2DScene` and preserve the
existing 2D road painter and area/POI label policy.

### LOD and camera metric

`LodPolicy` maps `roadMarking` to level 1 (`lib/engine/scene/lod_policy.dart:18-24`);
level 1 max is 3,500 m, level 2 max is 1,200 m (`:38-44`). There is no
distinct annotation kind today. Reusing `roadMarking` would violate the
approved annotation maximum; add an annotation category scoped to the approved
1,200 m maximum and do not globally move existing road markings from 3,500 m.

`FogoSceneView` sends `OrbitCamera.distanceMeters` to adapter LOD
(`lib/features/map/presentation/render/fogo_scene_view.dart:67-84`). Camera
position is computed from `target + distanceMeters * direction`
(`lib/engine/scene/camera_controller.dart:66-73`); current LOD input is thus
the global orbit radius from target, not per-annotation camera-to-object
distance. Tile culling is separate: adapter uses camera target as `cullCenter`
and a tile AABB/radius test, with 6,000 m base and 8,000 m cap
(`flutter_scene_adapter.dart:45-50,197-245`). The approved 1,200 m distance
origin/basis is not specified and must not be invented.

The current hysteresis code has an evidence-backed transition defect. For a
level with maximum `M`, `isLevelVisible` infers prior visibility from
`previousDistance <= M`, then returns `cameraDistance <= 0.85*M` for that
branch (`lod_policy.dart:46-59`). Adapter reevaluates only when accepted camera
distance changes by at least 50 m and passes the prior accepted distance
(`flutter_scene_adapter.dart:201-215`); upload resets that distance to infinity
(`:87-91`). Deterministic trace for L1: 3,550 → 3,500 → 3,450 m yields
false → true → false; visibility becomes true again at 2,975 m. For L2 the
corresponding trace is 1,250 → 1,200 → 1,150 → 1,020 m, yielding
false → true → false → true. This conflicts with a stable visible-nearby
interpretation and is not covered by the existing LOD test, which only checks
prior distance 6,000 m at current 5,000 and 3,000 m
(`test/engine/lod_and_camera_test.dart:10-17`). Preserve the approved maximum;
route the 1,200 m hysteresis treatment through the listed open decision before
choosing how to correct or scope this shared policy.

## Root causes and symptoms

| ID | Kind / severity | Finding and evidence | Mapped symptoms |
|---|---|---|---|
| RC-01 | root cause / major | Mapper compresses tags into bool at `lib/engine/osm/osm_feature_mapper.dart:405-413`; bool cannot distinguish forward/reverse (`road_properties.dart:24-26`), and roundabout clause overrides explicit values. | S-01 (`-1` shown as not one-way in selection, `selection_details.dart:37`); S-02 (explicit roundabout `no` is treated as one-way at same mapper line). |
| RC-02 | root cause / moderate | Equal-weight coordinate mean replaces cumulative path midpoint (`label_candidates.dart:33-42`). | S-03 (unevenly sampled or curved road labels drift from route midpoint/road). |
| RC-03 | root cause / major | UI screen overlay is mounted in `FogoSceneView` as well as `Map2DView` (`fogo_scene_view.dart:237-245`; `map_2d_view.dart:237-245`). | S-04 (2D UI labels float over the 3D scene, including mode transitions; page mounts both at `map_3d_page.dart:269-332`). |
| RC-04 | root cause / major, implementation blocker | Scene object identity is mandatory and doubles as tile/render/pick key (`map_scene.dart:9-21`; `fogo_engine.dart:677-718`; adapter `:155-170,317-329`). There is no non-entity annotation path. | S-05 (sentinel or entity-map omission can corrupt selection; nearest retained annotation hit returns null instead of the base road). |
| RC-05 | root cause / moderate | Engine UVs exist but adapter drops them; current material path is color-only (`mesh_data.dart:45-53`; adapter `:126-154`). | S-06 (atlas-backed decal texture cannot be sampled by uploaded mesh). |
| RC-06 | root cause / moderate | No separate annotation LOD classification; `roadMarking` remains L1/3,500 m (`lod_policy.dart:18-24,38-44`). | S-07 (using existing marking kind exposes annotations beyond approved 1,200 m). |
| RC-07 | root cause / major, adjacent shared-policy defect | Prior-distance hysteresis branch is inconsistent with stable visibility (`lod_policy.dart:53-59`; adapter `flutter_scene_adapter.dart:201-215`); deterministic trace above. | S-08 (node visible at max, hidden on next closer ≥50 m update, visible again at 0.85×max). |
| RC-08 | root cause / minor edge case | Empty `name` wins `name ?? ref` (`road.dart:26`) and is then skipped (`label_candidates.dart:30-32`). | S-09 (non-empty `ref` is not labeled when `name` is empty). |

**Related integration hazard, not a separately reproduced visual failure:**
`TileManager.assign` stores tile ownership by entity ID (`spatial_partitioner.dart:96-115`),
while a road and junction pad can share the road ID (`fogo_engine.dart:172-181,653-665`).
The later owner write can therefore be reused for both meshes by the second
pass (`fogo_engine.dart:677-718`). New annotation batches need explicit tile
ownership independent of entity identity; any broader existing ownership fix
needs a focused regression before Engineering expands scope.

## Minimal correction / integration handoff to ENG-0009

No code correction was made; report-only is mandatory. Recommended minimum,
mapped to ENG-0009:

1. **ENG AC-03 / parser and caller tests:** Add direction state `both` / `forward` /
   `reverse` while keeping bool `true` for either one-way direction. Give
   explicit recognized `yes`, `-1`, `no` precedence over roundabout default;
   missing roundabout means forward. Keep the separate vector `MapRoad` path
   and its existing 2D join/dedup semantics unchanged. Test every matrix row,
   bool meaning, selection display, vector bool callers, and ordered points/
   `nodeRefs` alignment for reverse direction.
2. **ENG AC-02 / label tests:** Replace arithmetic vertex average with an
   interpolated cumulative path-length midpoint. Keep existing collision and
   priority behavior. Test unevenly sampled and curved routes, including
   absent/empty `name` fallback to `ref`, and verify anchor tracking during
   2D pan/zoom without changing the independent road painter.
3. **ENG AC-01/02 / view test:** Remove `LabelOverlay` from `FogoSceneView`,
   retaining its 2D mount in `Map2DView`; remove now-unused 3D candidate
   plumbing if appropriate. Test label presence only in 2D through mode
   transitions; do not change area/POI label policy.
4. **ENG AC-05/06 / no-ID scene transport:** Add a distinct engine-independent
   annotation placement/batch path on `MapScene` with explicit tile ownership
   and no entity ID. Keep `MapSceneObject.entityId` required for cartographic
   selectable objects. Adapter should create render-only nodes without entity
   name, highlight, or pick-map registration; set
   `MeshGeometry.retainCpuData: false` and `Node.raycastable = false`. Test
   annotation raycast-through and base-road picking. Do not use a sentinel or
   make identity silently ambiguous. Include annotation bounds in tile culling.
5. **ENG AC-04/05/07 / engine-adapter contract:** Engine supplies direction,
   geometry/placement, and existing spatial tile association; adapter rasterizes
   text and creates per-tile atlases/materials during scene upload. Forward
   `MeshData.texCoords` into `MeshGeometry.fromArrays`; use textured unlit
   `AlphaMode.blend` materials. Batch arrows/decal quads by tile (not one node
   per mark); skip affected decals if atlas generation fails. Add tests for UV
   upload, material/alpha, atlas failure, tile batching, and no arrows in
   `Map2DScene`. No dependency or palette token is needed.
6. **ENG AC-05 / LOD regression:** Give annotation batches a distinct close-LOD
   classification, maximum 1,200 m; leave `roadMarking` at 3,500 m unless a
   scope decision says otherwise. Add boundary and transition tests before
   reusing shared hysteresis. The existing policy's actual near-boundary
   behavior conflicts with stable visibility; route its correction/scope and
   the annotation distance basis through the open decision rather than
   inventing a metric or hysteresis band.

## Required regressions before validation

- OSM tag matrix: `yes`, `-1`, `no`, absent ordinary way, absent roundabout,
  explicit roundabout `no`, and other values on/off roundabout; assert direction
  plus legacy bool meaning. Verify existing bool consumers and ordered source
  geometry/node-reference integrity.
- Route-length midpoint on unevenly sampled and curved roads; name/ref including
  empty-name fallback; existing area/POI policy unchanged.
- 2D-only `LabelOverlay` through 2D↔3D cross-fade; anchor follows pan/zoom;
  no change to separate 2D road painter.
- Arrow direction (forward/reverse/both), curved tangent, short-way coverage,
  approximate spacing/height/lane offsets after tolerances are decided.
- Per-tile decal/arrow batching, upload-time atlas generation/failure handling,
  UV transfer, unlit alpha blend, and no per-frame atlas work.
- Annotation LOD boundary/transition under the approved distance basis; verify
  existing roadMarking still has 3,500 m policy unless separately approved.
- No annotation entity ID or retained Flutter Scene hit geometry; raycast passes
  through and base road stays selectable; `Map2DScene` gets no arrows.
- `dart format` on scoped Dart files, `flutter analyze`, `flutter test`, and
  available Linux debug build; report exact commands/results or unavailable
  prerequisites.

## Open decisions — preserve as open

1. Tile-edge atlas ownership and atlas failure granularity.
2. Tolerances for approximately 45 m arrow spacing and approximately 0.04 m
   surface offset.
3. Minimum text fit, straightness, and legibility thresholds.
4. 1,200 m annotation LOD distance origin/basis and hysteresis treatment.
5. Whether existing 3,500 m `roadMarking` policy is deliberately unchanged
   while annotation LOD is scoped separately.

No values are selected here. Route any decision that changes approved scope
through Orchestrator/Documentation Director.

## Validation and handoff

- Analysis specialists: `bug-diagnosis-specialist` (one-way callers, labels,
  LOD transition); `static-analysis-specialist` (scene, tile, LOD and adapter
  seams). All inspections were read-only.
- Existing focused test run by label analyst:
  `flutter test test/engine/osm_reader_mapper_test.dart --reporter expanded` —
  passed. This test does not cover label anchors/view mounts or the missing
  oneway matrix rows.
- LOD transition verified by deterministic source-branch evaluation, not by
  runtime test. Scene/UV API options verified against installed
  `flutter_scene 0.24.3` sources.
- No scene raycast, visual, or widget-mount runtime reproduction was performed;
  scene behavior in this report is source-traced, not runtime-validated.
- No formatter, full test suite, analyzer, or Linux build was run: this stage is
  report-only and made no source changes. Engineering/Validation own those
  checks after the gate opens.
- Pre-existing worktree was already extensively modified/deleted/untracked at
  inspection start. No source/test cleanup or edits were made.

**Handoff:** Return this report to the Orchestrator for ENG-0009. Engineering
must not begin analyzed implementation until the report is returned and the
unresolved identity/LOD decisions are routed. Validation remains post-ENG;
Delivery Auditor remains the final verdict owner.
