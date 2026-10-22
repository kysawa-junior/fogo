# ADR-0006: Cartographic refinement of the 3D engine

- Status: Accepted (user-directed TASK-0006, 2026-10-22)
- Extends: ADR-0005

## Context

TASK-0005 delivered the 3D engine. The user audit confirmed by code
inspection:

1. Street widths were fixed screen-pixel values per class at every zoom,
   producing thick bands at mid zoom; casing halo was a fixed +1.2/+1.6 px.
2. One-way arrows were drawn every 100 px on every one-way street (cap 500)
   with no screen test, no junction exclusion, and a spacing-continuity bug
   across clipped runs — the "repeated light triangles" in dense grids.
3. Buildings were painted before roads, so at pitch road fills sliced
   through the near-side extrusion walls (wrong occlusion).
4. The road-surface cache was keyed by camera center, so every pan rebuilt
   every road surface.
5. Village/suburb labels had no upper zoom bound and there was no per-kind
   budget, saturating regional views; adjacent area polygons showed
   antialiasing seams.

## Decision

1. **Width model**: per-class zoom ramps in screen pixels (presentation
   width), evaluated on a quantized zoom bucket (1/4 zoom) so the hierarchy
   is stable on screen while geometry rebuilds only at bucket boundaries.
   Casing pad scales with width (`0.6 + 0.18·w`, clamped) instead of a
   constant.
2. **Pan-stable geometry**: road surfaces are buffered in absolute Web
   Mercator metres (half-width = ramp width / bucket scale), cached by
   (zoom bucket, metre half-width). Pan, rotation and pitch reuse buffers;
   only zoom-bucket crossings rebuild. The projection cache stores
   absolute metres too. Presentation widths stay screen pixels; the
   geometric metre width is derived per bucket.
3. **Depth order**: flat views keep roofs under streets (areas → buildings
   → roads); pitched views draw ground roads first, then depth-sorted
   extrusions, so near walls correctly cover streets behind them.
4. **One-way arrows**: spacing scales with street width, per-frame cap 250,
   junction-edge exclusion, per-run spacing reset, and screen-bounds test.
5. **Labels**: per-kind zoom ranges with upper bounds (city ≤14, town 10–15,
   village 12–15, suburb 13–16.5) and a priority budget per frame
   (city > town > village > suburb), implemented as a pure testable
   selector.
6. **Area seams**: water/green/farmland fills get a same-colour hairline
   stroke to close antialiasing seams between adjacent parcels.
7. Smoothing keeps its screen-constant resample step (8 px), now expressed
   in metres per bucket; endpoints and sharp corners stay exact.

## Consequences

- Zoom animation rebuilds surfaces only at bucket crossings (4 per integer
  zoom); pans and rotations reuse geometry.
- Tests read widths from the exposed ramp helper instead of magic
  constants, so probe positions track the model.
- All changes are geometric/compositional; the F.O.G.O. palette and UI are
  untouched. No data is invented; smoothing still cannot move junction
  nodes.
