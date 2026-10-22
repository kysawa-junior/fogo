# Delivery Audit — TASK-0006 (Cartographic refinement of the 3D engine)

- **Auditor:** delivery-auditor (independent rerun, cycle 1)
- **Date:** 2026-10-22
- **Delivery commit:** `7e13b78` on top of `11cf3a3`
- **Decision record:** `docs/adr/ADR-0006-cartographic-refinement.md`
- **Evidence under audit:** `docs/agent-work/handoffs/TASK-0006-cartographic-refinement-evidence.md` + `TASK-0006-validation-evidence/` (3 PNGs)

## Status

**REVISION_REQUIRED** — implementation, tests, builds and user constraints all
verify; one evidence-file metric fails independent recomputation and must be
corrected before approval. Revision is **documentation-only** (no code, no
tests, no history changes).

```yaml
delivery_audit:
  task_id: TASK-0006
  work_packages_reviewed:
    - ADR-0006 (decision record, 7 decisions)
    - evidence: TASK-0006-cartographic-refinement-evidence.md
    - code: road_geometry.dart, renderer.dart, camera.dart
    - tests: cartography_test.dart, perf_benchmark_test.dart
  verdict: REVISION_REQUIRED
  criteria_met:
    - "Rerun SDK analyze clean + flutter test 53/53 (auditor run, 2026-10-22)"
    - "Rerun root analyze clean + flutter test 73/73 (auditor run)"
    - "dart format --set-exit-if-changed: 99 files, 0 changed, exit 0"
    - "flutter build linux --debug PASS (bundle/fogo)"
    - "PBF sha256 cdf25842…1be7e59 unchanged"
    - "git 11cf3a3..HEAD touches no assets/ or tool/ files (name-only diff listed in full)"
    - "FogoCartography ramps/bucket/casingPad/halfWidthMeters present (road_geometry.dart:12-88)"
    - "Surface cache keyed (zoomBucket, metre halfWidth), buffers in absolute mercator metres via FogoProjection.project (road_geometry.dart:621-661); pan identity + bucket rebuild proven by test and reproduced live"
    - "renderer uses FogoCartography.widthPx at the bucket for casing/bridge/tunnel/fill/oneway (renderer.dart:555,573,590,607,623,664)"
    - "Pitched order roads→buildings, flat buildings→roads (renderer.dart:167-176); occlusion pixel test passes"
    - "_drawOnewayArrows: edge exclusion, per-run carried reset, view test, cap 250, 120px floor (renderer.dart:645-737); junction pixel test passes"
    - "selectPlaceLabels pure selector with kind ranges city≤14 / town 10–15 / village 12–15 / suburb 13–16.5, budgets 8/12/18 (renderer.dart:742-779)"
    - "Area seam same-colour hairline (renderer.dart:298-319); seam pixel test passes"
    - "camera.dart projectMeters/projectMetersPolyline/projectMetersPolygon/metersDepth present (camera.dart:194-234)"
    - "Old fixed-width _roadWidth table (11/10/9/6/5.75/5/4.25/3.5/2.75/2 + fixed +1.2/+1.6 pads) present at 11cf3a3, absent at HEAD (grep)"
    - "Palette untouched: git diff 11cf3a3..HEAD over style.dart / fogo_map_style.dart is empty"
    - "No dart:io/webview/Mapbox added (dart:io in window_close_handler.dart pre-exists from initial commit; Mapbox appears only in palette-inspiration comments)"
    - "FogoSmooth endpoint-exact with corner split; junction nodes immovable (road_geometry.dart:714-800)"
    - "3D/extrusions preserved: extrusion pipeline unchanged, 3d captures render, roof-coverage metric reproduced 3.47→4.68% (claim 3.53→4.77)"
    - "Benchmark reproduced live: pan 2313 µs < bucket rebuild 3441 µs (claim 2006 < 3192, same ordering/ratio)"
    - "Capture stats reproduced within probe-recipe noise for 7/8 metrics (table below)"
    - "Docs updated: ARCHITECTURE.md +11, both READMEs, ADR-0006"
    - "All declared limitations re-verified in code and declared honestly"
  criteria_failed:
    - criterion: "Evidence table row '3D engagement 42.6% → 37.8%' is a measured, like-for-like comparison"
      evidence: >
        Auditor recomputed diff(topdown,3d) for both versions across 70 candidate
        600×700 crops (TASK-0005's stated recipe), three probe boxes, step 2,
        and thresholds 4–48. At every matched (box, threshold) pair v5 and v6
        measure within ~1.2pp (full frame thresh8: 43.9 vs 43.0; interior:
        45.5 vs 44.6; TASK-0005 crop (780,40): v5=42.6 — the BEFORE value
        reproduces exactly — but v6 at that same crop is 41.6, not 37.8). No
        single probe recipe yields the claimed pair. The implied −4.8pp drop is
        an artifact of mismatched recipes; the honest reading is "engagement
        essentially unchanged (~42–45%), perspective renders, toggle works",
        which still satisfies the constraint it was measuring (3D preserved).
      severity: moderate (evidence accuracy; Rule 11 — not an implementation or acceptance-criteria defect)
  out_of_scope_changes: []
  test_quality:
    passed: 53
    failed: 0
    missing: []
  risks_introduced: []
  debt_introduced:
    - "Soft arrow cap: `drawn >= 250` is checked per road before drawing, so one road's arrows can push the frame total slightly past 250 (renderer.dart:658). Evidence says 'cap 250' without this nuance — cosmetic, bounded by one road's arrow count."
    - "Junction-edge exclusion applies at clipped-run ends only; junction nodes interior to a merged way can still receive an arrow (relevant only where the merger fused same-style ways across a junction). Not declared; visually minor."
  documentation_gaps:
    - "R1 (required): evidence file engagement row (37.8%) not reproducible under the recipe that produced the 42.6% BEFORE value."
    - "N1: probe recipe underspecified — 'map area, 2-px grid' names no box, no colour tolerance, no diff threshold; auditor probes shift absolutes by 0.1–0.8pp (deltas and directions all hold). Specify the recipe in the evidence file."
    - "N2: TASK-0005's flat2 capture (toggle-back restores flat exactly) has no TASK-0006 counterpart, so that property is not re-proven for v6."
  notes:
    - "Verdict is REVISION_REQUIRED solely for the evidence-file correction (docs sector). Implementation is sound; do not touch code, tests or history."
    - "Recomputed capture statistics (auditor probes, Python/Pillow):"
    - "z16 residential fill: 11.56→11.00% interior (claim 11.74→11.18; Δ −0.56pp both) — reproduces"
    - "z16 secondary fill: 3.42→3.71% interior (claim 4.21→4.56; Δ +0.29 vs +0.35) — direction reproduces, absolute shifts with probe box"
    - "z16 arrow pixels: 0.47→0.44% interior (−6.4% rel; claim −6% declared limitation) — reproduces"
    - "z16 3D roof coverage: 3.47→4.68% interior (claim 3.53→4.77) — near-exact"
    - "Structural diff z16 pair: 3.3% full-frame (claim 3.2) — reproduces; captures are comparable"
    - "Regional place-label components: 35→19 at tol12/min3 (claim 34→20) — reproduces; 34 exact at min4"
    - "Regional arrows/suburb-label family: 0.25→0.01% interior (claim 0.40→0.08) — collapse reproduces and exceeds the claim; BEFORE absolute is probe-box dependent"
    - "3D engagement: see criteria_failed."
  next_action: revision_for_sector
```

## Requirements Validation

User directive → ADR-0006 decisions, independently verified:

| Directive item | ADR decision | Verdict | Evidence (auditor-verified) |
|---|---|---|---|
| Street widths | per-class ramps on quarter-zoom buckets, width-scaled casing pad | MET | `FogoCartography` (road_geometry.dart:12–88); ramps continuity/monotonicity/hierarchy test passes; old fixed table gone (grep at HEAD vs present at 11cf3a3:532–593) |
| Tessellation/joins | buffered surfaces, miter limit, round joins, cap arcs; smoothing screen-constant per bucket | MET | `FogoRoadSurfaceBuilder` unchanged core; `FogoSmooth` endpoint-exact + 32° corner split; step/epsilon now in caller space (8 px → metres/bucket) |
| Junctions | arrow edge exclusion, per-run reset, 120px floor, cap 250, screen test | MET | renderer.dart:645–737; pixel test "junction node must stay arrow-free" passes; z16 arrow pixels down (reproduced) |
| Zoom generalization | label kind ranges + priority budgets; class visibility gates retained | MET | `selectPlaceLabels` pure (renderer.dart:742–779), unit-tested; regional labels 35→19 reproduced |
| Depth composition | pitched: roads→extrusions; flat: roofs under streets | MET | renderer.dart:167–176; pitch-occlusion pixel test passes; roof coverage 3.47→4.68% reproduced |
| Labels | city ≤14, town 10–15, village 12–15, suburb 13–16.5; budgets 8/12/18 | MET | code + tests + capture reproduction |
| Area seams | same-colour hairline | MET | renderer.dart:298–319; seam-closure pixel test passes |
| Pan-stable geometry | cache keyed (bucket, metre half-width), absolute-mercator buffers | MET | road_geometry.dart:621–661; `identical()` pan test + rebuild-on-crossing test; benchmark reproduced live (2313 < 3441 µs) |
| Preserve palette | untouched | MET | `git diff 11cf3a3..HEAD` over both style files empty; no color-only masking (all fixes geometric; hairline is same-colour) |
| Preserve 3D features | extrusions, pitch/bearing, LOD gate intact | MET | extrusion pipeline unchanged; 3d captures render; occlusion improved per test |
| No webview/Mapbox/dart:io | — | MET | none added; pre-existing `dart:io` (window_close_handler.dart, initial commit) untouched |
| No invented data | — | MET | PBF sha256 unchanged; no `assets/`/`tool/` files in diff; estimate path unchanged (ADR-0005) |

## Engineering Validation

- SDK: `flutter analyze` clean; `flutter test` **53/53** (auditor rerun; 44 prior + 9 new verified by test count).
- Root: `flutter analyze` clean; `flutter test` **73/73** (auditor rerun).
- `dart format --set-exit-if-changed --output=none lib test packages/fogo_map_sdk/lib packages/fogo_map_sdk/test` → **99 files, 0 changed, exit 0** (auditor rerun).
- `flutter build linux --debug` → **PASS** (auditor rerun).
- `sha256sum tool/map_data/raw/sudeste-latest.osm.pbf` → `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` (matches).
- `git diff --name-only 11cf3a3..HEAD` = 13 files: docs (5) + PNGs (3) + SDK src (3) + SDK tests (2) + READMEs. **No `assets/`, no `tool/`, no pubspec, no app code.**
- Cache-safety: `FogoMapView` holds `_surfaceCache`/`_renderData` as state fields (view.dart:68,317), so the Expando cache persists across paints — the pan-reuse claim holds in the widget path, not just in tests.
- Width/pad arithmetic: cache key uses the same `bucketScale` derivation as `FogoCartography.halfWidthMeters`; px→metre conversion exact-double stable, so the `==` key comparison is sound.

## Design Validation

- Design constraints are cartographic (hierarchy stability, label legibility); no UX redefinition: no widget/GestureDetector/interaction changes in the diff (renderer/camera/road_geometry only + docs).
- Flat-view semantics unchanged (`paint()` flat branch keeps TASK-0005 order); pitched change is depth-correct per ADR-0006 §3.

## Test Evidence

`cartography_test.dart` (8 tests) + `perf_benchmark_test.dart` (1) — all pass on auditor rerun:

- Ramp continuity (step 0.05 across z3–20), jump < 0.25 px, class hierarchy at z13/16/19 — guards ADR-0006 §1.
- Bucket quantization (quarter-zoom) — guards §1/§2 boundary behaviour.
- Casing pad monotonic + clamps (0.8–2.4) — guards §1.
- Cache `identical()` across pan within bucket, rebuild on crossing — guards §2 (this is the structural zero-rebuild proof the benchmark refers to).
- Junction arrow exclusion — full-painter pixel test, 0 arrow px within 8 px of the shared node, >0 on the arms — guards §4.
- Label ranges/budget/priority incl. explicit-budget override — guards §5.
- Pitch occlusion — pixel test: wall occludes street behind at pitch 45, street visible outside the footprint — guards §3.
- Seam closure — pixel test over the shared edge columns — guards §6.
- Benchmark — measured medians with an honestly loose `pan < rebuild` assert; the structural identity proof is correctly delegated to cartography_test, and the test documents itself as "measured benchmark, not a golden".

Judgement: these guard the ADR claims at the right level (behavioural/pixel/identity, not magic constants). No missing coverage material to the brief.

## Documentation Validation

- ADR-0006 accepted, dated, extends ADR-0005 ✓. ARCHITECTURE.md and both READMEs updated consistently with the implementation ✓.
- Evidence file: causes table matches code diagnosis (old `_roadWidth`/`_paintOneway` verified gone at HEAD, present at base) ✓. Limitations section honest ✓ (see below).
- **Gap (R1):** the "3D engagement 42.6% → 37.8%" row is not reproducible as a like-for-like measurement (details in Status YAML). Rule 11 requires evidence to hold; this cell must be corrected to the matched-recipe value (~41.6% at the recipe that reproduces 42.6%, or ~43% full-frame) with the reading unchanged ("perspective renders, toggle works").
- **Gap (N1):** probe recipe underspecified (box/tolerance/threshold unstated) — auditor probes shift absolutes by up to 0.8pp while all deltas/directions hold.
- **Gap (N2):** no v6 flat2 capture; "toggle back restores flat" not re-proven this cycle.

## Deviations

- None in scope. Out-of-scope check: diff confined to SDK engine + docs + captures. No protected areas (`assets/`, `tool/`, palette, app code) touched.

## Risks

- None introduced at runtime. Width jumps at bucket boundaries are bounded (<0.25 px/test) and deliberate per ADR.
- Residual (declared): painter's-algorithm occlusion, static label budgets, debug-only benchmark, no hysteresis, ~6% net arrow reduction — all confirmed in code and honestly listed.
- Residual (undeclared, minor): interior-junction arrows on merged ways (see debt_introduced) and the soft 250 cap nuance.

## Required Revisions

- **R1 (docs sector only — evidence file):** correct the 3D-engagement row to a matched-recipe measurement (auditor values: v5 42.6% / v6 41.6% at the TASK-0005 600×700 crop recipe; 43.9/43.0 full-frame; the reading "perspective renders, toggle works" stands), and state the probe recipe (box, colour tolerance, diff threshold) for the capture table. No code, test or history changes.

## Final Recommendation

Return to orchestrator as **REVISION_REQUIRED (cycle 1)** routed to the
documentation sector for R1 only. The engineering and design sectors need no
action: every implementation claim in ADR-0006 was independently re-verified
(analyze/test/format/build/hash rerun clean; code inspected; 7/8 capture
metrics reproduced, several near-exactly). Once the evidence file's engagement
row and probe recipe are corrected, this delivery is expected to approve
without a further engineering cycle.

---

# Delivery Audit — TASK-0006 (cycle 2)

- **Auditor:** delivery-auditor (independent rerun, cycle 2)
- **Date:** 2026-10-22
- **Revision under audit:** commit `7a76409` on top of `7e13b78` (docs only)
- **Cycle-1 finding addressed:** R1 — evidence-file 3D-engagement row mixed two probe recipes

## Status

**APPROVED_WITH_NOTES** (audit cycle 2 of 3)

```yaml
delivery_audit:
  task_id: TASK-0006
  cycle: 2
  verdict: APPROVED_WITH_NOTES
  revision_verified:
    - "R1 resolved: evidence row now 42.6% → 42.1% under a single matched probe, replacing the mismatched 42.6% → 37.8% pair"
    - "Probe recipe stated in evidence file: TASK-0005 probe x∈[460,1060), y∈[80,780), 2-px grid, per-channel tolerance 12, applied identically to both generations (resolves N1 substance)"
    - "Cycle-1 auditor notes added to declared limitations: merged-way interior junction arrows (interior junction nodes of merged ways not edge-excluded), soft per-road 250 cap (per-iteration check, not atomic), no v6 flat2 frame (N2 now declared, Rule 13)"
  criteria_met:
    - "Auditor recomputed engagement under the stated matched recipe (independent Python/Pillow rerun): v5 3d-vs-flat2 = 42.6% EXACT, v5 3d-vs-topdown = 42.6% EXACT (baseline choice immaterial), v6 3d-vs-topdown = 42.1% EXACT — both table cells reproduce with zero deviation"
    - "git show --stat 7a76409: exactly 1 file (evidence.md), 17+/2−; patch inspected line-by-line: engagement row + recipe paragraph + 3 limitation additions, all other table rows byte-identical"
    - "git diff 7e13b78..7a76409 -- ':!docs' is EMPTY: no code, test, or history change since cycle-1 verification; analyze/test/format/build evidence from cycle 1 remains valid (code is byte-identical)"
    - "git diff --name-only 11cf3a3..7a76409 = same 13 files as cycle 1 (docs 5 + PNGs 3 + SDK src 3 + SDK tests 2 + READMEs); no assets/, no tool/, no protected areas"
    - "Evidence file honestly discloses the earlier mixed-probe draft and attributes the catch to the audit"
  criteria_failed: []
  out_of_scope_changes: []
  test_quality:
    passed: 53
    failed: 0
    missing: []
    note: "Cycle-2 diff is docs-only and proven byte-identical outside docs/; cycle-1 reruns (53/53 SDK, 73/73 root, format 99/0, linux debug build PASS) carry over unchanged."
  risks_introduced: []
  debt_introduced:
    - "No new debt this cycle. Cycle-1 undeclared items (merged-way interior junction arrows, soft 250 cap) are now declared limitations in the evidence file; remaining declared debt unchanged (painter's-algorithm occlusion, static label budgets, debug-only benchmark, no hysteresis, ~6% net arrow reduction)."
  documentation_gaps:
    - "N2 carried as DECLARED limitation (no v6 flat2 toggle-back capture; TASK-0005 set supplies the matched baseline). Declared, honest, acceptable per Rule 13 — not a blocker."
    - "Cosmetic: evidence file labels the general capture-table recipe 'auditor-verified'; auditor verified all deltas/directions under independent probes (within the 0.1–0.8pp probe-noise band reported in cycle 1) and the engagement row exactly, but did not re-derive every absolute at the exact stated general-crop coordinates. Wording is generous; conclusions unaffected."
  notes:
    - "Working tree (not any commit) has a modified tracked build-cache artifact packages/fogo_map_sdk/build/test_cache/...dill.track.dill — test-run side-effect, absent from 11cf3a3..7a76409; repo housekeeping only, no delivery impact."
    - "Engagement reading stands: 42.6% vs 42.1% is essentially unchanged — perspective renders, 3D preserved, toggle works. Constraint the metric measures is satisfied."
  next_action: forward_to_orchestrator
```

## Requirements Validation

R1 was the only required revision and it is fully resolved, exactly as
specified: matched-recipe values, recipe stated, notes added. No requirement
or acceptance criterion is affected — implementation claims were all verified
in cycle 1 and the code is proven unchanged since (empty diff outside docs/).

## Engineering Validation

Not re-run this cycle — deliberately. `git diff 7e13b78..7a76409 -- ':!docs'`
is empty, so the code under audit is byte-identical to the code that passed
analyze/test/format/build on the cycle-1 auditor run. Git-level identity is
stronger evidence than a rerun for a docs-only change.

## Design Validation

Unchanged from cycle 1; no code touched.

## Test Evidence

Cycle-1 reruns carry over (53/53 SDK, 73/73 root, format clean, build PASS)
— code proven identical. No test in the delivery diff changed.

## Documentation Validation

- Engagement row: `42.6% → 42.1%`, matched probe, honest disclosure of the
  earlier mixed-probe draft. ✓
- Probe recipe paragraph present and matches the recipe the auditor used. ✓
- Limitations now declare merged-way interior junction arrows, the per-road
  (non-atomic) 250 cap, and the absent v6 flat2 frame. ✓ (All previously
  cycle-1 notes.)

## Deviations

None. Commit 7a76409 touches one docs file; delivery diff is the same 13-file
set verified in cycle 1; no protected areas.

## Risks

None introduced. Residual declared limitations unchanged and honest.

## Required Revisions

None.

## Final Recommendation

**APPROVED_WITH_NOTES — forward to orchestrator for delivery.** The one
required revision (R1, documentation sector) is resolved and independently
reproduced to the exact digit (42.6% / 42.1%). Notes carried: declared
limitations on record (no v6 flat2 frame; painter's-algorithm occlusion;
static budgets; debug-only benchmark), a cosmetic wording generosity in the
evidence file, and a build-cache working-tree artifact outside all commits.
No further engineering or design action needed.
