# Delivery Audit — TASK-0005 (3D vector engine, night v3, smooth curves)

- **Task:** TASK-0005 — user-directed evolution of `fogo_map_sdk` into a 3D
  perspective engine over local OSM cells (ADR-0005)
- **Delivery under audit:** git `957ab7a` on top of `4d5faf5`
- **Auditor:** Delivery Auditor (independent rerun, 2026-10-22)
- **Audit cycle:** 1

## Status

**REVISION_REQUIRED** — routed to the engineering sector; the fix is small and
surgical. All other criteria pass with independently reproduced evidence.

## Requirements Validation

| # | Criterion | Result | Evidence (independently reproduced) |
|---|---|---|---|
| 1 | SDK `flutter analyze` | ✅ PASS | Rerun: "No issues found" |
| 2 | SDK `flutter test` = 38 | ✅ PASS | Rerun: `+38: All tests passed!` |
| 3 | Root `flutter analyze` | ✅ PASS | Rerun: "No issues found" |
| 4 | Root `flutter test` = 73 | ✅ PASS | Rerun: `+73: All tests passed!` |
| 5 | `dart format --set-exit-if-changed` | ✅ PASS | 96 files, 0 changed, exit 0 |
| 6 | `flutter build linux --debug` | ✅ PASS | Built `build/linux/x64/debug/bundle/fogo` |
| 7 | PBF sha256 unchanged + manifest match | ✅ PASS | `cdf25842…1be7e59` recomputed = `assets/map/manifest.json` `sourceSha256` |
| 8 | Protected data untouched | ✅ PASS | 0 files under `assets/`/`tool/` in `4d5faf5..957ab7a`; no `assets/map` file newer than 2026-10-21 (manifest mtime 2026-10-20 00:35); 58 cells present; no write APIs (`File(`, `writeAs`, `.write`) anywhere in the diff — estimate code computes a local `heightPx` only (`renderer.dart:358-362`) |
| 9 | Perspective camera: pitch 0–60, bearing, near-plane clip (polylines AND polygons) | ✅ PASS (code) | Pinhole projection `projectRotated`/`rotatedDepth` (`camera.dart:159-190`); pitch clamp 0–60 (`kFogoMaxPitchDegrees`, `setPitch`, `_validateCamera` `camera.dart:430-433, 570-581`); bearing normalized 0–360 (`_normalizeBearing` `camera.dart:43-46`); polyline segment near-clip (`projectGroundPolyline` `camera.dart:195-242`); polygon Sutherland–Hodgman near-clip (`projectGroundPolygon` `camera.dart:248-275`); ground ray-cast inverse (`unproject` `camera.dart:279-298`); center-scale invariant (`focalLength == centerDepth` `camera.dart:116-123`); 12 tests in `camera_projection_test.dart` |
| 10 | Extrusion policy: real height first, estimates behind flag (default true), no `building:levels` | ⚠️ PASS with one defect (see R1) | Real `heightMeters > 0` first, else `style.estimateBuildingHeights` (`renderer.dart:358-362`); flag default true (`style.dart:64`); `levels:3` → `heightMeters == null` asserted (`data_source_test.dart:60-79`); flag fallback + in-process determinism tested (`renderer_test.dart:514-598`). **BUT cross-process determinism fails — R1 below.** |
| 11 | FogoSmooth endpoint/corner preservation (unit tests) | ✅ PASS | Endpoint-preserving Catmull-Rom with 32° corner guard (`road_geometry.dart:631-703`); `smooth_test.dart`: junction endpoints exactly fixed, sharp corners exact vertices, gentle curves resampled, short inputs unchanged (4 tests) |
| 12 | Night v3 palette lockstep SDK ↔ app | ✅ PASS | All shared tokens byte-identical: background/`mapCanvas` `#0D0F14`, water `#0B1726`, roads `#585F6E→#171A21`, roof `#1B1E26`, walls `#232733`/`#14161D` (`style.dart:21-55` vs `fogo_map_style.dart:12-59`); app constructs SDK style from app tokens (`map_workspace_page.dart:108-146`) |
| 13 | No Mapbox dep / webview / `dart:io` / native channels added | ✅ PASS | `grep -i mapbox|webview` in both `pubspec.yaml`: clean; `grep dart:io|MethodChannel` in `packages/fogo_map_sdk/lib`: clean. "Mapbox" appears only in comments stating tokens are F.O.G.O.-owned |
| 14 | Docs match implementation | ⚠️ PASS in tree, ✗ in commit (R2) | `README.md:27,41-45` (background `#0D0F14`, pitch 0–60 with 0°/45° toggle declared, bearing transient, spline, estimates render-only, `building:levels` never); `docs/ARCHITECTURE.md:75,81,97-107` (same + `estimateBuildingHeights = false` fallback); `packages/fogo_map_sdk/README.md:87-89,115-123` — **correct content exists only as an uncommitted working-tree change; commit `957ab7a` does not include it (R2)** |
| 15 | Evidence statistical proof reproducible | ✅ PASS (exact) | Recomputed with Pillow, same protocol (crop 460..1060 × 80..780, step 2, thr 12/ch): `diff(topdown, flat2) = 0.0%`, `diff(topdown, 3d) = 42.6%`, `diff(3d, flat2) = 42.6%`; wall shade `(32,35,46)` present only in the 3D capture (219 px vs 0/0); road tokens present (`#474D59` 2.37%, `#2A2F3A` 9.22% of crop); all 4 PNG sha256s match the evidence file's prefixes and suffixes |
| 16 | Declared limitations accurate | ⚠️ Mostly, one undeclared behavioral deviation (R1) + one unmet ADR clause (R3) | Declared and verified in code: bearing only via trackpad twist (`view.dart` rotation → `rotateBy`); walls behind near-plane skipped (walls use per-corner projection, no polygon clip); screen-space label collision (`FogoLabelLayout`); estimates visualization-only; no `dart:io`/channels in SDK |

## Engineering Validation

- Offline contract preserved: no network code in the diff; the only files touched
  are docs, evidence, app design tokens, SDK sources and SDK tests — all within
  TASK-0005 scope. No out-of-scope changes.
- App persistence unchanged and correct: center/zoom only
  (`map_workspace_page.dart:49-56, 85-92`; root test
  "workspace persists center/zoom only and exposes accessible transient 3D
  toggle" passes). Pitch/bearing transient per ADR.
- Accessibility preserved: 3D toggle has `Semantics(label: 'Visão 3D', toggled:)`
  + keyboard activation (`zoom_controls.dart:70-108`); marker behind camera
  collapses to `SizedBox.shrink()` (`view.dart`).

## Design Validation

- Palette v3 delivered as specified; roads lighter than land confirmed both in
  code and in the recomputed pixel statistics.
- Wall shading (fixed northwest light, two-tone) confirmed by the `(32,35,46)`
  wall-shade pixels appearing only in the pitched capture.
- Building footprints keep crisp corners (smoothing applies to road-class
  geometry only — `FogoRoadSurfaceCache._surface` is the sole `FogoSmooth`
  call site).

## Test Evidence

- SDK: 38/38 passed. Root: 73/73 passed. Total 111 passed, 0 failed.
- New regression coverage: 3D camera/projection (12 tests), polyline near-clip
  (direct), smoothing (4 tests), estimate flag fallback + in-process
  determinism, widget-level pitch 45 marker/route alignment.
- Missing (notes, not blockers):
  - No direct unit test for polygon near-plane clipping
    (`projectGroundPolygon`); covered only indirectly via pitched renders.
  - No direct test for extrusion depth ordering (painter's sort);
    covered only indirectly.
  - The determinism test is same-process only — which is precisely why R1
    escaped (see below).

## Documentation Validation

- ADR-0005 present and accurate for the camera/smoothing/palette/no-new-sources
  decisions.
- Evidence file commands/results table reproduces exactly, except:
  - `dart format` counted **95** files in evidence; the specified set is
    **96** (`lib`, `test`, `packages/fogo_map_sdk/{lib,test}`). Formatting
    itself is clean (0 changed). Trivial discrepancy.
- `packages/fogo_map_sdk/README.md` documentation update is **not in commit
  `957ab7a`** — see R2.

## Deviations

1. **R1 (the blocker): estimate jitter is not deterministic across processes.**
   `renderer.dart:393` seeds the height jitter with
   `Object.hashAll(building.coordinates.take(4))`. Dart VM hash values are
   **randomized per process**. Independently reproduced on this machine with
   Flutter's own Dart SDK (`flutter/bin/dart`, Flutter 3.47.1), identical
   coordinates across 5 fresh processes yield `jitter = 0.0 / 0.733 / 0.2 /
   0.333 / 0.2` (expression `((hash & 0xF) / 15).clamp(0,1)`). Consequence: an
   untagged building's estimated height (band base ± up to 4 m) **changes
   between app restarts**. This contradicts, verbatim:
   - ADR-0005: "deterministic, coordinate-seeded display-only estimates"
   - evidence file: "deterministic display-only estimates"
   - `packages/fogo_map_sdk/README.md`: "deterministic display-only estimates"
   - `style.dart` doc comment: "deterministic display-only estimates"
   - `renderer.dart:384` comment: "stable jitter"

   The unit test (`renderer_test.dart`: repeated renders identical) proves only
   same-process determinism, so the claim as written is unevidenced and, as
   behavior, false across restarts. This per-session variance is also **not
   declared** in the evidence limitations (Rule 13 violation).
2. **R2: SDK README update uncommitted.** The v3 documentation for
   `packages/fogo_map_sdk/README.md` (pitch 0–60, bearing, near-plane clip,
   smoothing, estimates flag — content verified correct) exists only as a
   working-tree modification. Commit `957ab7a` does not touch that file, so the
   committed README still describes the old camera ("pitch accepts only 0° or
   45°", non-perspective). The delivered commit contradicts the implementation
   it ships.
3. **R3 (minor): unmet ADR consequence clause, undeclared.** ADR-0005
   Consequences: estimates "are labeled as such in docs **and in the layers
   panel**; the toggle falls back to real-heights-only." Docs label estimates
   display-only everywhere, and the SDK flag + fallback exist and are tested —
   but `layers_panel.dart` carries no estimates-as-visualization-aid labeling
   and no `estimateBuildingHeights` toggle (only "Edificações"). The evidence
   limitations/deferred list does not mention this gap.
4. **N5 (pre-existing, not introduced):** app overrides SDK `railDisused` with
   `FogoColors.textDisabled` `#5D6879` (`map_workspace_page.dart:134`,
   present already at `4d5faf5`) — an odd light color against the night
   palette; unrelated to this delivery, noted for backlog.
5. **N6 (pre-existing):** the git-tracked build cache
   `packages/fogo_map_sdk/build/test_cache/*.dill.track.dill` is dirtied by
   every test run; untrack it in a housekeeping commit.

## Risks

- Painter's-algorithm depth sort (no z-buffer): intersecting/concave footprints
  can misorder at high pitch — accepted by ADR, but untested directly.
- `Object.hashAll` dependence (R1) also means estimate heights are not
  reproducible for support/debugging ("that building was 5 m yesterday").
- Polygon near-plane clip uses a conservative `near × 4` margin
  (`camera.dart:250`): geometry slightly in front of that margin can be dropped
  at extreme pitch — consistent with the declared wall-skip limitation family,
  but the margin choice itself is undocumented.

## Debt Introduced

- R1's unstable hash (or, if declared instead of fixed, an explicit
  per-session-variance clause added to ADR-0005, evidence, and both READMEs).
- R2's dangling uncommitted doc change.

## Required Revisions (engineering sector, cycle 1)

1. **R1 (must fix):** make the estimate jitter stable across processes —
   e.g., replace `Object.hashAll` with a fixed-algorithm hash (FNV-1a over the
   four doubles' bit patterns) in `renderer.dart:393` — **or**, if per-session
   variance is accepted as intended behavior, amend ADR-0005, the evidence
   limitations, and all doc mentions of "deterministic" to say
   "stable within a session". Either path must add a regression test that pins
   the estimate for fixed coordinates to a golden constant (immune to future
   hash-seed changes).
2. **R2 (must fix):** commit the `packages/fogo_map_sdk/README.md` update so
   the delivered commit's docs match the delivered code.
3. **R3 (route to design, small):** add the estimates visualization-aid label
   (and optionally the real-heights-only toggle) to the layers panel, or amend
   the ADR-0005 consequence clause to docs-only labeling.
4. **(should, test quality):** direct unit tests for polygon near-plane
   clipping and depth ordering.

## Auditor Limitations (Rule 13)

- Pixel verification is statistical (Pillow), not human visual review — same
  limitation the evidence itself declares; the four PNGs were not inspected
  aesthetically.
- Checks ran on Linux x64 with Flutter 3.47.1 stable only; other platforms not
  exercised.
- Cross-process hash behavior was tested on the VM bundled with this Flutter
  install; release-mode AOT could not be directly sampled, but hash
  randomization is a Dart VM policy, not a debug-only behavior.
- The working tree (not a fresh checkout of `957ab7a`) was audited; this is how
  R2 was found.

## Final Recommendation

**REVISION_REQUIRED** → `instrum-orchestrator`, routed to the engineering sector
(+ small design follow-up). All build/test/format/protected-data/evidence
criteria reproduce cleanly, and the 3D engine itself is sound; but the
"deterministic estimates" property stated in ADR-0005, the evidence, and two
READMEs is falsifiable on the delivered platform (R1), the SDK README update
never landed in the commit (R2), and one ADR consequence clause is unmet and
undeclared (R3). All three fixes are small; expect approval on cycle 2.
