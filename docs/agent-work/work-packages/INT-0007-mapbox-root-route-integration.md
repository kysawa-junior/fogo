---
id: INT-0007
version: "1"
status: approved
source:
  user_request: "TASK-0007"
  orchestrator_task_id: TASK-0007
objective: "Define the cross-boundary contract connecting root routing and geographic search, a WebView-hosted Mapbox GL JS v3.33.0 map, native host/window lifecycle, token configuration, and runtime prerequisites."
background: "This integration artifact was explicitly requested even though Design is not assigned. It aligns Flutter, JavaScript/WebView, and native host boundaries for the user-approved Mapbox Standard Night root route."
scope:
  included:
    - "Flutter root route and search-result to WebView map-camera integration."
    - "Map readiness, pending search focus, failure reporting, and disposal boundaries."
    - "Native host/window lifecycle and per-platform WebView/network prerequisites."
    - "Public-token configuration and attribution/security constraints."
  excluded:
    - "Design deliverables or a separate design assignment."
    - "Changing inventory/predictive route behavior or the protected 3D engine implementation."
    - "Adding Flutter Web, a native Mapbox Flutter SDK, or a second map implementation."
    - "Reopening approved token, plugin/version, GL JS version, or center assumption as user decisions."
requirements:
  functional:
    - "The Flutter `/` route hosts exactly one Mapbox GL JS Standard night map in a WebView; no 3D engine viewport is mounted on this route."
    - "Existing geographic search selection reaches the map and focuses its camera on the selected coordinate."
    - "Map load/readiness and failures cross the WebView boundary as visible Flutter states; no indefinite blank viewport."
    - "Desktop native window and titlebar remain intact; mobile does not invoke desktop window controls."
  non_functional:
    - "Use the same WebView-hosted Mapbox GL JS v3.33.0 implementation on Android, iOS, Linux, Windows, and macOS; Flutter Web is excluded."
    - "Use compile-time MAPBOX_ACCESS_TOKEN, defaulting to supplied public pk token; never use, expose, or log an sk token."
    - "Maintain HTTPS/ATS and required Mapbox logo/attribution."
    - "Report actual host/runtime validation, including token origin/referrer behavior; the supplied token is not a missing-token blocker."
constraints:
  technical:
    - "Existing result coordinate is LatLng(latitude, longitude); Mapbox center order is [longitude, latitude]."
    - "Mapbox GL JS v3.33.0 CDN release is pinned and requires WebGL2; detect and report WebGL2 unavailability."
    - "The selected user-approved plugin is flutter_inappwebview 6.2.0-beta.3; do not substitute it. Validate actual host behavior; Linux requires WPE 2.0."
    - "Validate supported Windows WebView2 runtime/version and exact host/NuGet setup; Android release requires INTERNET permission; macOS sandbox requires outgoing-client entitlement."
    - "Do not modify lib/engine/** or lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart; preserve all pre-existing worktree changes."
  architectural:
    - "Root route replacement does not redefine inventory/predictive routing or remove the protected legacy 3D page."
    - "All window_manager initialization, titlebar, and close handling is platform/lifecycle gated to desktop."
    - "Bridge is narrow and lifecycle-safe; ignore callbacks after WebView/page disposal."
  visual:
    - "User-approved Mapbox Standard Night spec is the visual source of truth; no additional design decisions are made by this contract."
    - "Keep Mapbox logo and required attribution visible on the loaded map."
  business:
    - "The supplied public token and compile-time configuration key/default are approved; validate token origin/referrer behavior on actual WebViews."
dependencies:
  agents:
    - "engineering-lead"
    - "delivery-auditor"
  work_packages:
    - "ENG-0007"
  modules:
    - "Flutter router, app shell, search provider/results, and map presentation"
    - "WebView plugin and Mapbox GL JS runtime"
    - "Android, iOS, Linux, Windows, and macOS host/window lifecycle"
assigned_agents:
  - "engineering-lead"
affected_areas:
  modules:
    - "Flutter root routing and geographic search"
    - "WebView-to-Flutter readiness, search-focus, and failure bridge"
    - "Native host lifecycle, desktop window controls, and runtime configuration"
  packages:
    - "flutter_inappwebview 6.2.0-beta.3 (selected prerelease; host validation required)"
    - "Mapbox GL JS v3.33.0 CDN release (pinned)"
  files:
    - "lib/app/router/app_router.dart"
    - "lib/main.dart"
    - "lib/app/fogo_app.dart"
    - "lib/app/window_close_handler.dart"
    - "lib/core/design_system/widgets/fogo_titlebar/**"
    - "New root map/bridge files and existing geographic search integration points"
    - "Android app main manifest, macOS entitlements, pubspec.yaml/pubspec.lock as required"
protected_areas:
  modules:
    - "lib/engine/**"
  files:
    - "lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart"
    - "All pre-task working-tree modifications; preserve existing contents/diffs."
deliverables:
  - "Shared Flutter-to-Mapbox coordinate, readiness, and failure contract documented here."
  - "Explicit host/window, token, security, and runtime prerequisite boundaries."
  - "Remaining implementation follow-ups distinguished from approved decisions and validation risks."
acceptance_criteria:
  - "Flutter root route owns presentation and search selection; WebView map owns Mapbox rendering and camera operations."
  - "Search coordinate crosses boundary as `[longitude, latitude]`; pre-readiness selection is handled safely and behavior documented/tested. Retaining the latest pending selection is recommended but not mandated."
  - "Map readiness/failure returns to Flutter and is visible; late bridge events after disposal are ignored."
  - "Desktop window/titlebar remains; Android/iOS make no window_manager calls or show desktop window controls."
  - "Compile-time MAPBOX_ACCESS_TOKEN defaults to the supplied public pk token; no sk token is used, exposed, or logged. Token origin/referrer behavior is validated on actual hosts, not blocked by missing credentials."
  - "Per-host prerequisites and actual validation status are recorded; unavailable targets are not reported as validated."
  - "Protected engine/page areas and pre-existing working-tree changes remain unchanged."
testing_requirements:
  - "Verify search coordinate ordering and bridge behavior before and after map/style readiness."
  - "Verify visible loading/failure paths and ignored callbacks after disposal."
  - "Verify platform gating of all window_manager call sites."
  - "Validate actual WebView/runtime/WebGL2 behavior on each available native host and report missing prerequisites."
documentation_requirements:
  - "Record compile-time MAPBOX_ACCESS_TOKEN and supplied default, platform/runtime setup, and actual token origin/referrer validation."
  - "Document target-by-target validation evidence and unavailable prerequisites."
risks:
  - "Linux WPE 2.0 is absent locally and selected plugin is prerelease; actual per-host WPE/WebView/WebGL2 validation is required."
  - "Supported Windows WebView2 runtime/version and exact host/NuGet setup remain to be validated."
  - "Exact failure/retry copy and UX remain an engineering follow-up."
  - "Token origin/referrer restriction behavior must be validated in actual WebViews."
  - "ADR-0005 is referenced by existing code but unavailable in inspected docs; verify if available and relevant, otherwise report limitation without treating it as a product gate."
completion_report:
  required: true
feature_id: "TASK-0007-mapbox-standard-night-root-route"
shared_models:
  - "Existing GeoSearchResult and its LatLng(latitude, longitude) coordinate; do not duplicate search-result model."
  - "Mapbox camera center coordinate represented at JS boundary as [longitude, latitude]."
shared_states:
  - "Loading: Flutter WebView/map host is not yet ready; show a visible loading state."
  - "Ready: Mapbox map/style load completed; queued search focus may be applied."
  - "Failure: WebView, style, WebGL2, or required configuration unavailable; report visibly to Flutter. Retry treatment remains open."
  - "Pending search focus: selection may arrive before Ready. Recommended safe policy is retain latest pending coordinate until Ready; engineering may adopt this or choose another safe behavior, document it, and test it. This is not a user-mandated behavior or unresolved user question."
responsibilities:
  design:
    - "No Design team is assigned. User-approved Mapbox Standard Night spec remains visual source of truth. User approval is recorded; compiler leaves the spec file's `awaiting spec review` metadata untouched, and that metadata is not an implementation gate."
  engineering:
    - "Flutter owns root route, search-result selection, window lifecycle, desktop-only window controls, and visible loading/failure presentation."
    - "WebView/Mapbox GL JS owns map rendering, Mapbox style readiness, WebGL2 capability detection, and camera movement."
    - "Bridge transports readiness/failure and camera-focus requests; it converts LatLng(latitude, longitude) to [longitude, latitude], implements the selected safe pre-readiness behavior, and ignores callbacks after disposal."
    - "Platform integration owns verified plugin/runtime and network prerequisites without weakening HTTPS/ATS."
approval_required_from:
  - "design-lead"
  - "engineering-lead"
  - "delivery-auditor"
---
# Integration Contract INT-0007 — Mapbox Root Route

## Boundary ownership

**Flutter** owns `/` routing, search selection, app/native-window lifecycle, and user-visible loading/failure presentation. **The WebView-hosted Mapbox GL JS v3.33.0 map** owns map rendering, Mapbox style readiness, WebGL2 capability detection, and camera movement. **The platform host** owns WebView/runtime registration, network permissions/entitlements, and desktop-only window integration.

F.O.G.O. geographic search remains the source of results. Reuse the existing `GeoSearchResult`/`LatLng(latitude, longitude)` model; do not create a duplicate. At the JavaScript boundary, represent the camera coordinate as Mapbox `[longitude, latitude]`.

## Readiness and camera-focus contract

Flutter may receive search selection before WebView or Mapbox style is ready. Map/bridge must report readiness after Mapbox map/style `load`; Flutter must show a visible loading state until then. Recommended safe behavior is to retain the latest pending selected coordinate and apply it once ready. Engineering may adopt this or choose another safe behavior, then document/test that choice; this recommendation is not a user-mandated policy or open user question. Once ready, subsequent selections focus the camera on their coordinate. Late bridge callbacks after page/WebView disposal are ignored.

WebView, style, WebGL2, and required-configuration failures must be reported to Flutter and shown visibly; the screen must not remain indefinitely blank. Exact error copy and retry treatment remain open. Preserve Mapbox logo and required attribution on loaded maps.

## Platform and window contract

Use one WebView-hosted Mapbox GL JS v3.33.0 implementation on Android, iOS, Linux, Windows, and macOS; exclude Flutter Web and native Mapbox Flutter SDKs. Keep the map inside the existing desktop native window and preserve desktop titlebar/window controls. Gate every `window_manager` startup, titlebar, and close-handler call to desktop. Android/iOS neither call `window_manager` nor show desktop controls. `/inventory` and `/predictive` remain unchanged.

The selected, user-approved `flutter_inappwebview` 6.2.0-beta.3 is prerelease; do not substitute it and validate actual behavior on all five targets. Linux requires WPE 2.0; validate supported Windows WebView2 runtime/version and exact host/NuGet setup; Android release requires INTERNET permission; macOS sandbox requires outgoing-client entitlement. Keep HTTPS/ATS unchanged. Mapbox GL JS v3.33.0 CDN is pinned and requires WebGL2; validate/report host failures.

## Token and configuration contract

*(token Mapbox removido — push protection)*

## Remaining implementation follow-ups

- Exact failure/retry copy and UX.
- Supported Windows WebView2 runtime/version and exact host/NuGet setup.
- Actual per-host WPE/WebView/WebGL2 validation and target-by-target evidence.
- Token origin/referrer restriction behavior in the actual WebView.
- ADR-0005 verification if available and relevant; report evidence or limitation without treating absence as a product gate.

The token/default, plugin/version, GL JS v3.33.0 pin, and Marília-SP center assumption are settled. Engineering chooses a reasonable initial zoom. Latest-pending focus is a recommended safe behavior, not an open user question. Preserve `lib/engine/**`, the protected `map_3d_page.dart`, `/inventory`, `/predictive`, desktop window/titlebar behavior, and all pre-existing working-tree modifications.
