#!/usr/bin/env python3
"""Extrai o `.osm.gz` único da região (assets/map/osm/regiao.osm.gz) do PBF
local do sudeste.

Dados © OpenStreetMap contributors. Sem download: usa o PBF já presente em
tool/map_data/raw/. O bbox cobre as três cidades do catálogo regional
(Marília-SP, Vera Cruz-SP e Garça-SP) e o corredor entre elas — um único
arquivo carrega as três juntas (ver lib/engine/region/region_catalog.dart).
"""
import osmium

PBF = "tool/map_data/raw/sudeste-latest.osm.pbf"

# União das caixas urbanas do catálogo + corredor (Marília oeste → Garça leste).
REGION = (-49.975, -22.245, -49.634, -22.200)
OUT = "assets/map/osm/regiao.osm.gz"


def in_box(lon, lat, box):
    return box[0] <= lon <= box[2] and box[1] <= lat <= box[3]


def extract(box):
    # Passo 1: ways que tocam o bbox, ids dos nós necessários e ids de nós
    # com tags dentro do bbox (semáforos, travessias isoladas…).
    way_ids = set()
    needed_nodes = set()
    tagged_node_ids = set()
    for obj in osmium.FileProcessor(PBF).with_locations():
        if isinstance(obj, osmium.osm.Node):
            if obj.tags and in_box(obj.location.lon, obj.location.lat, box):
                tagged_node_ids.add(obj.id)
        elif isinstance(obj, osmium.osm.Way):
            pts = [(n.location.lon, n.location.lat) for n in obj.nodes]
            if any(in_box(lon, lat, box) for lon, lat in pts):
                way_ids.add(obj.id)
                needed_nodes.update(n.ref for n in obj.nodes)

    print(f"regiao: {len(way_ids)} ways, {len(tagged_node_ids)} tagged nodes",
          flush=True)

    # Passo 2: escreve nós necessários/tagged, ways incluídos e relations
    # multipolygon com membros incluídos.
    rel_count = 0
    with osmium.SimpleWriter(OUT) as w:
        for obj in osmium.FileProcessor(PBF).with_locations():
            if isinstance(obj, osmium.osm.Node):
                if obj.id in needed_nodes or obj.id in tagged_node_ids:
                    w.add_node(obj)
            elif isinstance(obj, osmium.osm.Way):
                if obj.id in way_ids:
                    w.add_way(obj)
            elif isinstance(obj, osmium.osm.Relation):
                if any(m.type == "w" and m.ref in way_ids for m in obj.members):
                    rel_count += 1
                    w.add_relation(obj)
    print(f"regiao: done, {rel_count} relations", flush=True)


def main():
    extract(REGION)


if __name__ == "__main__":
    main()
