# TASK-0004 / ENG-0004 v2 — Post-Cleanup Validation & Evidence

**Disposition:** Phase 4 parity gate passed before cleanup; engineering then completed the gated cleanup. Post-cleanup validation passed for formatting, SDK/root/Python tests, analysis, and Linux debug build. Windows, macOS, and iOS remain unavailable on this Debian Linux host. Android and Web evidence is compile-only; no runtime validation. No Delivery Auditor verdict or approval is claimed.

Authority: `docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md` (canonical ENG-0004 v2). No Git metadata exists, so no Git diff/status is available.

## Phase 4 pre-cleanup validation (historical)

| Check | Exact command / working directory | Result |
|---|---|---|
| Dart format | `dart format --output=none --set-exit-if-changed lib test packages/fogo_map_sdk/lib packages/fogo_map_sdk/test` (repo root) | PASS, 100 files checked, 0 changed, exit 0; pre-cleanup run. |
| SDK tests | `flutter test` (cwd `packages/fogo_map_sdk`) | PASS, all 30 package tests, exit 0. |
| Full app tests | `flutter test` (repo root) | PASS, all 84 tests, exit 0; pre-cleanup run. |
| Root analysis | `flutter analyze` (repo root) | PASS, no issues, exit 0. |
| Linux debug build | `flutter build linux --debug` (repo root) | PASS, built `build/linux/x64/debug/bundle/fogo`, exit 0. |
| Generator tests | `python3 -m unittest discover -s tool/map_data/tests -v` (repo root) | PASS, 30 tests, exit 0; pre-cleanup run. Tests use temporary fixtures; no PBF generation was invoked. |
| Workspace interaction repeat | `flutter test test/workspace_semantics_test.dart` (repo root), run 3 consecutive times | PASS, 2 tests each run, all 3 runs exit 0. |
| SDK Android compile smoke | `flutter build apk --debug` (cwd `/tmp/opencode/task-0004-sdk-android`; temporary Flutter host imports SDK via path dependency) | PASS, debug APK built, exit 0. No Android device was connected. |
| SDK Web compile smoke | `flutter build web --release` (cwd `/tmp/opencode/task-0004-sdk-web`; temporary Flutter host imports SDK via path dependency) | PASS, Web bundle built, exit 0. Browser execution not run. |
| Phase 2 staged semantic recheck | Read-only `build_map_data.compare_outputs` invocation recorded below (repo root; compares current `assets/map` with retained stage under `/tmp/opencode`) | PASS: 58 cells compared, 0 height additions, `generatedAt` only changed. The PBF was neither read nor hashed in this recheck. |

Phase 4 pre-cleanup raw command output is in `docs/agent-work/handoffs/TASK-0004-validation-evidence/`. The first Web fixture build returned “not configured for the web”; after `flutter create --platforms=web`, the SDK-host Web build passed. `flutter doctor -v` reports Flutter 3.47.1 / Dart 3.13.1, Debian Linux; Android SDK lacks cmdline-tools and license status is unknown despite the successful APK build; Chrome is absent. `flutter devices --machine` lists Linux only.

## Post-cleanup validation (engineering lead)

The following outcomes are from the engineering lead's post-cleanup validation; these are separate from the historical Phase 4 counts above. No test count is carried forward or conflated between runs.

| Check | Command / working directory | Result |
|---|---|---|
| Dart format | `dart format --output=none --set-exit-if-changed lib test packages/fogo_map_sdk/lib packages/fogo_map_sdk/test` (repo root) | PASS, 95 files checked, 0 changes. |
| SDK tests | `flutter test` (`packages/fogo_map_sdk`) | PASS, 30 tests. |
| Full app tests | `flutter test` (repo root) | PASS, 73 tests. |
| Python tests | `python3 -m unittest discover -s tool/map_data/tests -v` (repo root) | PASS, 25 tests. |
| Analysis | `flutter analyze` (repo root) | PASS. |
| Linux debug build | `flutter build linux --debug` (repo root) | PASS. |

These outcomes validate the post-cleanup tree. Android/Web were not rerun here: their Phase 4 evidence remains SDK-host compile-only, with no device or browser execution. The existing raw logs in the evidence directory are Phase 4 logs; this report records the lead-reported post-cleanup outcomes separately.

### SDK target availability

| Target | Evidence / status |
|---|---|
| Linux | PASS: Phase 4 SDK tests and native parity capture; post-cleanup SDK tests and integrated F.O.G.O. Linux debug build also passed. |
| Android | PASS: Phase 4 SDK-host debug APK compile only. No device/runtime validation; not rerun after cleanup. |
| Web | PASS: Phase 4 SDK-host release compile only. Chrome absent; no browser execution; not rerun after cleanup. **This is not evidence of F.O.G.O. application Web support.** |
| Windows | Unavailable: Debian Linux host; no Windows target toolchain. Not run. |
| macOS | Unavailable: Debian Linux host; no macOS target toolchain. Not run. |
| iOS | Unavailable: Debian Linux host; no Xcode/`xcodebuild`. Not run. |

The unavailable targets are not failures: canonical acceptance criterion 9 says to report package checks for all listed targets, including unavailable ones; testing requirement 2 explicitly says to run checks on each *available* target and declare unavailable targets. Linux, Android, and Web are the available SDK compile targets evidenced above.

## Phase 2 source and staged semantic evidence

Phase 2 recorded the local source PBF SHA-256 immediately before and after generation as `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59`; the manifest `sourceSha256` was the same. These recorded values are carried forward as instructed; **Phase 4 did not read or rehash the PBF**. Current baseline and retained staged manifests both contain that `sourceSha256`. A distinct post-cleanup rehash is recorded below; it is not a new immediate before/after-generation pair.

Retained candidate stage: `/tmp/opencode/task-0004-eng0004-compare.8UzNtL`; baseline: `assets/map`. Re-ran the generator's read-only semantic comparator without generation or promotion:

```sh
python3 -B - <<'PY'
import importlib.util, json
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    'build_map_data_readonly', Path('tool/map_data/build_map_data.py')
)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
baseline = Path('assets/map')
stage = Path('/tmp/opencode/task-0004-eng0004-compare.8UzNtL')
expected_sha = 'cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59'
stage_manifest = json.loads((stage / 'manifest.json').read_text())
current_manifest = json.loads((baseline / 'manifest.json').read_text())
height_counts = {
    name: stage_manifest['counts'][name]
    for name in builder.HEIGHT_COUNTER_FIELDS
}
summary = builder.compare_outputs(
    baseline, stage, stage_manifest['generatedAt'], expected_sha, height_counts
)
print(json.dumps({
    'sourcePbfReadOrHashed': False,
    'baselineCellFiles': len(builder._cell_files(baseline)),
    'stageCellFiles': len(builder._cell_files(stage)),
    'baselineSourceSha256': current_manifest['sourceSha256'],
    'stageSourceSha256': stage_manifest['sourceSha256'],
    'comparison': summary,
}, sort_keys=True, indent=2))
PY
```

Output: `baselineCellFiles=58`, `stageCellFiles=58`; both manifest source hashes equal the recorded PBF hash; current `generatedAt=2026-10-20T00:35:43-0300`, stage `generatedAt=2026-10-20T23:00:42-0300`; `cellFilesCompared=58`, `heightAdditions=0`, `heightAdditionsByCell={}`, `approvedManifestChanges=["generatedAt"]`; height counters are positive numeric `7`, levels-only `23`, rejected `0`, unsupported `0`. Comparator returned successfully. This verifies staged membership, geometry, non-height cell/manifest content and counters against the current cells; zero additions are expected because current cells already contain seven heights. The exact Phase 2 before/after values and these comparator results are now preserved here. The stage directory is under `/tmp` and is not a durable handoff artifact; the command and result above remain in this report. Comparator implementation: `tool/map_data/build_map_data.py::compare_outputs`.

## Native Linux visual evidence

The built Linux app was launched as a native Flutter desktop process with an isolated temporary `HOME`; captures were taken from its X11 window with FFmpeg (`x11grab -window_id`), not from a browser or unit-render output. No map network comparison was used.

| Case | Capture | What is visible |
|---|---|---|
| Marília-SP | `.../TASK-0004-validation-evidence/native-marilia-city.png` | Native app after Marília fit; Marília label and local map features visible. |
| Vera Cruz-SP | `.../TASK-0004-validation-evidence/native-vera-cruz.png` (`native-vera-cruz-detail.png` is byte-identical, SHA-256 `82ae783d…a26c1` — a duplicate, not a distinct capture) | Native app after panning to the Vera Cruz area; the corridor capture also shows the “Vera Cruz” label near viewport center. |
| Garça-SP | `.../TASK-0004-validation-evidence/native-garca.png` | Native app after Garça fit; Garça label and local features visible. |
| Corridor / region | `.../TASK-0004-validation-evidence/native-corridor.png` | “Região” fit; Marília, Vera Cruz and Garça labels and connecting corridor visible. |
| Coverage edge | `.../TASK-0004-validation-evidence/native-coverage-edge.png` | Garça view crosses exact data edge; rendered content ends against dark empty area. |
| Outside coverage | `.../TASK-0004-validation-evidence/native-outside-coverage.png` | Dark empty map and native status “fora da cobertura”. |

All six requested cases have native captures. Initial Wayland root capture was black and is retained but excluded (`native-initial-screen.png`); switching to `GDK_BACKEND=x11` enabled app-window captures. A later recapture attempt found the app window already exited; previously saved captures remain available. Native screenshot logs and images are in the evidence directory.

## Phase 4 pre-cleanup bundle and map-data sizes

Historical Phase 4 snapshot: logical regular-file byte sums measured after the pre-cleanup Linux debug build. These figures include raster files and are not post-cleanup sizes or release-size estimates. No post-cleanup size measurement is claimed here.

| Artifact | Files | Bytes |
|---|---:|---:|
| SDK Dart library source (`packages/fogo_map_sdk/lib`, `*.dart`) | 12 | 109,548 |
| F.O.G.O. Linux debug bundle | 21,908 | 183,993,259 |
| Linux debug app launcher `fogo` | 1 | 46,784 |
| Flutter Linux engine `libflutter_linux_gtk.so` | 1 | 43,336,696 |
| Debug `kernel_blob.bin` | 1 | 94,701,968 |
| SDK-host Android debug APK (temporary compile fixture, not F.O.G.O. app) | 1 | 146,140,634 |
| SDK-host Web output (temporary compile fixture, not F.O.G.O. app) | 38 | 42,199,961 |
| `assets/map` total (also embedded in Linux debug app bundle) | 21,889 | 40,034,264 |
| Vector cells (`assets/map/cells/*.json.gz`) | 58 | 1,522,625 |
| Raster PNGs (`assets/map/tiles/**/*.png`) | 21,829 | 38,508,843 |
| Map manifests (`assets/map/manifest.json`, `assets/map/tiles/manifest.json`) | 2 | 2,796 |
| Existing source PBF (`tool/map_data/raw/sudeste-latest.osm.pbf`) | 1 | 861,713,601 |

SDK has no standalone binary bundle; SDK Dart source is incorporated into host builds. The Android/Web sizes above are compile-smoke hosts only. Current manifest reports `l0Bytes=1,302,396`, `l1Bytes=220,229`; the source PBF was not regenerated or rehashed during Phase 4. The distinct current post-cleanup rehash is recorded below.

## Raster inventory and completed cleanup

Engineering completed cleanup after recording the passing Phase 4 parity gate. Exactly **21,830 inventoried files** were removed: 21,829 PNGs (21,828 XYZ tiles plus `assets/map/tiles/blank.png`) and `assets/map/tiles/manifest.json`. The cleanup also removed 680 empty raster directories. The legacy raster renderer/runtime and root `flutter_map` dependency were removed; `MapWorkspacePage` uses the SDK.

The inventory and deletion artifacts are retained:

| Artifact | SHA-256 of artifact | Entries |
|---|---|---:|
| `docs/agent-work/handoffs/TASK-0004-raster-inventory.sha256` | `f383642df94056cc6bc931360a7f5f07d798a177b3d5b835e9f4e96841d51c6b` | 21,829 PNG path/checksum entries |
| `docs/agent-work/handoffs/TASK-0004-raster-cleanup.sha256` | `1f2f946f09c83d0f63c6b6f9d373eafcbb8cfc58fe4b44cf4c128f40ab1cef79` | 21,830 deleted file path/checksum entries |

`TASK-0004-raster-cleanup.md` records pre-delete checksum verification, exact deletions, and preserved data. The cleanup list includes the 21,829 PNG inventory entries plus the tile manifest entry. **Cleanup is complete; no raster files remain.** This is engineering cleanup evidence, not an Auditor verdict.

The cleanup checksum file retains an inventory-era header stating the tile manifest was “not hashed; not modified”; a later appended comment and final checksum entry separately add `assets/map/tiles/manifest.json` to the deletion list. The 21,830 checksum entries and cleanup report identify the completed deletion set; this report-only follow-up does not edit that owned checksum artifact.

## Final post-cleanup boundary and protected-data checks

The final read-only checks confirmed the post-cleanup runtime/data boundary:

| Check | Result |
|---|---|
| Runtime/dependency/generator scan | PASS: no `package:flutter_map`, `flutter_map` dependency declaration, `TileLayer`, `AssetTileProvider`, or raster asset path in app/SDK runtime or `tool/map_data` generator sources. The SDK boundary test contains forbidden-package strings as test assertions; it is not runtime use. |
| Vector cells | PASS: 58 `assets/map/cells/*.json.gz` files present. Cleanup record states all 58 were rehashed before and after and unchanged. |
| Raster assets | PASS: 0 raster files; `assets/map/tiles/` and its raster manifest are absent. |
| Retained map manifest | PASS: `assets/map/manifest.json` SHA-256 `365ea1d533e48bac4894108c51dd498966f37ee1e4436281453a35c805dc3534`, matching cleanup record. |
| Retained local PBF | PASS: current read-only SHA-256 `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59`; equals recorded Phase 2 before/after hashes and manifest `sourceSha256`. |

The PBF value above is a **post-cleanup current rehash**, not an immediate before/after generation claim. No generation ran during cleanup or this final check. Generation integrity evidence remains the Phase 2 immediate before/after pair and staged semantic comparison documented above; the cleanup report separately records unchanged PBF size, mtime, and inode.

## Quality artifact

Canonical ENG-0004 v2 numbers acceptance criteria in order at lines 117–129: AC-07 is the PBF hash/semantic gate; target availability is AC-09. Unavailable targets do not fail AC-09 because it and testing requirement 2 require checks only where available plus an availability report. The quality artifact below maps to that sequence. “pass: true” means evidence is recorded, not implementation or Delivery Auditor approval.

```yaml
quality_artifact:
  task_id: TASK-0004
  test_strategy:
    levels: [unit, integration, ui, contract]
  criteria_verified:
    - criterion_id: ENG-0004-AC-01-sdk-boundary
      test_id: sdk_boundary_test.dart; source-level runtime/dependency scan; Phase 4 Linux, Android SDK-host, and Web SDK-host package builds
      pass: true
    - criterion_id: ENG-0004-AC-02-projection-camera
      test_id: camera_projection_test.dart (round-trip, 0/45-degree inverse, fit bounds, events, transient pitch); workspace_semantics_test.dart
      pass: true
    - criterion_id: ENG-0004-AC-03-gestures-selection
      test_id: map_widget_test.dart (drag, pinch, double-tap, wheel, fling, secondary-click/long-press coordinate selection, route independence)
      pass: true
    - criterion_id: ENG-0004-AC-04-data-loading-clipping-errors-cache
      test_id: data_source_test.dart; map_widget_test.dart (coverage, missing/empty/corrupt data, cache caps/pruning)
      pass: true
    - criterion_id: ENG-0004-AC-05-rendering-semantics
      test_id: renderer_test.dart; root renderer/road tests; native captures
      pass: true
    - criterion_id: ENG-0004-AC-06-height-generator
      test_id: Phase 4 generator-python-tests.log (30 pre-cleanup tests) and lead-reported post-cleanup Python suite (25 passed): accepted/rejected grammar, counters, persistence, no-download, safety
      pass: true
    - criterion_id: ENG-0004-AC-07-pbf-hashes-semantic-gate
      test_id: Phase 2 before/after and manifest SHA-256 recorded above; read-only compare_outputs recheck (58 cells; 0 additions; generatedAt only)
      pass: true
    - criterion_id: ENG-0004-AC-08-native-region-evidence
      test_id: six native Linux app screenshots listed above
      pass: true
    - criterion_id: ENG-0004-AC-09-validation-available-targets
      test_id: Post-cleanup lead validation: format 95 files, SDK 30, root 73, Python 25, flutter analyze, Linux debug build all passed; Phase 4 Android/Web SDK-host compile only; Windows/macOS/iOS unavailable
      pass: true
    - criterion_id: ENG-0004-AC-10-pre-cleanup-parity-gate
      test_id: AC-01 through AC-09 parity evidence, including six native captures, completed before cleanup; engineering parity gate passed
      pass: true
    - criterion_id: ENG-0004-AC-11-gated-cleanup
      test_id: TASK-0004-raster-cleanup.md and TASK-0004-raster-cleanup.sha256 (21,830 entries); post-cleanup runtime scan; 58 cells and manifest retained
      pass: true
    - criterion_id: ENG-0004-AC-12-post-parity-docs
      test_id: ADR-0004 and engineering completion report; successor ADR and documentation updates recorded after parity
      pass: true
    - criterion_id: ENG-0004-AC-13-auditor-evidence-handoff
      test_id: This evidence report, Phase 4 raw logs/native captures, inventory and exact cleanup list; independent Delivery Auditor review remains pending
      pass: true
  recompose_audit:
    unstable_params:
      - MapWorkspacePage rebuilds routePolylines/routeMarkers lists; active-route painter compares polylines by identity, so parent rebuild may repaint. Not profiled.
    fixed: []
  ui_thread_blockers:
    - No native frame profile run. Cell decode uses compute; Flutter Web executes compute callback on the same event loop, so large-cell decode can block Web UI.
  cancellation_violations: []
  memory_findings:
    - LRU limits 64 L0 / 24 L1 and 8 MiB decompressed-cell cap are covered by tests. No runtime heap profile; current dataset has 58 compressed cells totaling 1,522,625 bytes.
  dead_code:
    - Not assessed; no dedicated dead-code scan run.
  regressions: []
  coverage_delta: not measured -> not measured (line coverage not collected)
```

## Concerns and limitations

- **Selection scope:** approved spec requires screen-to-coordinate map selection, not feature picking by OSM ID. SDK emits coordinate, screen position and input source; secondary-click/long-press tests cover it and the app uses callbacks for route stops. Feature-level OSM selection is not claimed or required.
- **Native accessibility/status is only partially evidenced.** SDK map semantics expose a map label, zoom value and increase/decrease actions; rendered OSM features are not individually semantic nodes. App displays coverage status as top-bar text, but it is not declared a live region and no native screen-reader/status-announcement test was run.
- **Performance and memory profiling were not run.** Code inspection found the list-identity repaint risk above; native frame timing, recomposition counts and heap usage remain unmeasured. Web decode limitation is documented and package-local.
- No line-coverage baseline or comparable legacy/native golden screenshots were available. Current new-renderer captures are visual evidence, not an exact Mapbox comparison.
- Phase 4 did not rehash the source PBF. Phase 2 immediate before/after generation hashes and staged semantic result are recorded above. A current post-cleanup rehash matches those values and manifest `sourceSha256`, but is not a new generation pair. The staged compare directory remains under `/tmp` only.
- Post-cleanup format/test/analyze/build results are lead-reported in this handoff; the raw logs currently in the evidence directory are pre-cleanup Phase 4 logs. Native screenshots and Android/Web compile-smoke evidence are also pre-cleanup; no Android device or Web browser/runtime check was performed.
- No post-cleanup bundle/map-data size measurement was supplied; the size table is explicitly a pre-cleanup snapshot.
- `TASK-0004-engineering-completion.md` still lists Phase 4's 100-format/84-root-test/30-Python-test counts. Treat those as its pre-cleanup run; this report records separate post-cleanup outcomes. The completion report was not edited per this assignment's ownership boundary.
- Historical handoff VAL-0003 records an earlier Garça tap interception. Current `workspace_semantics_test.dart` passed three consecutive runs; current line 221 is a semantics value assertion, not that historical tap. No current flaky result observed.

## Produced files and validation boundary

- Report: `docs/agent-work/handoffs/TASK-0004-validation-evidence.md` (only file modified for this reassessment).
- Raw logs and screenshots: `docs/agent-work/handoffs/TASK-0004-validation-evidence/` (includes commands/results, platform/size reports, native PNGs and capture logs). Temporary compile fixtures remain under `/tmp/opencode/task-0004-sdk-{android,web}`; isolated app HOME remains under `/tmp/opencode/task-0004-native-home`.
- This reassessment changed only this validation report. It did not edit implementation source, map cells/manifests, raster assets, cleanup/completion reports, dependency declarations, or PBF. Engineering—not this report update—performed cleanup and post-cleanup validation. Repository lacks Git metadata, so a whole-worktree Git diff cannot be independently established.

**Handoff status:** parity gate passed before cleanup; cleanup completed and recorded; post-cleanup checks passed as listed. Windows/macOS/iOS remain unavailable. Android/Web remain compile-only with no runtime validation. **No Delivery Auditor verdict or approval.**
