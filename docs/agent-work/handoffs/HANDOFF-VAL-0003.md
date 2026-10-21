# Validation handoff — VAL-0003 Offline dark map tiles

**Task:** TASK-0003 / ENG-0003  
**Validator:** Quality & Performance Engineer  
**Result:** 7/9 acceptance criteria verified; AC-03 and AC-07 remain unverified. Not an approval verdict.

## Criterion-by-criterion verdict

| Criterion | Result | Evidence |
| --- | --- | --- |
| VAL-0003 AC-01 — background/palette and omission of roads, buildings, labels | **PASS** | `python3 -m unittest discover -s tool/map_data/tests -v`: 5/5 pass. Pixel assertions cover background and approved area/water/rail palette; synthetic forbidden-only inputs emit no XYZ PNG. Generator reads only `areas`, `wl`, and `rail`. |
| AC-02 — deterministic generation and current-region XYZ coverage | **PASS** | Generator determinism test compares generated metadata and SHA-256 for two temp outputs. Independent audit decoded all 21,828 present tiles, checked 256×256 PNGs, matched file count/bytes to manifest, recomputed z7–18 bounds from bbox, and verified every tile path is inside bounds. Full-region regeneration was not run. |
| AC-03 — local tiles, dark missing/out-of-bounds behavior, no tile networking | **FAIL / evidence gap** | Runtime test verifies local URL, `AssetTileProvider`, `tileBounds`, z7–18 limits, null `fallbackUrl`, and `blank.png` pixel `[1,1,10,255]`. Flutter `AssetTileProvider` source uses `AssetImage`; app config has no remote map-tile URL/provider. Inspected outside-coverage capture is dark. **No test actually requests a missing/in-bounds or out-of-bounds tile and asserts rendered error image plus zero network calls**, as required by VAL-0003 testing requirements. Static evidence is strong but not runnable evidence for full criterion. |
| AC-04 — nearest native zoom and fixed-width roads through z20 | **PASS** | `offline_map_runtime_test.dart` requests z7 below range and z18 above range. `road_surface_test.dart` checks per-class screen widths at z7, 12, 14, 15, 16, 18, and 20. |
| AC-05 — partial viewport overlap and outside-only background | **PASS** | `viewportIntersectsCoverage` tests partial overlap true/outside false; workspace test checks vector layer absent outside coverage. Inspected `region-edge-final.png` and `outside-final.png`; outside map canvas is dark (`#01010A`) and retains OSM attribution. |
| AC-06 — overlay controls/order, no duplicate roads, preserved rendering | **PASS** | Generator omits road/building/label records; painter tests verify transparent/static-feature separation, building/label/POI toggles, exact bbox clipping, bridge/tunnel treatment, road-label-over-road order, and palette. Road/filter/geometry tests pass. Workspace test asserts tile < vector < route < markers and attribution. Test emits a non-fatal missed-hit warning at `workspace_semantics_test.dart:221`; see limitations. |
| AC-07 — README/architecture/ADR and unchanged TASK-0001/2 reports | **FAIL / unverifiable history** | README, `docs/ARCHITECTURE.md`, and ADR-0003 document local generation, hybrid layers, z7–18, nearest-level scaling, dark outside coverage, and no runtime tile network. No `.git` metadata/baseline exists, so historical-report immutability cannot be established. Current SHA-256 values are recorded below, but are not a baseline comparison. |
| AC-08 — actual tile/build measurements | **PASS** | Independent disk/manifest/build measurements below. |
| AC-09 — formatting, targeted/full tests, analysis, build, visual evidence | **PASS with note** | All required commands below passed. Existing TASK-0003 visual captures inspected for all three cities, edge, and outside; captures were not freshly produced by this validation session. |

## Test strategy and exact checks

- **Generator/unit:** `python3 -m unittest discover -s tool/map_data/tests -v` — 5 tests passed in 0.041 s.
- **Dart format check:** `dart format --output=none --set-exit-if-changed lib test` — 82 files checked, 0 changed.
- **Targeted Flutter:** `flutter test --no-pub test/offline_map_runtime_test.dart test/vector_overlay_painter_test.dart test/workspace_semantics_test.dart test/road_surface_test.dart test/road_geometry_merger_test.dart test/road_projection_cache_test.dart` — 39 tests passed in 24.266 s; hit-test warning noted below.
- **Full Flutter:** `flutter test --no-pub` — 83 tests passed in 25.897 s; same warning.
- **Analysis:** `flutter analyze --no-pub` — no issues (analyzer reported 3.1 s).
- **Linux build:** `flutter build linux --debug --no-pub` — succeeded in 18.732 s (incremental build; pre-existing build cache).
- **Bundle:** `du -sb build/linux/x64/debug/bundle` — 184,297,877 bytes; sum of contained file sizes matched exactly.
- **First targeted test invocation** omitted `--no-pub`; Flutter auto-resolved dependencies and logged package downloads (`material_color_utilities 0.13.0`, `screen_retriever 0.2.2`, `test_api 0.7.12`). Subsequent targeted/full tests, analysis, and build used `--no-pub`. No PBF or raster tiles were downloaded; generator source reads only existing cells and manifest. The source PBF was already present locally (861,713,601 bytes).
- A first timing wrapper using `/usr/bin/time` did not run tests because that executable is absent; the successful targeted run used Bash timing.

## Artifact audit

- Manifest reports **63,114** bbox XYZ positions across z7–18; **21,828** nonblank PNGs totaling **38,508,278 bytes**. `blank.png` is **565 bytes**.
- Disk audit found exactly 21,828 matching files/38,508,278 bytes. All decoded as valid 256×256 PNGs; all computed per-zoom XYZ bounds matched the manifest. All 667 required `z/x` asset directories are declared, and the Linux bundle contains the same 21,828 PNGs and byte total.
- Current source inputs: `assets/map/cells/` and `assets/map/manifest.json`. `render_tiles.py` has no PBF/network path; `fetch_data.sh` is separate. No public raster URL found in runtime tile code.
- Build bundle measured **184,297,877 bytes**. Build was incremental, not a clean-build timing.

## Visual evidence inspected

Pre-existing TASK-0003 captures under `/tmp/opencode/task-0003/` (1920×1080; timestamped 2026-10-19 16:46–16:47):

- `city-marilia-final.png`
- `city-veracruz-final.png`
- `city-garca-final.png`
- `region-edge-final.png`
- `outside-final.png`

These show local dark base, live roads/labels, city/corridor coverage, clipped edge, and dark outside canvas with attribution. A current-session X11 root capture at `/tmp/opencode/val0003/root-current.png` was all black and unusable; therefore visual inspection relies on the task captures, not a fresh validation capture.

## Findings and limitations

- **Missing-tile test gap (AC-03):** add/execute a deterministic test that requests an absent local coordinate and an out-of-bounds coordinate, asserts `#01010A` image output and observes no network request. No implementation was changed here.
- Current runtime launch log contained **372** `Unable to load asset` / `Asset not found` messages for omitted blank-only tile paths. This is consistent with sparse assets and the configured local error image, not evidence of network fallback; it is noisy diagnostics and warrants engineering review.
- Full 63,114-position generation was not rerun (would rewrite generated product assets); determinism was exercised against temporary fixtures and actual assets/manifests were audited in place.
- Historical reports cannot be compared to a Git baseline. Current hashes only: TASK-0001 `067c91ef8ab826e24246e14facab3d704c5c8c48a27b523a16d7718258585507`; TASK-0002 `455e4da9d5f9d2816b7adbc30b71c7c98a89514f9c61430ab3e2b1915def5cea`.
- Repeated widget-test warning: `workspace_semantics_test.dart:221` taps “Garça” at a point intercepted by “Rotas e otimização.” It is non-fatal and reproducible; suite passes, but that tap/search-selection assertion is not reliable evidence of the interaction.
- No runtime frame-time or heap profile was collected. No concrete UI-thread blocker, memory leak, coroutine cancellation violation, dead code, or test flakiness was established. Project is Flutter; Compose recomposition audit is not applicable.

## Quality artifact

```yaml
quality_artifact:
  task_id: TASK-0003
  test_strategy:
    levels: [unit, integration, ui]
  criteria_verified:
    - {criterion_id: VAL-0003-AC-01, test_id: GEN-PIXEL-OMISSION, pass: true}
    - {criterion_id: VAL-0003-AC-02, test_id: GEN-DETERMINISM-COVERAGE-AUDIT, pass: true}
    - {criterion_id: VAL-0003-AC-03, test_id: RUNTIME-LOCAL-TILE-FALLBACK, pass: false}
    - {criterion_id: VAL-0003-AC-04, test_id: RUNTIME-ZOOM-ROAD-WIDTH, pass: true}
    - {criterion_id: VAL-0003-AC-05, test_id: VIEWPORT-INTERSECTION-UI-CAPTURES, pass: true}
    - {criterion_id: VAL-0003-AC-06, test_id: OVERLAY-PRESERVATION-REGRESSION, pass: true}
    - {criterion_id: VAL-0003-AC-07, test_id: DOCS-ADR-HISTORICAL-REPORTS, pass: false}
    - {criterion_id: VAL-0003-AC-08, test_id: TILE-BUNDLE-BUILD-MEASUREMENTS, pass: true}
    - {criterion_id: VAL-0003-AC-09, test_id: FORMAT-TEST-ANALYZE-BUILD-VISUAL, pass: true}
  recompose_audit:
    unstable_params: ["N/A — Flutter project; Compose audit not applicable"]
    fixed: []
  ui_thread_blockers: []
  cancellation_violations: []
  memory_findings: ["No heap profile collected; source uses viewport cell pruning; no leak established"]
  dead_code: []
  regressions: []
  coverage_delta: "not measured → not measured (83 Flutter tests passed; coverage instrumentation not run)"
```

## Files reviewed / modified

Reviewed: VAL-0003 and ENG-0003 work packages, approved spec, Flutter map layer/controller/painter/data/provider, generator/tests/tooling, manifests/assets/pubspec, README, architecture doc, ADR-0003, historical TASK-0001/2 reports, and referenced visual captures.

Modified: this handoff is the only source/document file written. Flutter test/build refreshed build and tool caches; no product code or approved spec/WP changed. Baseline file changes cannot be enumerated because workspace has no Git metadata.

## Recommended next agent

`engineering-lead` — resolve AC-03 test evidence gap, decide whether to quiet expected missing-asset diagnostics, and seek a historical-report baseline if one exists.

**Workflow status:** Validation evidence returned to engineering. Delivery Auditor verdict remains pending; no approval issued.
