# Handoff — TASK-0007 Mapbox Standard Night Root Route

## Work packages

- Engineering: `docs/agent-work/work-packages/ENG-0007-mapbox-standard-night-root-route.md`
- Integration contract: `docs/agent-work/work-packages/INT-0007-mapbox-root-route-integration.md`
- Master Brief: `docs/agent-work/briefs/MASTER-BRIEF-TASK-0007.md`

## Execution order

User-approved spec is the visual source of truth; no Design Work Package or Code Analysis assignment is required. User approval is recorded. Its spec file status may still say “awaiting spec review” because compiler does not own that artifact; do not treat that metadata as an implementation gate. Engineering lead performs feasibility review against the integration contract, then implements only authorized scope. Keep delivery audit after engineering evidence is collected.

## Required coordination

- Do not modify `lib/engine/**`, `lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart`, or any pre-task working-tree changes.
*(token Mapbox removido — push protection)*
- Use selected `flutter_inappwebview` 6.2.0-beta.3 without substitution and pinned Mapbox GL JS v3.33.0 CDN. Marília-SP is a spec assumption; engineering chooses reasonable zoom. Latest-pending focus is recommended safe behavior, not mandated; engineering may choose another safe behavior and document/test it.
- Follow up only on exact failure/retry UX, Windows WebView2 runtime/version and exact host setup, actual per-host WPE/WebView/WebGL2 validation, token origin/referrer behavior in actual WebViews, and ADR-0005 verification if available/relevant.
- Record target-by-target build/test/host evidence and unavailable prerequisites for the delivery auditor. Do not claim unrun validation.

## Engineering completion evidence — revision for auditor

### Code-level implementation and automated checks

- Root-route Mapbox implementation remains in the existing `MapboxMapPage` and `MapboxFocusBridge`; this revision added page/bridge integration cases to the existing `test/mapbox_map_page_failure_test.dart` plus this evidence update. No production map code changed in this revision.
- New page/bridge widget tests exercise the existing search UI against a fake WebView controller:
  - Selecting before `ready` queues focus; `ready` sends `window.focusMap([-49.95,-22.22]);`.
  - Selecting after `ready` sends `window.focusMap([78.9012,12.3456]);`.
  - A rejected `evaluateJavascript` call produces visible map recovery UI. Existing `test/mapbox_map_page_failure_test.dart` also verifies callbacks after page disposal are ignored.
- `flutter test test/mapbox_map_page_failure_test.dart`: **8 passed, 0 failed**, including 2 new search-to-WebView focus cases.
- `flutter test test/app_router_test.dart test/window_manager_platform_test.dart test/mapbox_map_page_failure_test.dart test/features/map/presentation/pages/mapbox_focus_bridge_test.dart`: **19 passed, 0 failed**.
- `flutter analyze`: **passed**, no issues found.
- `dart format --output=none --set-exit-if-changed test/mapbox_map_page_failure_test.dart`: **passed**, 1 file checked, 0 changes.
- Full `flutter test`: **187 passed, 3 failed, 0 skipped (190 total)**; command exits 1. The three failures are in the already-dirty, protected `test/engine/fogo_engine_test.dart`, and were reproduced in `/tmp/opencode/TASK-0007-flutter-test-lead.log`:
  1. `constrói motor completo a partir da fixture`, line 53: expected `junctionPadCount == 6`, actual `1`.
  2. `junção: pad pertence à via prioritária e cobre o nó compartilhado`, line 224: expected 2 objects for `way/12` (road mesh + junction pad), actual 1.
  3. `ETAPA 05: cruzamento ferroviário de nível com pad real`, line 413: expected at least one pad, actual 0.
- Investigation: junction arms are grouped by `_roadLift(...)` in `lib/engine/fogo_engine.dart`; `_roadLift` adds road-type render elevation (`primary` 0.10, `rail` 0.03, local types 0.0). Arms sharing a network node but having different road types therefore get different group keys; singleton groups are skipped. This is consistent with the missing pads and all three assertions. Engine implementation and engine tests were not changed. A clean baseline was not isolated, so exact pre-task baseline disposition remains unverified; these failures were already reported by the prior audit and reproduced during this targeted revision.

### Build evidence — not native runtime validation

- `flutter build apk --debug`: **passed**, exit 0; produced `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build apk --release`: **passed**, exit 0; produced `build/app/outputs/flutter-apk/app-release.apk` (56.3 MB). This APK uses Android's debug signing configuration and is not production-signed. Both final builds emitted a non-fatal Java restricted-access warning.
- These APK builds prove Android compilation/packaging only. They do not prove Android WebView or Mapbox runtime behavior.

### Runtime validation and unavailable hosts

- Environment: Debian GNU/Linux 13, x86_64. `flutter devices` lists Linux desktop only. No Android device is connected; the configured `Pixel_10` emulator was not launched and `adb` is unavailable.
- Post-audit Linux fix: installed `libwpewebkit-2.0-dev`, `libwpebackend-fdo-1.0-dev`, and `libsecret-1-dev`. Debian 13's WPE 2.48.3 lacks the optional theme-color API added in WPE 2.50, so `packages/flutter_inappwebview_linux` carries the upstream compatibility guard and a local path override.
- After the fix, `flutter build linux --debug` passed. A 45-second `flutter run -d linux` initialized the app, WPEBackend-FDO, and the WebView GL texture; the process was terminated by the test timeout. This confirms Linux WebView startup, not that Mapbox rendered correctly.
- iOS, Windows, and macOS native hosts/toolchains are unavailable on this Linux host (`xcodebuild`/`xcrun` absent); no host validation was attempted for them.
- **Still unverified:** actual Mapbox CDN/style load, WebGL2 map rendering, visible Mapbox logo/attribution, mouse/touch pan and zoom, and token origin/referrer restrictions. Do not infer these from widget tests or APK builds.
- After adding the local plugin package, `flutter analyze` passes with the vendored package excluded from app analysis; the focused route/platform/bridge suite passes **19/19**.
