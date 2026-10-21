# ADR-0005: 3D vector engine on local OSM cells, Mapbox-night-inspired

- Status: Accepted (user-directed, 2026-10-21)
- Supersedes: ADR-0004 rendering clauses (data pipeline and package boundary remain)

## Context

The user rejected both the Mapbox API dependency and any webview approach for
the Linux desktop app. The interest in Mapbox is the visual result: 3D
rendering of vector tiles in a night preset. F.O.G.O. already owns its offline
regional OSM cell dataset and the `fogo_map_sdk` engine, whose current look
the user rejected as chaotic, and whose "pitch" is a flat cosine squash
without perspective.

## Decision

Evolve `fogo_map_sdk` into a real 3D vector map engine, fully offline:

1. **Perspective camera.** Replace the cosine-squash pitch with a true 3D
   pinhole camera: Web Mercator ground plane plus a height axis, bearing
   rotation (0–360°), continuous pitch (0–60°), zoom overzoom beyond cell
   native zoom (vector geometry scales cleanly). Center stays anchored at
   screen center at every pitch, matching the 2D scale invariant. A ground
   ray-cast inverse keeps right-click/long-press selection and fit/persistence
   working at any pitch and bearing.
2. **3D extrusions.** Buildings render as extruded prisms with two-tone
   directional wall shading and depth ordering (painter's algorithm).
   Display height policy: real numeric OSM `height` when present (7
   buildings); otherwise deterministic, coordinate-seeded display-only
   estimates banded by footprint size. Estimates exist only at render time —
   cell/manifest data stay untouched — and a style flag restricts extrusion
   to real heights. This supersedes ADR-0004's "render only real heights"
   clause for display purposes only.
3. **Smooth curves.** Roads, rails, waterlines and route lines render through
   an endpoint-preserving spline pass (Catmull-Rom resampling) so shared
   junction vertices stay connected while dense OSM polylines read as flowing
   curves, in the spirit of Mapbox's polished vector rendering. Building
   footprints keep crisp corners.
4. **Night theme v2.** Palette retuned toward the Mapbox Standard night
   appearance: near-black blue land, dark navy water, light desaturated road
   ribbons (inverted hierarchy: roads lighter than land, unlike v1's
   dark-on-dark), shaded extrusions, pale labels with dark halos. Always
   night; no time-based switching; no Mapbox-hosted style, tokens or tiles.
5. **No new data sources.** No Mapbox API, no webview, no native channels,
   no network for basemap. Offline regional coverage and the OSRM/Nominatim
   services remain as-is.

## Consequences

- The visual target is "indistinguishable at first glance", not
  pixel-identical: the Standard renderer and its exact style tokens are
  proprietary and are not copied.
- Extrusion estimates are visualization aids and are labeled as such in
  docs and in the layers panel; the toggle falls back to real-heights-only.
- Perspective math, near-plane clipping, depth sorting and spline smoothing
  require new regression tests; camera persistence keeps center/zoom only
  (pitch and bearing stay transient).
