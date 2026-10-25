# Mapbox Standard Night for F.O.G.O.

- **Task:** TASK-0007
- **Status:** Design approved; awaiting spec review
- **Date:** 2026-10-25

## Goal

Replace the F.O.G.O. operations screen's 3D-engine viewport with Mapbox Standard in night mode. Keep the Flutter application and its native desktop window, support mobile targets, and leave the 3D engine available for later separation.

## Current state

- `/` routes to `Map3dPage`, which uses `FogoEngine`, `FlutterSceneAdapter`, and `FogoSceneView`.
- That page also exposes engine-specific OSM imports, city selection, 3D selection details, and engine statistics.
- The current app startup and titlebar call `window_manager` unconditionally, despite Android/iOS project targets.
- Mapbox's Flutter SDK supports Android/iOS, not Linux, Windows, macOS, or Web. Mapbox Standard is not compatible with Mapbox Static Tiles, so raster tiles cannot provide this exact style.
- Mapbox GL JS supports the Standard style and its `lightPreset: night` configuration.
- The current environment has no WPE/WebKit pkg-config package. The proposed Linux WebView path therefore has a host runtime prerequisite.

## Approved architecture

Use one Mapbox GL JS map embedded in a platform WebView across Android, iOS, Linux, Windows, and macOS. Keep F.O.G.O.'s navigation and map UI in Flutter; do not add Mapbox's native Flutter SDK or a second map implementation. The native desktop window remains. Flutter Web in a standalone browser is not a target for this change.

Configure the map with:

- Style URI: `mapbox://styles/mapbox/standard`
- Standard import ID: `basemap`
- `basemap.lightPreset`: `night`
- Top-down 2D camera; pan and zoom remain interactive.
- The public `pk` token supplied by the user, provided to the client configuration. Do not use or request a secret `sk` token.

Use a WebView plugin with Linux, Windows, macOS, Android, and iOS implementations. Linux requires WPE 2.0; Windows requires its supported WebView runtime. Keep Mapbox attribution visible.

## F.O.G.O. screen behavior

- Route `/` displays the Mapbox map and retains F.O.G.O. navigation and geographic search.
- Selecting a search result moves the Mapbox camera to that coordinate.
- Use Marília-SP as the initial center, matching the current regional focus; make no claim that this is a confirmed user requirement.
- Keep the desktop titlebar/window controls on desktop. Skip desktop window initialization and titlebar controls on Android/iOS.
- Remove engine-only controls from the primary F.O.G.O. screen: local `.osm` import, engine city loading, engine status/statistics, 3D toggle, and engine-backed entity selection.
- Keep the existing engine sources, dependencies, tests, and all current local changes untouched. This task only removes the engine from the primary route; it does not extract or delete it.
- Keep inventory and predictive-city routes unchanged.

## Failure and attribution behavior

Show a clear map loading/error state if the WebView or Mapbox style fails; do not leave an indefinitely blank viewport. Keep Mapbox's required logo and attribution controls visible. Map display requires network access.

The `pk` token is public and will be inspectable in the client. Restrict it in Mapbox account settings where supported. No secret token belongs in source, assets, or logs.

## Acceptance criteria

1. `/` loads Mapbox Standard with the night preset and a 2D camera; no 3D engine viewport is mounted there.
2. Pan and zoom work with mouse and touch. Search-result selection moves the camera.
3. The map is embedded in the existing desktop window and works on Android/iOS without desktop window-manager calls.
4. Mapbox attribution remains visible, and map/WebView failures produce a visible error state.
5. Engine files and pre-existing local engine changes remain unchanged.
6. Run Dart formatting, `flutter analyze`, `flutter test`, and available target builds. Record unavailable native targets and missing Linux WebView prerequisites rather than claiming they passed.

## Scope and risks

**In scope:** primary operations map, WebView/Mapbox GL JS integration, camera/search bridge, platform-gated startup/titlebar, Mapbox token wiring, focused tests and validation.

**Out of scope:** extracting/deleting the 3D engine, changing the other modules, offline maps, custom Mapbox style, native Mapbox SDK, and a separate Flutter Web browser application.

**Risks:** Linux WebView requires WPE 2.0, which is absent in the current environment; WebView availability/runtime differs by OS; Mapbox GL JS requires network access; the public token is visible in the distributed client.
