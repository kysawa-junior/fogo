# TASK-0004 / ENG-0004 v2 — Phase 0 discovery and safety baseline

**Status:** Phase 0 complete; discovery only. No generator, cell, manifest, PBF, raster, SDK, or app implementation was run or changed.

## Authority and scope

- Canonical work package: `docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md`, ENG-0004 v2.
- Approved source spec: `docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md`, status exactly **“Reviewed and approved by the user on 2026-10-19.”** This is not a Delivery Auditor verdict; no auditor verdict is claimed.
- The superseded duplicate `ENG-0004-owned-offline-map-sdk.md` was not used as authority.
- Discovery followed current generator semantics and only counted generator-eligible, closed building/building:part ways with at least four clipped points inside the generator’s existing expanded bbox. It does not claim a census of unrelated objects elsewhere in the 862 MB southeastern PBF or building relations (which the current generator does not process).

## Findings

### Local PBF and actual height tags

Source: `tool/map_data/raw/sudeste-latest.osm.pbf`, 861,713,601 bytes.

| Check | SHA-256 |
|---|---|
| Before first read-only height scan | `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` |
| After each read-only height scan (including final corrected census) | `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` |
| Existing `assets/map/manifest.json` `sourceSha256` | `cdf25842bdea84298f30b4080670cb75bf493dfbafdeeb33fe8b271eb1be7e59` |

Hashes are equal. These are baseline inspection hashes, **not** future generation evidence. Re-hash immediately before and after any later generation.

Read-only scan results:

- 9,013 eligible closed building/building:part ways in the current generator’s region/filter.
- 30 ways satisfy the current mixed `height OR building:levels` predicate.
- 7 have non-empty explicit `height` values; 6 distinct strings: `"3"` (2 ways), `"4"`, `"5"`, `"8"`, `"15"`, `"63"` (1 each).
- All 7 are bare positive integer values. No decimals, units, commas, signs, ranges, lists, or unsupported formats were observed among eligible ways.
- 23 ways are levels-only. Of the 7 explicit heights, 3 also have `building:levels`; 4 do not.
- Numeric non-positive values: 0. Unsupported explicit `height` strings: 0. Empty explicit height values: 0.

### Recommended narrow height contract

Use a strict ASCII base-10 decimal token with a decimal point only; interpret an unqualified numeric value as metres under OSM `height` convention. Persist accepted value as a JSON number in metres. Do not convert or guess units.

- Numeric-token recognition for reporting: `^-?[0-9]+(?:\.[0-9]+)?$`.
- Accept for extrusion only when parsing yields a finite value `> 0`. Positive accepted form is digits with optional `.` plus one or more fractional digits; leading zeros are allowed. The optional minus is solely to classify numeric non-positive values as rejected, never to accept them.
- `0`, `-0`, and negative numeric values: **rejected**, flat.
- Missing/empty `height`: no height. `building:levels` alone: flat; never infer a height.
- Unsupported and reported, without conversion: explicit unit suffixes (`m`, `cm`, `ft`), feet/inches notation, leading `+`, whitespace, comma decimals, exponent notation, fractions, semicolon lists, ranges, and other non-matching strings. Examples: `"10 m"`, `"3,5"`, `"4'6\""`, `"3;4"`, `"3-5"`, `"1e2"`, `".5"`, `"5."`.
- No arbitrary maximum height was selected: only finite, strictly-positive values pass the numeric rule. Extremely large but finite numeric values were not present in this regional scan; decide whether to add an explicit physical upper bound before implementation rather than silently clamping or inventing one.

### Counter semantics — preserve existing values

Do not rename, reinterpret, or recompute legacy `counts.buildingsWithHeightTag`. In `build_map_data.py`, `heights_tagged` increments **once per eligible OSM way**, before cell replication, when either `tags.get("height")` or `tags.get("building:levels")` is truthy. Current manifest value `30` is therefore intentionally mixed (7 explicit heights + 23 levels-only).

`counts.buildings` has different semantics: it sums building records across L1 cells, so one OSM way may be counted in multiple cells. Current value is 9,064, versus 9,013 eligible source ways. Do not use this per-cell count for the height counters.

Recommended additive height-only counts, each counted once per eligible OSM way before cell replication:

- `buildingsWithPositiveNumericHeight`: accepted positive numeric `height` (current baseline 7; includes features that also have levels).
- `buildingsWithLevelsOnly`: non-empty `building:levels` with absent/empty `height` (current baseline 23; excludes records with an explicit rejected/unsupported height).
- `buildingsWithRejectedHeight`: numeric-token value that is zero or negative (current baseline 0).
- `buildingsWithUnsupportedHeight`: non-empty explicit `height` outside numeric grammar (current baseline 0).

These definitions keep the legacy mixed value at 30 and leave all non-height counts unchanged. A future height plus levels contributes to the explicit-height and legacy mixed counts, not the levels-only count.

### Cell, manifest, and generator baseline

- Source manifest: `assets/map/manifest.json`, version 2; bbox `[-50.04,-22.31,-49.59,-22.13]`, cell size `0.05`, 9 columns × 4 rows; `counts.buildings=9064`, `counts.buildingsWithHeightTag=30`, `l0Bytes=1,302,396`, `l1Bytes=220,133`.
- There are 58 compressed source cells: 36 `l0_*.json.gz` and 22 `l1_*.json.gz`.
- L0 JSON contains variable layer arrays (`roads`, `areas`, `rail`, `wl`, `pois`, `labels`). Existing record fields include road `{c,n,r,o,br,tn,p,b}`, area `{k,p,b}`, rail `{k,p,b}`, waterline `{k,n,p,b}`, and POI/label `{k,x,y,n}`. L1 is `{"bld":[...]}`; current building records contain only `p` (flat lat/lon coordinates) and `b` (bbox). No cell currently persists `height`.
- `tool/map_data/build_map_data.py` imports stdlib modules plus `osmium`; `process()` uses `osmium.FileProcessor(...).with_locations().with_areas()`. It filters building ways, increments the mixed counter once per qualifying way, then appends building records to every intersected L1 cell. `write_outputs()` gzip-compresses JSON and writes cells and manifest directly to `--out`; it has no staging/semantic-diff/promotion gate and does not itself protect prior outputs. It can overwrite existing cells/manifest. Do not invoke it against `assets/map` until later work adds the required staged semantic gate.
- `tool/map_data/fetch_data.sh` downloads the PBF when absent and then invokes the generator. Do not use it for this task or later local-only generation; invoke the builder directly with the existing explicit PBF path.
- Current raster generator `tool/map_data/render_tiles.py` consumes source cells/manifest and writes tiles/metadata; it does not access the PBF. No raster generator was run.
- Generated `generatedAt`, `l0Bytes`, and `l1Bytes` are fields to classify carefully in a later allowlisted semantic comparison. Gzip byte equality is not a substitute for decompressed JSON semantic comparison.

### Dependencies and decoder/cache/corrupt-data recommendation

- Environment: Python 3.13.5 (`/usr/bin/python3`); `osmium` importable, distribution version 4.3.1; Pillow importable, version 12.3.0. `tool/map_data/requirements.txt` declares only `Pillow==12.3.0`; it omits the generator’s required `osmium`/pyosmium dependency. The tool README describes a `.venv-map`, but no candidate local venv was found in the inspected workspace.
- Generator dependencies: Python stdlib plus pyosmium/osmium 4.3.1. Raster renderer/tests: Python stdlib plus Pillow 12.3.0. No Python package was installed or changed.
- Flutter 3.47.1 / Dart 3.13.1. `pubspec.lock` contains `archive` 4.5.2 as **transitive**, not direct in root `pubspec.yaml`; the package is present in the local pub cache. For the new SDK, declare the chosen decoder directly in the SDK package rather than relying on this transitive root lock entry.
- Recommended portable gzip decoder: `archive` `GZipDecoder` (observed package version 4.5.2). Its source selects native gzip on IO targets and a Dart inflater on Web. Prefer strict `decodeStream` with an explicit output cap and a checked success result; package docs warn `decodeBytes` alone can return partial output for truncation. Suggested initial decompressed-cell limit: **8 MiB per cell**; largest current L0 expansion is 752,346 bytes and largest L1 expansion is 731,610 bytes. Verify checksum where supported. Do not add direct SDK `dart:io` imports.
- Current `MapDataStore` already uses LRU caps 64 L0 / 24 L1; current dataset has only 36 / 22 cells, respectively. Reuse these exact caps as the initial SDK bound. `MapDataNotifier` prunes its loaded map to the viewport plus existing 40% horizontal padding and loads L1 only at zoom >=15.5; preserve or explicitly revalidate this behavior.
- Current store decodes through Flutter `compute`; on native it uses an isolate, but Flutter Web implementation awaits one turn and invokes callback on the same event loop. Do not claim Web background-isolate decoding.
- Missing cell assets are normal and return null. Corrupt gzip/JSON currently throws from `MapDataStore`; its caller catches and debug-logs the exception, silently omitting the cell. Manifest parse failures can also escape store loading. Recommend a typed controlled data-error status identifying tier/cell (or manifest), keep the map interactive/other cells renderable, distinguish corruption from normal missing cells, and do not cache failed/partial decode.

## Raster inventory and safety proof

Created `docs/agent-work/handoffs/ENG-0004-raster-inventory.sha256` as sorted `sha256sum` output with exact repository-relative paths.

- XYZ PNGs: **21,828**.
- `blank.png`: **1**.
- Total PNGs/manifest lines: **21,829**.
- XYZ PNG byte sum: **38,508,278**; blank: **565** bytes; total: **38,508,843**.
- All paths match `assets/map/tiles/{z}/{x}/{y}.png` plus `assets/map/tiles/blank.png`; no other PNG layout or symlink found.
- Inventory file SHA-256: `cd8a59cca9732bc6425f0c6c5bb7edbf9f6d07cb62ab54e16570e999405146d5`.
- `sha256sum -c` verified all 21,829 entries after inventory creation.
- Raster tile manifest reports `tileCount=21,828`, `tileBytes=38,508,278`, `tilePositions=63,114`, z7–18; matches observed inventory/byte totals. No raster, raster manifest, source cell, source manifest, or PBF was modified.

## Exact baseline commands

The PBF tag census was read-only. Exact scanner used:

```sh
python3 - <<'PY'
import collections, math, osmium, re, time
PBF='tool/map_data/raw/sudeste-latest.osm.pbf'
BBOX=(-50.04,-22.31,-49.59,-22.13); MARGIN=0.02
num_re=re.compile(r'(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)\Z')
all_values=collections.Counter(); height_with_levels=0; levels_only=0; height_only=0; no_height=0; empty_height=0
eligible=0; tagged_mixed=0; accepted=0; parsed_nonpositive=0; unsupported=0
bad_location=0; start=time.monotonic()
fp=osmium.FileProcessor(PBF).with_locations()
for obj in fp:
    if not obj.is_way(): continue
    tags={tag.k:tag.v for tag in obj.tags}
    if 'building' not in tags and 'building:part' not in tags: continue
    if not obj.is_closed() or len(obj.nodes)<4: continue
    pts=[]
    valid=True
    for node in obj.nodes:
        try: lat,lon=node.lat,node.lon
        except Exception:
            valid=False; break
        if not math.isfinite(lat) or not math.isfinite(lon): valid=False; break
        if BBOX[1]-MARGIN <= lat <= BBOX[3]+MARGIN and BBOX[0]-MARGIN <= lon <= BBOX[2]+MARGIN:
            pts.append((lat,lon))
    if not valid:
        bad_location+=1; continue
    if len(pts)<4: continue
    eligible+=1
    h=tags.get('height')
    levels=tags.get('building:levels')
    if 'height' in tags and not h: empty_height+=1
    if h or levels: tagged_mixed+=1
    if h:
        all_values[h]+=1
        if levels: height_with_levels+=1
        else: height_only+=1
        if num_re.fullmatch(h):
            try: value=float(h)
            except ValueError: value=float('nan')
            if math.isfinite(value) and value>0: accepted+=1
            else: parsed_nonpositive+=1
        else: unsupported+=1
    else:
        if levels: levels_only+=1
        else: no_height+=1
print('scan_seconds',round(time.monotonic()-start,1))
print('eligible_closed_building_ways_in_generator_bbox',eligible)
print('eligible_with_truthy_height_or_levels_legacy_counter',tagged_mixed)
print('eligible_height_plus_levels',height_with_levels)
print('eligible_height_only',height_only)
print('eligible_levels_only_no_truthy_height',levels_only)
print('eligible_neither_height_nor_levels',no_height)
print('eligible_empty_height_tag',empty_height)
print('height_values_positive_ascii_decimal_m_candidate',accepted)
print('height_values_numeric_nonpositive_candidate',parsed_nonpositive)
print('height_values_outside_decimal_candidate',unsupported)
print('invalid_location_building_ways_skipped',bad_location)
print('distinct_nonempty_height_values',len(all_values))
print('value_counts_exact:')
for value,count in sorted(all_values.items(), key=lambda kv:(-kv[1],kv[0])):
    print(f'{count}\t{value!r}')
PY
```

PBF SHA before was captured by this Python `hashlib.sha256` streaming 8 MiB blocks; after each scan: `sha256sum tool/map_data/raw/sudeste-latest.osm.pbf`.

```sh
python3 - <<'PY'
import hashlib
h=hashlib.sha256()
with open('tool/map_data/raw/sudeste-latest.osm.pbf','rb') as f:
    for block in iter(lambda:f.read(8*1024*1024),b''): h.update(block)
print(h.hexdigest())
PY
sha256sum tool/map_data/raw/sudeste-latest.osm.pbf
```

Inventory preflight asserted 21,829 PNGs, 21,828 XYZ paths, one `blank.png`, no other PNG paths, and no symlinks. Inventory command:

```sh
LC_ALL=C find assets/map/tiles -type f -name '*.png' -print0 \
  | LC_ALL=C sort -z \
  | xargs -0 sha256sum \
  > docs/agent-work/handoffs/ENG-0004-raster-inventory.sha256
sha256sum -c docs/agent-work/handoffs/ENG-0004-raster-inventory.sha256 >/dev/null
```

## Safety and unresolved items

- No generator or downloader was run. The PBF was read only; its before/after SHA and manifest SHA match. The complete raster inventory was verified; no raster cleanup occurred.
- Future generation must use the existing PBF by explicit path, stage outside protected outputs, compare decompressed cell JSON and manifest semantically, preserve geometry/membership/coverage/non-height content and non-height counts, and promote only approved height/schema/count changes. Never run `fetch_data.sh` for this workflow.
- Resolve allowlisted manifest metadata handling (`generatedAt`, `l0Bytes`, `l1Bytes`) before promotion; do not treat arbitrary manifest drift as approved.
- Confirm whether product wants a maximum finite building height. No such cap was found in the approved WP/spec; baseline proposes finite and positive only.
- `archive` 4.5.2 is locally available and portable but transitive in current app; make it a direct dependency of the new SDK.
- No formatter, test suite, build, or generator validation was run; this phase was discovery/safety baseline only.

## Files inspected

`docs/agent-work/work-packages/ENG-0004-fogo-map-sdk.md`; `docs/superpowers/specs/2026-10-19-fogo-map-sdk-design.md`; `docs/agent-work/briefs/TASK-0004-master-brief.md`; `docs/agent-work/handoffs/HANDOFF-TASK-0004.md`; `tool/map_data/build_map_data.py`; `tool/map_data/render_tiles.py`; `tool/map_data/README.md`; `tool/map_data/requirements.txt`; `tool/map_data/fetch_data.sh`; `tool/map_data/raw/sudeste-latest.osm.pbf`; `assets/map/manifest.json`; `assets/map/cells/l0_0_0.json.gz`; `assets/map/cells/l1_0_0.json.gz`; `assets/map/cells/l1_8_1.json.gz`; `assets/map/tiles/manifest.json`; `pubspec.yaml`; `pubspec.lock`; `lib/features/map/vector/map_data_store.dart`; `lib/features/map/vector/map_data_controller.dart`; `lib/features/map/vector/vector_data.dart`; `tool/map_data/tests/test_render_tiles.py`; Flutter SDK Web `compute` implementation; cached `archive` 4.5.2 decoder source.

## Files modified

- `docs/agent-work/handoffs/ENG-0004-baseline.md` — this baseline report.
- `docs/agent-work/handoffs/ENG-0004-raster-inventory.sha256` — exact 21,829-path SHA-256 inventory.

No other repository files were written by this step. Repository has no Git metadata, so Git status/diff could not be used as evidence.

## Recommended next step

Engineering lead reviews this baseline and dispatches later implementation phases. Preserve all historical TASK-0001/2/3 records and keep raster cleanup gated on parity evidence.
