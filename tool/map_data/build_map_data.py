#!/usr/bin/env python3
"""F.O.G.O. — Pipeline de aquisição/preparação da base cartográfica real.

Fonte: OpenStreetMap (extrato regional da Geofabrik — `sudeste-latest.osm.pbf`,
       que contém Marília-SP e Garça-SP). Nenhum dado é inventado: tudo vem
       do OSM; atribuição obrigatória "© OpenStreetMap contributors".

Reproduzível:
    python3 tool/map_data/build_map_data.py --pbf tool/map_data/raw/sudeste-latest.osm.pbf \
        --stage /tmp/fogo-map-stage --promote-to assets/map
Saída:
    stage/manifest.json
    stage/cells/l0_{x}_{y}.json.gz
    stage/cells/l1_{x}_{y}.json.gz

Promotion to assets/map occurs only after source hashes and semantic comparison pass.

Política de uso: extrato baixado uma única vez de CDN oficial da Geofabrik;
nenhuma consulta repetida a servidores públicos durante o uso da aplicação.
"""
import argparse
import gzip
import hashlib
import json
import math
import os
import re
import sys
import tempfile
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import osmium

# Região de cobertura: Marília-SP + Garça-SP + corredor (SP-333) + periferias.
# Fonte dos centros: Nominatim (consultados e verificados em 2026-10).
BBOX = (-50.04, -22.31, -49.59, -22.13)  # (min_lon, min_lat, max_lon, max_lat)
MARGIN = 0.02  # margem p/ continuidade de vias que cruzam a borda
CELL = 0.05

ROAD_CLASS = {
    "motorway": 0, "motorway_link": 0, "trunk": 1, "trunk_link": 1,
    "primary": 2, "primary_link": 2, "secondary": 3, "secondary_link": 3,
    "tertiary": 4, "tertiary_link": 4, "unclassified": 5, "residential": 6,
    "living_street": 6, "service": 7, "track": 8, "pedestrian": 7,
    "footway": 9, "path": 9, "cycleway": 9, "steps": 9, "bridleway": 9,
}
AREA_KIND = {"water": 0, "green": 1, "farmland": 2, "boundary": 3}
POI_KIND = {"amenity": 0, "shop": 1, "tourism": 2, "leisure": 3, "healthcare": 4, "craft": 5, "office": 5}
LABEL_KIND = {"city": 0, "town": 1, "village": 2, "suburb": 3, "hamlet": 2, "neighbourhood": 3}


def in_box(lat, lon):
    return (BBOX[1] - MARGIN <= lat <= BBOX[3] + MARGIN and
            BBOX[0] - MARGIN <= lon <= BBOX[2] + MARGIN)


def cells_for(lat0, lon0, lat1, lon1):
    x0 = max(0, int((lon0 - BBOX[0]) / CELL))
    x1 = min(COLX - 1, int((lon1 - BBOX[0]) / CELL))
    y0 = max(0, int((lat0 - BBOX[1]) / CELL))
    y1 = min(COLY - 1, int((lat1 - BBOX[1]) / CELL))
    return [(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)]


def r5(v):
    return round(v, 5)


COLX = math.ceil((BBOX[2] - BBOX[0]) / CELL)
COLY = math.ceil((BBOX[3] - BBOX[1]) / CELL)

REPO_ROOT = Path(__file__).resolve().parents[2]
ASSETS_ROOT = REPO_ROOT / "assets" / "map"
HEIGHT_RE = re.compile(r"^[0-9]+(?:\.[0-9]+)?$")
SIGNED_NUMERIC_HEIGHT_RE = re.compile(r"^-?[0-9]+(?:\.[0-9]+)?$")
HEIGHT_COUNTER_FIELDS = {
    "buildingsWithPositiveNumericHeight",
    "buildingsWithLevelsOnly",
    "buildingsWithRejectedHeight",
    "buildingsWithUnsupportedHeight",
}

roads = []      # {c,n,r,p}
areas = []      # {k,p}
pois = []       # {k,x,y,n}
labels = []     # {k,x,y,n}
buildings = []  # source-way count is separate from per-cell records
heights_tagged = 0
building_count = 0
height_stats = Counter()
unsupported_height_values = Counter()


def bbox_of(pts):
    lats = [p[0] for p in pts]
    lons = [p[1] for p in pts]
    return min(lats), min(lons), max(lats), max(lons)


def parse_height(value: str | None) -> tuple[float | None, str]:
    """Accept only finite positive ASCII decimal metre values."""
    if not value:
        return None, "missing"
    if not isinstance(value, str):
        return None, "unsupported"
    if HEIGHT_RE.fullmatch(value):
        parsed = float(value)
        if not math.isfinite(parsed):
            return None, "nonfinite"
        if parsed > 0:
            return parsed, "accepted"
        if any(char in "123456789" for char in value):
            return None, "underflow"
        return None, "nonpositive"
    if SIGNED_NUMERIC_HEIGHT_RE.fullmatch(value):
        parsed = float(value)
        if not math.isfinite(parsed):
            return None, "nonfinite"
        return None, "nonpositive"
    return None, "unsupported"


def account_building_height_tags(tags: dict[str, str]) -> float | None:
    """Count height/levels once per eligible source way; keep legacy semantics."""
    global heights_tagged

    raw_height = tags.get("height")
    levels = tags.get("building:levels")
    if raw_height or levels:
        heights_tagged += 1

    if not raw_height:
        if levels:
            height_stats["levels_only"] += 1
        return None

    parsed, status = parse_height(raw_height)
    height_stats[status] += 1
    if status == "unsupported":
        unsupported_height_values[raw_height] += 1
    return parsed


def building_record(points: list[list[float]], height: float | None = None) -> dict[str, Any]:
    record: dict[str, Any] = {
        "p": [coordinate for point in points for coordinate in point],
        "b": [r5(value) for value in bbox_of(points)],
    }
    if height is not None:
        record["height"] = height
    return record


def reset_data() -> None:
    """Clear global accumulators before a repeatable generator invocation."""
    global building_count, heights_tagged

    roads.clear()
    areas.clear()
    pois.clear()
    labels.clear()
    ROADS.clear()
    RAIL.clear()
    WATERLINE.clear()
    L0.clear()
    L1.clear()
    BOUNDARIES.clear()
    height_stats.clear()
    unsupported_height_values.clear()
    building_count = 0
    heights_tagged = 0


ROADS = []  # coleta global para merge topológico (dissolve de vias)


def add_road(tags, coords):
    hw = tags.get("highway")
    if not hw:
        return
    cls = ROAD_CLASS.get(hw, 10)
    name = tags.get("name", "")
    ref = tags.get("ref", "")
    oneway = 1 if tags.get("oneway") in ("yes", "true", "1", "-1") else 0
    bridge = 1 if tags.get("bridge") not in (None, "no") else 0
    tunnel = 1 if tags.get("tunnel") not in (None, "no") else 0
    runs, cur = [], []
    for lat, lon in coords:
        if in_box(lat, lon):
            cur.append([r5(lat), r5(lon)])
        else:
            if len(cur) >= 2:
                runs.append(cur)
            cur = []
    if len(cur) >= 2:
        runs.append(cur)
    for run in runs:
        ROADS.append({
            "c": cls, "n": name, "r": ref, "o": oneway, "br": bridge, "tn": tunnel,
            "pts": run,
        })


def _tangent(pts, at_end):
    # direção (metros locais) nas pontas
    a, b = (pts[0], pts[1]) if at_end else (pts[-2], pts[-1])
    import math
    dy = (a[0] - b[0]) * 111132.0
    dx = (a[1] - b[1]) * 111320.0 * math.cos(math.radians((a[0] + b[0]) / 2))
    return math.atan2(dy, dx)


def _pt_dist_m(p, q):
    import math
    dy = (p[0] - q[0]) * 111132.0
    dx = (p[1] - q[1]) * 111320.0 * math.cos(math.radians((p[0] + q[0]) / 2))
    return math.hypot(dx, dy)


def _near_interior(p, runs, eps_m=2.5):
    # a ponta toca o INTERIOR de outra via? (T-junção → não fundir)
    for r in runs:
        if len(r["pts"]) < 2:
            continue
        for i in range(len(r["pts"]) - 1):
            a, b = r["pts"][i], r["pts"][i + 1]
            # distância ponto-segmento (aprox local plana)
            ax, ay = a[1], a[0]
            bx, by = b[1], b[0]
            px, py = p[1], p[0]
            abx, aby = bx - ax, by - ay
            t = 0 if (abx == 0 and aby == 0) else max(0.0, min(1.0, ((px - ax) * abx + (py - ay) * aby) / (abx * abx + aby * aby)))
            cx, cy = ax + t * abx, ay + t * aby
            d = _pt_dist_m([py, px], [cy, cx])
            if d < eps_m:
                # extremidades não contam como interior
                if _pt_dist_m(p, a) < eps_m or _pt_dist_m(p, b) < eps_m:
                    continue
                return True
    return False


def merge_roads(eps_m=2.5, max_angle_deg=30.0):
    """Dissolve vias contínuas: funde pontas coincidentes (mesma classe,
    tangentes alinhadas) que NÃO sejam junções (nó com 3+ vias ou T).
    Elimina caps intermediários de um mesmo logradouro dividido em ways."""
    import math
    grid = {}
    def key(p):
        return (round(p[0] / 0.0002), round(p[1] / 0.0002))

    def index(r, i):
        for end in (0, -1):
            k = key(r["pts"][end])
            grid.setdefault(k, []).append((i, end))

    for i, r in enumerate(ROADS):
        index(r, i)

    merged = True
    while merged:
        merged = False
        grid.clear()
        for i, r in enumerate(ROADS):
            if r is not None:
                index(r, i)
        for i, a in enumerate(ROADS):
            if a is None:
                continue
            for end_a in (0, -1):
                pa = a["pts"][end_a]
                cands = []
                for dkx in (-1, 0, 1):
                    for dky in (-1, 0, 1):
                        for (j, end_b) in grid.get((key(pa)[0] + dkx, key(pa)[1] + dky), []):
                            if j <= i or ROADS[j] is None:
                                continue
                            pb = ROADS[j]["pts"][end_b]
                            if _pt_dist_m(pa, pb) > eps_m:
                                continue
                            if ROADS[j]["c"] != a["c"]:
                                continue
                            cands.append((j, end_b))
                if len(cands) != 1:
                    continue  # junção (3+) ou ponta solta
                j, end_b = cands[0]
                b = ROADS[j]
                # tangentes alinhadas na junção
                ta = _tangent(a["pts"], end_a == 0)
                tb = _tangent(b["pts"], end_b != 0)
                diff = abs((ta - tb + math.pi) % (2 * math.pi) - math.pi)
                if diff > max_angle_deg * math.pi / 180.0:
                    continue
                # não fundir se a junção toca interior de outra via (T)
                others = [r for k, r in enumerate(ROADS) if r is not None and k != i and k != j]
                if _near_interior(pa, others, eps_m):
                    continue
                # funde: alinha pontas
                if end_a == 0:
                    a["pts"] = (b["pts"] if end_b == 0 else list(reversed(b["pts"]))) + a["pts"]
                else:
                    a["pts"] = a["pts"] + (b["pts"] if end_b == -1 else list(reversed(b["pts"])))
                ROADS[j] = None
                merged = True
                break
    ROADS[:] = [r for r in ROADS if r is not None]


def distribute_roads_to_cells():
    for r in ROADS:
        run = r["pts"]
        b = bbox_of(run)
        for cx, cy in cells_for(*b):
            L0[(cx, cy)]["roads"].append(
                {"c": r["c"], "n": r["n"], "r": r["r"], "o": r["o"], "br": r["br"], "tn": r["tn"],
                 "p": [c for pt in run for c in pt], "b": [r5(b[0]), r5(b[1]), r5(b[2]), r5(b[3])]}
            )


RAIL = []      # {"p","b"} por célula
WATERLINE = []  # {"k","n","p","b"} por célula

WATERWAY_CLASS = {"river": 0, "canal": 1, "stream": 2, "drain": 3, "ditch": 3}


def add_line(layer_name, record, b):
    for cx, cy in cells_for(*b):
        L0[(cx, cy)][layer_name].append(record)


RAILWAY_KIND = {"rail": 0, "light_rail": 0, "narrow_gauge": 0, "tram": 1,
                "disused": 2, "abandoned": 2}


def add_railway(tags, coords):
    rw = tags.get("railway")
    if rw not in RAILWAY_KIND:
        return
    runs, cur = [], []
    for lat, lon in coords:
        if in_box(lat, lon):
            cur.append([r5(lat), r5(lon)])
        else:
            if len(cur) >= 2:
                runs.append(cur)
            cur = []
    if len(cur) >= 2:
        runs.append(cur)
    for run in runs:
        b = bbox_of(run)
        rec = {"k": RAILWAY_KIND[rw], "p": [c for pt in run for c in pt],
               "b": [r5(b[0]), r5(b[1]), r5(b[2]), r5(b[3])]}
        for cx, cy in cells_for(*b):
            L0[(cx, cy)]["rail"].append(rec)


def add_waterway(tags, coords):
    ww = tags.get("waterway")
    if ww not in WATERWAY_CLASS:
        return
    runs, cur = [], []
    for lat, lon in coords:
        if in_box(lat, lon):
            cur.append([r5(lat), r5(lon)])
        else:
            if len(cur) >= 2:
                runs.append(cur)
            cur = []
    if len(cur) >= 2:
        runs.append(cur)
    name = tags.get("name", "")
    for run in runs:
        b = bbox_of(run)
        rec = {"k": WATERWAY_CLASS[ww], "n": name,
               "p": [c for pt in run for c in pt],
               "b": [r5(b[0]), r5(b[1]), r5(b[2]), r5(b[3])]}
        for cx, cy in cells_for(*b):
            L0[(cx, cy)]["wl"].append(rec)


def add_area(kind, coords):
    pts = [[r5(lat), r5(lon)] for lat, lon in coords if in_box(lat, lon)]
    if len(pts) < 4:
        return
    b = bbox_of(pts)
    rec = {"k": AREA_KIND[kind], "p": [c for pt in pts for c in pt], "b": [r5(b[0]), r5(b[1]), r5(b[2]), r5(b[3])]}
    if kind == "boundary":
        BOUNDARIES.append(rec)
    else:
        for cx, cy in cells_for(*b):
            L0[(cx, cy)]["areas"].append(rec)


def area_kind_for(tags):
    if tags.get("natural") in ("wood", "scrub") or tags.get("landuse") in ("forest", "grass", "recreation_ground", "village_green", "cemetery"):
        return "green"
    if tags.get("leisure") in ("park", "garden", "pitch", "playground", "golf_course"):
        return "green"
    if tags.get("landuse") == "farmland":
        return "farmland"
    if tags.get("natural") == "water" or tags.get("waterway") == "riverbank" or tags.get("landuse") in ("reservoir", "basin"):
        return "water"
    return None


L0 = defaultdict(lambda: defaultdict(list))
L1 = defaultdict(lambda: defaultdict(list))
BOUNDARIES = []


def way_coords(way):
    return [(n.lat, n.lon) for n in way.nodes]


def ring_coords(ring):
    return [(nr.lat, nr.lon) for nr in ring]


def process():
    global building_count, heights_tagged
    fp = osmium.FileProcessor(args.pbf).with_locations().with_areas()
    t0 = time.time()
    n = 0
    for obj in fp:
        n += 1
        if n % 20_000_000 == 0:
            print(f"  ...{n} objetos ({time.time()-t0:.0f}s)", flush=True)
        if obj.is_way():
            tags = {t.k: t.v for t in obj.tags}
            coords = way_coords(obj)
            if tags.get("highway"):
                add_road(tags, coords)
                continue
            if tags.get("railway"):
                add_railway(tags, coords)
                continue
            if tags.get("waterway"):
                add_waterway(tags, coords)
                continue
            if "building" in tags or "building:part" in tags:
                if obj.is_closed() and len(coords) >= 4:
                    pts = [[r5(lat), r5(lon)] for lat, lon in coords if in_box(lat, lon)]
                    if len(pts) >= 4:
                        building_count += 1
                        height = account_building_height_tags(tags)
                        b = bbox_of(pts)
                        rec = building_record(pts, height)
                        for cx, cy in cells_for(*b):
                            L1[(cx, cy)]["bld"].append(rec)
                continue
            if "name" in tags and any(k in tags for k in POI_KIND):
                # POIs mapeados como prédios/áreas: usa o centróide
                if coords:
                    clat = sum(c[0] for c in coords) / len(coords)
                    clng = sum(c[1] for c in coords) / len(coords)
                    if in_box(clat, clng):
                        for k in POI_KIND:
                            if k in tags:
                                rec = {"k": POI_KIND[k], "x": r5(clat), "y": r5(clng), "n": tags.get("name", "")}
                                b = (rec["x"], rec["y"], rec["x"], rec["y"])
                                for cx, cy in cells_for(*b):
                                    L0[(cx, cy)]["pois"].append(rec)
                                break
                continue
            kind = area_kind_for(tags)
            if kind and obj.is_closed():
                add_area(kind, coords)
        elif obj.is_area():
            tags = {t.k: t.v for t in obj.tags}
            if tags.get("boundary") == "administrative" and tags.get("admin_level") == "8":
                for ring in obj.outer_rings():
                    add_area("boundary", ring_coords(ring))
                continue
            kind = area_kind_for(tags)
            if kind:
                for ring in obj.outer_rings():
                    add_area(kind, ring_coords(ring))
        elif obj.is_node():
            tags = {t.k: t.v for t in obj.tags}
            if not in_box(obj.lat, obj.lon):
                continue
            place = tags.get("place")
            name = tags.get("name", "")
            if place in LABEL_KIND and name:
                rec = {"k": LABEL_KIND[place], "x": r5(obj.lat), "y": r5(obj.lon), "n": name}
                b = (rec["x"], rec["y"], rec["x"], rec["y"])
                for cx, cy in cells_for(*b):
                    L0[(cx, cy)]["labels"].append(rec)
                continue
            if "name" in tags and any(k in tags for k in POI_KIND):
                for k in POI_KIND:
                    if k in tags:
                        rec = {"k": POI_KIND[k], "x": r5(obj.lat), "y": r5(obj.lon), "n": name}
                        b = (rec["x"], rec["y"], rec["x"], rec["y"])
                        for cx, cy in cells_for(*b):
                            L0[(cx, cy)]["pois"].append(rec)
                        break
    print(f"processado: {n} objetos em {time.time()-t0:.0f}s", flush=True)
    pre = len(ROADS)
    merge_roads()
    print(f"merge topológico: {pre} → {len(ROADS)} vias", flush=True)
    distribute_roads_to_cells()


class GenerationError(RuntimeError):
    """Generation or promotion failed closed."""


class SemanticComparisonError(GenerationError):
    """Staged output contains a non-allowlisted semantic change."""


def height_manifest_counts() -> dict[str, int]:
    return {
        "buildingsWithPositiveNumericHeight": height_stats["accepted"],
        "buildingsWithLevelsOnly": height_stats["levels_only"],
        "buildingsWithRejectedHeight": (
            height_stats["nonpositive"] + height_stats["nonfinite"] + height_stats["underflow"]
        ),
        "buildingsWithUnsupportedHeight": height_stats["unsupported"],
    }


def report_height_counts() -> None:
    print(f"height accepted: {height_stats['accepted']}")
    print(f"height levels-only: {height_stats['levels_only']}")
    print(f"height rejected numeric nonpositive: {height_stats['nonpositive']}")
    print(f"height rejected nonfinite/underflow: {height_stats['nonfinite'] + height_stats['underflow']}")
    print(f"height unsupported values: {height_stats['unsupported']}")
    for value, count in sorted(unsupported_height_values.items()):
        print(f"  {value!r}: {count}")


def validate_stage_path(stage: Path, protected: tuple[Path, ...]) -> None:
    stage = stage.resolve()
    for target in protected:
        target = target.resolve()
        if stage == target or stage.is_relative_to(target) or target.is_relative_to(stage):
            raise GenerationError(f"stage path overlaps protected output: {target}")
    if stage.exists():
        if stage.is_symlink() or not stage.is_dir():
            raise GenerationError(f"stage path must be a real directory: {stage}")
        if any(stage.iterdir()):
            raise GenerationError(f"stage directory must be empty: {stage}")


def write_outputs(source_sha256: str, generated_at: str) -> None:
    out = Path(args.stage).resolve()
    validate_stage_path(out, (ASSETS_ROOT,))
    cells_dir = out / "cells"
    cells_dir.mkdir(parents=True, exist_ok=True)
    total_l0 = 0
    total_l1 = 0
    for (cx, cy), data in L0.items():
        data["areas"] = list({id(r): r for r in data["areas"]}.values())
        data["rail"] = list({id(r): r for r in data.get("rail", [])}.values())
        data["wl"] = list({id(r): r for r in data.get("wl", [])}.values())
        # limites municipais entram em todas as células (são 2 polígonos)
        data["areas"].extend(BOUNDARIES)
        blob = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
        raw = gzip.compress(blob.encode("utf-8"), 9)
        (cells_dir / f"l0_{cx}_{cy}.json.gz").write_bytes(raw)
        total_l0 += len(raw)
    for (cx, cy), data in L1.items():
        blob = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
        raw = gzip.compress(blob.encode("utf-8"), 9)
        (cells_dir / f"l1_{cx}_{cy}.json.gz").write_bytes(raw)
        total_l1 += len(raw)

    counts = {
        "roadsInCells": sum(len(v["roads"]) for v in L0.values()),
        "rail": sum(len(v.get("rail", [])) for v in L0.values()),
        "waterlines": sum(len(v.get("wl", [])) for v in L0.values()),
        "areas": sum(len(v["areas"]) for v in L0.values()),
        "pois": sum(len(v["pois"]) for v in L0.values()),
        "labels": sum(len(v["labels"]) for v in L0.values()),
        "buildings": sum(len(v["bld"]) for v in L1.values()),
        # Preserve legacy mixed per-source-way semantics.
        "buildingsWithHeightTag": heights_tagged,
        **height_manifest_counts(),
    }
    manifest = {
        "version": 2,
        "bbox": list(BBOX),
        "tileBounds": {
            "west": BBOX[0],
            "south": BBOX[1],
            "east": BBOX[2],
            "north": BBOX[3],
        },
        "cellSize": CELL,
        "cols": COLX,
        "rows": COLY,
        "generatedAt": generated_at,
        "source": "OpenStreetMap — extrato Geofabrik sudeste-latest.osm.pbf",
        "sourceSha256": source_sha256,
        "attribution": "© OpenStreetMap contributors",
        "counts": counts,
        "l0Bytes": total_l0,
        "l1Bytes": total_l1,
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(json.dumps(manifest["counts"], indent=2))
    print(f"l0: {total_l0/1e6:.1f} MB | l1: {total_l1/1e6:.1f} MB")
    report_height_counts()


def sha256(path: str | Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _reject_json_constant(value: str) -> None:
    raise ValueError(f"invalid JSON constant: {value}")


def _load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"), parse_constant=_reject_json_constant)
    except (OSError, json.JSONDecodeError, ValueError) as error:
        raise SemanticComparisonError(f"invalid JSON file {path}: {error}") from error


def _json_equal(before: Any, after: Any) -> bool:
    if type(before) is not type(after):
        return False
    if isinstance(before, dict):
        return before.keys() == after.keys() and all(
            _json_equal(before[key], after[key]) for key in before
        )
    if isinstance(before, list):
        return len(before) == len(after) and all(
            _json_equal(old, new) for old, new in zip(before, after)
        )
    return before == after


def _cell_files(root: Path) -> dict[str, Path]:
    cells = root / "cells"
    if cells.is_symlink() or not cells.is_dir():
        raise SemanticComparisonError(f"cells directory missing or unsafe: {cells}")
    files: dict[str, Path] = {}
    for path in cells.rglob("*"):
        if path.is_symlink():
            raise SemanticComparisonError(f"symlink in cells tree: {path}")
        if path.is_file():
            relative = path.relative_to(cells).as_posix()
            if not relative.endswith(".json.gz"):
                raise SemanticComparisonError(f"unexpected cell file: {relative}")
            files[relative] = path
    return files


def _load_gzip_json(path: Path) -> Any:
    with gzip.open(path, "rt", encoding="utf-8") as compressed:
        return json.loads(compressed.read(), parse_constant=_reject_json_constant)


def _valid_positive_height(value: Any) -> bool:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False
    try:
        return math.isfinite(value) and value > 0
    except OverflowError:
        return False


def _compare_cell_json(
    before: Any,
    after: Any,
    relative_path: str,
    height_additions: Counter[str],
    path: tuple[str, ...] = (),
    building_record: bool = False,
) -> None:
    if type(before) is not type(after):
        raise SemanticComparisonError(f"JSON type changed at {relative_path}:{path}")
    if isinstance(before, dict):
        before_keys = set(before)
        after_keys = set(after)
        removed = before_keys - after_keys
        added = after_keys - before_keys
        if removed:
            raise SemanticComparisonError(f"JSON fields removed at {relative_path}:{path}: {sorted(removed)}")
        if added:
            if not building_record or added != {"height"}:
                raise SemanticComparisonError(f"unapproved JSON fields added at {relative_path}:{path}: {sorted(added)}")
            if not _valid_positive_height(after["height"]):
                raise SemanticComparisonError(f"invalid additive height at {relative_path}:{path}")
            height_additions[relative_path] += 1
        for key in before_keys:
            _compare_cell_json(
                before[key], after[key], relative_path, height_additions,
                path + (key,), False,
            )
        return
    if isinstance(before, list):
        if len(before) != len(after):
            raise SemanticComparisonError(f"JSON list length changed at {relative_path}:{path}")
        for old_item, new_item in zip(before, after):
            _compare_cell_json(
                old_item, new_item, relative_path, height_additions,
                path, path == ("bld",),
            )
        return
    if before != after:
        raise SemanticComparisonError(f"JSON value changed at {relative_path}:{path}")


def _byte_total(files: dict[str, Path], tier: str) -> int:
    return sum(path.stat().st_size for name, path in files.items() if name.startswith(f"{tier}_"))


def _validate_height_counts(counts: dict[str, int]) -> None:
    if set(counts) != HEIGHT_COUNTER_FIELDS:
        raise SemanticComparisonError("height counters do not match approved counter allowlist")
    if any(type(value) is not int or value < 0 for value in counts.values()):
        raise SemanticComparisonError("height counters must be nonnegative integers")


def compare_outputs(
    baseline: Path,
    stage: Path,
    expected_generated_at: str,
    expected_source_sha256: str,
    expected_height_counts: dict[str, int],
) -> dict[str, Any]:
    """Compare gzip JSON deeply; allow only additive building heights and listed manifest fields.

    Manifest allowlist: generatedAt (must equal this run's timestamp), l1Bytes
    (must equal staged compressed L1 bytes), and the four height-only counters.
    l0Bytes must remain unchanged and match staged compressed L0 bytes. All other
    metadata, counts, fields, and cell membership must remain identical.
    """
    _validate_height_counts(expected_height_counts)
    before_files = _cell_files(baseline)
    stage_files = _cell_files(stage)
    if set(before_files) != set(stage_files):
        missing = sorted(set(before_files) - set(stage_files))
        added = sorted(set(stage_files) - set(before_files))
        raise SemanticComparisonError(f"cell path membership changed; missing={missing}, added={added}")

    height_additions: Counter[str] = Counter()
    for relative in sorted(before_files):
        try:
            before_json = _load_gzip_json(before_files[relative])
            stage_json = _load_gzip_json(stage_files[relative])
        except (OSError, EOFError, gzip.BadGzipFile, json.JSONDecodeError, ValueError) as error:
            raise SemanticComparisonError(f"invalid cell JSON in {relative}: {error}") from error
        _compare_cell_json(before_json, stage_json, relative, height_additions)

    before_manifest_path = baseline / "manifest.json"
    stage_manifest_path = stage / "manifest.json"
    if not before_manifest_path.is_file() or not stage_manifest_path.is_file():
        raise SemanticComparisonError("baseline or staged manifest missing")
    before_manifest = _load_json(before_manifest_path)
    stage_manifest = _load_json(stage_manifest_path)
    if not isinstance(before_manifest, dict) or not isinstance(stage_manifest, dict):
        raise SemanticComparisonError("manifest must be a JSON object")
    if set(before_manifest) != set(stage_manifest):
        raise SemanticComparisonError("manifest top-level fields changed")
    if stage_manifest.get("sourceSha256") != expected_source_sha256:
        raise SemanticComparisonError("staged manifest sourceSha256 does not match PBF")
    try:
        time.strptime(expected_generated_at, "%Y-%m-%dT%H:%M:%S%z")
    except ValueError as error:
        raise SemanticComparisonError("generatedAt is not in the generator's timestamp format") from error
    if stage_manifest.get("generatedAt") != expected_generated_at:
        raise SemanticComparisonError("staged generatedAt does not match this generation run")

    before_counts = before_manifest.get("counts")
    stage_counts = stage_manifest.get("counts")
    if not isinstance(before_counts, dict) or not isinstance(stage_counts, dict):
        raise SemanticComparisonError("manifest counts must be JSON objects")
    if set(stage_counts) != set(before_counts) | HEIGHT_COUNTER_FIELDS:
        raise SemanticComparisonError("manifest count fields changed outside approved height counters")
    for name, value in before_counts.items():
        if name not in HEIGHT_COUNTER_FIELDS and not _json_equal(stage_counts[name], value):
            raise SemanticComparisonError(f"non-height manifest count changed: counts.{name}")
    for name, expected in expected_height_counts.items():
        if type(stage_counts.get(name)) is not int or stage_counts[name] != expected:
            raise SemanticComparisonError(f"staged height counter does not match generator: counts.{name}")

    manifest_changes: list[str] = []
    for name, before_value in before_manifest.items():
        after_value = stage_manifest[name]
        if name == "generatedAt":
            if type(after_value) is not str:
                raise SemanticComparisonError("invalid generatedAt")
            if before_value != after_value:
                manifest_changes.append(name)
        elif name == "l1Bytes":
            if type(after_value) is not int or after_value != _byte_total(stage_files, "l1"):
                raise SemanticComparisonError("staged l1Bytes does not match staged L1 files")
            if before_value != after_value:
                manifest_changes.append(name)
        elif name == "l0Bytes":
            if type(before_value) is not int or before_value != _byte_total(before_files, "l0"):
                raise SemanticComparisonError("baseline l0Bytes does not match baseline L0 files")
            if type(after_value) is not int or after_value != _byte_total(stage_files, "l0"):
                raise SemanticComparisonError("staged l0Bytes does not match staged L0 files")
            if after_value != before_value:
                raise SemanticComparisonError("non-height manifest field changed: l0Bytes")
        elif name == "counts":
            for counter in sorted(HEIGHT_COUNTER_FIELDS):
                if before_counts.get(counter) != stage_counts[counter]:
                    manifest_changes.append(f"counts.{counter}")
        elif not _json_equal(after_value, before_value):
            raise SemanticComparisonError(f"non-allowlisted manifest field changed: {name}")

    if type(stage_manifest.get("l0Bytes")) is not int or stage_manifest["l0Bytes"] != _byte_total(stage_files, "l0"):
        raise SemanticComparisonError("staged l0Bytes does not match staged L0 files")

    return {
        "cellFilesCompared": len(before_files),
        "heightAdditions": sum(height_additions.values()),
        "heightAdditionsByCell": dict(sorted(height_additions.items())),
        "approvedManifestChanges": manifest_changes,
        "heightCounters": dict(expected_height_counts),
    }


def _atomic_write(path: Path, contents: bytes) -> None:
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=f".{path.name}.", delete=False) as output:
            temporary = Path(output.name)
            output.write(contents)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def promote_stage(
    baseline: Path,
    stage: Path,
    expected_generated_at: str,
    expected_source_sha256: str,
    source_sha256_after: str,
    expected_height_counts: dict[str, int],
) -> dict[str, Any]:
    if expected_source_sha256 != source_sha256_after:
        raise GenerationError("PBF SHA-256 changed; refusing promotion")
    summary = compare_outputs(
        baseline, stage, expected_generated_at, expected_source_sha256, expected_height_counts
    )
    baseline_files = _cell_files(baseline)
    stage_files = _cell_files(stage)
    destinations = [(baseline_files[name], stage_files[name]) for name in sorted(baseline_files)]
    destinations.append((baseline / "manifest.json", stage / "manifest.json"))
    backups = {target: target.read_bytes() for target, _source in destinations}
    replaced: list[Path] = []
    try:
        for target, source in destinations:
            _atomic_write(target, source.read_bytes())
            replaced.append(target)
    except OSError as error:
        rollback_errors: list[str] = []
        for target in reversed(replaced):
            try:
                _atomic_write(target, backups[target])
            except OSError as rollback_error:
                rollback_errors.append(f"{target}: {rollback_error}")
        if rollback_errors:
            raise GenerationError(
                f"promotion failed and rollback was incomplete: {rollback_errors}"
            ) from error
        raise GenerationError("promotion failed; replaced files were rolled back") from error
    return summary


def generate_staged(pbf: Path, stage: Path, promote_to: Path | None = None) -> dict[str, Any]:
    global args

    pbf = pbf.resolve()
    stage = stage.resolve()
    target = promote_to.resolve() if promote_to is not None else None
    if not pbf.is_file():
        raise GenerationError(f"local PBF is absent: {pbf}")
    protected = (ASSETS_ROOT,) if target is None else (ASSETS_ROOT, target)
    validate_stage_path(stage, protected)
    if target is not None and (not (target / "manifest.json").is_file() or not (target / "cells").is_dir()):
        raise GenerationError(f"promotion baseline is incomplete: {target}")

    reset_data()
    args = argparse.Namespace(pbf=str(pbf), stage=str(stage))
    source_sha256_before = sha256(pbf)
    process()
    source_sha256_after_read = sha256(pbf)
    if source_sha256_before != source_sha256_after_read:
        raise GenerationError(
            "PBF SHA-256 changed during processing; no staged files written "
            f"(before={source_sha256_before}, after={source_sha256_after_read})"
        )

    stage.mkdir(parents=True, exist_ok=True)
    generated_at = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    write_outputs(source_sha256_before, generated_at)
    source_sha256_after = sha256(pbf)
    if source_sha256_before != source_sha256_after:
        raise GenerationError(
            "PBF SHA-256 changed during generation; refusing promotion "
            f"(before={source_sha256_before}, after={source_sha256_after})"
        )

    staged_manifest = _load_json(stage / "manifest.json")
    if staged_manifest.get("sourceSha256") != source_sha256_before:
        raise GenerationError("staged manifest sourceSha256 does not match PBF")

    summary = None
    if target is not None:
        summary = promote_stage(
            target, stage, generated_at, source_sha256_before,
            source_sha256_after, height_manifest_counts(),
        )
        print(f"semantic delta: {json.dumps(summary, ensure_ascii=False, sort_keys=True)}")
    return {
        "sourceSha256Before": source_sha256_before,
        "sourceSha256After": source_sha256_after,
        "semanticDelta": summary,
        "heightCounts": height_manifest_counts(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Stage and gate local OSM map data generation.")
    parser.add_argument("--pbf", required=True, help="existing local PBF; never downloaded")
    parser.add_argument("--stage", type=Path, help="new or empty staging directory outside assets/map")
    parser.add_argument("--out", type=Path, help="legacy spelling for gated promotion target (not a direct output)")
    parser.add_argument("--promote-to", type=Path, help="baseline/output directory; promotion is gated")
    parsed = parser.parse_args(argv)
    if parsed.out is not None and parsed.promote_to is not None:
        parser.error("use only one of --out or --promote-to")
    target = parsed.promote_to or parsed.out
    if parsed.stage is None and target is None:
        parser.error("provide --stage, or provide --out/--promote-to for a temporary stage")
    try:
        if parsed.stage is None:
            with tempfile.TemporaryDirectory(prefix="fogo-map-stage-") as temporary_stage:
                result = generate_staged(Path(parsed.pbf), Path(temporary_stage), target)
        else:
            result = generate_staged(Path(parsed.pbf), parsed.stage, target)
    except GenerationError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    print(f"PBF SHA-256 before: {result['sourceSha256Before']}")
    print(f"PBF SHA-256 after:  {result['sourceSha256After']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
