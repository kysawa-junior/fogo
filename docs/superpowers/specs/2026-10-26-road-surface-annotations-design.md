# Road Surface Names and Direction Arrows — TASK-0009

- **Status:** design approved by user; awaiting spec review
- **Date:** 2026-10-26

## Goal

Render named streets and traffic-direction arrows as world-space annotations
on the 3D OSM road surface. Keep cartographic UI labels in 2D only and fix
their road anchor so labels remain attached to the mapped way.

## Current state

- `Road.name` resolves OSM `name`, then `ref`.
- `RoadProperties.oneway` is boolean. `OsmFeatureMapper` recognizes `yes` and
  `junction=roundabout`, but loses `oneway=-1` direction.
- `extractLabelCandidates` places road labels at the arithmetic mean of OSM
  vertices, which can drift on unevenly sampled ways.
- `LabelOverlay` is mounted in both `Map2DView` and `FogoSceneView`; it is a
  screen-space widget using `PerspectiveCamera.worldToScreen`, so it floats
  over the 3D scene rather than lying on the road.
- `FogoEngine` builds road meshes and a separate `Map2DScene`. `MeshData`
  supports UV coordinates, but `FlutterSceneAdapter` currently does not pass
  them into `MeshGeometry.fromArrays`.
- The bundled regional OSM extract contains 5,338 highway ways, 2,699 with a
  `name` or `ref`; annotation batching and LOD are required to limit overhead.

## Approved design

### Road names and 2D labels

1. Keep `LabelOverlay` only in `Map2DView`; remove it from `FogoSceneView`.
   Road, area, and POI UI labels remain available in 2D and never float over
   the 3D scene.
2. Place 2D road-label candidates at the route-length midpoint rather than
   averaging OSM vertices. Existing label collision and priority policy stays.
3. In 3D, represent each named road with a transparent, world-space decal
   plane. Rasterize text once with Flutter text painting, pack labels into
   per-tile texture atlases, and batch decal quads by tile. Use `name` then
   `ref`, `FogoPalette.crossing` text with a dark outline, UVs, and an unlit
   alpha-blended material. Align each plane to the local road tangent on the
   longest sufficiently straight portion. Fit text to the available segment;
   omit it if it cannot fit legibly.
4. Raise decals approximately 0.04 m above the road surface. Show them only
   at close 3D LOD (maximum camera distance 1,200 m). They are visual-only,
   not selectable; raycasts must continue to reach the road below.
5. Atlas generation happens during scene upload, not per frame. If a text
   atlas cannot be generated, skip those decals without blocking the rest of
   the scene; 2D labels remain unaffected.

### Direction arrows

1. Model traffic direction as `both`, `forward`, or `reverse`, while
   preserving the existing `oneway` boolean behavior for callers.
2. OSM interpretation:
   - `oneway=yes`: forward along ordered way points.
   - `oneway=-1`: reverse the ordered way direction.
   - `oneway=no`: both directions.
   - Missing `oneway` on a roundabout: forward; explicit `no` overrides this.
   - Other/absent values: both directions.
3. Generate simple filled arrow meshes along cumulative road distance, every
   approximately 45 m. Put at least one arrow per allowed direction on a
   shorter way. Bidirectional arrows point opposite ways, offset by one
   quarter of road width to sit in separate lanes; one-way arrows follow the
   directed way. Orient each arrow to the local tangent, including curved
   ways. Use the existing crossing/marking palette; do not add a color token.
4. Raise arrows approximately 0.04 m above the rendered road surface. Batch
   arrow geometry by tile and use the same close 3D LOD as road-name decals.
   The independent `Map2DScene` receives no arrows.

### Architecture and selection

- Keep OSM parsing and road geometry in the engine; keep text rasterization,
  atlas textures, and Flutter Scene materials in the render adapter.
- Carry engine-independent road-label placement data through `MapScene`;
  assign annotation batches to existing spatial tiles.
- Pass UVs through `FlutterSceneAdapter`; use unlit `AlphaMode.blend` texture
  materials for decals. Batch arrows and decals by tile instead of creating
  a node per arrow or label. No new package dependency.
- Annotation meshes do not claim a road `entityId` or intercept picking;
  create their geometry without retained CPU data so raycasts pass through;
  the base road remains the selectable entity.
- No change to area/POI label policy in 2D or to the separate 2D road painter.

## Acceptance criteria

1. Road names appear on the asphalt in close 3D, follow local road direction,
   move with perspective, and are not screen-space overlays.
2. UI labels appear only in 2D and road labels stay anchored at the
   length-based midpoint while panning/zooming.
3. Bidirectional roads show opposing arrows; `yes`, `-1`, roundabouts, and
   explicit `no` follow the OSM direction rules above.
4. Arrows repeat at the specified spacing (or at least once on short ways),
   follow curves, and sit above the correct road elevation.
5. Annotation batches obey the 1,200 m 3D LOD, do not appear in the 2D scene,
   and do not block road selection.
6. Tests cover OSM parsing, label anchors, arrow direction/spacing/height,
   texture UV upload, 2D/3D label separation, and scene selection.
7. `dart format`, `flutter analyze`, `flutter test`, and the available Linux
   debug build pass.

## Risks and limits

- Text is rasterized onto a real 3D mesh plane, not extruded letter geometry;
  this is intentional for legibility and memory/performance.
- Text on a ground plane naturally foreshortens at low camera elevation.
- Roads without enough straight length for their name may have no 3D label.
- `oneway=reversible` and other uncommon values are treated as bidirectional
  in this first version.
