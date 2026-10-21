# TASK-0001 — Road surface continuity

**Verdict:** Complete with noted environment limitations.

## Delivered

- Kept roads as filled polygons. Reworked offset joins, capped inner miters at
  `2×` half-width with a bevel fallback, removed degenerate points, and fixed
  cyclic closure and opposite-winding annulus contours.
- Added render-only dissolution of duplicate/continuous ways. It preserves
  one-way ordering and leaves ambiguous branches separate; source cell records
  and OSM assets are not rewritten.
- Added per-paint coordinate projection reuse with half-pixel snapping and
  directional 3px label halo shadows. Preserved per-class casing/fill batching
  and painter order.
- Updated `docs/ARCHITECTURE.md` and the approved geometry specification/WPs.

## Validation evidence

| Command/check | Result |
| --- | --- |
| `dart format lib/features/map/vector/{map_data_controller,road_geometry_merger,road_projection_cache,road_surface,vector_painter}.dart test/{road_geometry_merger,road_projection_cache,road_surface}_test.dart` | 8 files formatted; 0 changes on final pass |
| `flutter analyze` | No issues found |
| `flutter test` | All 68 tests passed |
| `flutter build linux --debug` | Succeeded: `build/linux/x64/debug/bundle/fogo` |
| Painter inspection | One class path per casing/fill batch; casing before fill; labels after road drawing; 3px directional halo |
| Visual inspection | `/tmp/opencode/continuity_after.png`; Garça roundabout renders as a continuous ring with its center unfilled |

The full test run emits an existing non-fatal hit-test warning in
`test/workspace_semantics_test.dart:186`; it does not fail the suite.

## Files changed

- `lib/features/map/vector/map_data_controller.dart`
- `lib/features/map/vector/road_geometry_merger.dart`
- `lib/features/map/vector/road_projection_cache.dart`
- `lib/features/map/vector/road_surface.dart`
- `lib/features/map/vector/vector_painter.dart`
- `test/road_geometry_merger_test.dart`
- `test/road_projection_cache_test.dart`
- `test/road_surface_test.dart`
- `docs/ARCHITECTURE.md`
- `docs/superpowers/specs/2026-10-19-road-surface-continuity-design.md`
- `docs/agent-work/work-packages/ENG-0001-road-surface-continuity.md`
- `docs/agent-work/work-packages/VAL-0001-road-surface-continuity-validation.md`
- `docs/agent-work/handoffs/HANDOFF-TASK-0001.md`
- `docs/agent-work/delivery-reports/TASK-0001-road-surface-continuity.md`

## Limitations

- Workspace has no Git metadata. A baseline diff, commit, and independent
  repository-level confirmation of untouched assets were unavailable. The
  implementation does not write to map assets or source cell records.
- Shared-node identity uses normalized coordinate values because the current
  `MapRoad` schema has no OSM node IDs.
- Visual validation is a captured target viewport, not an automated
  cross-device visual regression suite.
