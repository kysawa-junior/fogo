# Delivery Audit — TASK-0005 (3D vector engine, night v3, smooth curves)

- **Task:** TASK-0005 — user-directed evolution of `fogo_map_sdk` into a 3D
  perspective engine over local OSM cells (ADR-0005)
- **Delivery under audit:** git `957ab7a` on top of `4d5faf5`
- **Auditor:** Delivery Auditor (independent rerun, 2026-10-22)
- **Audit cycle:** 1

> **Superseded by the cycle-2 audit below** — the revision commit `0d7b00e`
> fixed R2 and R3 but did **not** fix R1. See "Delivery Audit — Cycle 2".

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

---

# Delivery Audit — Cycle 2 (revision `0d7b00e` on top of `957ab7a`)

- **Delivery under audit:** git `0d7b00e` on top of `957ab7a`
- **Auditor:** Delivery Auditor (independent rerun, 2026-10-22)
- **Audit cycle:** 2 (revision cycle 1)
- **Revision diff:** 6 files, +357/−10 — docs ×2, `layers_panel.dart`,
  SDK `README.md`, SDK `renderer.dart`, SDK `estimate_clip_test.dart`.
  0 files under `assets/`/`tool/`; no write APIs / `dart:io` / channels
  in the diff. Working tree == HEAD except the pre-existing tracked
  `.dill` cache (see hygiene note).

## Status

**REVISION_REQUIRED** — R2 and R3 are fixed; **R1 is not**. The FNV-1a
helper was added to `renderer.dart` but never wired into the renderer: the
estimate call site still seeds jitter with `Object.hashAll`, so estimated
heights still change across app restarts, and the golden test passes
against an orphan helper — a false green. This is audit cycle 2 of 3.

## Requirements Validation (rerun of full battery)

| # | Criterion | Result | Evidence (independently reproduced) |
|---|---|---|---|
| 1 | SDK `flutter analyze` | ✅ PASS | Rerun: "No issues found" |
| 2 | SDK `flutter test` = 42 | ✅ PASS | Rerun: `+42: All tests passed!` (38 + 4 new) |
| 3 | Root `flutter analyze` | ✅ PASS | Rerun: "No issues found" |
| 4 | Root `flutter test` = 73 | ✅ PASS | Rerun: `+73: All tests passed!` |
| 5 | `dart format --set-exit-if-changed` | ✅ PASS | 97 files, 0 changed, exit 0 — matches the corrected evidence count |
| 6 | `flutter build linux --debug` | ✅ PASS | Built `build/linux/x64/debug/bundle/fogo` |
| 7 | PBF sha256 unchanged + manifest match | ✅ PASS | Recomputed `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` = manifest `sourceSha256` `cdf25842…1be7e59` |
| 8 | Protected data untouched by `957ab7a..0d7b00e` | ✅ PASS | 0 files under `assets/`/`tool/` in the revision diff; no `File(`/`writeAs`/`.write`/`dart:io`/`MethodChannel` in it; 58 cells still present |
| 9 | R2 fixed: SDK README v3 committed | ✅ PASS | `git show 0d7b00e --stat` includes `packages/fogo_map_sdk/README.md` (+19/−8); content matches implementation (continuous pitch 0–60, bearing trackpad twist, near-plane clipping, endpoint-preserving spline, estimates flag default true, `building:levels` never used); `git status` shows no uncommitted SDK README |
| 10 | R3 fixed: layers panel labels estimates | ✅ PASS | `layers_panel.dart:72-78` — always-visible panel footer caption: "Em vista 3D, edifícios sem altura real do OSM usam alturas estimadas apenas para visualização (ADR-0005)." Meets the ADR-0005 consequence clause (label in docs **and** layers panel; SDK flag still provides the real-heights-only fallback) |
| 11 | New near-plane polygon clipping tests | ✅ PASS | `estimate_clip_test.dart:48-107`: straddling quad at pitch 60 clips non-null (≥3 vertices); fully-behind polygon returns null; clipped vertices finite (< 1e6) across spans 0.01–0.6, pitch 55, bearing 40. Addresses cycle-1 "should" item (depth-ordering direct test still missing — note, not blocker) |
| 12 | R1 fixed: stable cross-process estimate seed | ❌ **FAIL** | See below — the defect is **still live** in `0d7b00e` |
| 13 | Declared limitations accurate | ✅ PASS | All four remain declared in the evidence file (lines 73–84): bearing trackpad-only; walls behind near-plane skipped; screen-space label collision; estimates visualization-only |

## R1 — not fixed: helper added, call site untouched (audit cycle 2)

The revision added a correct FNV-1a helper as a top-level function in
`renderer.dart:14-31` (`fogoHeightJitter`, `@visibleForTesting`, integer-only
arithmetic, no `hashCode`) — **but the renderer never calls it**. The estimate
path still reads, at `renderer.dart:410-411`:

```dart
final int hash = Object.hashAll(building.coordinates.take(4));
final double jitter = ((hash & 0xF) / 15).clamp(0, 1).toDouble();
```

Byte-identical to the `957ab7a` defect line (`renderer.dart:393` there; only
the +17-line helper insertion shifted it down). Repo-wide grep:
`fogoHeightJitter` is referenced **only** by `test/estimate_clip_test.dart` —
dead code in production.

Independently reproduced (fresh Dart processes, Flutter 3.47.1 Dart SDK,
same coordinates `[-22.2172, -49.95, -22.2171, -49.9501]`):

```
jitter = 0.733… / 0.2 / 0.4 / 0.2 / 0.867   (5 processes, same input)
```

The cross-process nondeterminism ADR-0005 forbids ("deterministic,
coordinate-seeded display-only estimates") is therefore still falsifiable on
the delivered commit.

Consequences that make this a blocker rather than a note:

1. **False green:** the golden test pins the orphan helper to the spec, not
   the renderer's actual jitter source; 42/42 SDK tests pass while the defect
   persists. The wired path (`_estimatedHeightPx`) has no test tying it to
   `fogoHeightJitter`.
2. **Evidence now overstates the fix (Rule 11):** the evidence file's
   revision section (lines 96–104) says "All revision findings fixed …
   Replaced with a stable FNV-1a integer seed over coordinate values", and
   the commit message says "fix: stable height-estimate seed". The delivered
   code falsifies both claims. ADR-0005, both READMEs, and `style.dart` still
   promise deterministic estimates — now contradicted by HEAD, exactly as in
   cycle 1.

## Deviations (cycle 2)

1. **R1 unfixed (blocker, must fix):** wire the helper in — replace
   `renderer.dart:410-411` with `final double jitter = fogoHeightJitter(building.coordinates);`
   (the helper internally consumes `take(8)` and skips non-finite values), and
   add one renderer-level regression that a fixed-coordinate building's
   estimated height equals the `fogoHeightJitter`-derived value (so the golden
   test covers the wired path, not just the helper). Update the evidence
   revision section and commit message to describe the fix actually landed.
2. **Pre-existing hygiene (not a blocker, per orchestrator note):**
   `packages/fogo_map_sdk/build/test_cache/*.dill.track.dill` is a tracked
   build artifact from the user's initial commit `4d5faf5` that dirties on
   every test run (currently the only `git status` entry). Untrack in a
   housekeeping commit.
3. Carried notes, unchanged from cycle 1 (not blockers): app overrides SDK
   `railDisused` with `#5D6879` (pre-existing, `4d5faf5`); no direct
   depth-ordering test; polygon near-clip `near × 4` margin undocumented.

## Risks

- Unchanged from cycle 1 (painter's-algorithm sorting at high pitch; polygon
  clip margin) — accepted by ADR, declared, not introduced by the revision.
- New: two consecutive cycles claiming "deterministic estimates" while the
  property is absent means the claim now has no evidentiary basis in either
  the code or the test suite. Third failed audit cycle escalates BLOCKED
  per org rules.

## Test Evidence (cycle 2)

- SDK: 42/42 passed. Root: 73/73 passed. Total 115, 0 failed. Analyze clean
  in both. Format clean (97 files). Linux debug build PASS.
- The 4 new tests themselves are well-constructed (independent FNV-1a
  oracle; direct clipping coverage) — their green result just does not
  cover the production defect (R1).
- Missing: a test that exercises `_estimatedHeightPx` (or any renderer-level
  estimate) against the golden spec.

## Auditor Limitations (Rule 13)

- Same as cycle 1: Linux x64 + Flutter 3.47.1 stable only; pixel evidence
  statistical (not re-run this cycle — rendering pipeline unchanged by
  the revision diff, which touches docs, one caption, one comment-level
  SDK change, and tests only); cross-process hash behavior verified on the
  VM bundled with this Flutter install (hash randomization is a Dart VM
  policy, not debug-only).
- The working tree (== HEAD except the pre-existing tracked `.dill`) was
  audited; all conclusions verified against `git show 0d7b00e:…` blobs as
  well as the working tree.

## Final Recommendation

**REVISION_REQUIRED** → `instrum-orchestrator`, routed to the engineering
sector. R2 ✅, R3 ✅, clipping tests ✅, full battery reproduces clean
(42/42, 73/73, format 97/0, build PASS, PBF sha unchanged, protected areas
untouched). One blocker remains: R1 — the stable seed exists but is dead
code; the renderer still uses the process-randomized `Object.hashAll`, the
documented "all findings fixed" claim is falsifiable, and the golden test
is a false green. The actual fix is a one-line call-site change plus a
wired-path regression test and a corrected evidence section. Audit cycle 3
of 3: another failed cycle on this finding escalates **BLOCKED**.

```yaml
delivery_audit:
  task_id: TASK-0005
  work_packages_reviewed: [TASK-0005, ENG revision 0d7b00e]
  verdict: REVISION_REQUIRED
  criteria_met:
    - "SDK analyze clean (rerun 2026-10-22)"
    - "SDK tests 42/42 (rerun, +42: All tests passed)"
    - "Root analyze clean (rerun)"
    - "Root tests 73/73 (rerun)"
    - "dart format 97 files, 0 changed, exit 0"
    - "flutter build linux --debug PASS (bundle/fogo)"
    - "PBF sha256 cdf25842…1be7e59 recomputed = manifest sourceSha256"
    - "0 assets/ or tool/ files in 957ab7a..0d7b00e; no write APIs; 58 cells intact"
    - "R2 fixed: SDK README v3 committed in 0d7b00e (+19/-8), content matches code"
    - "R3 fixed: layers_panel.dart:72-78 always-visible caption labels display-only estimates (ADR-0005)"
    - "Near-plane polygon clipping direct tests present and passing (estimate_clip_test.dart:48-107)"
    - "All four known limitations still declared in evidence file lines 73-84"
  criteria_failed:
    - criterion: "R1: deterministic cross-process estimate seed (ADR-0005)"
      evidence: "renderer.dart:410-411 still Object.hashAll(building.coordinates.take(4)), byte-identical to 957ab7a:393; fogoHeightJitter referenced only by tests (dead code); 5 fresh Dart processes same coords -> jitter 0.733/0.2/0.4/0.2/0.867; evidence file lines 96-104 claim 'All revision findings fixed' which the code falsifies"
      severity: blocker
  out_of_scope_changes: []
  test_quality:
    passed: 115
    failed: 0
    missing: ["renderer-level test tying _estimatedHeightPx to fogoHeightJitter golden spec", "direct depth-ordering (painter's sort) test (note, carried)"]
  risks_introduced:
    - "False-green coverage: golden test validates an unwired helper while production defect persists"
    - "Evidence file + commit message now document a fix absent from the code (Rule 11)"
  debt_introduced:
    - "Dead @visibleForTesting helper until wired (resolves with the R1 fix)"
    - "Pre-existing (4d5faf5): tracked build cache .dill dirties on every test run - housekeeping untrack"
  documentation_gaps:
    - "evidence TASK-0005-3d-engine-evidence.md revision section overstates R1 fix; commit message 0d7b00e same"
  notes:
    - "Audit cycle 2 of 3; next failed cycle on R1 escalates BLOCKED"
    - "Full battery (analyze/test/format/build/sha/protected) reproduces clean"
    - ".dill dirt is pre-existing hygiene per orchestrator, not a blocker"
  next_action: revision_for_sector
```

---

# Delivery Audit — Cycle 3 (revision `9bddfe2` on top of `0d7b00e`)

- **Delivery under audit:** git `9bddfe2` (current HEAD)
- **Auditor:** Delivery Auditor (independent rerun, 2026-10-22)
- **Audit cycle:** 3 of 3 (final; cycles 1–2 both `REVISION_REQUIRED`)
- **Revision diff `9bddfe2`:** 4 files, +373/−2 — audit report, evidence,
  `renderer.dart` (−2/+3: the R1 wiring), `estimate_clip_test.dart`
  (+154: wired-path test). 0 files under `assets/`/`tool/`.

## Status

**REVISION_REQUIRED** — R1 itself is now genuinely fixed and verified, but
two new acceptance criteria fail, each with a false evidence claim attached,
on the third consecutive cycle with a falsifiable claim. Per the org rule
(three audit cycles without approval), this escalates **BLOCKED**.

## What passes (independently reproduced, cycle 3)

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | R1 wired | ✅ PASS | `renderer.dart:412` reads `final double jitter = fogoHeightJitter(building.coordinates);`; `9bddfe2` diff is the exact −2/+3 replacement of the `Object.hashAll` lines. Repo-wide grep in `packages/fogo_map_sdk/lib`: `Object.hashAll` only at `road_geometry.dart:84,88` (`FogoRoadGeometryMerger._deduplicate` bucket keys) and the `renderer.dart:16` doc comment |
| 2 | Evidence honesty about cycle 2 | ✅ PASS | `TASK-0005-3d-engine-evidence.md` "Revision cycle 2" (lines 118–145) admits the failed edit ("the replacement edit failed on formatting drift and went unnoticed") and the false claim ("the cycle-1 claim 'all revision findings fixed' was false for R1"); commit message `9bddfe2` repeats the admission. Known-limitations section (lines 73–84) intact |
| 3 | SDK `flutter analyze` | ✅ PASS | "No issues found" |
| 4 | SDK `flutter test` = 43 | ✅ PASS | `+43: All tests passed!` |
| 5 | Root `flutter analyze` | ✅ PASS | "No issues found" |
| 6 | Root `flutter test` = 73 | ✅ PASS | `+73: All tests passed!` |
| 7 | `flutter build linux --debug` | ✅ PASS | `✓ Built build/linux/x64/debug/bundle/fogo`, exit 0 |
| 8 | PBF sha256 + manifest | ✅ PASS | Recomputed `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` = manifest `sourceSha256`; 58 cells (36 `l0` + 22 `l1`), bbox/cellSize 0.05/cols 9/rows 4 intact |
| 9 | Protected areas `957ab7a..9bddfe2` | ✅ PASS | 6 files, none under `assets/`/`tool/`; the 3 `File(`/`writeAs`/`dart:io`/`MethodChannel` grep hits are quoted text inside the audit-report markdown in the diff, not code |
| 10 | Cross-process determinism of the wired seed | ✅ PASS | FNV-1a helper is pure integer arithmetic over coordinates; spec value for the test footprint = `0.3333…` identical across 3 fresh Dart VMs; with the call site wired, the ADR-0005 / SDK README "deterministic, coordinate-seeded" claims are now true |
| 11 | Evidence's app-merger claim | ✅ PASS | `lib/features/map/vector/road_geometry_merger.dart:77-91` does use `Object.hash`/`hashAll` as within-process dedupe buckets, exactly as stated |

## F1 — `dart format` gate fails; evidence claims "clean" (Rule 11)

Independent rerun:

```
$ dart format --set-exit-if-changed --output=none \
    lib test packages/fogo_map_sdk/lib packages/fogo_map_sdk/test
Changed packages/fogo_map_sdk/test/estimate_clip_test.dart
Formatted 97 files (1 changed) in 0.22 seconds.   exit 1
```

`packages/fogo_map_sdk/test/estimate_clip_test.dart` — the file `9bddfe2`
itself modified (+154) — is unformatted (the `coordinates:`/`bbox` list
block, lines ~136–146). Reproduced identically in a fresh `git clone` of
`9bddfe2`, so this is the committed state, not working-tree drift. Cycle 2
verified **97 files, 0 changed** at `0d7b00e`, so the regression was
introduced by `9bddfe2`. The evidence file's post-cycle-2 section claims
"`dart format` clean" — the command was evidently not run after the last
edit. (The cycle-3 brief's "98 files expected" is itself off: the specified
set contains 97 dart files, as in cycle 2; the material fact is the 1
changed.)

## F2 — the wired-path test does not guard the jitter seed; evidence claims it does (Rule 11)

The cycle-2 revision mandate was: *"add one renderer-level regression that
a fixed-coordinate building's estimated height equals the `fogoHeightJitter`-derived value (so the golden test covers the wired path, not just the
helper)."* The delivered test (`estimate_clip_test.dart:113-228`, "wired
estimate path") renders at pitch 45, measures the roof-top pixel row, and
asserts it matches the SDK's own `projectGround` projection of the
spec-derived height — but its tolerance window admits **every** jitter
value in [0, 1], so it cannot detect a regression to per-process hashing.

**Empirical:** in a scratch clone with `renderer.dart:412` reverted to the
`Object.hashAll(building.coordinates.take(4))` defect (audit artifacts
untouched), the wired-path test passed **10/10 fresh `flutter test`
processes** with the defect live.

**Analytic (exact SDK constants):** fov 36.87° → `centerDepth = 384`,
`scale = 0.41865 px/m`, footprint `northEdge = 13.981 px`, spec jitter
`0.3333`. Across the full jitter domain the roof row spans
`sy(0) = 112.05` … `sy(1) = 110.82` — a total shift of **1.225 px**, against
an assertion window **2.0 px** wide (`measured − syRoof ∈ [−0.5, +1.5]`,
plus integer-row quantization). No jitter value, randomized or pinned, can
fail the pixel assertion; ~0.082 px per 1/15 jitter step.

The test does meaningfully guard the **band** (a wrong area band → base
4.5/12/30 m shifts the roof row ≥ ~1.7 px and fails) and the flag fallback
(`estimateBuildingHeights: false` restores the flat roof, asserted). But
the regression it was written to catch — the cycle-2 defect class — passes
the entire 43-test suite. Meanwhile the evidence file claims: *"A
regression to per-process hashing changes the extrusion height and fails
the pixel assertion in the overwhelming majority of runs"* — empirically
0/10 and analytically impossible. The commit message presents the test as
"the auditor-required pixel-level regression test".

## Deviations (cycle 3)

1. **F1 (must fix):** run `dart format` on the file (or the four standard
   paths) and commit; correct the evidence sentence "`dart format` clean".
2. **F2 (must fix):** make the wired-path test actually pin the seed, e.g.:
   raise zoom/viewport until the 4 m jitter span exceeds the window with
   margin and shrink the window; or assert a sub-pixel/anti-aliased
   centroid instead of the first bright row; or compare two footprints
   whose spec-jitter deltas differ; or expose `_estimatedHeightPx`'s input
   via `@visibleForTesting`. Then correct the evidence sentence about
   "overwhelming majority of runs".
3. Carried notes, unchanged (not blockers): app `railDisused #5D6879`
   override (pre-existing `4d5faf5`); no direct depth-ordering test;
   polygon near-clip `near × 4` margin undocumented; tracked `.dill` build
   cache dirties on every test run (housekeeping untrack).

## Risks

- Third consecutive cycle with an evidence claim falsifiable by running
  the delivered commands (cycle 1: "deterministic"; cycle 2: "all findings
  fixed"; cycle 3: "dart format clean" + "fails the pixel assertion in the
  overwhelming majority of runs"). The systemic failure mode is unexecuted
  checks asserted as passed — this is what the 3-cycle escalation rule
  exists for.
- The production code for R1 is correct and stays correct; the residual
  risk is regression blindness (a one-line revert of the wiring passes the
  whole suite) plus the false test-strength claim inviting future reliance
  on it.

## Test Evidence (cycle 3)

- SDK 43/43, root 73/73, analyze clean both, build PASS (all rerun).
- Scratch experiment: 10/10 wired-test passes with the R1 defect
  reintroduced (proves insensitivity); 5/5 passes with the FNV-1a wiring
  restored; FNV-1a arithmetic identical across 3 fresh Dart VMs.

## Auditor Limitations (Rule 13)

- Linux x64, Flutter 3.47.1 stable only; release-mode AOT not sampled
  (the wired seed is pure integer arithmetic — deterministic by
  construction on all platforms).
- The 10+5 fresh-process sample is small, but the analytic bound (1.225 px
  full-range shift vs a 2.0 px window) makes the insensitivity conclusion
  exact, not statistical.
- Pixel checks are statistical/programmatic, not human visual review.
- The scratch-clone experiment modified only a throwaway copy under
  `/tmp/opencode/`; the delivery repo, its tests, and history were not
  touched by this audit (the only working-tree change remains the
  pre-existing tracked `.dill`).

## Final Recommendation

**REVISION_REQUIRED → escalate BLOCKED** → `instrum-orchestrator`, to the
user with evidence. For the record: the substantive R1 fix is real,
surgical, and verified; the full battery otherwise reproduces clean; the
two remaining defects are a one-command formatting fix, one test-window
tightening, and two evidence sentences — small work, but they are the
third cycle of exactly the claim-without-verification pattern the
escalation rule exists to stop. Per org rule, three audit cycles without
approval mandate BLOCKED; the user may accept the residual risk or order
the small fix.

```yaml
delivery_audit:
  task_id: TASK-0005
  work_packages_reviewed: [TASK-0005, ENG revision 9bddfe2]
  verdict: REVISION_REQUIRED
  criteria_met:
    - "R1 wired: renderer.dart:412 calls fogoHeightJitter(building.coordinates); 9bddfe2 diff is the exact -2/+3 replacement"
    - "Object.hashAll in SDK lib only in FogoRoadGeometryMerger._deduplicate (road_geometry.dart:84,88) + doc comment"
    - "Evidence Revision-cycle-2 section honestly admits failed edit + false cycle-1 claim; limitations intact"
    - "SDK analyze clean; SDK tests 43/43 (rerun)"
    - "Root analyze clean; root tests 73/73 (rerun)"
    - "flutter build linux --debug PASS"
    - "PBF sha256 cdf25842...1be7e59 = manifest sourceSha256; 58 cells; manifest intact"
    - "0 assets//tool/ files in 957ab7a..9bddfe2; no write APIs in code"
    - "Cross-process determinism: FNV-1a identical across fresh VMs (0.3333 for test footprint); ADR/README deterministic claims now true"
  criteria_failed:
    - criterion: "dart format --set-exit-if-changed clean (battery gate)"
      evidence: "exit 1, 97 files 1 changed: estimate_clip_test.dart unformatted in committed 9bddfe2 (reproduced in fresh clone; cycle-2 verified 97/0 at 0d7b00e); evidence claims 'dart format clean'"
      severity: minor_functional_gate
    - criterion: "Wired-path regression test pins the estimate to the fogoHeightJitter seed (cycle-2 mandate)"
      evidence: "10/10 fresh-process passes with Object.hashAll reverted at renderer.dart:412; analytic: full jitter domain shifts roof row 1.225px vs 2.0px assertion window (fov 36.87 -> centerDepth 384, scale 0.41865, sy 110.82-112.05, spec 111.64) - no jitter value can fail it; evidence claims 'fails the pixel assertion in the overwhelming majority of runs'"
      severity: major
  out_of_scope_changes: []
  test_quality:
    passed: 116
    failed: 0
    missing: ["jitter-seed guard on the wired path (band + flag fallback ARE guarded)", "direct depth-ordering test (carried note)"]
  risks_introduced:
    - "Suite is blind to a one-line revert of the R1 wiring (false-green shape of cycle 2 persists one level deeper)"
    - "Third consecutive cycle with an unexecuted check asserted as passed (Rule 11 pattern)"
  debt_introduced:
    - "Unformatted estimate_clip_test.dart until dart format applied"
    - "Pre-existing: tracked .dill cache dirties per test run; railDisused #5D6879 override; near-clip margin undocumented"
  documentation_gaps:
    - "Evidence: 'dart format clean' false; 'fails the pixel assertion in the overwhelming majority of runs' false"
  notes:
    - "Audit cycle 3 of 3: three cycles without approval -> BLOCKED escalation per org rule"
    - "R1 production fix itself is correct, surgical, and verified; remaining fixes are one format command, one test-window tightening, two evidence sentences"
  next_action: forward_to_orchestrator
```

---

# Delivery Audit — Cycle 4 (revision `ec0e6a5` on top of `9bddfe2`)

- **Delivery under audit:** git `ec0e6a5` (current HEAD)
- **Auditor:** Delivery Auditor (independent rerun, 2026-10-22)
- **Audit cycle:** 4 — **user-authorized final cycle** after the cycle-3
  BLOCKED escalation (user explicitly accepted the exception to the
  3-cycle rule)
- **Revision diff `9bddfe2..ec0e6a5`:** 4 files, +324/−31 — this audit
  report, the evidence file, `renderer.dart` (pure extraction of the
  estimate definition), `estimate_clip_test.dart` (new golden + honest
  pixel-test scope). 0 files under `assets/`/`tool/`.

## Status

**APPROVED_WITH_NOTES** — every cycle-3 finding is fixed and independently
verified, every battery criterion reproduces clean, and — decisive for a
delivery with this audit history — the new guard claims were **empirically
re-tested both ways** (regression live → suite red; documented limitation →
suite green exactly as documented). No falsifiable claim remains.

## Requirements Validation (cycle 4, all independently reproduced)

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | **F1: format gate** | ✅ PASS | `dart format --set-exit-if-changed --output=none lib test packages/fogo_map_sdk/lib packages/fogo_map_sdk/test` → `Formatted 97 files (0 changed)`, **exit 0** — in the working tree **and** in a fresh `git clone` checked out at `ec0e6a5` (i.e. the committed state, not working-tree drift) |
| 2 | **F2: estimate definition extracted, renderer delegates** | ✅ PASS | `renderer.dart:18-32` `fogoEstimatedHeightMeters` = band (90/350/1500/6000 → 4.5/7.5/12/21/30 m) + `fogoHeightJitter(coordinates) * 4`; `renderer.dart:425-436` `_estimatedHeightPx` measures the footprint, then delegates in one call (`renderer.dart:433-435`); **no local band logic, no `Object.hashAll`** in the estimate path. The `9bddfe2..ec0e6a5` renderer diff is a **pure extraction**: band bases/thresholds byte-identical, only the code moved |
| 3 | **Golden pins the shared function against an independent spec** | ✅ PASS | `estimate_clip_test.dart:68-97` "estimated height matches the ADR-0005 specification": `fogoEstimatedHeightMeters` vs `_specEstimated` (independent band+FNV-1a reimplementation, lines 25-39) across 50/89.99/90/349.99/350/1499.99/1500/5999.99/6000/12000 m² — all band boundaries covered |
| 4 | **Pixel test honest scope** | ✅ PASS | Renamed "renderer extrusion consumes the shared estimate function" (`estimate_clip_test.dart:163`); comment (lines 164-168) states sub-pixel jitter steps are pinned by the golden, not the pixel row; **no claim anywhere that pixels pin the seed**; flag fallback (`estimateBuildingHeights: false` → flat roof) still asserted (lines 258-283) |
| 5 | **Seed-guard claim is true (empirical, both directions)** | ✅ PASS | See "Revert experiments" below — regression of the shared seed → suite red 4/4 fresh processes; renderer-path-only regression → suite green 3/3, exactly the documented limitation |
| 6 | SDK `flutter analyze` | ✅ PASS | "No issues found" |
| 7 | SDK `flutter test` | ✅ PASS | `+44: All tests passed!` (43 + 1 new golden) |
| 8 | Root `flutter analyze` | ✅ PASS | "No issues found" |
| 9 | Root `flutter test` | ✅ PASS | `+73: All tests passed!` |
| 10 | `flutter build linux --debug` | ✅ PASS | `✓ Built build/linux/x64/debug/bundle/fogo` |
| 11 | PBF sha256 + manifest | ✅ PASS | Recomputed `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` = expected = `assets/map/manifest.json` `sourceSha256` |
| 12 | Protected areas `957ab7a..HEAD` | ✅ PASS | 6 files total, **0** under `assets/`/`tool/` (pathspec diff empty — byte-verified); 0 write-API/`dart:io`/`MethodChannel` hits in the code portion of the diff |
| 13 | `Object.hashAll` confined | ✅ PASS | In `packages/fogo_map_sdk/lib`: only `road_geometry.dart:84,88` (`FogoRoadGeometryMerger._deduplicate` within-process buckets, pre-existing) + the doc comment explaining why it is not used for estimates |
| 14 | Evidence file cycle-3 section honest | ✅ PASS | Admits both findings ("process failures on my side"), labels the prior "overwhelming majority" claim false, describes the golden as the seed guard and the pixel test as band/flag/wiring only — all verified accurate; every post-cycle-3 claim (format 97/0 exit 0, SDK 44/44, root 73/73, build PASS) reproduced by this rerun |
| 15 | Commit message `ec0e6a5` honest | ✅ PASS | "shared pure function… renderer delegates to; a golden pins it against an independent spec implementation across all band boundaries. The pixel test keeps its real job (band/flag/wiring) with honest documentation" — each clause independently verified above |

## Revert experiments (decisive cycle-4 evidence)

Run in a throwaway clone of `ec0e6a5` under `/tmp/opencode/` (delivery repo,
tests, and history untouched; the only main-repo working-tree change remains
the pre-existing tracked `.dill`):

- **A — renderer-path regression reintroduced** (`_estimatedHeightPx` patched
  back to inline `Object.hashAll` band logic, shared function + golden
  untouched): `estimate_clip_test.dart` **passes 3/3 fresh processes**. The
  suite is blind to this specific revert — which is precisely what the
  delivered documentation now says (pixel test guards band/flag/wiring, not
  the seed). Honest limitation, confirmed, no false claim attached.
- **B — shared seed regression reintroduced** (`fogoHeightJitter` body
  patched to `Object.hashAll`): suite **fails 4/4 fresh processes** — the
  golden "estimated height matches the ADR-0005 specification" red in
  runs 1-3, the FNV-1a spec test red in 4/4 (run 4's golden pass is the
  analytically expected 1-in-16 random jitter coincidence; the suite still
  goes red via the spec test). This is the exact defect class of cycles 1-2,
  and the delivered golden catches it. The cycle-3 mandate — a regression
  test that actually guards the seed — is met at the level the code now
  guarantees (the shared function); the guard is probabilistic per process
  (~15/16 golden alone, ~1−(1/16)³ ≈ 99.98% with the FNV spec test) and
  empirically verified.

## Deviations (cycle 4)

None blocking. Notes for the record:

1. **Residual, documented and accepted:** a future edit that makes
   `_estimatedHeightPx` bypass the shared function would pass the suite
   (experiment A). Accepted because (a) it is documented honestly in the
   delivered test and evidence, (b) the delegation is one line, read-verified
   here, and (c) the pixel test still guards band/flag/wiring on the wired
   path. Not a false claim; a declared limitation (Rule 13 satisfied).
2. Wording nit: ADR-0005 specifies "deterministic, coordinate-seeded"
   estimates; the FNV-1a constants are the implementation choice, pinned by
   the golden pair rather than by ADR text. The test comment "FNV-1a seed
   specified in ADR-0005" is loose by one degree; immaterial to guarding.
3. Carried pre-existing (not blockers, unchanged from cycles 1-3): tracked
   `.dill` build cache dirties on every test run (housekeeping untrack
   recommended); app `railDisused #5D6879` override (`4d5faf5`); no direct
   depth-ordering (painter's sort) test; polygon near-clip `near × 4` margin
   undocumented.

## Risks

- Estimate determinism now rests on a one-line delegation; a deliberate
  rewrite of `_estimatedHeightPx` would regress silently (experiment A).
  Mitigation in place: shared function is the single definition, golden
  guards it, and any such rewrite would re-duplicate band logic — a visible
  diff pattern for review.
- No new risks introduced by `ec0e6a5`; the extraction reduces surface area
  (one definition instead of two places to drift).

## Test Evidence (cycle 4)

- SDK **44/44**, root **73/73** → 117 passed, 0 failed (rerun).
- Analyze clean both; format 97/0 exit 0 (tree + fresh clone); Linux debug
  build PASS; PBF sha exact.
- Guard strength empirically re-tested both directions (A green 3/3, B red
  4/4) — no claim in the delivery rests on unexecuted checks.
- Missing: none material. Depth-ordering direct test remains a carried note
  (painter's algorithm accepted by ADR-0005).

## Documentation Validation

- Evidence file cycle-3 section and commit message `ec0e6a5`: every factual
  claim reproduced (format 97/0, 44/44, 73/73, build PASS, golden/pixel
  division of labor). ADR-0005's "deterministic, coordinate-seeded" is now
  true of shipped behavior and guarded by tests.
- No documentation gaps remain for this delivery.

## Auditor Limitations (Rule 13)

- Linux x64, Flutter 3.47.1 stable only; release-mode AOT not sampled (the
  seed is pure integer arithmetic — deterministic by construction on all
  platforms).
- Revert experiments sample 3-4 fresh processes per direction; the analytic
  bounds (1-in-16 golden coincidence; 2.0 px window vs ~1.2 px signal from
  cycle 3) make the conclusions exact, not statistical.
- Fresh-clone format check ran without `pub get` (dart format does not need
  package resolution; count 97 matches the full expected file set).
- Pixel verification remains statistical/programmatic, not human visual
  review.

## Final Recommendation

**APPROVED_WITH_NOTES** → `instrum-orchestrator` → user. All cycle-3
findings fixed and verified; the full battery reproduces clean in both the
working tree and a fresh clone of the delivered commit; and the two claims
that matter most given this task's audit history — the golden guards the
seed, the pixel test does not and says so — were both empirically
re-tested. Notes record the honestly-documented residual limitation and
four pre-existing carried items; none warrant another revision cycle.

```yaml
delivery_audit:
  task_id: TASK-0005
  work_packages_reviewed: [TASK-0005, ENG revision ec0e6a5]
  verdict: APPROVED_WITH_NOTES
  criteria_met:
    - "F1: dart format --set-exit-if-changed exit 0, 97 files 0 changed, in working tree AND fresh clone of ec0e6a5"
    - "F2: fogoEstimatedHeightMeters (renderer.dart:18-32) = band 90/350/1500/6000 -> 4.5/7.5/12/21/30 + fogoHeightJitter*4; _estimatedHeightPx delegates one-line, no Object.hashAll; extraction pure vs 9bddfe2"
    - "Golden estimate_clip_test.dart:68-97 pins shared function vs independent _specEstimated across all band boundaries"
    - "Pixel test renamed with honest scope (lines 163-168); no claim that pixels pin the seed; flag fallback still asserted"
    - "Seed-guard claim empirically verified: shared-seed revert -> suite red 4/4 fresh processes (golden 3/4, FNV spec test 4/4)"
    - "Renderer-path revert -> suite green 3/3, exactly the documented limitation (honest, not a false claim)"
    - "SDK analyze clean; SDK tests 44/44 (rerun)"
    - "Root analyze clean; root tests 73/73 (rerun)"
    - "flutter build linux --debug PASS (bundle/fogo)"
    - "PBF sha256 cdf25842...1be7e59 recomputed = manifest sourceSha256"
    - "0 assets/ or tool/ files in 957ab7a..ec0e6a5; 0 write APIs in code diff; Object.hashAll only in merger dedupe + doc comment"
    - "Evidence cycle-3 section + commit message ec0e6a5: every claim independently reproduced; no overstatement"
  criteria_failed: []
  out_of_scope_changes: []
  test_quality:
    passed: 117
    failed: 0
    missing: ["direct depth-ordering (painter's sort) test (carried note, accepted by ADR)"]
  risks_introduced: []
  debt_introduced:
    - "Accepted residual (documented in delivery): suite blind to a future renderer-path bypass of the shared estimate function; one-line delegation is the mitigation point"
    - "Pre-existing carried: tracked .dill cache dirties per test run; railDisused #5D6879 app override (4d5faf5); near-clip near x 4 margin undocumented"
  documentation_gaps: []
  notes:
    - "User-authorized final cycle (4 of 4) after cycle-3 BLOCKED escalation"
    - "Golden seed-guard detection is probabilistic per process (~15/16 alone; ~99.98% with the FNV spec test) - role claim verified, empirically 4/4"
    - "ADR-0005 pins 'deterministic, coordinate-seeded'; FNV-1a constants pinned by the golden pair, not ADR text (wording nit in test comment)"
  next_action: forward_to_orchestrator
```
