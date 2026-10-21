---
id: VAL-0001
version: "2"
status: approved
source: {user_request: TASK-0001, orchestrator_task_id: TASK-0001}
objective: Independently validate road-surface continuity remediation and provide test, analysis, build, and painter-inspection evidence.
background: Approved design requires geometry regression tests plus formatting, analysis, full-suite, and Linux debug-build checks when available. Newly confirmed in-scope runtime geometry preprocessing deduplicates cell copies and merges compatible uniquely connected ways while preserving topology and one-way direction.
scope:
  included: [Validate ENG-0001 criteria including runtime geometry preprocessing, run required checks, inspect painter invariants, report evidence and limitations]
  excluded: [Expand approved design, regenerate OSM assets, change schema or unrelated map behavior]
requirements:
  functional:
    - Confirm identical ways loaded from multiple cells are deduplicated in derived render geometry.
    - Confirm merging requires matching rendered style/name, normalized endpoint, compatible tangents/directions, and unique continuation; one-way direction is preserved and ambiguous branches remain untouched.
    - Confirm map data loading applies runtime merging before road-surface construction without modifying source cell records.
    - Confirm two one-way named roundabout arcs close despite a differently named access branch.
    - Confirm tests cover L-corner containment, closed-loop band and hollow center, degenerates, cap semantics, and projection reuse/snapping.
    - Confirm closed roads include final-to-first coverage and opposite-winding contours preserve a hollow center under nonzero fill.
    - Confirm open round caps and closed no-cap semantics, plus 2 miter cap and safe fallback.
    - Confirm projection cache is coordinate-keyed, per-frame, and snaps to half-pixels.
    - Confirm per-class casing/fill batching, casing-before-fill order, labels after roads, and directional 3px label halo.
    - Confirm OSM data/assets, widths, colors, bridge/tunnel treatment, layer order, navigation, and unrelated behavior remain unchanged.
  non_functional: [Record actual commands and results; do not report unrun checks as passing.]
constraints:
  technical: [Use docs/superpowers/specs/2026-10-19-road-surface-continuity-design.md; do not regenerate OSM assets or change schema.]
  architectural: [Validate existing Flutter vector-map renderer; do not request renderer replacement.]
  visual: [Verify approved continuity and halo requirements without redefining design.]
  business: [Do not change navigation or unrelated map behavior during validation.]
dependencies:
  agents: [engineering-lead]
  work_packages: [ENG-0001]
  modules: [lib/features/map/vector]
assigned_agents: [quality-performance-engineer]
affected_areas:
  modules: [lib/features/map/vector]
  packages: [Flutter test/analyze/build toolchain]
  files: [lib/features/map/vector/road_geometry_merger.dart, lib/features/map/vector/map_data_controller.dart, lib/features/map/vector/road_surface.dart, lib/features/map/vector/vector_painter.dart, test/road_geometry_merger_test.dart, test/road_surface_test.dart]
protected_areas: {modules: [], files: []}
deliverables: [Validation report with exact commands and evidence, painter-order inspection, explicit environment limitations]
acceptance_criteria:
  - Regression tests verify duplicate cell-copy deduplication; compatible unique-way merging; one-way preservation; ambiguous-branch non-merging; and closure of two one-way named roundabout arcs despite a differently named access branch.
  - Regression tests verify L-corner containment, closed-loop hollow annulus, degenerates, cap semantics, and cache reuse/snapping.
  - Run dart format, flutter analyze, full flutter test, and flutter build linux --debug when available; report all outcomes.
  - Painter inspection confirms batching and order; approved unrelated map behavior remains unchanged.
  - No check is reported passing without evidence; failures and environment limitations are explicit.
testing_requirements: [Review test/road_geometry_merger_test.dart for duplicate cell copies, one-way direction, ambiguous branches, and named roundabout arcs closing around a differently named access branch; run formatter on changed Dart files, flutter analyze, flutter test, and flutter build linux --debug when available; inspect geometry tests and painter draw/label order.]
documentation_requirements: [Record exact commands, outcomes, evidence, and limitations in completion report.]
risks: [Bounds-only tests cannot prove a hollow center; validate nonzero-fill semantics. Linux build dependencies may be unavailable.]
completion_report: {required: true}
---
# Work Package VAL-0001 — Road surface continuity validation

Validate ENG-0001 independently against the approved design, including runtime-only road-geometry preprocessing. Do not expand the approved polygon-buffer scope or alter/regenerate OSM assets or schema.

## Recipe

1. Review `test/road_geometry_merger_test.dart` for identical cell-copy deduplication; matching style/name and normalized endpoint; compatible tangent/direction and one-way preservation; ambiguous-branch non-merging; and two one-way named roundabout arcs closing despite a differently named access branch. Inspect `map_data_controller.dart` to confirm merger integration operates on derived render geometry without changing source records.
2. Review `test/road_surface_test.dart` for L-corner containment and miter fallback; closed-loop closing-edge coverage and hollow center under nonzero fill; degenerate points; open/closed cap semantics; and per-frame coordinate-keyed cache reuse with half-pixel snapping.
3. From the project root run `dart format` on changed Dart files, `flutter analyze`, full `flutter test`, and `flutter build linux --debug` when available.
4. Inspect the painter: batching remains one class path/draw call per casing/fill pass, casing precedes fill, and labels follow roads. Confirm the specified directional 3px halo.
5. Report exact commands, outcomes, evidence, and limitations. Do not regenerate OSM assets or alter unrelated behavior.
