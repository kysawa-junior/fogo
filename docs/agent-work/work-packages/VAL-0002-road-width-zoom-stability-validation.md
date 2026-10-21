---
id: VAL-0002
version: "1"
status: approved
source: {user_request: TASK-0002, orchestrator_task_id: TASK-0002}
objective: Independently verify fixed per-class polygon-road widths and 2.4px casing delta at every zoom, same-bucket surface-cache invalidation, and preservation of adaptive railway and unrelated map behavior.
background: Validate ENG-0002 against docs/superpowers/specs/2026-10-19-road-width-zoom-stability-design.md, including all-class pixel conversions at overview and street zooms, adaptive railway widths, cache behavior, and project checks. The denser overview is an explicitly approved tradeoff.
scope:
  included: [review implementation and tests, run specified checks, inspect representative rendering at z7/z12/z14/z15/z16/z18/z20, report evidence and limitations]
  excluded: [feature implementation, expanding approved behavior, redefining geometry or visual design]
requirements:
  functional:
    - Verify every RoadClass has stable polygon fill pixel width at z7/12/14/15/16/18/20 matching its existing z16 target.
    - Verify every RoadClass has stable casing outer pixel width at z7/12/14/15/16/18/20 matching z16 fill plus a fixed 2.4px casing delta.
    - Verify raw RoadWidths.width remains adaptive across zooms for railway styling, and class visibility thresholds remain unchanged.
    - Verify unchanged requested meter widths reuse cached surfaces and changed widths rebuild the affected surface in one 0.25 zoom bucket.
    - Verify polygon geometry, classes, hierarchy, colors, assets/schema, filters, camera behavior, and other layers remain unchanged; record approved denser overview.
  non_functional: [Report only checks actually run; record exact commands, outcomes, visual evidence, and environment limitations.]
constraints:
  technical: [Use approved spec and ENG-0002 as sources of truth; do not implement changes during validation; route gaps to engineering.]
  architectural: [Validate the existing Flutter vector-map renderer and cache; do not request renderer replacement.]
  visual: [Inspect representative polygon roads without redefining design or styling; note overview density as approved tradeoff.]
  business: [Do not change map data, navigation, or unrelated map behavior.]
dependencies:
  agents: [engineering-lead]
  work_packages: [ENG-0002]
  modules: [lib/features/map/vector/road_widths.dart, lib/features/map/vector/road_surface.dart, lib/features/map/vector/vector_painter.dart, test/road_surface_test.dart, docs/ARCHITECTURE.md]
assigned_agents: [quality-performance-engineer]
affected_areas:
  modules: [lib/features/map/vector]
  packages: [Flutter test/analyze/build toolchain]
  files: [lib/features/map/vector/road_widths.dart, lib/features/map/vector/road_surface.dart, lib/features/map/vector/vector_painter.dart, test/road_surface_test.dart, docs/ARCHITECTURE.md]
protected_areas:
  modules: []
  files: []
deliverables: [Validation report with exact command outcomes and criterion evidence, visual inspection notes for z7/z12/z14/z15/z16/z18/z20, explicit failures and limitations]
acceptance_criteria:
  - test/road_surface_test.dart covers every RoadClass and converts halfFillMeters and halfCasingMeters back to pixels at z7/12/14/15/16/18/20, matching each class's existing z16 target and fixed 2.4px casing delta.
  - Tests confirm raw RoadWidths.width stays adaptive across zooms for railway styling and class visibility thresholds are unchanged.
  - Tests prove same-width cache reuse and different-width rebuild within one 0.25 zoom bucket.
  - Run dart format on changed Dart files, targeted and full flutter tests, flutter analyze, and flutter build linux --debug when available; report outcomes and limitations.
  - Visual inspection at z7/z12/z14/z15/z16/z18/z20 confirms polygon roads use stable class widths, the casing delta stays fixed, and unrelated layer order is unchanged; record the approved denser overview or explain why inspection was unavailable.
testing_requirements:
  - Verify all-class conversion tests at z7, z12, z14, z15, z16, z18, and z20; fill pixel width is 2 * halfFillMeters / mpp and casing outer width is 2 * halfCasingMeters / mpp.
  - Confirm tests compare against each existing z16 class target plus a 2.4px casing delta at every zoom, preserve adaptive RoadWidths.width for rail styling, and check unchanged class visibility thresholds.
  - Verify cache tests issue requests in one bucket, reuse the same surface for the same requested meter width, and rebuild after requested width changes.
  - From project root run dart format on changed Dart files, flutter test test/road_surface_test.dart, flutter analyze, flutter test, and flutter build linux --debug when available.
  - Inspect railway/polygon call-site separation and confirm road polygons, class hierarchy/thresholds, colors, assets/schema, filters, camera behavior, bridge/tunnel treatment, other layers, and layer ordering remain unchanged; record denser overview as approved.
documentation_requirements:
  - Report exact commands, outcomes, visual evidence, changed paths, and environment limitations.
  - Confirm docs/ARCHITECTURE.md accurately describes all-zoom per-class polygon widths, fixed 2.4px casing delta, adaptive railway width behavior, approved denser-overview tradeoff, and within-bucket cache invalidation.
risks: [Automated conversion tests cannot alone prove rendered styling or layer order; Linux build dependencies may be unavailable.]
completion_report: {required: true}
---
# Work Package VAL-0002 — Road width zoom stability validation

Validate `ENG-0002` independently against `docs/superpowers/specs/2026-10-19-road-width-zoom-stability-design.md`. Do not implement changes or broaden the approved behavior. Treat denser overview from fixed pixel widths as an explicitly approved tradeoff.

## Validation recipe

1. Review `test/road_surface_test.dart`: for every `RoadClass`, verify `2 * halfFillMeters / mpp` at zooms 7, 12, 14, 15, 16, 18, and 20 equals that class's existing z16 fill target. Verify `2 * halfCasingMeters / mpp` equals that fill target plus a fixed 2.4px. Confirm raw `RoadWidths.width` remains adaptive across zooms for railway styling and class visibility thresholds remain unchanged.
2. Confirm cache coverage keeps requests in one 0.25 zoom bucket, reuses the identical surface for unchanged requested meter widths, and rebuilds for changed widths.
3. From project root run `dart format` on changed Dart files, `flutter test test/road_surface_test.dart`, `flutter analyze`, full `flutter test`, and `flutter build linux --debug` when available. Record exact results; unrun checks are not passes.
4. Inspect representative local and major polygon roads at zooms 7, 12, 14, 15, 16, 18, and 20. Check stable class widths and casing delta; verify thresholds, hierarchy, colors, assets/schema, filters, camera behavior, bridge/tunnel styling, other layers, and layer order remain unchanged. Record approved denser overview. Report inspection evidence or limitations.
5. Confirm `docs/ARCHITECTURE.md` matches implementation. Return evidence, failures, and environment limitations to engineering.
