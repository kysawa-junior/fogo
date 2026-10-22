# TASK-0006 — Cartographic refinement: evidence and delivery report

**Date:** 2026-10-22
**Decision record:** [`docs/adr/ADR-0006-cartographic-refinement.md`](../../adr/ADR-0006-cartographic-refinement.md)
**User directive:** audit, fix and refine the existing 3D vector engine —
street widths, tessellation/joins, generalization by zoom, depth
composition, labels — preserving architecture, palette and 3D features.

## Confirmed causes (code-level diagnosis, not presumed)

| Symptom | Confirmed cause | Location |
|---|---|---|
| Thick street bands at mid zoom | Fixed screen-px width per class at every zoom; fixed +1.2/+1.6 casing pad | old `_roadWidth` table, `_paintRoads` |
| "Repeated light triangles" | One-way arrows every 100 px on every one-way street (cap 500), no screen test, no junction exclusion, spacing continuity bug across clipped runs | old `_paintOneway`/`_drawOnewayArrows` |
| Streets slicing building walls at pitch | `_paintBuildings` painted before `_paintRoads` unconditionally | old `paint()` order |
| Full rebuild on every pan | Surface cache keyed by `camera.center`; projection cache in center-relative px | old `FogoRoadSurfaceCache` |
| Regional label saturation | `village`/`suburb` labels had no upper zoom bound; no per-kind budget; city/town/village/suburb all stacking | old `_paintLabels` |
| Parcel patchwork seams | Per-polygon antialiasing leaves dark seams between adjacent same-colour fills | old `_paintAreas` |

Confirmed healthy (no action): two-pass casing-then-fill (no seams at
crossings), per-level bridge/tunnel passes, junction-node-preserving
smoothing, per-cell road dedupe/merge, building LOD gate at z≥15.

## Changes (ADR-0006)

- `road_geometry.dart`: new `FogoCartography` (per-class zoom ramps in
  screen px, casing pad `0.6+0.18·w`, quarter-zoom buckets, metre
  half-width). Surface cache now buffers in **absolute mercator metres**
  keyed by (zoom bucket, metre width) — pan/rotation/pitch reuse buffers.
  `FogoSmooth` parameterized (step/epsilon in caller space). Projection
  cache stores absolute metres.
- `camera.dart`: `projectMeters`, `projectMetersPolyline`,
  `projectMetersPolygon`, `metersDepth` — near-plane-clipped metre-space
  pipeline.
- `renderer.dart`: metre-space pipeline everywhere; widths from the ramps at
  the zoom bucket; pitched order = roads first, depth-sorted extrusions
  after (near walls correctly occlude streets behind them; flat keeps roofs
  under streets); one-way arrows with junction-edge exclusion, per-run
  spacing reset, 120 px floor, cap 250, screen-bounds test; place labels via
  pure `selectPlaceLabels` (city ≤14, town 10–15, village 12–15, suburb
  13–16.5; budget 8/12/18 by zoom, city>town>village>suburb); same-colour
  hairline on water/green/farmland fills to close AA seams.
- Tests: `cartography_test.dart` (ramp continuity/monotonicity/hierarchy,
  buckets, casing pad, cache identity across pan + rebuild on bucket
  crossing, junction arrow exclusion, label rules, pitch occlusion pixel
  test, seam closure) and `perf_benchmark_test.dart` (measured benchmark).

## Verification (2026-10-22)

- SDK `flutter analyze` clean; `flutter test` **53/53** (44 prior + 9 new
  including the measured benchmark).
- Root app `flutter analyze` clean; `flutter test` **73/73**.
- `dart format` exit 0; `flutter build linux --debug` PASS; PBF sha256
  unchanged (`cdf25842…1be7e59`); no `assets/`/`tool/` files touched.

### Measured benchmark (not an estimate)

40 roads × 20 points, 512×512, 12 paints per path, medians:
**pan-repaint 2006 µs vs zoom-bucket rebuild 3192 µs**. The structural
identity test additionally proves a pan performs zero buffer rebuilds —
before ADR-0006 every pan was a full rebuild.

### Before/after captures (native X11, same camera recipes)

Captures in [`TASK-0006-validation-evidence/`](TASK-0006-validation-evidence/)
compared with TASK-0005's (same persisted-camera recipes; statistical
analysis — this environment has no image-capable review):

| Metric (map area, 2-px grid) | BEFORE | AFTER | Reading |
|---|---|---|---|
| Marília z16: residential fill coverage | 11.74% | 11.18% | ramp 4.5 px vs old 5 px |
| Marília z16: secondary fill coverage | 4.21% | 4.56% | ramp 6.5 px vs old 6 px |
| Marília z16: one-way arrow pixels | 0.65% | 0.61% | junction exclusion + 120 px floor; service offset partially |
| Marília z16 3D: roof coverage | 3.53% | 4.77% | walls+roof composition at pitch |
| 3D engagement (3d vs topdown diff) | 42.6% | 37.8% | perspective renders, toggle works |
| Regional: place-label pixels on the map | 34 | 20 | −40% label budget at regional zoom |
| Regional: arrows/junction artefacts | 0.40% | 0.08% | probe family (arrows + suburb-label colour) collapses |

Structural diff of the z16 pair is 3.2% — the same scene with the modelled
width deltas, i.e. the camera recipes are directly comparable.

## Remaining limitations (declared, not masked)

- One-way arrow totals at z16 fall only ~6% net: residential spacing rose
  (100→120 px) but service spacing fell (150→120 px). The junction
  exclusion removes the visually worst repeats; a per-class spacing table
  remains future tuning.
- Place-label budget is static per zoom band; no distance-based priority
  weighting yet.
- Extrusion occlusion is painter's-algorithm per footprint; intersecting
  tall footprints at extreme pitch can mis-order (no per-triangle depth).
- No release-mode/AOT profiling; benchmark is debug-build wall-clock.
- Label stability during pan relies on deterministic sort order; no
  hysteresis for margin pop-in.
