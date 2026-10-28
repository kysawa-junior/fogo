---
id: VAL-0009
version: "1"
status: approved
source:
  user_request: "TASK-0009"
  orchestrator_task_id: TASK-0009
objective: "Validate TASK-0009 road annotation behavior and provide reproducible test, analysis, format, and Linux debug-build evidence."
background: "The approved design and CODE-0009/INT-0009 handoff require coverage for bool compatibility, explicit roundabout no, 2D anchors, 3D arrows/decals, adapter UV upload, LOD, and non-intercepting selection, plus Dart/Flutter validation. Existing local worktree content must be preserved."
scope:
  included:
    - "Validate ENG-0009 against AC-01 through AC-08 and the approved design spec."
    - "Run focused parser, label-anchor, arrow-geometry, atlas/UV, view-separation, LOD, and raycast/picking tests."
    - "Run formatter, flutter analyze, flutter test, and Linux debug build where prerequisites are available."
    - "Record exact commands, outputs, pass/fail status, limitations, and evidence for Delivery Auditor."
    - "Verify validation did not reset, remove, or overwrite unrelated pre-existing worktree content."
  excluded:
    - "Implement or modify feature code; return failures to Engineering with evidence."
    - "Broaden scope into unrelated dirty files, general cleanup, data regeneration, or whole-repository reformatting."
    - "Issue final delivery approval; Delivery Auditor owns the verdict."
requirements:
  functional:
    - "Confirm tag→direction→bool matrix: yes=forward/true; -1=reverse/true; no=both/false; missing roundabout=forward/true; explicit roundabout no=both/false; other/absent=both/false."
    - "Confirm RoadProperties.oneway API remains and true means one permitted direction; explicitly record roundabout-no false as intentional correction of old blanket-roundabout true result."
    - "Confirm code changes follow returned CODE-0009 correction/integration handoff; report any divergence instead of silently accepting it."
    - "Confirm 2D road labels use cumulative path-length midpoint and UI labels are not mounted in 3D."
    - "Confirm arrows follow direction and curvature, meet spacing/short-way rules, use separate bidirectional lanes, and sit at approved height."
    - "Confirm decals use atlas UV/material upload, per-tile batching, graceful atlas failure, and 1,200 m maximum camera distance."
    - "Confirm Map2DScene contains no arrows and annotations do not intercept raycasts or change base-road pickability."
  non_functional:
    - "Use narrowly scoped test/formatter commands; do not modify unrelated pre-existing worktree content during validation."
    - "Report unavailable Linux/build prerequisites explicitly; do not claim an unrun check passed."
constraints:
  technical:
    - "Validate only approved TASK-0009 behavior and ENG-0009 using repository tests."
    - "Run dart format only for feature-touched Dart files; avoid whole-repository formatting because worktree contains prior edits."
    - "Expected checks include flutter analyze, flutter test, and flutter build linux --debug; report actual availability and exit status."
  architectural:
    - "Do not implement or change feature architecture during validation."
    - "Preserve engine parsing/geometry and adapter texture/material responsibilities."
  visual:
    - "Compare visual behavior only against approved TASK-0009 design spec; validation makes no new visual decisions."
  business: []
dependencies:
  agents:
    - "code-analysis-lead"
    - "engineering-lead"
    - "quality-performance-engineer"
  work_packages:
    - "CODE-0009"
    - "INT-0009"
    - "ENG-0009"
  modules:
    - "OSM road direction parsing and road geometry"
    - "2D road-label candidate placement"
    - "MapScene annotation batching and Flutter Scene adapter upload"
    - "Road selection/raycast behavior"
assigned_agents:
  - "quality-performance-engineer"
affected_areas:
  modules:
    - "Focused tests for road parser, label anchors, geometry, adapter, LOD, and picking"
    - "Dart format/analyze/test and Linux debug-build validation"
  packages: []
  files:
    - "Tests under test/engine/ for OSM parsing and annotation geometry"
    - "Tests under test/features/map/presentation/render/ for labels, adapter, scene separation, and raycasts"
    - "Only feature-touched Dart files for scoped formatter run"
protected_areas:
  modules:
    - "All pre-task modifications, deletions, and untracked worktree content outside approved implementation scope."
  files:
    - "Every pre-task modified, deleted, or untracked path and its existing content; do not reset, remove, or overwrite it."
deliverables:
  - "Validation matrix mapping AC-01 through AC-08 to test names and evidence."
  - "Exact format/analyze/test/build commands, exit status, and relevant output or log reference."
  - "Visual/runtime evidence for close-3D annotations, 2D-only labels, LOD, and selectable roads when runnable."
  - "Explicit failing tests, unverified criteria, unavailable prerequisites, and limitations; no unsupported pass claims."
acceptance_criteria:
  - "Focused tests validate yes/forward/true, -1/reverse/true, no/both/false, roundabout default true, explicit roundabout no/both/false, and other/absent false."
  - "RoadProperties.oneway API remains and true means one permitted direction; roundabout explicit-no false is recorded as intentional input-specific correction."
  - "Implementation conforms to CODE-0009 handoff or divergences are reported with evidence."
  - "Tests validate path-length label anchor, arrow direction/spacing/lanes/curvature/height, atlas/UV upload/fallback, and LOD."
  - "Tests validate 2D/3D separation, no arrows in Map2DScene, raycast-through annotations, and base-road pickability."
  - "Feature-touched Dart files pass formatter validation; flutter analyze and flutter test pass, or failures are fully reported."
  - "Linux debug build passes where toolchain is available, or missing prerequisites and exact failure are reported."
  - "Validation does not modify, reset, or remove unrelated pre-existing worktree changes."
testing_requirements:
  - "Run parser and caller tests for yes=forward/true, -1=reverse/true, no=both/false, missing roundabout=forward/true, explicit roundabout no=both/false, and other/absent=both/false. Confirm true means one permitted direction and record the explicit-no behavior change."
  - "Compare source changes with CODE-0009 correction/integration handoff; flag unapproved deviations."
  - "Run cumulative-midpoint tests on unevenly sampled ways and 2D/3D overlay separation tests."
  - "Run arrow tests for cumulative spacing, short-way minimum, direction reversal, opposing lanes, curves, and approximately 0.04 m elevation."
  - "Run atlas/UV/material upload, upload-time generation, failure fallback, per-tile batching, and 1,200 m LOD tests."
  - "Run scene tests proving annotations do not intercept raycasts and base roads remain pickable."
  - "Run dart format on scoped files, flutter analyze, flutter test, and flutter build linux --debug; capture exact output and exit codes."
  - "If visual host is available, capture close 3D and 2D evidence; otherwise state limitation and rely only on executed automated checks."
documentation_requirements:
  - "Provide reproducible evidence and map every acceptance criterion to test/output."
  - "Separate automated evidence from unrun visual/native checks and explain unavailable prerequisites."
  - "Do not modify the approved design or unrelated documentation; return defects to Engineering and retest fixes."
risks:
  - "Green unit tests may miss atlas orientation, foreshortening, alpha blending, or actual raycast behavior; visual evidence may be unavailable."
  - "Pre-existing dirty files increase accidental-change risk from formatting or fixtures; keep commands scoped."
  - "Linux Flutter/desktop prerequisites may block debug build; report exact reason rather than claim success."
completion_report:
  required: true
---
# Work Package VAL-0009 — Road-Surface Annotations Validation

## Objective

Validate Engineering's TASK-0009 implementation against the approved design and acceptance criteria. Provide reproducible test/build evidence and distinguish automated evidence from unavailable visual or Linux runtime checks. Do not implement or fix feature code; route failures to Engineering.

## Validation recipe

1. Confirm CODE-0009 handoff was returned before Engineering changes to analyzed concerns. Map focused tests to AC-01–AC-08. Cover `yes=forward/true`, `-1=reverse/true`, `no=both/false`, missing roundabout=`forward/true`, explicit roundabout `no=both/false`, and other/absent=`both/false`; verify `RoadProperties.oneway` remains and true means one permitted direction. Explicit roundabout no intentionally changes old mapper's blanket-roundabout true result.
2. Validate 2D cumulative-distance midpoint anchors on unevenly sampled ways; ensure UI labels are only in `Map2DView` and existing 2D area/POI labels and road painter behavior remain unchanged.
3. Validate arrow direction, cumulative ~45 m spacing, minimum arrows on short ways, opposing bidirectional lane offsets, tangent following on curved roads, and ~0.04 m elevation.
4. Validate per-tile batching, text atlas upload/UV/material path, atlas failure fallback, upload-time rather than per-frame generation, and 1,200 m LOD cutoff.
5. Validate no arrows in `Map2DScene`, no annotation road entity/picking data, raycasts reaching base road, and continued base-road selection.
6. Run `dart format` only on feature-touched Dart files, `flutter analyze`, `flutter test`, and `flutter build linux --debug`. Record command, exit status, and concise output for every check. Do not reformat unrelated dirty files.
7. If a visual host is available, capture close 3D and 2D evidence. Otherwise mark visual checks unavailable; do not infer visual success from unit tests.

## Evidence and handoff

Return a criterion-to-evidence matrix, test names, exact commands/results, build prerequisite status, screenshots/log references if available, failures, and unverified criteria. Confirm code changes follow CODE-0009 handoff and preserve all pre-existing worktree content. Delivery Auditor issues final verdict; this package does not approve delivery.
