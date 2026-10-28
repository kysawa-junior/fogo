---
id: ENG-0007
version: "1"
status: approved
source:
  user_request: "TASK-0007"
  orchestrator_task_id: TASK-0007
objective: "Replace only the root route renderer with a WebView-hosted Mapbox GL JS Standard night map while preserving search, navigation, other routes, native window behavior, and protected local work."
background: "The user-approved Mapbox Standard Night spec is the visual source of truth. Existing root is Map3dPage; Mapbox GL JS v3.33.0 in flutter_inappwebview 6.2.0-beta.3 is selected for five native hosts. The worktree contains pre-existing modifications that must remain untouched."
scope:
  included:
    - "Route `/` to a new WebView-hosted Mapbox GL JS Standard map with night preset and top-down 2D camera."
    - "Retain geographic search and F.O.G.O. navigation; bridge selected result coordinates to map camera focus."
    - "Keep visible loading and WebView/style/WebGL/configuration failure states and Mapbox attribution."
    - "Platform-gate all window_manager initialization, titlebar, and close handling to desktop."
    - "Add only required host/runtime configuration, focused tests, and directly contradicted operational-documentation updates."
    - "Preserve `/inventory` and `/predictive` behavior."
  excluded:
    - "Flutter Web, a native Mapbox Flutter SDK, or a second map implementation."
    - "Changes to engine implementation or the protected Map3dPage file."
    - "Changes to inventory or predictive-city behavior."
    - "Unrelated documentation, source, test, or working-tree cleanup."
requirements:
  functional:
    - "On `/`, display one Mapbox GL JS Standard map with `basemap.lightPreset=night` and top-down 2D camera; do not mount the 3D engine viewport."
    - "Support mouse and touch pan/zoom on validated targets."
    - "Selecting a geographic search result moves camera to the coordinate, converting LatLng(latitude, longitude) to Mapbox [longitude, latitude]."
    - "Keep F.O.G.O. navigation/search; omit engine-only OSM import, city load, engine status/statistics, 3D toggle, and engine-backed entity selection from primary screen."
    - "Show visible loading and failure states; preserve Mapbox logo and required attribution on loaded map."
    - "Keep `/inventory` and `/predictive` behavior unchanged."
  non_functional:
    - "Use the same WebView-hosted Mapbox GL JS map on Android, iOS, Linux, Windows, and macOS; Flutter Web is excluded."
    - "Use compile-time configurable MAPBOX_ACCESS_TOKEN, defaulting to the supplied approved public pk token; never use, expose, or log an sk token."
    - "Keep HTTPS/ATS and existing security settings intact."
    - "Preserve all pre-existing working-tree changes."
    - "Run formatter, flutter analyze/test, and builds for available target hosts; accurately report unavailable prerequisites and targets."
constraints:
  technical:
    - "Use the selected, user-approved prerelease flutter_inappwebview 6.2.0-beta.3 without substituting another plugin; validate on each native host, especially Linux WPE 2.0."
    - "Linux requires WPE 2.0; validate supported Windows WebView2 runtime/version and exact host/NuGet setup; Android release requires INTERNET permission; macOS sandbox requires outgoing-client entitlement."
    - "Use Mapbox GL JS v3.33.0 from the CDN; it requires WebGL2, which must be detected and unavailable behavior handled explicitly."
    - "Use a narrow lifecycle-safe JS bridge; wait for map/style load readiness, handle pre-readiness search focus safely, preserve coordinate ordering, and ignore callbacks after disposal. Retaining only the latest pending selection is recommended, not mandated; engineering may choose another safe policy and document/test it."
    - "Use compile-time MAPBOX_ACCESS_TOKEN, defaulting to the supplied public token; validate actual WebView origin/referrer restrictions on hosts."
  architectural:
    - "Preserve existing app/router architecture and use the user-approved spec; verify ADR-0005 if available and relevant, without treating unavailable metadata as a product gate."
    - "Do not pass dummy MapEngineState to TopBar. Reuse search with compatible engine-status decoupling, or use a route-specific header without editing the protected legacy page."
    - "Gate every window_manager call site, including startup, app shell, close handler, and titlebar; Android/iOS must not invoke it."
  visual:
    - "Use the approved Mapbox Standard Night spec as visual source of truth; do not introduce unapproved map styling decisions."
    - "Preserve visible Mapbox logo and required attribution."
  business:
    - "The supplied public token is approved and is the default compile-time configuration; never describe token absence as a blocker."
dependencies:
  agents:
    - "engineering-lead"
    - "delivery-auditor"
  work_packages:
    - "INT-0007"
  modules:
    - "App router, application shell, and startup/window lifecycle"
    - "Map presentation and existing geographic search"
    - "WebView host and Mapbox GL JS runtime"
    - "Android, iOS, Linux, Windows, and macOS host configuration"
assigned_agents:
  - "engineering-lead"
affected_areas:
  modules:
    - "lib/app routing, app shell, startup, close handling, and desktop titlebar"
    - "Map presentation, geographic search/header compatibility, and WebView bridge"
    - "Native host registration and platform runtime configuration"
  packages:
    - "flutter_inappwebview 6.2.0-beta.3 (selected prerelease; host/runtime validation required)"
    - "Mapbox GL JS v3.33.0 CDN release (pinned)"
  files:
    - "lib/app/router/app_router.dart"
    - "lib/main.dart"
    - "lib/app/fogo_app.dart"
    - "lib/app/window_close_handler.dart"
    - "lib/core/design_system/widgets/fogo_titlebar/**"
    - "New root map presentation and JS bridge files"
    - "Existing geographic search provider/results and TopBar only if compatible"
    - "pubspec.yaml and pubspec.lock"
    - "Android app main manifest and macOS entitlements"
    - "Platform registration/build files only as needed"
    - "README.md and tool/map_data/README.md only for directly contradicted operational claims"
    - "Focused routing, platform-gate, bridge/search-camera, and unaffected-route tests"
protected_areas:
  modules:
    - "lib/engine/**"
  files:
    - "lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart"
    - "Every path with a pre-task working-tree modification; preserve its existing content and diff, especially pubspec.lock, README.md, engine files, map_3d_page.dart, and tests."
deliverables:
  - "Root route uses pinned Mapbox GL JS v3.33.0 Standard night map in embedded WebView on supported native hosts."
  - "Lifecycle-safe search-to-camera bridge and visible readiness/failure states."
  - "Desktop-only window_manager/titlebar behavior; no mobile window_manager calls or desktop controls."
  - "Compile-time MAPBOX_ACCESS_TOKEN defaults to supplied public pk token; no sk token is used or exposed."
  - "Required host configuration and focused tests, with remaining runtime/validation follow-ups recorded."
  - "Only directly contradicted operational documentation claims updated, preserving local edits."
acceptance_criteria:
  - "AC-01: `/` loads Mapbox Standard night style with top-down 2D camera and no mounted 3D engine viewport."
  - "AC-02: Pan/zoom works with mouse and touch on validated supported targets."
  - "AC-03: Search-result selection focuses camera using Mapbox [longitude, latitude] order; pre-readiness selection is handled safely. Latest-pending retention is recommended but not mandated; document and test the chosen behavior."
  - "AC-04: F.O.G.O. navigation/search remain; engine-only controls are absent from primary screen."
  - "AC-05: Inventory and predictive-city routes behave unchanged."
  - "AC-06: Existing desktop native window/titlebar remains; all five native hosts are validated or unavailable prerequisites reported."
  - "AC-07: Android/iOS never invoke window_manager or show desktop window controls; every call site is lifecycle/platform gated."
  - "AC-08: Loaded map retains logo/attribution; load, WebView, style, WebGL, and configuration failures are visible with no indefinite blank viewport."
  - "AC-09: Compile-time MAPBOX_ACCESS_TOKEN defaults to the supplied approved public pk token; no sk token is used, exposed, or logged. Validate actual WebView origin/referrer behavior; token absence is not a blocker."
  - "AC-10: No edits under lib/engine/** or to map_3d_page.dart; all pre-existing local changes remain intact."
  - "AC-11: Linux WPE 2.0 and Windows WebView runtime requirements are documented; Android and macOS network configuration is validated."
  - "AC-12: Formatter, flutter analyze/test, and builds for available targets run; results and unavailable targets are reported accurately."
  - "AC-13: Directly affected README/map-data operational claims are updated without erasing local edits."
testing_requirements:
  - "Test root route selection and verify inventory/predictive routes are unchanged."
  - "Test platform gates for all window_manager startup, titlebar, and close-handler call paths; Android/iOS must not invoke them."
  - "Test bridge readiness, the chosen safe pre-readiness focus behavior, [longitude, latitude] conversion, error reporting, and callbacks after disposal."
  - "Test invalid-configuration, WebView/style failure, and WebGL2-unavailable states; verify supplied default public token reaches the map without logging it."
  - "Run formatter, flutter analyze, flutter test, and builds for each available native target; record actual WPE/WebView/WebGL2 host validation and unavailable prerequisites."
  - "Validate token origin/referrer restrictions in actual WebViews; do not describe this as a missing-token blocker."
documentation_requirements:
  - "Document compile-time MAPBOX_ACCESS_TOKEN and supplied public default; never document or expose an sk token."
  - "Document Linux WPE 2.0, Windows WebView2 runtime/NuGet, Android release INTERNET, and macOS outgoing-client entitlement prerequisites."
  - "Correct only directly contradicted operational route/platform/runtime/network claims in README.md and tool/map_data/README.md, preserving existing edits."
  - "Record unvalidated host targets, token origin/referrer validation, exact failure/retry UX, Windows runtime/setup, and ADR-0005 verification if relevant."
risks:
  - "High: Linux plugin support is prerelease/initial and WPE 2.0 is absent locally; real Linux WPE/WebGL2 validation is needed."
  - "High: per-host WebView/WebGL2 and token origin/referrer behavior require actual host validation."
  - "Medium: Android release INTERNET permission and macOS outgoing-client entitlement must be present and validated."
  - "Medium: bridge readiness/lifecycle and coordinate-order mistakes can misplace search focus."
  - "Medium: engine-coupled TopBar must be decoupled without touching protected legacy Map3dPage or using dummy state."
  - "High: pre-existing worktree and pubspec.lock edits risk accidental overwrite."
  - "Low/conditional: ADR-0005 is unavailable; verify if available and relevant, and report evidence or limitation without inventing a decision."
completion_report:
  required: true
architecture:
  pattern: "Existing Flutter architecture; inspect and preserve"
  state_management: "Existing project state management; inspect and preserve"
  ui_framework: "Flutter"
design_dependency:
  package: ""
  status: "Approved spec is the visual source of truth; no Design Work Package is assigned."
implementation_requirements:
  - "Use compile-time MAPBOX_ACCESS_TOKEN with the supplied public token as default; use Mapbox GL JS v3.33.0 CDN and flutter_inappwebview 6.2.0-beta.3 as selected. Do not reopen these choices."
  - "Treat Marília-SP as the design spec's initial-center assumption and choose a reasonable initial zoom in engineering; neither requires confirmation."
  - "Validate the selected plugin/runtime on actual Android, iOS, Linux, Windows, and macOS hosts before claiming support; do not substitute another plugin."
  - "Wait for Mapbox style/map load readiness; latest-pending focus is recommended safe behavior, not mandated. Engineering may select another safe behavior and must document/test it; ignore bridge events after disposal."
  - "Resolve only exact failure/retry UX, Windows WebView2 runtime/version and host setup, per-host WPE/WebView/WebGL2 validation, actual token origin/referrer behavior, and ADR-0005 verification if available/relevant."
  - "Do not pass dummy MapEngineState to TopBar or modify the protected Map3dPage to enable reuse."
  - "Preserve all local modifications and keep existing HTTPS/ATS security settings."
required_tests:
  - "Root route, navigation, inventory/predictive regression tests."
  - "All window_manager platform/lifecycle gate tests."
  - "Search bridge readiness, coordinate-order, selected pre-readiness policy, disposal, and failure-state tests."
  - "Formatter, flutter analyze/test, and available native target builds; record actual host coverage."
forbidden_changes:
  - "Do not edit any file under lib/engine/**; this is a protected area in the Master Brief."
  - "Do not edit lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart; this is a protected file in the Master Brief."
  - "Do not overwrite, reset, or discard any pre-task working-tree modification; all such modifications are protected by the Master Brief."
---
# Work Package ENG-0007 — Mapbox Standard Night Root Route

## Objective

Implement the user-approved root-route replacement as a single Mapbox GL JS v3.33.0 Standard night map hosted inside the existing Flutter application WebView on Android, iOS, Linux, Windows, and macOS. Use the selected `flutter_inappwebview` 6.2.0-beta.3 prerelease candidate. Configure compile-time `MAPBOX_ACCESS_TOKEN` with the supplied public `pk` token as its default. Preserve search/navigation, unaffected routes, desktop native-window behavior, and all pre-existing local changes.

## Scope and boundaries

Change only the root route and the supporting WebView bridge, search/header compatibility, platform lifecycle/configuration, tests, and operational documentation directly contradicted by the new runtime map. Do not modify `lib/engine/**` or `lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart`. Do not change `/inventory` or `/predictive`, and do not clean up/reset any existing dirty or untracked work.

Use the user-approved spec as the visual source of truth. The initial center is Marília-SP by spec assumption, not a confirmed requirement; choose a reasonable initial zoom in engineering. Do not mount a 3D engine viewport on `/`; omit engine-only controls. Keep the loaded map's Mapbox logo and required attribution visible. Show loading and visible failure states for invalid configuration, WebView/style failure, or unavailable WebGL2.

## Integration and implementation requirements

- Keep the map embedded in the existing desktop native window and preserve its titlebar/window controls. Gate all `window_manager` calls in startup, app shell, close handler, and titlebar to desktop; mobile must not call `window_manager` or show desktop controls.
- Retain existing geographic search. Convert `LatLng(latitude, longitude)` to Mapbox `[longitude, latitude]` at the bridge boundary. Marília-SP is the approved spec's center assumption; engineering chooses reasonable zoom.
- Wait for map/style `load` before applying search focus. Retaining the latest pending coordinate while not ready is recommended safe behavior, not mandated; engineering may choose another safe behavior and must document/test it. Ignore late events after disposal. Make readiness and failure visible to Flutter.
- Do not pass dummy `MapEngineState` to `TopBar`. Reuse search only if engine-status coupling can be removed compatibly, or provide a route-specific header without changing the protected legacy page.
*(token Mapbox removido — push protection)*
- Use selected `flutter_inappwebview` 6.2.0-beta.3 without substitution; validate all five native targets. Linux WPE 2.0, Windows WebView2 runtime/version and exact NuGet/host setup, Android release INTERNET permission, and macOS outgoing-client entitlement are prerequisites. Preserve HTTPS/ATS.
- Use pinned Mapbox GL JS v3.33.0 CDN and check WebGL2 capability. Update only directly contradicted operational documentation, preserving existing edits.

## Remaining implementation follow-ups

Remaining follow-ups only: exact failure/retry copy and UX; supported Windows WebView2 runtime/version and exact host setup; actual per-host WPE/WebView/WebGL2 validation; token origin/referrer restriction behavior in the actual WebView; and ADR-0005 verification if available/relevant. The token/default, compile-time key, selected plugin/version, GL JS v3.33.0 pin, Marília-SP center assumption, engineering-selected zoom, and recommended (optional) latest-pending policy are settled as recorded above. Do not reopen them as questions.

## Acceptance and evidence

Meet AC-01 through AC-13 in this package's frontmatter. Run formatter, `flutter analyze`, `flutter test`, and builds for available native targets. Test routing, search bridge readiness/order/lifecycle, platform gates, and unaffected routes. Explicitly report unavailable WPE/WebView runtimes and targets not built, actual token origin/referrer results, and any ADR-0005 verification limitation; do not claim unrun evidence or describe token absence as a blocker.

## Handoff

See `docs/agent-work/handoffs/HANDOFF-TASK-0007.md` for execution order and coordination boundary.
