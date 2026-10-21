# Road Surface Continuity Design

## Goal

Remove geometric gaps and floating artifacts at road bends, shared nodes, and
closed roundabouts while preserving the existing polygon-based OSM renderer.

## Current causes

- `RoadSurfaceBuilder.build` removes a duplicated closing coordinate, then
  creates directions only between consecutive remaining points. The closing
  segment from the final point to the first is omitted.
- `_join` adds an arc to the outer offset chain only. The inner chain connects
  offset points with a chord rather than the intersection of its offset lines.
- Open-road cap traversal and degenerate consecutive points need explicit
  geometric invariants and regression coverage.
- `MapRoad` stores coordinates but not OSM node IDs. The source pipeline rounds
  coordinates to five decimal places, so equal shared-node coordinates can be
  used as the per-frame cache key without changing assets.
- The Garça roundabout is represented by multiple open ways with the same
  name/class; its arcs meet at access nodes. Fixing cyclic buffers alone cannot
  close this ring unless compatible render-only ways are first dissolved.

## Design

Keep `RoadSurfaceBuilder`, polygon fills, class batching, and the existing
casing-then-fill painter order. Rework the builder to:

1. In the derived render geometry, deduplicate cell copies and merge uniquely
   connected ways with equal style/name and shared normalized endpoints. Keep
   one-way direction; do not merge through ambiguous same-style branches. This
   may turn segmented roundabout arcs into a closed line without changing the
   source cell records.
2. Remove consecutive degenerate points before calculating directions.
3. Construct both offset chains at each vertex: round arc on the outer side;
   offset-line intersection on the inner side, capped at miter ratio 2 with a
   non-spiking fallback for sharp turns.
4. Keep open ways as one polygon with correctly ordered round caps.
5. Treat closed ways cyclically, including final-to-first segment and joins.
   Emit outer and inner contours with opposite winding so nonzero fill renders
   a continuous road annulus without filling its center.
6. Cache projected coordinates per paint frame by normalized latitude /
   longitude and snap each projected point to a half-pixel.
7. Keep labels above road fills and strengthen the dark 3px halo using
   directional paragraph shadows; Flutter `Paragraph` does not expose
   `strokeText`.

No OSM asset schema, road-width rules, map data, navigation, or layer ordering
changes are in scope.

## Validation

- Unit tests cover inner-corner coverage on an L bend, complete cyclic coverage
  and an unfilled center for a closed loop, duplicate/degenerate vertices,
  open versus closed caps, and coordinate-cache snapping/reuse.
- Run `dart format`, `flutter analyze`, the complete `flutter test` suite, and
  `flutter build linux --debug` when available.
- Inspect the painter to confirm per-class polygon batching remains one draw
  call per casing/fill pass and labels remain after roads.

## Acceptance criteria

- No missing closing edge on roundabouts; road band remains continuous around
  the full loop, including rings represented by multiple OSM ways, and its
  center stays unfilled.
- Curved surfaces have no inner-corner chord gaps or acute miter spikes.
- Shared equal coordinates project identically within a frame at half-pixel
  precision.
- Existing OSM data, width hierarchy, class colors, bridge/tunnel treatment,
  layer order, and navigation remain unchanged.
- Tests, analysis, and build pass, or any environment limitation is reported.

## Constraints and risks

- Geometric snapping uses normalized coordinates, not OSM IDs, because IDs are
  absent from the current asset model. If future input stops preserving shared
  coordinates, the data schema must carry node IDs.
- Closed surfaces require correctly oriented inner/outer contours; tests must
  verify nonzero-fill behavior as well as coordinate bounds.
- This workspace has no Git metadata, so the design document cannot be
  committed here.
