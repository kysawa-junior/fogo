# VAL-0009 — Road-Surface Annotations Validation

**Task:** TASK-0009  
**Status:** Validation executed; criteria remain blocked by missing focused adapter, view, LOD-integration, and picking tests. No source or test files changed during validation.  
**Decision:** Return implementation to Engineering for test evidence. This is not a Delivery Auditor verdict.

## Quality artifact

```yaml
quality_artifact:
  task_id: TASK-0009
  test_strategy:
    levels: [unit, integration, ui, contract]
    executed: [unit, integration]
    gaps: [ui, adapter-contract]
  criteria_verified:
    - criterion_id: AC-01
      test_id: "MISSING: Flutter Scene atlas/UV/material and close-3D decal runtime test; source inspected"
      pass: false
    - criterion_id: AC-02
      test_id: "test/road_label_candidates_test.dart::road label uses cumulative midpoint (passes); no 2D/3D widget-mount test"
      pass: false
    - criterion_id: AC-03
      test_id: "test/engine/road_direction_test.dart::OSM road direction mapping cases (8 pass)"
      pass: true
    - criterion_id: AC-04
      test_id: "test/engine/road_annotations_test.dart::forward/reverse, lanes, 45m stations, short route, curve tangent, 0.04m lift (pass)"
      pass: true
    - criterion_id: AC-05
      test_id: "test/engine/road_annotations_test.dart::FogoEngine assigns explicit tile batches and complete bounds (pass); no atlas/UV/failure or direct-cutoff integration test"
      pass: false
    - criterion_id: AC-06
      test_id: "MISSING: annotation raycast-through/base-road picking and Map2DScene-no-arrows tests; source inspected"
      pass: false
    - criterion_id: AC-07
      test_id: "Focused test suite passes, but required atlas/UV, view-separation, direct LOD, and picking cases are absent"
      pass: false
    - criterion_id: AC-08
      test_id: "dart format check, flutter analyze, flutter test, flutter build linux --debug (all pass)"
      pass: true
  recompose_audit:
    unstable_params: []
    fixed: []
  ui_thread_blockers:
    - "Potential, unprofiled: per-tile TextPainter layout, atlas packing, and decal-mesh construction run synchronously on the UI isolate before asynchronous image conversion."
  cancellation_violations:
    - "Potential upload race, not reproduced: uploadScene has async yields but no cancellation/generation guard; an older upload can resume after a newer upload resets adapter scene/maps."
  memory_findings:
    - "No leak measurement performed. Atlas Picture, Image, and TextPainters are disposed in finally; GPU Texture2D lifetime across scene replacement is not evidenced by tests/runtime profiling."
  dead_code:
    - "FogoSceneView.labelCandidates remains accepted and passed by Map3dPage but is not read after the 3D overlay removal; appears to be compatibility plumbing."
  regressions:
    - signature: "SceneObjectKind.roadMarking maximum LOD"
      baseline: "3500 m via shared LodPolicy"
      current: "3500 m; annotation visibility separately uses direct <=1200 m cutoff"
  coverage_delta: "not measured → not measured (no coverage report/baseline; 235 tests pass)"
```

## Resolved decisions and source evidence

- **Direction and legacy bool:** `RoadProperties.oneway` remains; `true` is derived for both `forward` and `reverse`. Mapper explicitly handles `yes`, `-1`, `no`, and missing roundabout tags. `road_direction_test.dart` covers all eight matrix cases, including explicit roundabout `no=false`, other values, and preserved point/node-ref order. All pass. This is the intentional input-specific correction from the old blanket roundabout mapping.
- **Arrow geometry:** `road_annotations_test.dart` verifies ordered-way forward/reverse direction, opposing quarter-width lanes, exact 45 m station spacing on a 100 m path, one arrow per direction on a short way, curved local tangent, and 0.04 m lift. All pass.
- **2D anchor/name fallback:** `road_label_candidates_test.dart` verifies cumulative-distance midpoint against uneven sampling and unchanged area label policy. `Road.name` falls back from blank name to nonblank `ref`; annotation builder tests cover that. No widget test verifies the overlay is mounted only in `Map2DView`.
- **Decal span/fit:** `RoadAnnotationBuilder` evaluates contiguous spans using `chordLength² / arcLength`, then samples the winning span midpoint and tangent; there is no fixed angle threshold. Adapter omits text when its computed world width exceeds the supplied span. This is source evidence only: no test exercises a curved/competing span choice, legibility/omission, or rendered orientation.
- **Tile/bounds:** `FogoEngine` assigns each decal through `tileOfPoint(name.center)` and unions full placement/arrow bounds into batch and tile culling bounds. `road_annotations_test.dart` checks valid tile batches and that tile/batch bounds enclose complete placement/arrow bounds. It does not directly assert center-to-tile ownership.
- **Atlas/failure:** Adapter source creates a per-tile atlas during `uploadScene`, forwards decal UVs to `MeshGeometry.fromArrays`, uses `UnlitMaterial(colorTexture: ...)` with alpha blending, and catches atlas failure per tile while continuing arrow/base-scene upload. No runnable test exercises UV/material upload or injected atlas failure.
- **LOD:** `FogoSceneView` passes `OrbitCamera.distanceMeters` to `updateLOD`; annotation nodes use direct `cameraDistance <= 1200` visibility, outside shared hysteresis. Shared `LodPolicy` retains roadMarking at 3500 m. `road_annotation_adapter_test.dart` checks constants only; no test exercises cutoff transitions at 1200 m through the adapter.
- **Picking/2D:** Adapter source creates annotation nodes without entity registration and sets `retainCpuData: false` and `raycastable = false`. Engine sends only strokes/fills to `Map2DScene`. No test proves annotations pass raycasts through to a selectable road or asserts no arrows enter the 2D scene.

## Exact validation commands and results

1. Focused tests — exit 0, **47 passed**:

   ```sh
   flutter test --reporter expanded test/engine/road_direction_test.dart test/engine/road_annotations_test.dart test/road_label_candidates_test.dart test/road_annotation_adapter_test.dart test/flutter_scene_adapter_test.dart test/map_mode_test.dart test/map_2d_scene_test.dart test/engine/osm_reader_mapper_test.dart
   ```

   These run available parser, geometry, midpoint, mode/2D, LOD-constant, and existing mapper tests. The named atlas/UV, view-mount, and picking tests do not exist; they were not inferred from this green run.

2. Scoped formatter — exit 0, **18 files, 0 changed**. Used no-write mode to preserve dirty worktree:

   ```sh
   dart format --output=none --set-exit-if-changed lib/engine/domain/road.dart lib/engine/domain/road_properties.dart lib/engine/osm/osm_feature_mapper.dart lib/engine/fogo_engine.dart lib/engine/geometry/mesh_data.dart lib/engine/mesh/road_annotation_builder.dart lib/engine/scene/map_scene.dart lib/engine/scene/road_annotations.dart lib/features/map/presentation/render/label_candidates.dart lib/features/map/presentation/render/fogo_scene_view.dart lib/features/map/presentation/render/flutter_scene_adapter.dart test/engine/osm_reader_mapper_test.dart test/engine/fogo_engine_test.dart test/engine/road_annotations_test.dart test/engine/road_direction_test.dart test/road_annotation_adapter_test.dart test/road_label_candidates_test.dart test/flutter_scene_adapter_test.dart
   ```

3. `flutter analyze` — exit 0; **No issues found**.
4. `flutter test` — exit 0; **235 tests passed**.
5. `flutter build linux --debug` — exit 0; built `build/linux/x64/debug/bundle/fogo`.
6. `flutter doctor -v` — Linux toolchain available; Android cmdline-tools/licenses and Chrome unavailable (not needed for Linux build).

## Runtime/GPU evidence and limitations

- Host reports AMD Radeon Graphics (Mesa `radeonsi`), accelerated OpenGL 4.6 and Vulkan RADV; `flutter doctor -v` marks Linux toolchain ready.
- Launched built Linux app for a smoke check. Runtime log explicitly reports: `Using the Impeller rendering backend (OpenGLESSDF)`. Flutter Scene initialized and reported its depth configuration; app was manually terminated after the short smoke run. This confirms renderer startup, **not** visual annotation correctness.
- Screenshot capture unavailable: Spectacle reports that KWin is absent; `xwd -root -display :0` fails with X `BadMatch`. No close-3D/2D visual comparison or on-screen picking test was captured.
- No performance/frame-time, memory, stress/concurrent-upload, or coverage instrumentation was run. There is no Compose UI in this Flutter project; Flutter rebuild/recomposition profiling was not performed.

### Performance observations

- Road-name span selection evaluates all point pairs (`start`/`end` nested loops), O(n²) per named road. Engine construction runs through the map-load isolate, so this is load-time CPU cost rather than direct UI-thread work. No large-way benchmark was run; track only if import latency becomes material.
- Atlas text layout/packing remains synchronous per tile on the UI isolate, as noted above. The adapter yields between tile batches, but no per-tile frame-time bound is measured.

## Scope and worktree preservation

- At validation entry, `git status --porcelain=v1 --untracked-files=all` showed **172 existing dirty/untracked paths**. Formatting used no-write mode. No source/test was edited, staged, reset, cleaned, or reverted; the Linux build output is generated under `build/`.
- TASK-0009 implementation evidence inspected shows no new dependency or palette token; arrows/decal text reuse `FogoPalette.crossing`. The separate vector `MapRoad` model is not modified. Annotation data is carried on `MapScene`, not added to `Map2DScene`; annotation LOD is separate from shared `LodPolicy`.
- `README.md`, `pubspec.yaml`/`pubspec.lock`, palette files, `Map2DScene`, shared LOD files, and many unrelated paths were already dirty/untracked at validation entry. Their current uncommitted state prevents reliable attribution to the implementation agent; this validator did not edit them. Approved 2026-10-26 design spec is unchanged. README still contains stale screen-overlay description; it remains read-only under the brief.
- This report is the only repository file created by VAL-0009; runtime/screenshot logs were kept under `/tmp/opencode/val0009*`.

## Blocking evidence gaps / handoff

Return to Engineering for runnable tests covering: decal UV/material and atlas-failure isolation; 2D-only label mount; exact geometry-center tile ownership; direct 1200 m adapter visibility with shared roadMarking remaining 3500 m; no-arrow `Map2DScene`; and annotation raycast-through/base-road picking. Add curved-span selection/fit coverage if it is part of the required evidence. Then rerun affected tests and the formatter/analyze/full-test/build checks. No implementation change was made by Validation.
