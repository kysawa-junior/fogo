# Master Brief — TASK-0007: Mapbox Standard Night Root Route

## Source request and approval record

The user approved `docs/superpowers/specs/2026-10-25-mapbox-standard-night-design.md` for TASK-0007 and requested implementation. User approval is recorded here. The design spec is outside this compiler's artifact ownership and remains untouched; its file metadata may still say “awaiting spec review.” That metadata is not an implementation gate or an unresolved design question. This brief prepares implementation instructions only; no implementation is performed in this documentation stage.

## Objective and scope

Replace only `/` with one Mapbox GL JS Standard map hosted in an embedded WebView on Android, iOS, Linux, Windows, and macOS. Use the pinned Mapbox GL JS v3.33.0 CDN release, `basemap.lightPreset=night`, and a top-down 2D camera; do not mount the 3D engine viewport on `/`. Preserve F.O.G.O. navigation and geographic search, focusing the map camera on a selected result. Keep `/inventory` and `/predictive` behavior unchanged. Flutter Web is excluded; do not add a native Mapbox Flutter SDK or a second map implementation.

The approved design spec assumes an initial center at Marília-SP. Treat that center explicitly as an assumption, not a confirmed product requirement. Engineering chooses a reasonable initial zoom; no zoom confirmation is required. Support pan and zoom with mouse and touch. Do not show engine-only local OSM import, city load, engine status/statistics, 3D toggle, or engine-backed entity selection on the primary screen. Show visible loading and WebView/style/WebGL/configuration failure states rather than an indefinite blank viewport. Keep Mapbox logo and required attribution visible on a loaded map.

Keep the map within the existing desktop native window and preserve its titlebar/window controls. Gate all `window_manager` initialization, titlebar, and close handling to desktop; Android/iOS must not invoke `window_manager` or show desktop window controls.

## Requirements and constraints

*(token Mapbox removido — push protection)*
- Preserve HTTPS/ATS security. Android release builds need INTERNET permission; macOS needs the outgoing-client sandbox entitlement. Linux requires WPE 2.0. Windows requires WebView2 runtime/setup validation.
- `flutter_inappwebview` 6.2.0-beta.3 is the selected, user-approved prerelease candidate; do not substitute another plugin. Validate host/runtime behavior on all five native targets, especially Linux with WPE 2.0.
- Use the Mapbox GL JS v3.33.0 CDN release and check WebGL2 capability. Preserve attribution and visible map load/failure UI.
- Use a narrow, lifecycle-safe JS bridge, wait for map/style `load` readiness, use Mapbox `[longitude, latitude]` ordering, and ignore events after disposal. Retaining the latest pending search focus until ready is a recommended safe engineering behavior; engineering may adopt it or choose another safe behavior and document/test that choice. This is not a user-mandated policy or open product question.
- Do not pass a dummy `MapEngineState` to `TopBar`. Reuse search only with a compatible decoupling from engine status, or add a route-specific header without editing the protected `map_3d_page.dart`.
- Preserve all pre-existing working-tree changes, especially `pubspec.lock`, `README.md`, engine files, `map_3d_page.dart`, and tests. Do not modify `lib/engine/**` or `lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart`.
- Update operational documentation only where existing route/platform/runtime/network claims become directly false, preserving existing document edits.

## Affected areas

- `lib/app/router/app_router.dart`, `lib/main.dart`, `lib/app/fogo_app.dart`, `lib/app/window_close_handler.dart`, and `lib/core/design_system/widgets/fogo_titlebar/**`.
- New root map presentation/JS bridge; existing search provider/results reuse; `TopBar` only if compatibility is maintained.
- `pubspec.yaml`/`pubspec.lock`; Android main manifest; macOS entitlements; platform registration/build files only as needed.
- `README.md` and `tool/map_data/README.md` only for directly contradicted operational claims.
- Focused routing, platform-gate, bridge/search-camera tests and regression coverage for unaffected routes.

## Protected areas

- All files under `lib/engine/**`.
- `lib/features/map/presentation/pages/map_3d_page/map_3d_page.dart`.
- All pre-task working-tree modifications; do not overwrite or reset them.

## Confirmed findings and documentation audit

- The current root is `Map3dPage`; search provider/results are reusable. `TopBar` depends on `MapEngineState` and displays engine status.
- `window_manager` calls occur in `main.dart`, `FogoApp`, `WindowCloseHandler`, and `FogoTitlebar`; all call sites need platform gating.
- `GeoSearchResult` uses `LatLng(latitude, longitude)`; Mapbox center order is `[longitude, latitude]`.
- Mapbox GL JS v3 requires WebGL2; v3.33.0 is the settled CDN version.
- `flutter_inappwebview` 6.2.0-beta.3 is the selected package candidate. Linux WPE 2.0 is absent in the inspected environment. Discovery agents ran no tests/builds.
- The worktree already contains broad pre-existing changes, including README, lockfile, engine, `map_3d_page.dart`, and tests.
- `tool/map_data/README.md` claims the app makes no runtime map-network requests; that claim becomes false after this route is live. Its local OSM asset-pipeline description remains valid. It references absent `docs/agent-work/handoffs/TASK-0004-validation-evidence.md`.
- `README.md` describes a desktop-only app, 3D engine on `/`, and desktop-only run instructions; update only directly affected operational statements during implementation.
- No local `docs/architecture`, `docs/adr`, `docs/agent-work` examples, or `.agents` files were found during discovery. `lib/core/design_system/fogo_map_style.dart` references ADR-0005; verify it if available and relevant, without inventing an architecture decision or treating its absence as a product/design question.

## Remaining implementation follow-ups

These are the only unresolved implementation follow-ups; distinguish design/UX decisions from host validation tasks:

1. Choose and document exact failure/retry copy and UX.
2. Confirm supported Windows WebView2 runtime/version and exact host/NuGet setup.
3. Validate actual WebView, WPE, and WebGL2 behavior per available host; report unavailable prerequisites/targets.
4. Validate token origin/referrer restriction behavior in the actual WebView.
5. Verify ADR-0005 if it is available and relevant; report evidence or inability to verify without making it a feature gate.

The public token, compile-time configuration key/default, plugin choice, Mapbox GL JS version, Marília-SP center assumption, engineering-selected zoom, and optional latest-pending focus policy are settled as recorded above; do not reopen them as questions.

## Risks

- **High:** Linux plugin support is prerelease/initial and WPE 2.0 is absent locally; real Linux WPE/WebGL2 validation is required.
- **High:** Native WebView/WebGL2 support and token origin/referrer behavior can vary by host; validate and report target-by-target evidence.
- **Medium:** Android release INTERNET permission and macOS outgoing-client entitlement need to be present and validated.
- **Medium:** Bridge readiness, callback lifecycle, and coordinate-order errors can misplace camera focus.
- **Medium:** Engine-coupled `TopBar` and protected legacy page constrain reuse.
- **High:** Dirty worktree and lockfile changes raise overwrite/regression risk.
- **Low/conditional:** ADR-0005 is unavailable in inspected docs; verify if available/relevant and report the limitation, not as a product blocker.

## Team assignment and sequence

- Engineering: required. Engineering lead and platform specialists as assigned by the orchestrator.
- Design: not assigned; approved spec is the visual source of truth.
- Code Analysis: not assigned; this is a net-new approved feature, not a defect/code-audit task.
- Sequence: engineering development, then delivery audit.

## Acceptance criteria

- **AC-01:** `/` loads Mapbox Standard night style using Mapbox GL JS v3.33.0 with a top-down 2D camera and no mounted 3D engine viewport.
- **AC-02:** Pan/zoom works with mouse and touch on validated supported targets.
- **AC-03:** Selecting a geographic search result focuses the camera to its coordinate using `[longitude, latitude]`; pre-readiness selection is handled safely. Retaining only the latest pending coordinate is recommended, not mandated; document/test the selected behavior.
- **AC-04:** F.O.G.O. navigation and search remain; engine-only controls are absent from the primary screen.
- **AC-05:** `/inventory` and `/predictive` behavior remains unchanged.
- **AC-06:** Existing desktop native window/titlebar is preserved; all five native hosts are validated or unavailable prerequisites explicitly reported.
- **AC-07:** Android/iOS do not invoke `window_manager` or show desktop controls; all call sites are lifecycle/platform gated.
- **AC-08:** Loaded map keeps logo/attribution; load, WebView, style, WebGL, and invalid-configuration failures are visible, with no indefinite blank viewport.
- **AC-09:** Compile-time `MAPBOX_ACCESS_TOKEN` defaults to the supplied public `pk` token; no `sk` token is used, exposed, or logged. Token origin/referrer behavior is validated on actual hosts and is not treated as missing-token blockage.
- **AC-10:** No changes under `lib/engine/**` or to `map_3d_page.dart`; all pre-existing local changes are preserved.
- **AC-11:** Linux WPE 2.0 and Windows WebView2 runtime/setup requirements are documented; Android and macOS network configuration is validated.
- **AC-12:** Formatter, `flutter analyze`, `flutter test`, and builds for available targets run; results and unavailable targets are reported accurately.
- **AC-13:** Directly affected README/map-data operational claims are updated without erasing local edits.

## Work packages

Engineering work is specified in `docs/agent-work/work-packages/ENG-0007-mapbox-standard-night-root-route.md`. Cross-boundary integration is specified in `docs/agent-work/work-packages/INT-0007-mapbox-root-route-integration.md`.
