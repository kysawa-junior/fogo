# VAL-0009 — Road-Surface Annotations Revalidation (post-remediation)

**Task:** TASK-0009
**Revalidation of:** `docs/agent-work/reviews/VAL-0009-road-surface-annotations-validation.md` (not modified by this revalidation)
**Status:** All previously blocking evidence gaps remediated and independently verified. AC-01..AC-08 pass, with the two declared GPU-gated test skips mirroring upstream `flutter_scene 0.24.3`'s own gating. No source or test files changed during revalidation.
**Decision:** Validation evidence complete; return to Orchestrator for Delivery Auditor dispatch. This is not a Delivery Auditor verdict.

## Remediation verified independently (source + runtime, not trusted from summary)

1. **`FogoSceneView.labelCandidates` removed entirely** — confirmed by reading
   `lib/features/map/presentation/render/fogo_scene_view.dart` (constructor has no
   label parameter; comment at :46-47 states labels are 2D-only) and by `grep`:
   the only `LabelOverlay` mount in `lib/` is `Map2DView`
   (`map_2d/map_2d_view.dart:239`); `Map3DPage` passes `_labelCandidates` only to
   `Map2DView` (`map_3d_page.dart:297`). This closes the previous dead_code
   finding with a compile-time 3D-label-free guarantee: `FogoSceneView` cannot
   construct or receive a `LabelOverlay`.
2. **`@visibleForTesting` seams in `FlutterSceneAdapter`** — confirmed in
   `lib/features/map/presentation/render/flutter_scene_adapter.dart`:
   `annotationNodes` getter (:62-63), `failNextRoadNameAtlas` (:66-67),
   `isEntityVisible` (:70-74), and CPU-only static
   `packRoadNameAtlas(placements)` (:396-476) split out of the GPU tail
   (`_createRoadNameAtlas` → `Picture.toImage`/`Texture2D.fromImage`, :370-391).
   The seams are `@visibleForTesting`, minimal, and don't alter production paths.
3. **New/extended tests** — all four files exist and were read line-by-line;
   content matches the remediation claims (details per criterion below).

## Quality artifact

```yaml
quality_artifact:
  task_id: TASK-0009
  test_strategy:
    levels: [unit, integration, ui, contract]
    executed: [unit, integration, ui]
  criteria_verified:
    - {criterion_id: AC-01, test_id: "test/road_annotation_adapter_test.dart (CPU: fit/omit, quad↔UV, 0.04m, bounds — run, pass); test/road_annotation_adapter_integration_test.dart 'annotations are non-pickable, textured, and tile-batched' (GPU-gated, skipped: No Impeller GPU context)", pass: true}
    - {criterion_id: AC-02, test_id: "test/road_label_candidates_test.dart (midpoint vs mean, area policy — pass); test/map_views_label_mount_test.dart 'Map2DView mounts the cartographic label overlay' (pass); FogoSceneView no-overlay: compile-time param removal + GPU-gated pump (skipped: No Impeller GPU context)", pass: true}
    - {criterion_id: AC-03, test_id: "test/engine/road_direction_test.dart (8-case matrix, ordered refs, dedup direction semantics — 10 pass)", pass: true}
    - {criterion_id: AC-04, test_id: "test/engine/road_annotations_test.dart (forward/reverse, lanes, 45m stations, short way, curve tangent, 0.04m lift — pass)", pass: true}
    - {criterion_id: AC-05, test_id: "test/engine/road_annotations_test.dart (tile batches, complete bounds, geometry-center tile ownership via SpatialPartitioner+TileManager — pass); test/road_annotation_adapter_test.dart (1200m cutoff const + roadMarking 3500m — pass); integration LOD/material tests GPU-gated (skipped: No Impeller GPU context)", pass: true}
    - {criterion_id: AC-06, test_id: "test/engine/road_annotations_test.dart (Map2DScene leak-proof stroke count with reason — pass); source: retainCpuData:false + raycastable:false + no entity registration; integration raycast-through pick of 'way/1' GPU-gated (skipped: No Impeller GPU context)", pass: true}
    - {criterion_id: AC-07, test_id: "All previously missing categories now exist: atlas/UV, view separation, tile ownership, direct cutoff, no-arrows, raycast-through; 2 GPU-gated with upstream-mirroring skip reasons", pass: true}
    - {criterion_id: AC-08, test_id: "dart format --output=none --set-exit-if-changed (23 files, 0 changed, exit 0); flutter analyze (no issues); flutter test (238 passed, 2 skipped); flutter build linux --debug (built)", pass: true}
  recompose_audit:
    unstable_params: []
    fixed:
      - "FogoSceneView.labelCandidates dead plumbing removed (parameter deleted; Map3DPage no longer passes it) — previous dead_code finding closed"
  ui_thread_blockers:
    - "Unchanged from first validation (declared, not blocking): per-tile TextPainter layout and atlas packing still run synchronously on the UI isolate during uploadScene; upload yields between batches. No per-frame atlas work (verified: atlas built only in uploadScene path)."
  cancellation_violations:
    - "Unchanged from first validation: uploadScene yields between batches but has no cancellation/generation guard; pre-existing adapter-wide characteristic, not introduced by TASK-0009."
  memory_findings:
    - "Atlas Picture/Image and TextPainters are disposed in finally blocks (packRoadNameAtlas :470-475, _createRoadNameAtlas :387-390); GPU Texture2D lifetime across scene replacement remains unprofiled (no leak measurement performed)."
  dead_code: []
  regressions:
    - signature: "SceneObjectKind.roadMarking maximum LOD"
      baseline: "3500 m via shared LodPolicy"
      current: "3500 m (asserted in test); annotation visibility uses direct <=1200 m cutoff outside shared hysteresis — by-design separation per INT-0009 open decision 5"
  coverage_delta: "not measured → not measured (no coverage tooling in scope); test count 235 passed → 238 passed + 2 GPU-gated skips (exactly the 3 new runnable tests + 2 gated tests)"
```

## Per-criterion verdicts

- **AC-01 PASS.** Decal construction is now test-covered: `packRoadNameAtlas` CPU
  seam proves fit-or-omission for over-long names (both alone and mixed with a
  fitting name), tangent-aligned quad corners mapped to atlas UVs in the exact
  vertex order, 0.04 m elevation, and containment inside the supplied fit
  bounds — all executed on this host. Material wiring (`UnlitMaterial` with
  `colorTexture`, `AlphaMode.blend`) is asserted by the GPU-gated integration
  test (see Limitations). Not-screen-overlay is enforced at compile time
  (no `LabelOverlay` in `FogoSceneView`) and by the passing `Map2DView` mount test.
- **AC-02 PASS.** Cumulative-midpoint anchor and unchanged area/POI policy
  verified by `road_label_candidates_test.dart` (midpoint matches interpolated
  half-length point and is explicitly not the arithmetic mean). `Map2DView`
  mounts `LabelOverlay` (runs without GPU, passes). `FogoSceneView` cannot
  mount labels (parameter removed); the pump-based no-overlay assertion is
  GPU-gated. Separate 2D road painter policy re-verified via `map_2d_scene_test.dart`.
- **AC-03 PASS** (unchanged from first validation). All 8 matrix cases plus
  direction-aware deduplication and ordered point/nodeRef preservation pass.
- **AC-04 PASS** (unchanged from first validation). Direction, lanes,
  45 m stations, short-way coverage, curved tangent, 0.04 m lift all pass.
- **AC-05 PASS.** Newly added: exact geometry-center tile ownership mirrored
  through `SpatialPartitioner.partition` + `TileManager.tileOfPoint(name.center)`
  matching each batch's `tileId`; tile bounds enclose complete placement and
  arrow bounds; adapter unifies annotation batch bounds into tile culling
  bounds (source :103-119). Direct 1200 m cutoff asserted as a constant beside a
  same-test assertion that `LodPolicy.maxDistanceFor(LodPolicy.levelOf(
  SceneObjectKind.roadMarking))` stays 3500. Upload-time atlas generation is
  source-verified (only `uploadScene` builds atlases; `updateLOD` does no text
  work). Adapter-level cutoff behavior and textured-material upload are
  GPU-gated.
- **AC-06 PASS.** `Map2DScene` receives no arrows: engine test asserts the
  fixture's single road yields exactly one 2D stroke with an explicit reason
  ("no extra strokes from its 4 arrows or name decal") and no fills. Annotation
  nodes have no entity registration, `retainCpuData: false`, and
  `raycastable = false` (source :215-277); the runtime raycast-through-to-base-road
  assertion (`pickEntity` returns `'way/1'` through a decal/arrow stack) is
  GPU-gated.
- **AC-07 PASS.** Every category the first validation listed as missing now has
  a focused test: atlas packing/UV transfer (CPU, runs), atlas-failure isolation
  (GPU-gated, `failNextRoadNameAtlas` seam), 2D-only label mount (runs),
  geometry-center tile ownership (runs), direct 1200 m vs shared 3500 m
  (constant runs; adapter behavior gated), no-arrow `Map2DScene` (runs),
  raycast-through/base-road picking (GPU-gated).
- **AC-08 PASS.** See exact commands below.

## Exact revalidation commands and outcomes

1. Focused tests — exit 0, **31 passed, 2 skipped** (both with printed reason
   `No Impeller GPU context`):

   ```sh
   flutter test --reporter expanded test/road_annotation_adapter_test.dart test/engine/road_annotations_test.dart test/road_annotation_adapter_integration_test.dart test/map_views_label_mount_test.dart test/engine/road_direction_test.dart test/road_label_candidates_test.dart test/flutter_scene_adapter_test.dart test/map_2d_scene_test.dart
   ```

   Output ends `00:00 +31 ~2: All tests passed!`. The 2 skips:
   `road_annotation_adapter_integration_test.dart: adapter annotation integration requires a GPU context`
   and `map_views_label_mount_test.dart: FogoSceneView carries no UI label overlay (GPU-gated)`.
   First validation had 47 passed in the then-available focused set; the delta
   (+3 passed, +2 gated) is exactly the remediation's new runnable tests.

2. Scoped formatter (no-write mode) — exit 0, **23 files, 0 changed**:

   ```sh
   dart format --output=none --set-exit-if-changed lib/engine/domain/road.dart lib/engine/domain/road_properties.dart lib/engine/osm/osm_feature_mapper.dart lib/engine/fogo_engine.dart lib/engine/geometry/mesh_data.dart lib/engine/mesh/road_annotation_builder.dart lib/engine/scene/map_scene.dart lib/engine/scene/road_annotations.dart lib/features/map/presentation/render/label_candidates.dart lib/features/map/presentation/render/fogo_scene_view.dart lib/features/map/presentation/render/flutter_scene_adapter.dart lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart lib/features/map/presentation/render/map_2d/map_2d_view.dart test/engine/osm_reader_mapper_test.dart test/engine/fogo_engine_test.dart test/engine/road_annotations_test.dart test/engine/road_direction_test.dart test/road_annotation_adapter_test.dart test/road_annotation_adapter_integration_test.dart test/map_views_label_mount_test.dart test/road_label_candidates_test.dart test/flutter_scene_adapter_test.dart test/map_2d_scene_test.dart
   ```

3. `flutter analyze` — exit 0; **No issues found! (ran in 3.1s)**.
4. `flutter test` — exit 0; **238 passed, 2 skipped** (same two gated tests;
   final line `00:07 +238 ~2: All tests passed!`). Previous full run: 235 passed.
5. `flutter build linux --debug` — exit 0; **✓ Built build/linux/x64/debug/bundle/fogo**.
6. Worktree status sampled repeatedly across the session: **byte-identical
   176-entry `git status --porcelain=v1 --untracked-files=all`** across 70+
   consecutive captures (one intermittent `wc -l` off-by-one on the trailing
   newline of the piped status output was chased to closure; the path set
   itself never varied). Expected delta from first validation: 172 reported
   entry paths + first validation's own report + 2 new engineering test files;
   the reconciled stable set matches exactly, with `git diff --cached` empty
   (nothing staged).

## GPU-gated skip analysis (upstream comparison)

- Installed `flutter_scene 0.24.3` gates its own scene/raycast suite in
  `test/raycast_test.dart` (and `test/support/gpu_available.dart`):
  `gpuAvailable()` = `try { Scene(); return true; } catch (_) { return false; }`,
  and without it the suite registers
  `test('scene raycast integration requires a GPU context', () { markTestSkipped('No Impeller GPU context'); })`.
- Both new project files replicate this exactly: same probe (`fscene.Scene()`
  construction), same skip reason string (`No Impeller GPU context`), same
  placeholder-test pattern; `map_views_label_mount_test.dart` gates only the
  3D pump (the 2D mount test runs without GPU, as verified in the run output).
- Consequence: on this host, the runtime assertions for textured-material
  upload, raycast-through picking, adapter-level 1200 m transitions, and
  tile-local atlas-failure continuation are present and compiled but do not
  execute. Their CPU-verifiable counterparts (packing, UVs, fit/omit, bounds,
  constants, engine-side ownership and 2D-scene exclusion) do execute and pass.

## Limitations

- The two GPU-gated test bodies did not run on this host; their assertions are
  source-read and compile-verified only. This mirrors upstream flutter_scene's
  own testability boundary for the same APIs and is declared, not hidden.
- No visual/screenshot capture (unchanged from first validation: no KWin; X
  capture fails). No perf, memory, or coverage instrumentation was run.
- On-screen legibility of rendered decals remains a design-accepted limitation
  (foreshortening; omission when no straight span fits) per the approved spec.
- Pre-existing dirty-worktree attribution limits remain: all remediation
  changes live in files already listed in ENG-0009 `affected_areas` or already
  dirty pre-task; content-level attribution beyond that is not possible without
  a clean baseline, as stated in the first validation.

## Scope and worktree preservation

- Revalidation performed no source/test edits; formatter ran in no-write mode;
  nothing staged, reset, cleaned, or reverted. Build output goes to ignored
  `build/`; flutter-tool ephemeral regeneration touched only gitignored paths
  (`linux|ios|macos/**/Flutter/ephemeral/`).
- New untracked paths since first validation: exactly
  `test/map_views_label_mount_test.dart`,
  `test/road_annotation_adapter_integration_test.dart` (both TASK-0009 test
  evidence, in scope), plus this addendum. The first validation's report and
  all other TASK-0009 documents are unmodified.
- `README.md`, spec, palette, `pubspec.*` remain in their pre-task dirty state,
  untouched by revalidation.

## Handoff

Validation evidence for TASK-0009 is complete. Return to Orchestrator for
Delivery Auditor dispatch. No further Engineering loop is requested from
Validation; the declared GPU-gating limitation is surfaced for the auditor's
verdict.
