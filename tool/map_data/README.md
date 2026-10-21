# Local OSM cell data

`assets/map` contains regional vector cells (`cells/l0_*.json.gz` and
`cells/l1_*.json.gz`) plus `manifest.json`; coverage is Marília-SP, Vera Cruz-SP,
Garça-SP, and their corridor. The app reads these local assets and makes no
runtime map-network requests. The raster renderer and Pillow flow have been
removed. The generator dependency is `osmium==4.3.1` (`requirements.txt`).

## Regenerate from the existing local PBF

`build_map_data.py` reads an existing PBF only; it has no download path. Install
the generator dependency, then stage outside `assets/map` (stage must be new or
empty):

```sh
python3 -m venv .venv-map
. .venv-map/bin/activate
python -m pip install -r tool/map_data/requirements.txt
python tool/map_data/build_map_data.py \
  --pbf tool/map_data/raw/sudeste-latest.osm.pbf \
  --stage /tmp/fogo-map-stage \
  --promote-to assets/map
```

The generator hashes the PBF immediately before and after processing/output;
the hashes must match, and staged `manifest.json` `sourceSha256` must equal that
digest. Promotion runs only after deep semantic comparison passes: cell paths,
membership, geometry, and non-height cell data must match. Only approved
positive building `height` additions and height-related manifest counters, plus
`generatedAt` and `l1Bytes`, may change. All remaining manifest fields/counts,
including non-height counts, are preserved; `l0Bytes` must remain unchanged and
match staged L0 files. Hash, source-SHA, or semantic mismatch fails closed
without promotion.

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
