# Local OSM data

`assets/map/osm/regiao.osm.gz` is the single packed OSM XML extract of the
F.O.G.O. region: Marília-SP, Vera Cruz-SP, Garça-SP, and their corridor in one
file (3D camera anchors per city live in `lib/engine/region/region_catalog.dart`).
The legacy vector cells (`cells/`, `manifest.json`) and the Mapbox raster/`MVT`
sources were removed; the 3D engine consumes only the OSM extract, and the user
can import any `.osm` via the file selector. `build_map_data.py` and its cell
pipeline are retained as project history only — do not run them against
`assets/map`.

## Regenerate the regional extract from the existing local PBF

`extract_osm_xml.py` reads the existing PBF only; it has no download path. The
generator dependency is `osmium==4.3.1` (`requirements.txt`):

```sh
python3 -m venv .venv-map
. . .venv-map/bin/activate
python -m pip install -r tool/map_data/requirements.txt
python tool/map_data/extract_osm_xml.py
```

The region bbox (union of the three urban boxes + corridor) is defined at the
top of the script; edit it there and rerun to re-cover a different area.

## Merge Overture Maps buildings into the extract

`overture_to_osm.py` converts the Overture buildings Parquet files (default
`~/dados-overture/edificios`) into OSM XML and rewrites
`assets/map/osm/regiao.osm.gz`. The 3D engine reads buildings through the
normal OSM path — no engine changes are involved.

```sh
uv run --with pyarrow --with shapely \
    python tool/map_data/overture_to_osm.py [--parquet-dir DIR] [--dry-run]
```

Behavior (spec: `docs/superpowers/specs/2026-10-27-overture-buildings-merge.md`):

- Only ground-level footprints fully inside the region bbox are merged.
- An OSM building (way or multipolygon) whose footprint intersects an Overture
  footprint is dropped — Overture wins the dedup.
- Buildings with courtyards or multiple parts become `type=multipolygon`
  relations; the rest are closed ways.
- Tags: `building=<subtype|yes>`, `height`, `building:levels` (from
  `num_floors`), `min_height`, `name`, `source=overture-maps`. The Overture
  dataset for this region has heights on only ~16 of 75k buildings; the rest
  fall back to the engine's per-category default heights.
- New elements use positive ids above the maximum id in the file (the engine
  rejects negative ids).
- **Always rerun this after `extract_osm_xml.py`** — regenerating the extract
  alone discards the Overture layer.

Current merge (2026-10-27): 75,203 Overture buildings in, 1,513 of the 1,518
OSM buildings dropped as covered, 6 multipolygons, ~344k nodes. Engine load of
the merged extract takes ~18 s in the map-load isolate.

## Height parsing and counters

`height` accepts only finite positive ASCII decimal metres matching
`^[0-9]+(?:\.[0-9]+)?$`; no unit conversion is performed. Zero, negative,
overflow/nonfinite, and positive values that underflow are rejected as numeric.
Units (for example `3 m`), leading `+`, whitespace, commas, exponent notation,
`.5`, `5.`, and non-ASCII digits are unsupported. Unsupported values are
reported, not guessed; `building:levels` never supplies a height.

Height counters count eligible source ways, not cell copies:

- `buildingsWithPositiveNumericHeight`: accepted numeric heights.
- `buildingsWithLevelsOnly`: nonempty `building:levels` without nonempty
  `height`.
- `buildingsWithRejectedHeight`: numeric zero/negative/nonfinite/underflow.
- `buildingsWithUnsupportedHeight`: nonempty `height` outside the grammar.
- Legacy `buildingsWithHeightTag`: once per way with either nonempty `height`
  or `building:levels`, including mixed tags. `buildings` counts per-cell
  records, so one way copied into multiple cells contributes multiple records.

## Status

The source spec is **reviewed and approved by the user on 2026-10-19**. Regional
parity evidence and the engineering cleanup-gate pass are recorded in
`docs/agent-work/handoffs/TASK-0004-validation-evidence.md`; no Delivery Auditor
approval is claimed.
