from __future__ import annotations

import gzip
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pyarrow as pa
import pyarrow.parquet as pq
from shapely.geometry import Polygon
from shapely import wkb as shapely_wkb

import overture_to_osm as merger  # noqa: E402

# Dentro da faixa regional (-49.975, -22.245, -49.634, -22.200).
REGION = merger.REGION


def _b(square, hole=False):
    lon, lat = square
    poly = Polygon(
        [(lon, lat), (lon + 0.0005, lat), (lon + 0.0005, lat + 0.0005), (lon, lat + 0.0005)],
        holes=[[(lon + 0.0001, lat + 0.0001), (lon + 0.0002, lat + 0.0001),
                (lon + 0.0002, lat + 0.0002), (lon + 0.0001, lat + 0.0001)]]
        if hole else None,
    )
    return poly.wkb


def _write_parquet(path: Path, rows) -> None:
    table = pa.table({
        "id": [r["id"] for r in rows],
        "names": [{"primary": r.get("name")} for r in rows],
        "height": [r.get("height") for r in rows],
        "min_height": [r.get("min_height") for r in rows],
        "is_underground": [r.get("is_underground", False) for r in rows],
        "num_floors": [r.get("num_floors") for r in rows],
        "subtype": [r.get("subtype") for r in rows],
        "geometry": [_b((r["lon"], r["lat"]), r.get("hole", False)) for r in rows],
    })
    pq.write_table(table, path)


def _write_osm(path: Path) -> None:
    # 2 prédios OSM: um sobreposto ao Overture "a" (deve cair), um isolado
    # (fica). Way 900 é o outer de um multipolygon prédio sobre o Overture
    # "b" (relation cai junto). LATs precisam ficar dentro da faixa
    # regional (sul=-22.245 .. norte=-22.200, só 0.045° de altura).
    xml = f"""<osm version="0.6">
    <node id="1" lat="{REGION[1] + 0.02}" lon="{REGION[0] + 0.05}"/>
    <node id="2" lat="{REGION[1] + 0.02}" lon="{REGION[0] + 0.0505}"/>
    <node id="3" lat="{REGION[1] + 0.0205}" lon="{REGION[0] + 0.0505}"/>
    <node id="4" lat="{REGION[1] + 0.0205}" lon="{REGION[0] + 0.05}"/>
    <node id="5" lat="{REGION[1] + 0.035}" lon="{REGION[0] + 0.1}"/>
    <node id="6" lat="{REGION[1] + 0.035}" lon="{REGION[0] + 0.1005}"/>
    <node id="7" lat="{REGION[1] + 0.0355}" lon="{REGION[0] + 0.1005}"/>
    <node id="8" lat="{REGION[1] + 0.0355}" lon="{REGION[0] + 0.1}"/>
    <node id="11" lat="{REGION[1] + 0.005}" lon="{REGION[0] + 0.01}"/>
    <node id="12" lat="{REGION[1] + 0.005}" lon="{REGION[0] + 0.0105}"/>
    <node id="13" lat="{REGION[1] + 0.0055}" lon="{REGION[0] + 0.0105}"/>
    <node id="14" lat="{REGION[1] + 0.0055}" lon="{REGION[0] + 0.01}"/>
    <way id="900">
      <nd ref="11"/><nd ref="12"/><nd ref="13"/><nd ref="14"/><nd ref="11"/>
      <tag k="building" v="yes"/>
    </way>
    <way id="901">
      <nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/><nd ref="1"/>
      <tag k="building" v="house"/>
    </way>
    <way id="902">
      <nd ref="5"/><nd ref="6"/><nd ref="7"/><nd ref="8"/><nd ref="5"/>
      <tag k="building" v="yes"/>
    </way>
    <relation id="950">
      <member type="way" ref="900" role="outer"/>
      <tag k="type" v="multipolygon"/>
      <tag k="building" v="yes"/>
    </relation>
    </osm>"""
    path.write_bytes(gzip.compress(xml.encode()))


def _tags(el) -> dict:
    return {t.get("k"): t.get("v") for t in el.findall("tag")}


class OvertureMergeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.parquet_dir = self.dir / "parquet"
        self.parquet_dir.mkdir()
        # "a" sobrepõe o way 901; "b" sobrepõe o outer 900 (relation 950);
        # "c" com pátio; "d" fora da região (excluído); "e" subterrâneo.
        base = (REGION[0] + 0.05, REGION[1] + 0.02)
        _write_parquet(self.parquet_dir / "x.parquet", [
            {"id": "a", "lon": base[0], "lat": base[1], "height": 12.5,
             "num_floors": 4, "subtype": "commercial", "name": "Loja A"},
            {"id": "b", "lon": REGION[0] + 0.01, "lat": REGION[1] + 0.005},
            {"id": "c", "lon": REGION[0] + 0.2, "lat": REGION[1] + 0.01,
             "hole": True, "min_height": 3.0},
            {"id": "d", "lon": REGION[0] - 0.01, "lat": REGION[1] + 0.01},
            {"id": "e", "lon": REGION[0] + 0.3, "lat": REGION[1] + 0.01,
             "is_underground": True},
        ])
        self.osm = self.dir / "regiao.osm.gz"
        _write_osm(self.osm)
        self.out = self.dir / "merged.osm.gz"
        self.stats = merger.merge(self.parquet_dir, self.osm, self.out)
        with gzip.open(self.out, "rb") as f:
            self.root = ET.parse(f).getroot()

    def tearDown(self):
        self.tmp.cleanup()

    def test_filters_and_counts(self):
        # d (fora da região) e e (subterrâneo) ficam de fora.
        self.assertEqual(self.stats["overture_in"], 3)
        self.assertEqual(self.stats["overture_dropped"], 0)

    def test_dedup_prefers_overture(self):
        way_ids = {w.get("id") for w in self.root.findall("way")}
        rel_ids = {r.get("id") for r in self.root.findall("relation")}
        self.assertNotIn("901", way_ids, "prédio OSM coberto por Overture cai")
        self.assertNotIn("900", way_ids, "outer do multipolygon coberto cai")
        self.assertNotIn("950", rel_ids, "relation coberta cai")
        self.assertIn("902", way_ids, "prédio OSM isolado fica")
        self.assertGreaterEqual(self.stats["osm_buildings_dropped"], 3)

    def test_tags_and_positive_ids_above_max(self):
        new_ways = [w for w in self.root.findall("way")
                    if _tags(w).get("source") == "overture-maps"]
        self.assertTrue(new_ways)
        a = next(w for w in new_ways if _tags(w).get("building") == "commercial")
        self.assertEqual(_tags(a)["height"], "12.5")
        self.assertEqual(_tags(a)["building:levels"], "4")
        self.assertEqual(_tags(a)["name"], "Loja A")
        for el in self.root.findall("node") + self.root.findall("way"):
            self.assertGreater(int(el.get("id")), 0, "leitor rejeita id negativo")

    def test_courtyard_becomes_multipolygon(self):
        overture_rels = [r for r in self.root.findall("relation")
                         if _tags(r).get("source") == "overture-maps"]
        self.assertEqual(len(overture_rels), 1)
        rel = overture_rels[0]
        roles = [m.get("role") for m in rel.findall("member")]
        self.assertEqual(sorted(roles), ["inner", "outer"])
        tags = _tags(rel)
        self.assertEqual(tags["type"], "multipolygon")
        self.assertEqual(tags["min_height"], "3")

    def test_roundtrip_readable_geometry(self):
        # Nodes novos com coords válidas e ways fechados. Regressão
        # lat/lon: shapely é (x=lon, y=lat) — invertê-los joga os prédios
        # a milhares de km e explode a grade de tiles do motor.
        overture_way_ids = {
            w.get("id") for w in self.root.findall("way")
            if _tags(w).get("source") == "overture-maps"
        }
        for rel in self.root.findall("relation"):
            if _tags(rel).get("source") == "overture-maps":
                overture_way_ids.update(
                    m.get("ref") for m in rel.findall("member"))
        for way in self.root.findall("way"):
            if way.get("id") not in overture_way_ids:
                continue
            refs = [nd.get("ref") for nd in way.findall("nd")]
            self.assertEqual(refs[0], refs[-1], "way Overture fechado")
        self.assertTrue(overture_way_ids)
        for node in self.root.findall("node"):
            nid = node.get("id")
            if nid is None or int(nid) <= 14:
                continue
            lat = float(node.get("lat"))
            lon = float(node.get("lon"))
            self.assertTrue(
                REGION[1] <= lat <= REGION[3] and REGION[0] <= lon <= REGION[2],
                f"node {nid} fora da faixa: lat={lat} lon={lon} (lat/lon trocados?)",
            )


if __name__ == "__main__":
    unittest.main()
