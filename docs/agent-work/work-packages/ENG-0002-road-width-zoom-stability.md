---
id: ENG-0002
version: "1"
status: approved
source: {user_request: TASK-0002, orchestrator_task_id: TASK-0002}
objective: Keep each polygon road class at its existing z16 screen width and a fixed 2.4px casing delta at every zoom while preserving adaptive railway width behavior.
background: Approved behavior is specified in docs/superpowers/specs/2026-10-19-road-width-zoom-stability-design.md. Fix existing Flutter vector-road width conversion and surface caching; retain polygon geometry and the approved denser overview tradeoff.
scope:
  included: [fixed per-class polygon width at every zoom using each class's z16 target, fixed 2.4px casing delta at every zoom, requested-meter-width cache invalidation, regression tests, architecture documentation]
  excluded: [road geometry algorithm changes, centerline strokes, road class or hierarchy changes, colors/assets/filters/other-layer changes, railway appearance changes]
requirements:
  functional:
    - At every zoom, each polygon road class uses its existing zoom-16 screen-width target.
    - Keep polygon casing delta fixed at 2.4px at every zoom.
    - Keep RoadWidths.width adaptive only for railway styling; do not use it to size polygon surfaces.
    - Within a 0.25 zoom bucket, reuse a cached contour for an unchanged requested half-width in meters; rebuild only the road contour whose requested width changed.
    - Preserve class visibility thresholds, polygon surfaces, classes, hierarchy, clamps, colors, assets/schema, filters, bridge/tunnel treatment, camera behavior, layer ordering, and unrelated map behavior.
  non_functional: [Retain RoadSurfaceCache bucket lifecycle and weak road ownership; keep width-to-meter conversion deterministic for fixed inputs.]
constraints:
  technical: [Use constant per-class z16 screen-width targets at every zoom only for polygon-road width calculations, not RoadWidths.width; cache by requested half-width in meters; keep existing renderer and polygon algorithm.]
  architectural: [Use the existing vector-map width, painter, and surface-cache modules; add no parallel renderer or cache.]
  visual: [Keep roads polygon-based; use each class's z16 target at every zoom and 2.4px casing delta at every zoom; preserve hierarchy, colors, clamps, filters, assets/schema, bridge/tunnel treatment, and other layers. Overview becoming denser is an explicitly approved tradeoff.]
  business: [Do not alter navigation, map data, or unrelated behavior.]
dependencies:
  agents: []
  work_packages: []
  modules: [lib/features/map/vector/road_widths.dart, lib/features/map/vector/road_surface.dart, lib/features/map/vector/vector_painter.dart, test/road_surface_test.dart, docs/ARCHITECTURE.md]
assigned_agents: [engineering-lead]
affected_areas:
  modules: [lib/features/map/vector]
  packages: [Flutter vector-map renderer and test toolchain]
  files: [lib/features/map/vector/road_widths.dart, lib/features/map/vector/road_surface.dart, lib/features/map/vector/vector_painter.dart, test/road_surface_test.dart, docs/ARCHITECTURE.md]
protected_areas:
  modules: []
  files: []
deliverables: [All-zoom fixed polygon widths and casing delta with same-bucket cache invalidation, regression tests, updated architecture documentation, completion report with changed paths and evidence]
acceptance_criteria:
  - For every RoadClass at zooms 7, 12, 14, 15, 16, 18, and 20, converting halfFillMeters back to pixels yields its existing z16 fill width.
  - For every RoadClass at zooms 7, 12, 14, 15, 16, 18, and 20, converting halfCasingMeters back to pixels yields its existing z16 fill width plus a fixed 2.4px casing delta.
  - Tests confirm RoadWidths.width remains adaptive across zooms and is retained only for railway styling; class visibility thresholds remain unchanged.
  - Cache tests confirm same-width requests reuse the identical surface and changed-width requests rebuild it within the same 0.25 zoom bucket.
  - Roads remain polygons; class thresholds, hierarchy, colors, assets/schema, filters, camera behavior, bridge/tunnel styling, and other layers remain unchanged.
  - Targeted tests, flutter analyze, full flutter test, and Linux debug build pass, or failures/limitations are reported; inspect local and major roads at overview and street zooms, including z7, z12, z14, z15, z16, z18, and z20, acknowledging denser overview.
testing_requirements:
  - In test/road_surface_test.dart cover all RoadClass values at z7, z12, z14, z15, z16, z18, and z20; convert halfFillMeters and halfCasingMeters back to pixels using each zoom's same m/px value and compare against the existing z16 class target and fixed 2.4px casing delta.
  - Verify raw RoadWidths.width remains adaptive across zooms for railway styling, and verify existing class visibility thresholds are unchanged.
  - Verify identical requested meter widths reuse a cached surface and changed widths rebuild within one quarter-zoom bucket.
  - Run dart format on changed Dart files, flutter test test/road_surface_test.dart, flutter analyze, flutter test, and flutter build linux --debug when available.
  - Inspect representative local and major roads at overview and street zooms, including z7, z12, z14, z15, z16, z18, and z20; confirm polygon form and other layer ordering, and record the approved denser overview.
documentation_requirements:
  - Update docs/ARCHITECTURE.md to describe per-class z16 polygon widths and fixed 2.4px casing delta at every zoom, adaptive railway width source, approved denser overview tradeoff, and cache invalidation when requested meter width changes within a bucket.
  - Report changed paths, exact commands and results, visual inspection evidence, and limitations.
risks: [Applying the plateau to RoadWidths.width changes railway styling; caching only by zoom bucket can retain stale contours when meter width changes within that bucket.]
completion_report: {required: true}
architecture: {pattern: Existing Flutter vector-map renderer with polygon road surfaces, state_management: No state-management changes, ui_framework: Flutter}
design_dependency: {package: docs/superpowers/specs/2026-10-19-road-width-zoom-stability-design.md, status: approved source of truth}
implementation_requirements: [Use each RoadClass's existing z16 screen-width target for polygon surfaces at every zoom; hold casing delta at 2.4px at every zoom; keep RoadWidths.width adaptive only for railway styling; retain class visibility thresholds, cache bucket lifecycle and weak ownership while comparing requested meter width; preserve polygon geometry and all other approved invariants.]
required_tests: [For each RoadClass test halfFillMeters and halfCasingMeters converted to pixels at z7/12/14/15/16/18/20 against its z16 target and fixed 2.4px casing delta; verify RoadWidths.width remains adaptive for railway styling; test same-width cache reuse and changed-width rebuild within one bucket.]
forbidden_changes: []
---
# Work Package ENG-0002 — Road width zoom stability

Implement the approved behavior from `docs/superpowers/specs/2026-10-19-road-width-zoom-stability-design.md` in the existing polygon-road pipeline. At every zoom, use each class's existing z16 screen width for polygon surfaces and hold casing delta at 2.4px. Keep raw `RoadWidths.width` adaptive only for railway styling. The overview becoming denser is explicitly approved.

For `RoadSurfaceCache`, retain the 0.25 zoom-bucket lifecycle and weak road ownership, but reuse a cached surface only when the requested half-width in meters is unchanged. A changed meter width within the same bucket must rebuild only that road's corresponding contour. Keep road geometry polygon-based and preserve class visibility thresholds, hierarchy, colors, assets/schema, filters, camera behavior, bridge/tunnel styling, and other layers.

Expected paths: `lib/features/map/vector/road_widths.dart`, `lib/features/map/vector/road_surface.dart`, integration review of `lib/features/map/vector/vector_painter.dart`, tests in `test/road_surface_test.dart`, and docs in `docs/ARCHITECTURE.md`. Test every RoadClass at z7, z12, z14, z15, z16, z18, and z20 against its z16 target; verify fixed 2.4px casing, adaptive railway `RoadWidths.width`, and same-bucket cache reuse/rebuild. Follow the acceptance criteria above. Report changed paths, actual commands/results, visual inspection evidence, approved denser-overview tradeoff, and limitations.
