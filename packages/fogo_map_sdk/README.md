# `fogo_map_sdk`

App-independent Flutter renderer for F.O.G.O.'s bundled regional OSM cells.
Package owns map projection, camera gestures, local feature loading, drawing,
and geographic selection. Host app keeps persistence, routing/search, region
controls, and operational state.

This is a regional OSM renderer, not a general MVT engine or Mapbox SDK. Its
night palette is F.O.G.O.-owned and visually inspired by a restrained night
map hierarchy; exact Mapbox Standard equivalence is not claimed.

The current F.O.G.O. dataset covers Marília-SP, Vera Cruz-SP, Garça-SP, and
their corridor. Package portability does not imply general-purpose geography or
full F.O.G.O. application Web support.

## Host setup

Add this package as a path dependency and include the local map assets in the
host application's Flutter asset bundle:

```yaml
dependencies:
  fogo_map_sdk:
    path: packages/fogo_map_sdk

flutter:
  assets:
    - assets/map/manifest.json
    - assets/map/cells/
```

The package does not bundle the F.O.G.O. data. It reads `manifest.json` and
`cells/l0_*.json.gz` / `cells/l1_*.json.gz` through Flutter's `AssetBundle` API.
There is no runtime network fallback.

## Minimal use

```dart
import 'package:fogo_map_sdk/fogo_map_sdk.dart';

final FogoMapController mapController = FogoMapController();
final FogoMapDataSource mapData = FogoMapDataSource();

FogoMapView(
  controller: mapController,
  dataSource: mapData,
  onCameraChanged: (camera) {
    // Persist center and zoom in the host app; pitch stays transient.
  },
  onSelection: (selection) {
    // Route the WGS84 selection to host-owned routing/selection state.
  },
)
```

Dispose the controller when its owning screen/controller is disposed. Optional
`AssetBundle`, manifest path, and cell directory can be passed to
`FogoMapDataSource` for tests or alternate host asset layouts.

## Public API

- `FogoMapView` draws the local map, caller polylines/markers, and OSM
  attribution. Optional callbacks expose camera, selection, and typed data
  status. A `statusBuilder` can render a host-specific loading/error indicator;
  the map remains dark and interactive when data is absent or corrupt.
- `FogoMapController.camera` is an immutable `FogoCameraState`. Commands include
  `moveTo`, `setCamera`, `fitBounds`, `zoomBy`, and `setPitch`; `cameraEvents`
  and `selectionEvents` are broadcast streams. Coordinate/screen conversion
  uses the current laid-out view size.
- `FogoCoordinate` is WGS84 latitude/longitude. `FogoGeoBounds` uses named west,
  south, east, north fields. `FogoProjection` owns EPSG:3857 forward/inverse
  transforms.
- `FogoMapStyle.fogoNight` supplies the F.O.G.O. palette and existing visibility
  controls. `showBuildings` and `showLabels` can be toggled independently; the
  latter also governs POIs, matching the existing renderer behavior.
- `FogoMapPolyline` and `FogoMapMarker` accept geographic coordinates and use
  the same camera transform as the map. Polyline widths, border widths, and dash
  lengths are screen pixels. Marker IDs must be unique within the view.
- `FogoMapSelection` reports coordinate, local screen position, and whether it
  came from secondary click, long press, or a programmatic controller call.
- `FogoMapDataStatus` distinguishes loading, ready, empty, outside-coverage, and
  manifest-error states. Cell corruption is reported in its typed `errors`
  list while other valid cells continue rendering. Missing cells are normal.

Camera starts top-down (0°), with a regional default center and zoom 11. The
camera is a true perspective pinhole over the ground plane: continuous pitch
0°–60°, bearing rotation 0°–360° (trackpad twist), and near-plane clipping for
geometry crossing the horizon. Center/zoom stay persisted by the host; pitch
and bearing are transient. Supported interactions include drag, pinch/trackpad
pan-zoom, double-tap, wheel zoom, fling, secondary click selection, long-press
selection, arrow-key pan, and +/- zoom. Accessibility semantics expose the map
and zoom increase/decrease actions.

## Data and rendering behavior

The default source paths match the current host assets. The loader requests
visible L0 cells, and L1 building cells at zoom 15.5 and above. It keeps the
existing 40% viewport prefetch margin, prunes view state outside that window,
and uses LRU limits of 64 L0 / 24 L1 cells. Gzip output is capped at 8 MiB per
cell. Corrupt/truncated gzip, invalid JSON, or invalid feature records become
typed errors and are not cached; missing assets are cached as empty results.

`compute` moves gzip/JSON decoding off the frame path on platforms where it
uses an isolate. Flutter Web's `compute` executes on the same event loop; this
package does not claim Web background-isolate decoding. No `dart:io`, native
plugin/channel, `flutter_map`, app state-management, routing/search dependency,
or network basemap is used by this package.

All local OSM geometry, labels, and local symbols are clipped to the exact
manifest bounds. Outside coverage and empty cells show the dark background.
Renderer preserves area/water/boundary, waterline, rail, road, building,
POI/label layer semantics; road class filters/order, casing/fill, bridges,
tunnels, one-way markings, label collision, and screen-pixel road widths.
Roads, rails, waterlines and route lines are drawn through an
endpoint-preserving Catmull-Rom spline, so dense OSM polylines read as
flowing curves while shared junction nodes stay exactly connected and sharp
corners stay crisp. Building footprints keep their original corners.

When pitched, buildings extrude: a real positive numeric OSM `height` wins;
otherwise the engine applies deterministic display-only estimates banded by
footprint area (`FogoMapStyle.estimateBuildingHeights`, default true). Walls
are shaded by a fixed light direction; estimates never modify cell data, and
setting the flag to false restricts extrusion to real heights only.
`building:levels` is never used as a height.
