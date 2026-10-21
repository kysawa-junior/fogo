---
id: ENG-0001
version: "2"
status: approved
source: {user_request: TASK-0001, orchestrator_task_id: TASK-0001}
objective: Fix road-surface continuity while preserving polygon-based OSM rendering.
background: Approved design identifies missing inner joins, omitted cyclic closure, and degenerate points as gap causes; also requires per-frame projection reuse and a stronger label halo. Newly confirmed in-scope runtime preprocessing deduplicates cell copies and dissolves compatible uniquely connected ways so segmented roundabouts can close without changing source records.
scope:
  included: [runtime render-geometry deduplication and dissolve, road geometry, projection cache, label halo, regression tests]
  excluded: [OSM schema/assets regeneration, road-width rules, unrelated map behavior]
requirements:
  functional:
    - Deduplicate identical ways loaded from multiple map cells in derived render geometry.
    - Merge uniquely connected ways only when rendered style, name, normalized endpoint, tangent compatibility, and direction permit; preserve one-way direction and leave ambiguous branches untouched.
    - Integrate the render-geometry merger in map data loading before road-surface construction without changing source cell records.
    - Remove consecutive degenerate points before computing directions.
    - Use inner offset-line intersections and outer round joins; cap miter ratio at 2 with safe fallback.
    - Close ways cyclically and emit opposite-winding contours for a hollow nonzero-fill annulus.
    - Keep open ways as one polygon with correctly ordered round caps; closed ways have no caps.
    - Cache normalized coordinate projections per paint frame and snap to half-pixels.
    - Strengthen dark 3px label halo with directional paragraph shadows.
    - Retain polygon surfaces, per-class batching, casing-before-fill order, labels after roads, and unrelated map behavior.
  non_functional: [Preserve OSM centerlines; scope projection cache to one frame.]
constraints:
  technical: [Use normalized coordinate keys, not absent OSM node IDs; keep dissolve render-only; do not regenerate OSM assets or change schema.]
  architectural: [Use existing Flutter vector-map renderer and test structure.]
  visual: [Preserve widths, class colors, bridge/tunnel treatment, and layer order; only strengthen specified halo.]
  business: [Keep navigation and unrelated map behavior unchanged.]
dependencies:
  agents: []
  work_packages: []
  modules: [lib/features/map/vector/vector_data.dart, lib/features/map/vector/road_widths.dart, lib/features/map/vector/road_geometry_merger.dart, lib/features/map/vector/map_data_controller.dart]
assigned_agents: [engineering-lead]
affected_areas:
  modules: [lib/features/map/vector]
  packages: [Flutter CustomPainter renderer]
  files: [lib/features/map/vector/road_geometry_merger.dart, lib/features/map/vector/map_data_controller.dart, lib/features/map/vector/road_surface.dart, lib/features/map/vector/vector_painter.dart, test/road_geometry_merger_test.dart, test/road_surface_test.dart]
protected_areas: {modules: [], files: []}
deliverables: [Corrected geometry, frame-scoped projection cache and halo, regression tests, implementation and validation evidence]
acceptance_criteria:
  - L bends have no inner-corner gap; miter ratio is capped at 2 with safe fallback.
  - Closed loops include the closing edge, form a continuous band, and leave the center hollow under nonzero fill.
  - Degenerate vertices do not create invalid geometry or break indexing; open/closed cap semantics are correct.
  - Identical cell copies are deduplicated; compatible uniquely connected ways dissolve without reversing one-way direction, while ambiguous branches remain separate.
  - Two one-way named roundabout arcs close despite a differently named access branch.
  - Equal normalized coordinates reuse per-frame projections snapped to half-pixel precision.
  - Existing batching, painter order, OSM assets/data, widths, colors, bridge/tunnel treatment, layer order, and navigation remain unchanged.
  - Tests, analysis, and Linux debug build pass or limitations are reported.
testing_requirements: [Add merger coverage for duplicate cell copies, one-way direction, ambiguous branches, and two one-way named roundabout arcs closing despite a differently named access branch in test/road_geometry_merger_test.dart; add geometry/cap/cache tests in test/road_surface_test.dart; run dart format, flutter analyze, full flutter test, and flutter build linux --debug when available; inspect batching and label order.]
documentation_requirements: [Report changed files, commands, results, and environment limitations.]
risks: [Wrong contour winding may fill loop center; coordinate cache and runtime dissolve assume equal normalized shared coordinates remain equal; over-merging at ambiguous branches could alter road topology.]
completion_report: {required: true}
architecture: {pattern: Existing Flutter vector-map CustomPainter, state_management: Riverpod, ui_framework: Flutter}
design_dependency: {package: docs/superpowers/specs/2026-10-19-road-surface-continuity-design.md, status: approved source of truth}
implementation_requirements: [Deduplicate and dissolve only derived render geometry before road-surface construction; retain polygon surfaces and existing approved polygon-buffer scope; handle cyclic/open geometry; clear projection cache per frame; preserve painter batching/order and unrelated map behavior.]
required_tests: [Duplicate cell-copy deduplication; compatible unique-way merge and one-way direction preservation; ambiguous branch remains unmerged; named one-way roundabout arcs close despite differently named access branch; L-corner containment/miter fallback; closed-loop annulus and hollow center; degenerate points; cap semantics; per-frame projection reuse and half-pixel snapping]
forbidden_changes: []
---
# Work Package ENG-0001 — Road surface continuity

Integrate runtime-only `RoadGeometryMerger` preprocessing through `map_data_controller.dart`: deduplicate identical ways loaded from multiple cells and merge only uniquely connected ways with matching rendered style/name, normalized shared endpoints, compatible tangents, and compatible directions. Preserve one-way direction and leave ambiguous branches untouched. Verify that two one-way named roundabout arcs close even when a differently named access branch meets them.

Then analyze and fix `RoadSurfaceBuilder` inner joins, degenerate input handling, cyclic closure, and open/closed caps per the approved design. Add frame-scoped coordinate-keyed projection reuse with half-pixel snapping and strengthen the dark 3px label halo using directional paragraph shadows. Runtime dissolve is derived render geometry only: retain existing approved polygon-buffer scope and do not alter source cell records, OSM assets, or schema.

Keep polygon surfaces, current per-class casing/fill batching and casing-before-fill order, labels above roads, OSM data/assets, widths, colors, bridge/tunnel treatment, layer order, navigation, and unrelated map behavior unchanged. Do not regenerate OSM assets. `forbidden_changes` is empty because no architecture-reviewer binding constraints or Master Brief protected areas were supplied.

Add merger regression tests in `test/road_geometry_merger_test.dart` and geometry tests in `test/road_surface_test.dart`. Run formatting, `flutter analyze`, full `flutter test`, and `flutter build linux --debug` when available; inspect batching and label order; report commands, outcomes, and environment limitations.
