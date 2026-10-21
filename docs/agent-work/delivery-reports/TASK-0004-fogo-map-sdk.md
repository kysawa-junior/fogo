# Delivery Audit — TASK-0004 F.O.G.O. Map SDK

**Auditor:** Delivery Auditor (independent; no implementation authorship)
**Date:** 2026-10-21
**Inputs:** ENG-0004 v2 (`docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md`), Master Brief
(`docs/agent-work/briefs/TASK-0004-master-brief.md`), approved spec
(`docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md`), HANDOFF-TASK-0004,
engineering completion / validation-evidence / raster-cleanup handoffs (+ both `.sha256`
inventories), ADR-0003/ADR-0004, README / docs/ARCHITECTURE.md / SDK README / tool README.

```yaml
delivery_audit:
  task_id: TASK-0004
  work_packages_reviewed: [ENG-0004-fogo-map-sdk.md v2]
  verdict: APPROVED_WITH_NOTES
  criteria_met:
    - AC-01 SDK boundary — rerun: root+SDK `flutter analyze` clean; grep of packages/fogo_map_sdk/lib shows no dart:io/MethodChannel/EventChannel/flutter_map; sdk_boundary_test.dart enforces forbidden imports+deps at source level; `archive` declared as direct dependency; latlong2 absent from package.
    - AC-02 projection/camera — rerun SDK `flutter test`: camera_projection_test (round-trip, 0°/45°, immutable camera validation, fit, events) + workspace_semantics (transient pitch, center/zoom persistence) all pass.
    - AC-03 gestures/selection — rerun: map_widget_test (drag, pinch, double-tap, wheel, fling, secondary-click/long-press selection, route independence) passes.
    - AC-04 data/clipping/errors/cache — rerun: data_source_test + map_widget_test (viewport cells, empty/outside status, corrupt-cell typed error without blocking camera, stale-manifest, LRU 64/24 + 8 MiB caps) pass; data_source.dart constants verified (l0CacheLimit 64, l1CacheLimit 24, maxDecompressedCellBytes 8 MiB, rootBundle + archive).
    - AC-05 rendering semantics — rerun: renderer_test (layer order/clipping, route polylines above map, height-only extrusion, label/POI toggles + collision) passes; 6 native X11 captures present (valid 1440x900 PNGs, capture logs recorded).
    - AC-06 height/generator — rerun `python3 -m unittest discover -s tool/map_data/tests`: 25/25 OK; manifest counters internally consistent (7+23=30 heightTag; rejected 0, unsupported 0); 7 numeric `height` values independently found in l1_1_1/l1_1_2/l1_7_2 cells; tool README documents grammar `^[0-9]+(?:\.[0-9]+)?$` metres, per-source-way counter semantics, no-download staging; requirements.txt now pins osmium==4.3.1.
    - AC-07 PBF hashes/semantic gate — current PBF SHA-256 cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59 == manifest sourceSha256 (rehashed by auditor); PBF size 861,713,601 and mtime 2026-10-18 unchanged since before TASK-0004 work; staged semantic-comparison record (58 cells, 0 height additions, only generatedAt) preserved in validation evidence. Historical before/after pair not independently reproducible (declared limitation, no Git baseline).
    - AC-08 native region evidence — 6 native captures present and distinct (Marília city, Vera Cruz, Garça, corridor, coverage edge, outside coverage); outside-coverage capture is a 26 KB dark frame consistent with the claim; x11grab + XTest command logs recorded. No browser comparison used.
    - AC-09 validation/targets — auditor reruns: dart format 95 files 0 changed (exit 0); root flutter test 73 passed; SDK flutter test 30 passed; python 25 passed; root + SDK flutter analyze no issues; flutter build linux --debug PASS. Android/Web = compile-only (pre-cleanup logs); Windows/macOS/iOS declared unavailable — consistent with WP AC-09 ("available" targets + availability report).
    - AC-10 pre-cleanup parity gate — Phase 4 evidence dir timestamps (23:11–23:26) precede cleanup-tree changes (23:37–23:48); raw pre-cleanup logs confirm format 100 / root 84 / python 30 / analyze / Linux build all passing before deletion.
    - AC-11 gated cleanup (assets) — TASK-0004-raster-cleanup.sha256 artifact hash 1f2f946f… verified; exactly 21,830 hash entries = 21,829 PNGs + assets/map/tiles/manifest.json; cleanup set == inventory set (f383642d…) + tile manifest; zero non-raster paths in deletion list; 0 raster files remain; 680 removed directories enumerated; assets/map/manifest.json retained with recorded hash 365ea1d5… matching auditor rehash.
    - AC-12 post-parity docs — ADR-0004 (23:51, after parity+cleanup) explicitly supersedes intact ADR-0003 (mtime 2026-10-19); README/ARCHITECTURE/SDK README/tool README verified accurate against implementation (SDK described, no flutter_map/raster-runtime claims, no Mapbox dependency anywhere, package-vs-app Web boundary, approximation disclaimer).
    - AC-13 auditor evidence handoff — commands, raw logs, captures, platform/size reports, exact inventory + exact deletion list received and validated by this audit.
  criteria_failed: []
  out_of_scope_changes:
    - "None material. Raster-path code/tool deletions beyond the 21,830-file asset record (see Deviations) are within master-brief scope ('removes … raster generator'; 'raster-only tooling') and affected-areas (legacy renderer replacement) but were not itemized in the deletion record."
  test_quality:
    passed: 128  # 73 root + 30 SDK + 25 python, all auditor-rerun
    failed: 0
    missing: []  # every WP-required behavior is covered by a passing test; the only removed tests tested the deleted raster path
  risks_introduced:
    - "Route-overlay list-identity repaint risk (parent rebuild may repaint active-route painter) — unprofiled; declared by engineering."
    - "Flutter Web compute runs on the UI event loop; large-cell decode can block Web UI — declared; SDK Web is compile-only, never runtime-validated."
    - "No Git metadata: the 5 deleted dart files and 2 deleted python files are unrecoverable except via baseline/log documentation; 2 of the 5 dart deletions cannot be individually named from surviving records."
  debt_introduced:
    - "Deletion-record gap: raster-only code/tool/test removals (render_tiles.py, test_render_tiles.py, vector_overlay_painter_test.dart, map_data_store.dart, map_data_controller.dart, offline_map_runtime_test.dart raster-test edit, +2 unnamed dart files) absent from the exact deletion list."
    - "TASK-0004-engineering-completion.md cites Phase 4 pre-cleanup counts (84/30/100) without a pre-cleanup label (validation evidence corrects this, but the completion report alone reads as current)."
  documentation_gaps:
    - "Cleanup report sentence 'No README, ADR, map cells/manifests, SDK source, tests, or fetch/source-PBF tools were edited' is contradicted: offline_map_runtime_test.dart was modified 2026-10-20 23:37 (raster TileLayer tests removed) and vector_overlay_painter_test.dart / test_render_tiles.py were deleted."
    - "native-vera-cruz.png and native-vera-cruz-detail.png are byte-identical (sha256 82ae783d…); the evidence table lists two captures for Vera Cruz-SP where only one distinct image exists (case still covered by that capture + the corridor capture)."
  notes:
    - "84→73 / 30→25 / 100→95 count deltas reconcile exactly to raster-only removals: dart 84 = 73 + 5 (vector_overlay_painter_test.dart) + 6 (raster TileLayer tests cut from offline_map_runtime_test.dart); python 30 = 25 (test_build_map_data) + 5 (test_render_tiles.py). Assessment: documentation inconsistency, NOT missing work."
    - "Auditor limitations: no image rendering in this audit environment (captures validated via PNG structure, dimensions, size-vs-content plausibility, and capture logs, not pixel inspection); no Git baseline, so pre-generation cell/manifest state and the Phase 2 immediate before/after PBF pair are consistent-but-not-reproducible historical claims; Android/Web evidence is pre-cleanup compile-only and was not rerun."
    - "All three mandated limitations are explicitly recorded where required: Web compute single-thread, Windows/macOS/iOS unavailable, no frame-time/heap profile (completion report, validation evidence, ADR-0004, SDK README, ARCHITECTURE)."
    - "No Delivery Auditor approval was claimed anywhere in engineering artifacts; spec status recorded exactly as user-approved 2026-10-19; historical TASK-0001/2/3 and HANDOFF-VAL-0003 records verified unedited (mtimes 2026-10-19; unresolved VAL-0003 AC-03/AC-07 preserved)."
  next_action: forward_to_orchestrator
```

## Status

**APPROVED_WITH_NOTES** — implementation, gated cleanup, protected areas, and post-parity
documentation all verified against independently rerun evidence. Notes below are
documentation-record corrections; none block the delivery. Recommended disposition:
orchestrator may route an optional documentation-only follow-up to engineering.

## Requirements Validation (Master Brief + ENG-0004 v2 ACs)

All 13 acceptance criteria verified with rerun evidence (see YAML `criteria_met`). Highlights:

- **AC-07 (PBF/semantic gate):** auditor rehash of `tool/map_data/raw/sudeste-latest.osm.pbf`
  = `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` = manifest
  `sourceSha256` = WP planning baseline. PBF mtime (2026-10-18 11:42) and size
  (861,713,601 B) predate all TASK-0004 engineering activity. Height persistence verified
  independently: 7 numeric heights found in cells `l1_1_1`, `l1_1_2`, `l1_7_2`, matching
  `buildingsWithPositiveNumericHeight: 7`; L0/L1 byte sums (1,302,396 / 220,229) match
  manifest `l0Bytes`/`l1Bytes` exactly.
- **AC-11 (cleanup):** deletion set independently recomputed from the two `.sha256`
  artifacts: cleanup = inventory ∪ {`assets/map/tiles/manifest.json`}; 21,830 entries,
  all under `assets/map/tiles/`; artifact hashes match the reported values
  (`f383642d…`, `1f2f946f…`); 0 raster files remain; 680 removed directories enumerated
  in the cleanup report; retained `assets/map/manifest.json` rehash matches the recorded
  `365ea1d5…`.

## Engineering Validation

- **SDK boundary:** no `dart:io`, `MethodChannel`/`EventChannel`, `flutter_map`,
  Riverpod/routing/search imports in `packages/fogo_map_sdk/lib` (grep + passing
  `sdk_boundary_test.dart` source scan). `archive` is a direct dependency; assets load
  via `rootBundle`; `compute` used for decode; cache bounds in code (64 L0 / 24 L1 /
  8 MiB) match docs and tests. Root pubspec: no `flutter_map`, no Mapbox package
  anywhere.
- **Integration:** `MapWorkspacePage` imports `package:fogo_map_sdk/fogo_map_sdk.dart`;
  camera persistence app-owned via `core/persistence/camera_preferences.dart`; route
  polylines/markers passed through the SDK transform; route/search services untouched
  (mtimes 2026-10-18, predate TASK-0004).
- **Generator:** 25/25 python tests pass on rerun; no-download + stage-safety +
  semantic-gate tests present; osmium pinned in `requirements.txt`; tool README
  documents grammar, units, counter semantics, and local-PBF-only regeneration.

## Design Validation

No Design WP required (per handoff). Night palette implemented as F.O.G.O.-owned
approximation; no exact-Mapbox claim anywhere; toggles, label collision, fixed
screen-pixel widths, attribution, and overlay ordering covered by passing tests and
native captures.

## Test Evidence (auditor reruns, 2026-10-21)

| Check | Command | Result |
|---|---|---|
| Format | `dart format --output=none --set-exit-if-changed lib test packages/fogo_map_sdk/lib packages/fogo_map_sdk/test` | 95 files, 0 changed, exit 0 |
| Root tests | `flutter test` | **73 passed**, exit 0 |
| SDK tests | `flutter test` (`packages/fogo_map_sdk`) | **30 passed**, exit 0 |
| Generator tests | `python3 -m unittest discover -s tool/map_data/tests` | **25 passed**, OK |
| Analysis (root + SDK) | `flutter analyze` ×2 | No issues, both |
| Linux debug build | `flutter build linux --debug` | PASS → `build/linux/x64/debug/bundle/fogo` |

**Count discrepancy assessment (84/30 vs 73/25):** documentation inconsistency, not
missing work. The completion report cites Phase 4 **pre-cleanup** runs (84 root / 30
python / 100 format-processed — all confirmed in the raw Phase 4 logs) without a
pre-cleanup label. The current tree runs 73 / 25 / 95 (auditor-verified). The deltas
reconcile exactly to removal of raster-path tests with the raster path:
84 = 73 + 5 (`vector_overlay_painter_test.dart`) + 6 (raster `TileLayer` tests cut from
`offline_map_runtime_test.dart`); 30 = 25 (`test_build_map_data.py`) + 5
(`test_render_tiles.py`). Every removed test tested deleted raster code; every
WP-required behavior remains covered by the current passing suites.

## Documentation Validation

- ADR-0004 explicitly supersedes ADR-0003 (created 23:51, after parity evidence and
  cleanup); ADR-0003 intact and unedited (mtime 2026-10-19).
- README.md, docs/ARCHITECTURE.md, packages/fogo_map_sdk/README.md, tool/map_data/README.md
  all verified accurate against the implementation: SDK described as current renderer, no
  stale flutter_map/raster instructions, osmium dependency documented, regional scope,
  visual approximation, package-vs-app Web boundary, height grammar and counter semantics.
- Spec status recorded everywhere as `Reviewed and approved by the user on 2026-10-19`,
  never as auditor approval. Historical TASK-0001/2/3, VAL-0003 (incl. unresolved
  AC-03/AC-07), ENG-0001/2/3 WPs, and prior delivery reports verified unedited (mtimes
  2026-10-19).

## Deviations

1. **Deletions beyond the recorded inventory (in-scope, unrecorded):** in addition to the
   21,830 inventoried raster assets, cleanup removed raster-path/legacy-renderer code:
   `tool/map_data/render_tiles.py`, `tool/map_data/tests/test_render_tiles.py`,
   `test/vector_overlay_painter_test.dart`, `lib/features/map/vector/map_data_store.dart`,
   `lib/features/map/vector/map_data_controller.dart`, and modified
   `test/offline_map_runtime_test.dart` (raster TileLayer tests removed; mtime 23:37).
   Dart-format count 100→95 implies 5 dart-file deletions; 3 are named above and 2 cannot
   be individually identified from surviving records (no Git). All are raster-path or
   legacy-renderer files within master-brief scope ("raster generator", "raster-only
   tooling", renderer replacement), and phase-0 `ENG-0004-baseline.md` had inventoried the
   generator and map_data files — but none appear in the exact deletion list.
2. **Contradicted record sentence:** cleanup report claims "No … tests … were edited";
   `offline_map_runtime_test.dart` was content-modified and two raster test files were
   deleted (see above).
3. **Completion-report count labeling:** pre-cleanup counts presented without label;
   the validation-evidence report already instructs readers to treat them as the
   Phase 4 pre-cleanup run.
4. **Vera Cruz capture duplication:** `native-vera-cruz.png` ≡ `native-vera-cruz-detail.png`
   (identical SHA-256). The Vera Cruz case remains evidenced (distinct capture + corridor
   capture showing the "Vera Cruz" label), but the evidence table overstates the artifact.
5. **Known, self-disclosed:** cleanup `.sha256` header still says the tile manifest was
   "not hashed" while the appended final entry hashes it (disclosed in validation
   evidence; the 21,830-entry deletion set is unambiguous).

## Risks

- Unprofiled route-overlay repaint (list identity) — declared, not regression-evidenced.
- Web decode on UI event loop — declared; SDK Web remains compile-only.
- Windows/macOS/iOS package checks unavailable — declared, not run.
- No Git metadata: the exact-deletion-record gap (Deviation 1) is the only recoverability
  exposure; baseline + Phase 4 logs allow reconstruction of everything except the 2
  unnamed dart files.

## Required Revisions

None blocking. Recommended (documentation-only, routable at orchestrator's discretion):

1. Append a deletion addendum to the cleanup record listing the raster-path code/tool/test
   removals named in Deviation 1 (and noting the 2 unidentifiable dart deletions).
2. Correct/annotate the cleanup report's "no tests edited" sentence and the completion
   report's pre-cleanup count labeling (validation evidence already carries the correct
   post-cleanup numbers).

## Final Recommendation

**APPROVED_WITH_NOTES.** The delivery meets the brief: all acceptance criteria pass with
independently rerun evidence (128 tests, analyze ×2, Linux debug build, format), the PBF
and all protected areas are preserved and verified, the raster cleanup is exact against
its inventory (21,830 = 21,829 PNGs + tiles manifest, zero non-raster deletions),
successor ADR/docs are accurate, and all mandated limitations are explicitly declared.
The notes concern evidence-record precision (unlisted code deletions, one contradicted
sentence, one duplicated capture, pre-cleanup count labeling) — none affect substance,
protected areas, or test coverage of required behavior.
