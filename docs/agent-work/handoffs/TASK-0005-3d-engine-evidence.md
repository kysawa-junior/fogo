# TASK-0005 — 3D vector engine on local cells: validation evidence

**Date:** 2026-10-22
**Decision record:** [`docs/adr/ADR-0005-3d-vector-engine.md`](../../adr/ADR-0005-3d-vector-engine.md)
**User direction (2026-10-21):** evolve `fogo_map_sdk` into a 3D engine, no
Mapbox API, no webview, offline vector map with polished curves, visual
inspired by Mapbox Standard night.

## Delivered

- True perspective pinhole camera over the Web Mercator ground plane:
  continuous pitch 0°–60°, bearing 0°–360° (trackpad twist), near-plane
  clipping for polylines (segment clip) and polygons (Sutherland–Hodgman),
  ground ray-cast inverse for selection/persistence at any pitch/bearing.
- 3D building extrusions: real OSM `height` first; otherwise deterministic
  display-only estimates banded by footprint area (`estimateBuildingHeights`
  style flag; data untouched — ADR-0005). Two-tone walls under a fixed
  northwest light, depth-sorted far-to-near.
- `FogoSmooth`: endpoint-preserving Catmull-Rom resample for roads, rails,
  waterlines and route lines; junction nodes stay exactly fixed; corners
  sharper than 32° stay crisp. Road surface cache now lives in ground space,
  so pitch/bearing reuse buffered surfaces.
- Night palette v3 (F.O.G.O.-owned, Standard-night-inspired): land
  `#0D0F14`, water `#0B1726`, roads **lighter than land** (`#585F6E`
  motorway → `#171A21` path), roofs `#1B1E26`, walls `#232733`/`#14161D`,
  pale labels with dark halos. App tokens updated in lockstep.

## Commands and results (2026-10-22)

| Check | Result |
|---|---|
| `flutter analyze` (`packages/fogo_map_sdk`) | No issues |
| `flutter analyze` (root app) | No issues |
| `flutter test` (`packages/fogo_map_sdk`) | **38 passed** (incl. new 3D camera, near-clip, smoothing and estimate tests) |
| `flutter test` (root app) | **73 passed** |
| `dart format` (95 files) | applied; re-check clean |
| `flutter build linux --debug` | PASS (`build/linux/x64/debug/bundle/fogo`) |
| `sha256sum tool/map_data/raw/sudeste-latest.osm.pbf` | `cdf25842…1be7e59` — unchanged, matches manifest `sourceSha256` |

## Native captures (Linux X11, no browser)

Method: built Linux debug bundle launched as a native process with isolated
`HOME` (`/tmp/opencode/task-0005-home`) and `GDK_BACKEND=x11`; window
`0x1e00003` (1440×900) captured with `ffmpeg -f x11grab -window_id`; UI
interactions driven by XTEST synthetic clicks (python-xlib) at computed
button positions (Marília chip → zoom+×4 → 3D toggle). Pixel analysis via
Python/Pillow (this environment has no image-capable review; analysis is
statistical, not visual).

| Capture | Content | SHA-256 |
|---|---|---|
| `task-0005-corridor.png` | Initial regional corridor view | `f398360f…22c9` |
| `task-0005-marilia-topdown.png` | Marília z16, pitch 0 | `4a60def0…01c` |
| `task-0005-marilia-3d.png` | Same camera, pitch 45° (3D toggle) | `7c8beb16…1f2f` |
| `task-0005-marilia-flat2.png` | Same camera, toggled back to pitch 0 | `22c56e6c…64bd` |

### Statistical verification

- Palette: map background `#0D0F14` dominant (~36% of frame incl. UI); road
  ramp colors present in every view (primary `#474D59` ≈1.7%, residential
  `#2A2F3A` ≈3%, service ≈1.7% at z16) — roads are now visible against land,
  unlike v4's dark-on-dark.
- **3D engagement proof (crop 600×700, step 2):**
  - `diff(topdown, flat2) = 0.0%` — two flat states of the same camera are
    pixel-identical;
  - `diff(topdown, 3d) = 42.6%` and `diff(3d, flat2) = 42.6%` — toggling the
    3D button changes ~43% of map pixels, i.e. the perspective camera and
    extrusions render, and toggling back restores the flat state exactly.
- Wall shades (lerps between `#14161D` and `#232733`, e.g. `(32,35,46)`
  ≈47k px) appear only in the pitched capture family, consistent with
  lit/dark extrusion walls.

## Known limitations

- Bearing rotation is available only via trackpad twist; there is no UI
  button or keyboard binding yet.
- Walls whose corners fall behind the near plane are skipped (rare pops at
  pitch near 60° close to buildings); roofs/roads/areas use proper
  near-plane polygon clipping.
- Label collision is screen-space only; pitched far-ground labels can
  overlap extrusions.
- Estimates are visualization-only and documented as such; they are not
  survey data.
- App Web support remains out of scope; SDK keeps no `dart:io`/channels.

## Not done / deferred

- No disk tile cache (cells are already local; no network source exists).
- No frame-time profiling of pitched repaints (surface cache makes pitch/
  bearing repaints reuse geometry, but no runtime numbers were collected).
