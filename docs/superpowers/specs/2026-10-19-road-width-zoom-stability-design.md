# Road Width Zoom Stability Design

## Goal

Keep polygon road widths stable in screen pixels at every map zoom so zooming
changes geographic coverage, not apparent road thickness.

## Approved behavior

- At every zoom, use each class's existing zoom-16 width as its fixed
  screen-pixel width. Preserve class hierarchy, filters, colors, and clamps.
- Freeze the casing delta to its zoom-16 value at every zoom so the visible
  outer road boundary also remains stable.
- Keep the adaptive `RoadWidths.width` behavior used by the railway renderer;
  constant widths apply only to road polygon surfaces.

## Geometry cache

Road surfaces are stored in geospatial coordinates, so a fixed pixel target
needs a different meter buffer when camera scale changes. Today the cache keeps
one surface per road for an entire 0.25-zoom bucket, even if the requested
meter width changes within that bucket. Store the last requested meter width
with each cached surface and rebuild only that road's contour when the width
changes. Reuse the contour when the exact requested width is unchanged; retain
the existing bucket lifecycle and weak road ownership.

## Out of scope

- No equalization across road classes.
- No camera behavior, railway appearance, polygon geometry algorithm, OSM
  assets/schema, road colors, or layer ordering changes.
- No conversion to centerline strokes.

## Acceptance criteria

- Each road class returns the same polygon screen-width target at overview,
  street, and deep-detail zooms; the target equals its existing z16 width.
- Road visibility thresholds remain unchanged.
- At identical `metersPerPixel`, `halfFillMeters` converts back to the target
  screen width; casing outer width remains stable at every zoom.
- `RoadSurfaceCache` reuses surfaces for unchanged meter widths and rebuilds
  after a width change inside the same zoom bucket.
- Full `flutter analyze`, `flutter test`, and Linux debug build pass; inspect
  representative local and major roads at zoom 12, 14, 16, and 18.

## Explicit tradeoff

Constant pixel widths make roads visibly thicker and the overview denser than
the former zoom-scaled design. This is intentional per user approval: zoom
changes the camera's geographic coverage while road thickness stays fixed.
