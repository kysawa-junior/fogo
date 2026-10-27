#!/usr/bin/env python3
"""Mergeia edifícios do Overture Maps (.parquet) no extrato OSM regional.

Converte os footprints Overture (Marília-SP, Vera Cruz-SP, Garça-SP) para
XML OSM e reescreve `assets/map/osm/regiao.osm.gz`:

- prédios OSM cujo footprint intersecta um Overture são DESCARTADOS
  (Overture vence — dedup offline, custo zero no runtime);
- prédios Overture entram como ways fechados (ou `type=multipolygon`
  quando têm pátio ou múltiplas partes) com ids positivos ACIMA do
  máximo existente (o leitor do motor rejeita ids negativos);
- o motor 3D não muda nada: extrusão, isolate, 2D/3D, LOD e seleção
  seguem pelo caminho OSM existente.

Uso:
  uv run --with pyarrow --with shapely python tool/map_data/overture_to_osm.py \
      [--parquet-dir ~/dados-overture/edificios] \
      [--osm assets/map/osm/regiao.osm.gz] [--dry-run]

Rode SEMPRE depois de `extract_osm_xml.py` — regenerar o extrato do PBF
sozinho descarta a camada Overture.
"""
from __future__ import annotations

import argparse
import gzip
import math
import os
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

import pyarrow.parquet as pq
from shapely import wkb
from shapely.geometry import Polygon
from shapely.strtree import STRtree

# Mesma faixa do extrato regional (extract_osm_xml.py / RegionCatalog).
REGION = (-49.975, -22.245, -49.634, -22.200)

# Subtipos Overture mapeiam 1:1 para valores OSM de building=*.
_BUILDING_VALUES = {
    "commercial", "education", "outbuilding", "civic", "religious",
    "industrial", "residential", "agricultural", "medical", "transportation",
    "entertainment", "service", "church", "hotel", "retail", "office",
    "government", "sports", "history", "parking", "train_station",
    "university", "college", "school", "hospital", "fire_station",
    "warehouse", "factory", "barn", "shed", "garage", "garages",
    "apartments", "dormitory", "house", "detached", "kiosk", "hut",
    "roof", "ruins", "construction", "greenhouse", "carport",
}


def _fmt(value: float) -> str:
    """Decimal simples, sem notação científica (double.tryParse do motor)."""
    out = f"{value:.2f}".rstrip("0").rstrip(".")
    return "0" if out in ("", "-0") else out


def _num(value) -> float | None:
    """Número finito positivo razoável, ou None."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    v = float(value)
    if not math.isfinite(v) or v <= 0 or v >= 1e4:
        return None
    return v


def _ring_nodes(coords) -> list[tuple[float, float]]:
    """Vertices únicos do anel como (lat, lon) — shapely devolve (x=lon, y=lat)."""
    pts = [(round(float(y), 9), round(float(x), 9)) for x, y in list(coords)[:-1]]
    dedup = [pts[0]]
    for p in pts[1:]:
        if p != dedup[-1]:
            dedup.append(p)
    return dedup


def _load_overture(parquet_dir: Path) -> list[dict]:
    """Ground-level, totalmente dentro da faixa regional."""
    out = []
    for name in sorted(p for p in parquet_dir.iterdir() if p.suffix == ".parquet"):
        table = pq.read_table(
            name,
            columns=["id", "names", "height", "min_height", "is_underground",
                     "num_floors", "subtype", "geometry"],
        )
        cols = {c: table.column(c).to_pylist() for c in table.column_names}
        for i in range(table.num_rows):
            if cols["is_underground"][i]:
                continue
            geom = wkb.loads(cols["geometry"][i])
            b = geom.bounds
            if not (b[0] >= REGION[0] and b[1] >= REGION[1]
                    and b[2] <= REGION[2] and b[3] <= REGION[3]):
                continue
            parts = list(geom.geoms) if geom.geom_type == "MultiPolygon" else [geom]
            parts = [p for p in parts if not p.is_empty]
            if not parts:
                continue
            names = cols["names"][i] or {}
            out.append({
                "id": cols["id"][i],
                "name": (names.get("primary") or "").strip() or None,
                "height": _num(cols["height"][i]),
                "min_height": _num(cols["min_height"][i]),
                "floors": _num(cols["num_floors"][i]),
                "subtype": cols["subtype"][i],
                "parts": parts,
            })
    out.sort(key=lambda r: r["id"])
    return out


def _building_tag_value(el: ET.Element) -> str | None:
    """Valor de building=* quando o elemento é um prédio (≠ 'no')."""
    for t in el.findall("tag"):
        if t.get("k") == "building" and t.get("v") != "no":
            return t.get("v")
    return None


def _way_polygon(el: ET.Element, nodes: dict) -> Polygon | None:
    refs = [nd.get("ref") for nd in el.findall("nd")]
    if len(refs) < 4 or refs[0] != refs[-1]:
        return None
    try:
        pts = [nodes[r] for r in refs[:-1]]
    except KeyError:
        return None
    return Polygon(pts) if len(pts) >= 3 else None


def _dedup_osm_buildings(root: ET.Element, nodes: dict,
                         overture_geoms: list) -> set[str]:
    """Ids (`way/…`, `relation/…`) cobertos por Overture — Overture vence."""
    tree = STRtree(overture_geoms)
    drop: set[str] = set()

    for way in root.findall("way"):
        if _building_tag_value(way) is None:
            continue
        poly = _way_polygon(way, nodes)
        if poly is not None and not poly.is_empty and \
                tree.query(poly, predicate="intersects").size > 0:
            drop.add(f"way/{way.get('id')}")

    ways_by_id = {w.get("id"): w for w in root.findall("way")}
    building_relations = []
    kept_member_refs: set[str] = set()
    for rel in root.findall("relation"):
        tags = {t.get("k"): t.get("v") for t in rel.findall("tag")}
        if tags.get("type") != "multipolygon" or "building" not in tags \
                or tags["building"] == "no":
            kept_member_refs.update(m.get("ref") for m in rel.findall("member"))
            continue
        building_relations.append(rel)

    for rel in building_relations:
        hit = False
        for m in rel.findall("member"):
            if m.get("type") != "way" or m.get("role") == "inner":
                continue
            way = ways_by_id.get(m.get("ref"))
            if way is None:
                continue
            poly = _way_polygon(way, nodes)
            if poly is not None and not poly.is_empty and \
                    tree.query(poly, predicate="intersects").size > 0:
                hit = True
                break
        if hit:
            drop.add(f"relation/{rel.get('id')}")
            # Membros com tag building virariam prédios órfãos duplicados.
            for m in rel.findall("member"):
                if m.get("type") != "way":
                    continue
                way = ways_by_id.get(m.get("ref"))
                if way is not None and _building_tag_value(way) is not None \
                        and m.get("ref") not in kept_member_refs:
                    drop.add(f"way/{m.get('ref')}")
        else:
            kept_member_refs.update(m.get("ref") for m in rel.findall("member"))
    return drop


def _overture_tags(rec: dict) -> list[tuple[str, str]]:
    tags = [("building", rec["subtype"] if rec["subtype"] in _BUILDING_VALUES
             else "yes"),
            ("source", "overture-maps")]
    if rec["height"] is not None:
        tags.append(("height", _fmt(rec["height"])))
    if rec["floors"] is not None:
        tags.append(("building:levels", str(int(rec["floors"]))))
    if rec["min_height"] is not None:
        tags.append(("min_height", _fmt(rec["min_height"])))
    if rec["name"]:
        tags.append(("name", rec["name"]))
    return tags


def merge(parquet_dir: Path, osm_path: Path, output: Path | None = None,
          dry_run: bool = False) -> dict:
    stats = {"overture_in": 0, "overture_dropped": 0, "emitted_ways": 0,
             "emitted_relations": 0, "emitted_nodes": 0,
             "osm_buildings_dropped": 0}
    with gzip.open(osm_path, "rb") as f:
        tree = ET.parse(f)
    root = tree.getroot()

    # (lon, lat) — mesma ordem das geometrias Overture (x=lon, y=lat).
    nodes = {n.get("id"): (float(n.get("lon")), float(n.get("lat")))
             for n in root.findall("node")}
    overture = _load_overture(parquet_dir)
    stats["overture_in"] = len(overture)

    all_geoms = [p for r in overture for p in r["parts"]]
    if all_geoms:
        drop = _dedup_osm_buildings(root, nodes, all_geoms)
        stats["osm_buildings_dropped"] = len(drop)
        for kind in ("way", "relation"):
            for el in list(root.findall(kind)):
                if f"{kind}/{el.get('id')}" in drop:
                    root.remove(el)

    max_id = 0
    for kind in ("node", "way", "relation"):
        for el in root.findall(kind):
            try:
                max_id = max(max_id, int(el.get("id")))
            except (TypeError, ValueError):
                pass
    next_id = max_id

    def alloc() -> int:
        nonlocal next_id
        next_id += 1
        return next_id

    # Elementos novos saem agrupados no fim: nodes, depois ways, relations.
    new_nodes: list[ET.Element] = []
    new_ways: list[ET.Element] = []
    new_rels: list[ET.Element] = []

    def emit_way_from_ring(coords) -> ET.Element | None:
        pts = _ring_nodes(coords)
        if len(pts) < 3:
            return None
        refs = []
        for lat, lon in pts:
            nid = str(alloc())
            new_nodes.append(ET.Element("node", {"id": nid, "lat": f"{lat}",
                                                 "lon": f"{lon}"}))
            refs.append(nid)
        refs.append(refs[0])  # way fechado: último nd == primeiro
        way = ET.Element("way", {"id": str(alloc())})
        for ref in refs:
            way.append(ET.Element("nd", {"ref": ref}))
        new_ways.append(way)
        return way

    for rec in overture:
        outers: list[ET.Element] = []
        inners: list[ET.Element] = []
        for part in rec["parts"]:
            way = emit_way_from_ring(part.exterior.coords)
            if way is None:
                continue
            outers.append(way)
            for interior in part.interiors:
                hole = emit_way_from_ring(interior.coords)
                if hole is not None:
                    inners.append(hole)
        if not outers:
            stats["overture_dropped"] += 1
            continue
        tags = _overture_tags(rec)
        simple = len(outers) == 1 and not inners
        if simple:
            for k, v in tags:
                outers[0].append(ET.Element("tag", {"k": k, "v": v}))
            stats["emitted_ways"] += 1
        else:
            rel = ET.Element("relation", {"id": str(alloc())})
            for role, ways in (("outer", outers), ("inner", inners)):
                for way in ways:
                    rel.append(ET.Element("member", {
                        "type": "way", "ref": way.get("id"), "role": role}))
            for k, v in [("type", "multipolygon")] + tags:
                rel.append(ET.Element("tag", {"k": k, "v": v}))
            new_rels.append(rel)
            stats["emitted_ways"] += len(outers) + len(inners)
            stats["emitted_relations"] += 1

    stats["emitted_nodes"] = len(new_nodes)
    root.extend(new_nodes)
    root.extend(new_ways)
    root.extend(new_rels)

    if not dry_run:
        out = output or osm_path
        out.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=out.parent, suffix=".osm.gz")
        try:
            with os.fdopen(fd, "wb") as raw:
                with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as gz:
                    tree.write(gz, encoding="utf-8", xml_declaration=True)
            os.replace(tmp, out)
        except BaseException:
            os.unlink(tmp)
            raise
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--parquet-dir", type=Path,
                    default=Path("~/dados-overture/edificios").expanduser())
    ap.add_argument("--osm", type=Path,
                    default=Path("assets/map/osm/regiao.osm.gz"))
    ap.add_argument("--output", type=Path, default=None,
                    help="saída alternativa (padrão: reescreve --osm)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if not args.parquet_dir.is_dir():
        print(f"erro: {args.parquet_dir} não existe", file=sys.stderr)
        return 2
    stats = merge(args.parquet_dir, args.osm, args.output, args.dry_run)
    for k, v in stats.items():
        print(f"{k}: {v}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
