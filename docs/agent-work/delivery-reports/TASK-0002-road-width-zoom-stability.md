# TASK-0002 — Road width zoom stability

**Status:** Approved with notes.

## Delivered

- Polygon road widths now use each class's z16 screen width at **all zooms**;
  casing delta stays fixed at 2.4px. Adaptive `RoadWidths.width` remains
  unchanged for railway styling.
- `RoadSurfaceCache` now reuses only an identical requested meter width;
  changed widths rebuild only that road's cached contour.
- Added regression assertions for existing road-class visibility thresholds.
- Updated architecture documentation. No road data, assets, colors, filters,
  bridge/tunnel treatment, or layer order changed.

## Evidence

| Check | Result |
| --- | --- |
| `dart format lib/features/map/vector/fogo_vector_layer.dart lib/features/map/vector/road_surface.dart lib/features/map/vector/road_widths.dart lib/features/map/vector/vector_painter.dart test/road_surface_test.dart` | 5 files; 0 changes on final pass |
| `flutter analyze` | No issues found |
| `flutter test test/road_surface_test.dart` | All 16 tests passed |
| `flutter test` | All 70 tests passed; pre-existing hit-test warning at `test/workspace_semantics_test.dart:186` |
| `flutter build linux --debug` | Succeeded |
| Visual captures | z7/12/14/15/16/18/20: `/tmp/opencode/width_after_{7,12,14,15,16,18,20}.png` |

The pre-fix captures reproduced the defect: residential core-color runs were
typically 1px at z12/z14, versus 5px at z16/z18. Post-fix pixel scans find 5px
residential runs at overview; at z16/z18, residential runs are most commonly
5px and secondary runs 6px. Unit tests convert every class's buffers back to
pixels at z7–20. Local preferences were backed up before captures, restored,
and verified identical.

Visual inspection across z7–20 confirmed the camera extent changes; local-road
surface comparisons apply at zooms where those classes pass existing visibility
thresholds. The overview is intentionally denser. Thresholds are unchanged and
now have explicit boundary tests.

The full suite emits an existing non-fatal hit-test warning at
`test/workspace_semantics_test.dart:186`; all tests pass.

## Changed files

- `lib/features/map/vector/road_widths.dart`
- `lib/features/map/vector/road_surface.dart`
- `test/road_surface_test.dart`
- `lib/features/map/vector/vector_painter.dart`
- `lib/features/map/vector/fogo_vector_layer.dart`
- `docs/ARCHITECTURE.md`
- `docs/superpowers/specs/2026-10-19-road-width-zoom-stability-design.md`
- `docs/agent-work/work-packages/ENG-0002-road-width-zoom-stability.md`
- `docs/agent-work/work-packages/VAL-0002-road-width-zoom-stability-validation.md`
- `docs/agent-work/handoffs/HANDOFF-TASK-0002.md`
- `docs/agent-work/delivery-reports/TASK-0002-road-width-zoom-stability.md`

## Limitations

- Workspace has no Git metadata, so no baseline diff or commit was available.
- Screenshot checks cover the target Garça viewport on Linux, not automated
  cross-device visual regression.
- No zoom-animation frame-time profile was collected. At changing zoom, visible
  polygon contours whose meter width changes are rebuilt; monitor frame time on
  lower-end hardware if zoom interaction becomes sluggish.
- The overview is denser because constant screen-pixel widths apply at every
  zoom; this tradeoff was explicitly approved.
