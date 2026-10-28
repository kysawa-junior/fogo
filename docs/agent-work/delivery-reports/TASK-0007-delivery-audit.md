---
delivery_audit:
  task_id: TASK-0007
  work_packages_reviewed:
    - ENG-0007
    - INT-0007
    - MASTER-BRIEF-TASK-0007
    - docs/superpowers/specs/2026-10-25-mapbox-standard-night-design.md
    - docs/agent-work/handoffs/HANDOFF-TASK-0007.md
  verdict: APPROVED_WITH_NOTES
  criteria_met:
    - "AC-03: test/mapbox_map_page_failure_test.dart:158-208 verifies search selection before and after ready and exact Mapbox [longitude, latitude] JS calls; focused 19-test suite passes. test/features/map/presentation/pages/mapbox_focus_bridge_test.dart:6-23 verifies latest-pending selection and coordinate conversion."
    - "AC-04: lib/features/map/presentation/pages/mapbox_map_page.dart:207-225 retains F.O.G.O. header/search; page contains no 3D engine viewport or engine-only controls."
    - "AC-05: test/app_router_test.dart:11-26 passes and resolves /inventory and /predictive to their existing page types."
    - "AC-06: target availability is reported accurately in HANDOFF-TASK-0007.md:40-51; no unsupported host is claimed validated."
    - "AC-07: test/window_manager_platform_test.dart:35-103 passes Android/iOS startup, shell, titlebar, close-handler and listener-gating checks; lines 105-134 verify desktop lifecycle and titlebar controls."
    - "AC-08: lib/features/map/presentation/pages/mapbox_map_page.dart:109-126 and 264-315 implement visible failure states; widget tests cover configuration, WebView, style, WebGL2 and JS-evaluation failure. Mapbox attributionControl is enabled at lines 374-388."
    - "AC-09: lib/features/map/presentation/pages/mapbox_map_page.dart:30-33 uses the approved compile-time public pk default; widget test confirms it reaches the map document without appearing in captured debug/print output. Filtered invalid-token widget test passes. No sk token found in the implementation."
    - "AC-11: README.md:183-190 documents Linux WPE, Windows WebView2 SDK/runtime, Android INTERNET, macOS network entitlement and HTTPS/ATS. Android manifest has INTERNET; both macOS entitlements include com.apple.security.network.client. Android APK builds pass."
    - "AC-12: formatter, analyzer, full tests and available build attempts were run; outcomes and unavailable targets are recorded in this report and handoff."
    - "AC-13: README.md:177-211 and tool/map_data/README.md:3-8 update directly affected route, host and runtime-network statements."
  criteria_failed:
    - criterion: "AC-01 native Mapbox style load and AC-02 mouse/touch pan/zoom on a supported host"
      evidence: "Implementation pins GL JS v3.33.0 and Standard night in mapbox_map_page.dart:357-400, but no native WebView host was run. Android builds are packaging-only; Linux build fails for missing WPE 2.0; other native toolchains/hosts are unavailable."
      severity: "External runtime validation gap; disclosed and non-blocking for this audit per assignment."
    - criterion: "AC-08 loaded-map logo/attribution visibility"
      evidence: "Attribution control is enabled in source, but no real map rendered on a host; visual visibility is not independently demonstrated."
      severity: "External runtime validation gap; disclosed and non-blocking for this audit per assignment."
    - criterion: "AC-09 actual token origin/referrer restriction behavior"
      evidence: "No native WebView host was available; handoff and README explicitly state this behavior was not validated."
      severity: "External runtime validation gap; disclosed and non-blocking for this audit per assignment."
  out_of_scope_changes: []
  test_quality:
    passed: 187
    failed: 3
    missing:
      - "Real native WebView/Mapbox CDN/style load and WebGL2 checks."
      - "Host-level attribution/logo visibility and mouse/touch pan/zoom."
      - "Actual token origin/referrer behavior in WebViews."
  risks_introduced:
    - "Host runtime behavior remains unverified on all five native targets; no runtime support claim should be made until host checks run."
    - "Full flutter test exits 1: three failures remain in protected, already-dirty test/engine/fogo_engine_test.dart; handoff records prior reproduction and an investigation, but no clean baseline was isolated."
    - "The current checkout still contains broad protected/pre-existing diffs. The Master Brief records them as present before TASK-0007; no baseline snapshot exists for independent byte-for-byte comparison."
  debt_introduced:
    - "No new implementation debt identified in the targeted revision; no production map code changed per handoff."
  documentation_gaps:
    - "Handoff transparently leaves exact failure/retry UX wording as a follow-up; current copy and retry button are in mapbox_map_page.dart:264-315."
    - "Supported Windows WebView2 runtime distribution/setup remains unvalidated; README states this explicitly."
    - "ADR-0005 is referenced by existing project material but no ADR artifact was found in the inspected workspace; limitation is recorded in the Master Brief/handoff."
  notes:
    - "Targeted page test: 8 passed. Combined router/platform/map page/bridge suite: 19 passed. Invalid-token configuration case passed when filtered with --dart-define=MAPBOX_ACCESS_TOKEN=invalid."
    - "flutter analyze passed with no issues. dart format --output=none --set-exit-if-changed checked four affected source/test files; zero changes."
    - "Full flutter test: 187 passed, 3 failed (190 total): expected junctionPadCount 6, got 1; expected 2 way/12 objects, got 1; expected rail-crossing pad >0, got 0. All three are in test/engine/fogo_engine_test.dart, a protected/pre-existing area."
    - "flutter build apk --debug and --release passed. Release APK uses debug signing and is not production-signed. flutter build linux --debug failed because WPE WebKit 2.0 is missing."
    - "Environment: Flutter 3.47.1/Dart 3.13.1; Linux desktop only. No adb, xcodebuild, xcrun, or NuGet CLI. No native host runtime was validated."
    - "Protected paths remain dirty as documented pre-task changes (lib/engine/** and map_3d_page.dart). Audit made no source edits; post-validation git status/diff summary remained unchanged. Exact preservation cannot be independently hash-compared without the initial snapshot."
    - "No code revision requested. Approve with explicit external-validation and existing-suite-failure notes; do not represent unrun host checks as passed."
  next_action: forward_to_orchestrator
---

# Delivery Audit

## Status

**APPROVED_WITH_NOTES** — implementation and targeted contract tests are adequate for delivery review. Native-host and full-suite limitations remain explicit; no correction to route the revision back to engineering was identified.

## Requirements Validation

- Root route selects `MapboxMapPage` (`lib/app/router/app_router.dart:18-20`). The generated document pins Mapbox GL JS v3.33.0, Standard night, top-down camera, and WebGL2 detection (`lib/features/map/presentation/pages/mapbox_map_page.dart:357-400`). Actual map/style load remains unverified.
- Search-to-camera is covered at page level before and after `ready`; assertions verify `[-49.95,-22.22]` and `[78.9012,12.3456]` (`test/mapbox_map_page_failure_test.dart:158-184`). Bridge unit tests verify latest-pending focus and `LatLng(latitude, longitude)` conversion (`test/features/map/presentation/pages/mapbox_focus_bridge_test.dart:6-23`).
- Root page keeps F.O.G.O. search/navigation and omits engine-only controls. Router test verifies `/inventory` and `/predictive` still resolve to their existing pages (`test/app_router_test.dart:11-26`).
- Android/iOS window-manager gates and desktop titlebar/close lifecycle pass focused mocked-platform tests (`test/window_manager_platform_test.dart:35-134`).
- Failure UI is tested for configuration, WebView, style, WebGL2, JS evaluation, and callbacks after disposal (`test/mapbox_map_page_failure_test.dart:37-208`). Logo/attribution is configured, but visible host rendering was not observed.
- Android INTERNET permission and macOS outgoing-client entitlements are present. README documents compile-time token configuration, Linux WPE, Windows WebView2 SDK/runtime, Android/macOS network prerequisites, and unvalidated host checks.

## Engineering Validation

- `flutter analyze`: passed, no issues.
- `dart format --output=none --set-exit-if-changed` on the two affected Dart implementation files and two focused test files: passed, 4 files checked, 0 changes.
- Targeted page test: 8 passed. Combined router/platform/page/bridge suite: 19 passed. Filtered invalid-token state test: 1 passed.
- Full `flutter test`: **187 passed, 3 failed, 0 skipped (190 total)**. Failures are in protected `test/engine/fogo_engine_test.dart`: expected 6 junction pads/actual 1; expected 2 objects for way/12/actual 1; expected a rail-crossing pad/actual 0. Handoff reports prior reproduction and hypothesizes road-lift grouping; clean-baseline disposition remains unverified.
- `flutter build apk --debug` and `flutter build apk --release`: passed. Release build uses debug signing (`android/app/build.gradle.kts:33-36`); neither build proves Android WebView runtime behavior.
- `flutter build linux --debug`: failed at plugin CMake setup because WPE WebKit 2.0 is absent. Environment exposed Linux desktop only; no `adb`, `xcodebuild`, `xcrun`, or `nuget` command. No real WebView host was validated.
- Logs from this audit are under `/tmp/opencode/TASK-0007-audit/`.

## Design Validation

No Design Work Package was assigned. Code-level map settings match the user-approved Standard Night spec; visual/runtime behavior, including attribution visibility, remains unobserved because no host was available.

## Test Evidence

Automated fake-controller tests establish Flutter-side readiness, pending-focus, coordinate-order, failure UI, disposal, route, and mobile window-manager behavior. They do not execute Mapbox GL JS in a real WebView. Native map load, WebGL2, attribution, pan/zoom, and token-origin/referrer checks remain untested and are disclosed in `HANDOFF-TASK-0007.md:40-51` and `README.md:207-211`.

## Documentation Validation

`README.md` documents the public `MAPBOX_ACCESS_TOKEN` default, pending-focus choice, native prerequisites, and unavailable validations. `tool/map_data/README.md:3-8` corrects the runtime network claim. Windows runtime distribution/setup and exact failure/retry UX remain documented follow-ups. ADR-0005 was not found in the inspected workspace; this is not treated as a feature gate.

## Deviations

No new out-of-scope change was identified in the targeted revision. The current checkout contains extensive dirty/untracked work, including protected engine and legacy-page diffs; the Master Brief records those as pre-task changes. The handoff says no production map code changed in this revision. No initial snapshot is available to independently compare protected-file contents byte-for-byte.

## Risks

- Do not claim native support until each host/WebView is exercised; the selected plugin is prerelease and Linux WPE 2.0 is absent.
- Three unrelated/protected engine tests remain failing; the task's route-focused suite passes, but full suite is not green.
- Actual token origin/referrer restrictions and visible loaded-map attribution are unverified.

## Required Revisions

None for this audit. Host checks require environments that were unavailable; no impossible validation claim is requested. Keep these limitations attached to the delivery and run host validation when those hosts become available.

## Final Recommendation

**APPROVED_WITH_NOTES**. Forward to `instrum-orchestrator`; preserve explicit runtime limitations, the three existing engine-test failures, and the protected-baseline comparison limitation.

## Post-audit Linux WPE compatibility follow-up — 2026-10-25

**Correction verdict: APPROVED_WITH_NOTES** — forward to `instrum-orchestrator`.

### Correction review

- Debian GNU/Linux 13.6 reports `libwpewebkit-2.0-dev` 2.48.3-1, `libwpebackend-fdo-1.0-dev` 1.16.0-1, and `libsecret-1-dev` 0.21.7-1. The installed WPE headers do not declare `webkit_web_view_get_theme_color`.
- `pubspec.yaml` overrides only the federated `flutter_inappwebview_linux` implementation with `packages/flutter_inappwebview_linux`; the selected `flutter_inappwebview` 6.2.0-beta.3 and Linux implementation version 0.1.0-beta.1 remain unchanged. The local `getMetaThemeColor()` guard returns `std::nullopt` below WebKit 2.50 and compiles the original API path at/above 2.50. This matches upstream compatibility commit `889389e5d4069fd9f44927603793b90550c40b50` (the local comment is explanatory wording); the only other code delta against the cached 0.1.0-beta.1 source is a Debian 13 hint in the CMake missing-dependency message. Package README records the source version and upstream commit. This is a minimal behavioral patch and reproducible from the versioned package plus that guard; the path override necessarily vendors the plugin runtime source, so the vendored directory itself is not a tiny patch file.
- `analysis_options.yaml:21` explicitly excludes the vendored package. `flutter analyze` passed with no issues. The Linux build compiles the native plugin despite that Dart analyzer exclusion.
- Independently rerun on this environment: `flutter test test/app_router_test.dart test/window_manager_platform_test.dart test/mapbox_map_page_failure_test.dart test/features/map/presentation/pages/mapbox_focus_bridge_test.dart` passed 19/19; `flutter build linux --debug` passed and produced `build/linux/x64/debug/bundle/fogo`. `git diff --check` also passed.
- README lines 183-215 and refreshed handoff lines 48-53 correctly distinguish the successful Debian/WPE build from the still-unverified Mapbox style/WebGL2 rendering, attribution, interaction, and token-origin behavior. Handoff's 45-second Linux startup is reported there, but no retained startup log was available for independent verification in this follow-up.

### Carried limitations and audit boundary

- Full `flutter test` was not rerun: this correction changes Linux native plugin compatibility only. The last recorded full-suite result remains 187 passed / 3 failed; all three failures remain in protected `test/engine/fogo_engine_test.dart`: expected 6 junction pads, got 1 (line 53); expected 2 objects for way/12, got 1 (line 224); expected a rail-crossing pad >0, got 0 (line 413). Their clean-baseline disposition is still unverified, as previously recorded.
- This follow-up does not change or clear the prior limitations: actual Mapbox rendering and interaction, visible loaded-map attribution, token-origin behavior, other native targets, and byte-for-byte protected-area baseline comparison remain unverified/unavailable. No new protected-area change was identified in the Linux compatibility correction.
- No out-of-scope change or correction-specific test failure found. Maintain the local override only until a published upstream plugin release includes the guard; verify and remove the override then.
