# Overture Buildings Merge — TASK-0010

- **Status:** design approved by user; direct execution
- **Date:** 2026-10-27

## Goal

Bring Overture Maps building footprints (Marília-SP, Vera Cruz-SP, Garça-SP)
into the 3D scene through the existing OSM pipeline: extruded walls + roof,
isolate load, 2D footprints, LOD, and selection, with no engine Dart changes.

## Data reality (measured 2026-10-27)

- Source: `~/dados-overture/edificios/*.parquet` (Apache Parquet, WKB
  geometry, Overture buildings theme). Three files: Marília 138,767 rows,
  Vera Cruz 6,397, Garça 24,729 (whole municipalities).
- Fully inside the regional strip bbox `(-49.975, -22.245, -49.634, -22.200)`:
  **75,203** ground-level buildings; 51,376 of those inside the three urban
  boxes.
- Height coverage is nearly empty: 2 rows with `height`, 14 with
  `num_floors`. Everything else falls back to the engine's category default
  heights (`BuildingHeightEstimator`).
- 6 buildings have courtyards (inner rings); subtype is null for ~99.5%
  (the rest map directly to OSM `building=*` values).
- Current OSM extract has only **1,518 buildings** (2 with `height`) —
  Overture is the real building source for the region.

## Approved design

1. **Offline conversion, zero engine changes.** A Python tool
   (`tool/map_data/overture_to_osm.py`, run via `uv --with pyarrow --with
   shapely`) converts the Parquet footprints to OSM XML and rewrites
   `assets/map/osm/regiao.osm.gz`. No new Flutter/Dart dependency.
2. **Scope: full regional strip** (75,203 buildings), matching the extract
   bbox used by `extract_osm_xml.py`. Only fully-inside footprints are
   included; underground and non-ground levels are filtered out.
3. **Emission:** simple footprints become closed ways; footprints with
   courtyards (and multipolygons) become `type=multipolygon` relations —
   the mapper already supports multi-outer/inner buildings.
4. **Tags:** `building=<subtype|yes>`, `height` (when present, plain
   decimal), `building:levels` (from `num_floors`), `min_height` (when
   present), `name` (Overture primary name), `source=overture-maps`.
   Heights follow the existing estimator: `height` > levels × 3.2 m >
   category default.
5. **Dedup: Overture wins.** Existing OSM building ways/multipolygon
   relations whose footprint intersects any Overture footprint are dropped
   (shapely STRtree, offline). With OSM at 1,518 buildings this affects a
   small, well-defined set.
6. **IDs:** the engine's XML reader rejects negative ids, so new nodes,
   ways and relations get sequential positive ids above the maximum id
   present in the file.

## Validation

- Python test for the converter (synthetic parquet + tiny extract):
  filtering, tag emission, courtyard relation, dedup, id allocation.
- Dart asset regression suite keeps passing against the merged extract;
  building counts grow accordingly; every building still has a roof.
- `flutter analyze`, `flutter test`, `flutter build linux --debug`.
- Manual: navigate Marília, Vera Cruz and Garça in 3D.

## Risks and limits

- Scene grows from ~17k to ~90k objects: one-time isolate load and scene
  upload get proportionally slower; UI stays responsive via existing
  batching.
- Nearly all Overture buildings render at category-default heights (9 m
  for `yes`) — the source simply has no heights in this region.
- 2D mode gains ~75k building footprints (paths built once in the load
  isolate, culled by bbox per frame).
- `regiao.osm.gz` is regenerated: rerunning `extract_osm_xml.py` alone
  drops the Overture layer; the merge step must be rerun (documented in
  `tool/map_data/README.md`).
