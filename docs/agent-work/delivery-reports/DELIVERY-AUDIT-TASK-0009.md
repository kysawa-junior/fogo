# Delivery Audit — TASK-0009: Road-Surface Names and Direction Arrows

```yaml
delivery_audit:
  task_id: TASK-0009
  work_packages_reviewed: [CODE-0009, INT-0009, ENG-0009, VAL-0009]
  verdict: APPROVED_WITH_NOTES
  criteria_met:
    - AC-01..AC-08 (all; per-criterion evidence below, independently reproduced by this audit)
  criteria_failed: []
  out_of_scope_changes: []
  test_quality:
    passed: 238
    failed: 0
    missing: []  # 2 skips are GPU-gated with upstream-mirroring reasons, not missing tests
  risks_introduced:
    - "GPU-gated runtime assertions (textured material upload, raycast-through picking, adapter 1200 m transitions, tile-local atlas-failure continuation) are compiled and correct but did not execute on this headless-test host"
    - "Atlas GPU Texture2D lifetime across scene replacement unprofiled"
  debt_introduced:
    - "@visibleForTesting seams in FlutterSceneAdapter (annotationNodes, failNextRoadNameAtlas, isEntityVisible, packRoadNameAtlas) — minimal and test-only"
  documentation_gaps:
    - "README.md screen-overlay label description is stale vs delivered 3D decals; README edits were explicitly out of scope for this task and remain for a future documentation task"
  notes:
    - "Existing shared-LOD hysteresis near-threshold defect (CODE-0009 RC-07) is bypassed, not fixed, by the annotation-only direct 1200 m cutoff — correct scoping per user resolution; defect remains open for existing kinds"
    - "Vector 2D MapRoad bool format cannot represent reverse direction; direction fidelity is 3D-only by design"
    - "Pre-dirty worktree prevents content-level attribution of individual file diffs to this task; path-level and behavior-level verification used instead"
    - "Upload cancellation/generation guard absence and UI-isolate atlas layout are pre-existing adapter characteristics, declared by Validation, not introduced here"
  next_action: forward_to_orchestrator
```

## Status

**APPROVED_WITH_NOTES**

## Requirements Validation

Master Brief `docs/agent-work/briefs/MASTER-BRIEF-TASK-0009.md` consolidated requirements vs delivered source (all read directly by this audit):

| Requirement | Evidence (verified in source/tests this audit) |
|---|---|
| Direction state both/forward/reverse; bool API + true=one-permitted-direction preserved | `lib/engine/domain/road_properties.dart:10-33,48` — `oneway` remains `final bool`, derived `direction != both`; `RoadDirection { both, forward, reverse }`; legacy `oneway:` constructor callers still work |
| Tag matrix yes/-1/no/roundabouts/other | `lib/engine/osm/osm_feature_mapper.dart` `_roadDirection`: `'yes'→forward`, `'-1'→reverse`, `'no'→both`, `null`+roundabout→forward, other/absent→both. Explicit `'no'` case precedes the null-roundabout default, so explicit roundabout `no`=both/false — the approved input-specific correction |
| 2D labels cumulative-length midpoint, UI labels 2D-only | `label_candidates.dart` midpoint; `LabelOverlay` mounted only in `map_2d/map_2d_view.dart:239` — repo-wide grep shows zero other mounts; `FogoSceneView` no longer has a label parameter |
| Per-tile atlas, upload-time, UV, unlit alpha-blend material, failure isolation | `flutter_scene_adapter.dart:215-248`: per-batch try/catch with tile-local failure (arrows + base scene continue), `fromArrays(texCoords:)`, `UnlitMaterial(colorTexture:)..alphaMode = AlphaMode.blend`; atlas built only in `uploadScene`; `updateLOD` only toggles `node.visible` |
| ≤1200 m annotation LOD; roadMarking 3500 m unchanged | `RoadAnnotationBatch.maxCameraDistanceMeters = 1200` (`road_annotations.dart:38`); direct `cameraDistance <= 1200` visibility (`flutter_scene_adapter.dart:320-323`) scoped to `_annotationNodes` only; `LodPolicy` verified unchanged (roadMarking L1/3500, asserted in tests) — matches user-resolved decision |
| No entityId / no retained CPU hit geometry / raycasts pass through | `RoadAnnotationBatch` deliberately has no entity field; adapter nodes: `retainCpuData: false` + `raycastable = false` + no `_entityByNode` registration; `pickEntity` (:629-637) unchanged, still entity-map lookup |
| Tile = geometry-center owner, complete bounds | `fogo_engine.dart:706-716`: every decal/arrow assigned via `tiles.tileOfPoint(center)`; batch bounds union full placement+arrow bounds (`:688-690`) — matches user-resolved decision |
| Span selection longest/least-curved, no fixed angle threshold | `road_annotation_builder.dart:141-158`: score = `chordLength² / arcLength`, tie-break longer chord, comment states "no angle cutoff" |
| Arrows ~45 m, ~0.04 m lift, quarter-width lanes | `arrowSpacingMeters = 45`, `surfaceLiftMeters = 0.04` (:32-33); `FogoPalette.crossing` reused, no new token (map_scene.dart diff contains zero palette additions) |
| Map2DScene annotation-free | `fogo_engine.dart:806`: `map2d: Map2DScene(strokes: strokes2d, fills: fills2d)` only |
| Name-then-ref with blank handling | `road.dart:26-30`: trims; blank name falls back to non-blank `ref` |
| No new package | `pubspec.yaml` diff touches only asset manifest comments/paths (pre-existing dirty state); no dependency lines |

Out-of-scope check: vector 2D road path (`features.dart`, `road_join.dart`, `road_deduplication.dart`) has zero entries in `git status` — untouched, as required. README diff contains no annotation-related lines. Spec commit `1e26dd6` is HEAD; spec file unchanged.

## Engineering Validation

- CODE-0009 gate honored: report exists (`reviews/CODE-0009-road-surface-root-cause.md`), Engineering's implementation follows its correction handoff items 1–6 (direction enum + matrix, midpoint, 3D overlay removal, no-ID `MapScene.annotations` path with `tileOfPoint` ownership + `retainCpuData:false`/`raycastable:false`, UV/atlas adapter seam, separate 1200 m annotation LOD). No sentinel entityId used.
- Architecture boundary respected: engine owns parsing/placement/batching; adapter owns `packRoadNameAtlas`/TextPainter rasterization, `Picture.toImage`/`Texture2D` GPU tail, materials, upload.
- RC-07 (shared hysteresis transition defect) correctly *not* touched: annotation path avoids shared `LodPolicy.isLevelVisible` entirely; existing roadMarking behavior unchanged. Defect remains open — noted, out of scope.
- No per-frame atlas work (upload path only); no scene node per mark (one node per tile batch, parented under tile groups).

## Design Validation

Approved spec `docs/superpowers/specs/2026-10-26-road-surface-annotations-design.md` (commit 1e26dd6) is the sole visual source; no Design WP was assigned and none needed. All spec clauses implemented as written: 2D-only `LabelOverlay`, route-length midpoint, tangent-aligned atlas-backed decals with fit-or-omit, unlit alpha-blend crossing-colored text, arrows every ~45 m with short-way minimum, opposing quarter-width lanes, ~0.04 m lift, 1200 m close-LOD, tile batching, non-intercepting raycasts, no new dependency/palette token. Declared spec limitations (foreshortening, no label on insufficiently straight roads) remain declared.

## Test Evidence

Independently reproduced by this audit (not trusted from reports):

| Check | Command | Result |
|---|---|---|
| Analyzer | `flutter analyze` | exit 0, `No issues found! (ran in 3.1s)` |
| Full suite | `flutter test` | exit 0, **238 passed, 2 skipped**, `All tests passed!` — matches revalidation exactly |
| Focused gated files | `flutter test test/road_annotation_adapter_integration_test.dart test/map_views_label_mount_test.dart` | 2D mount test **passes on host**; 3D pump + adapter integration skipped with `No Impeller GPU context` |
| Scoped formatter | `dart format --output=none --set-exit-if-changed` (all 23 listed files, run in two batches) | **0 changed, exit 0** — no-write mode, worktree preserved |
| Linux build | `flutter build linux --debug` | exit 0, `✓ Built build/linux/x64/debug/bundle/fogo` |

GPU-gate legitimacy verified against upstream: both project files use the identical probe (`fscene.Scene()` constructor try/catch) and the identical skip reason string as `flutter_scene 0.24.3`'s own `test/raycast_test.dart:323` / `test/support/gpu_available.dart`. The skips mirror upstream's own testability boundary, not evasion. CPU-verifiable counterparts (packing, UV vertex order, fit/omit, bounds, constants, engine tile ownership, 2D-scene exclusion, direction matrix, arrow geometry) all execute and pass.

## Per-criterion evidence map

- **AC-01 PASS** — `road_annotation_adapter_test.dart` (CPU: fit-or-omission alone+mixed, quad↔UV exact vertex order, 0.04 m, bounds containment) passed this audit; span selection source-verified (`chordLength²/arcLength`); not-a-screen-overlay enforced at compile time (no `LabelOverlay` in `FogoSceneView`). Material/texturing runtime assert is GPU-gated (declared).
- **AC-02 PASS** — `road_label_candidates_test.dart` midpoint-not-mean passed; `map_views_label_mount_test.dart` Map2DView mount passed this audit; `FogoSceneView` label parameter deleted; vector 2D road painter files untouched (zero git-status entries).
- **AC-03 PASS** — `road_direction_test.dart` 10 tests (8-case matrix + ordered refs + direction-aware dedup) pass; mapper switch + bool derivation source-verified above; `RoadProperties.oneway` API intact.
- **AC-04 PASS** — `road_annotations_test.dart`: forward/reverse, opposing quarter-width lanes, exact 45 m stations on 100 m path, short-way minimum, curved tangent, 0.04 m lift.
- **AC-05 PASS** — `road_annotations_test.dart`: `tileOfPoint(center)` ownership via real `SpatialPartitioner`+`TileManager`, batch/tile bounds enclose complete placement/arrow bounds; `road_annotation_adapter_test.dart`: 1200 m constant + roadMarking 3500 m asserted in same test; upload-time atlas source-verified. Adapter-level transition behavior GPU-gated (declared).
- **AC-06 PASS** — `road_annotations_test.dart`: `Map2DScene` leak-proof stroke count with explicit reason; source: `retainCpuData:false`, `raycastable:false`, no entity registration, `pickEntity` unchanged; `Map2DScene` built from 2D strokes/fills only. Runtime raycast-through-to-`way/1` assert GPU-gated (declared).
- **AC-07 PASS** — every category VAL round 1 flagged missing now exists: atlas/UV (CPU), atlas-failure isolation (GPU-gated seam), 2D-only mount, center tile ownership, direct 1200 m vs shared 3500 m, no-arrows 2D scene, raycast-through. Coverage delta 235→238 passed +2 gated accounted for exactly.
- **AC-08 PASS** — reproduced in full above.

## Documentation Validation

- Master Brief, WPs, INT contract, CODE report, VAL reports, handoff: complete, mutually consistent, and consistent with delivered source (checked line-level where load-bearing).
- Worktree preservation verified: 176 porcelain entries (61 untracked / 61 deleted / 55 modified), **nothing staged** (`git diff --cached` empty via byte-level check; one phantom `wc -l` off-by-one chased to closure, same artifact revalidation documented), no resets; audit's own runs (analyze/test/build/no-write format) changed zero tracked files.
- Honest limitations: GPU-gated skips, no screenshot (KWin absent, X capture fails — revalidated), no perf/memory/coverage instrumentation, smoke run confirms renderer startup only. All declared, none inflated into pass claims.
- Gap (out of scope, correctly untouched): `README.md:78-80` still describes labels as screen overlays. README is protected/read-only for this task; stale-doc conflict was correctly surfaced through the Master Brief rather than silently edited. Needs a future documentation task.

## Deviations

- **None within scope.** All five CODE-0009 open decisions were resolved by the user exactly as recorded (1200 m direct OrbitCamera-distance cutoff scoped to annotations; center-tile ownership with complete bounds and per-tile failure isolation; longest/least-curved span with fit/omission and no fixed angle threshold; ~45 m / ~0.04 m as specified) — implementation matches each resolution.
- Roundabout explicit-`no` → both/false changes the old mapper result: intentional, user-approved, Master-Brief-authorized correction, correctly documented and tested as such (not hidden as compatibility).
- Cannot attribute individual diffs inside pre-dirty files (pubspec, README, map_scene.dart) to this task absent a clean baseline — inherited limitation, declared by Validation; path-level scope check plus content inspection of those diffs shows no TASK-0009 leakage.

## Risks

1. Four runtime behaviors (textured decal upload, raycast-through picking, adapter 1200 m transitions, atlas-failure continuation at runtime) are source-verified and compiled but unexecuted on this host. Mitigation exists: tests ship and will execute on any GPU/CI host; upstream ships the same gate for the same APIs.
2. GPU `Texture2D` lifetime across scene replacement unprofiled (declared).
3. Pre-existing (not introduced): `uploadScene` lacks a cancellation/generation guard; per-tile TextPainter layout runs synchronously on the UI isolate during upload with inter-batch yields. Both declared by Validation; monitor, do not block.
4. Residual shared-LOD hysteresis near-threshold defect (RC-07) remains for existing kinds — annotation-only direct cutoff was the correct minimal scope; defect needs its own evidence-based fix later.

## Required Revisions

None. Delivery meets the Master Brief, the approved spec, and AC-01..AC-08 with complete, reproducible evidence.

## Final Recommendation

**APPROVED_WITH_NOTES** — forward to `instrum-orchestrator` for user delivery. Notes for the record: (1) GPU-gated assertions await any GPU host/CI run; (2) README label-overlay staleness needs a follow-up documentation task; (3) RC-07 hysteresis and adapter upload-race/perf items remain open pre-existing debt, already documented in CODE-0009/VAL-0009. No further Engineering loop required for TASK-0009.
