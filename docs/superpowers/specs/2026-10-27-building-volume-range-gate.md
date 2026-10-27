# Building Volume Range Gate — TASK-0011

- **Status:** design approved by user; direct execution
- **Date:** 2026-10-27

## Goal

In 3D mode, render full building volumes (walls + roof) only within a small
radius around the camera. Outside that radius, buildings appear as flat
footprint pads (the light 2D-style representation). 2D mode stays unchanged.

## Current state

- All ~75k Overture + OSM building volumes are individual scene nodes, always
  resident on GPU; `LodPolicy` level 1 hides them only beyond 3,500 m from the
  camera target. At city overview the whole urban core draws as volumes.
- `BuildingMeshBuilder.build` returns the extruded volume (walls + roof +
  floor); the floor triangulation is computed and discarded into the merged
  volume mesh.
- `Map2DScene` already carries flat footprints for 2D mode (separate scene).

## Approved design

1. **Flat pads reuse the floor triangulation.** `BuildingMeshBuilder.build`
   returns both meshes: the volume and a flat pad (floor triangulation, +Y
   normals, reversed winding, lifted 0.06 m above ground). No extra
   triangulation; load time is preserved.
2. **Pads are merged per tile** into single meshes (~300 batches, not 75k
   nodes) and travel through `MapScene.buildingFootprints`
   (`BuildingFootprintBatch {tileId, mesh}`). Pads are visual-only: no
   entity id, `retainCpuData: false`, `raycastable = false`.
3. **Volume objects are range-gated.** `MapSceneObject.rangeGated` is true
   only for regular building volumes. Landmark volumes (stadium, hospital,
   temple, police — ~42 objects) are not gated and keep today's LOD behavior.
4. **Gate lives in the adapter.** `updateLOD` receives the camera position and
   evaluates per tile: horizontal distance from the camera to the tile AABB.
   Inside radius → volumes visible, pad hidden. Outside → pad visible,
   volumes hidden. `LodPolicy` owns the constants:
   `buildingVolumeRadiusMeters = 600` (enter) and
   `buildingVolumeHysteresisMeters = 100` (leave at 700 m). Re-evaluation on
   camera moves ≥ ~15 m or LOD distance steps; states are sticky inside the
   hysteresis band.
5. **LOD and mode interplay unchanged.** Beyond 3,500 m target distance both
   representations hide (existing level 1). Tile culling still hides whole
   tiles far away. 2D mode renders `Map2DScene` as today.

## Accepted tradeoffs

- Buildings outside the radius lose individual selection (merged pads are not
  pickable; clicks pass through). Near buildings remain selectable.
- Volume↔pad swap is a per-tile pop at the range edge, softened by hysteresis;
  at 600 m+ the two representations read similarly from typical angles.
- Amenity landmarks stay as always-on volumes by design.

## Validation

- Engine tests: flat pad geometry (+Y normals, lift, holes cut), per-tile
  batches cover every building's tile, volumes flagged `rangeGated`,
  landmarks not gated, `Map2DScene` untouched.
- Adapter tests: pure gate function (enter/leave/sticky) without GPU;
  GPU-gated integration for visibility flips at the radius, hysteresis
  stickiness, and 3,500 m LOD hiding both.
- Existing suites, `flutter analyze`, Linux debug build; engine load probe
  re-timed with the merged asset.

## Risks and limits

- Upload and GPU memory gain ~300 pad nodes (small); volumes remain resident
  while hidden — full streaming (upload/unload on demand) is out of scope.
- Far city reads as flat blocks; 9 m default-height boxes remain only within
  the radius.
