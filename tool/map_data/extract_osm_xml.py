#!/usr/bin/env python3
"""Extrai .osm.gz reais (XML OSM) por bbox do PBF local do sudeste.

Dados © OpenStreetMap contributors. Sem download: usa o PBF já presente em
tool/map_data/raw/. Saída: assets/map/osm/<city>.osm.gz.
"""
import osmium

PBF = "tool/map_data/raw/sudeste-latest.osm.pbf"

CITIES = {
    "marilia": (-49.975, -22.235, -49.925, -22.200),
    "vera-cruz": (-49.849, -22.236, -49.799, -22.206),
    "garca": (-49.684, -22.245, -49.634, -22.210),
}


def in_box(lon, lat, box):
    return box[0] <= lon <= box[2] and box[1] <= lat <= box[3]


def extract(name, box):
    # Passo 1: ways que tocam a box, ids dos nós necessários e ids de
    # nós com tags dentro da box (semáforos, travessias isoladas…).
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

    print(f"{name}: {len(way_ids)} ways, {len(tagged_node_ids)} tagged nodes",
          flush=True)

    # Passo 2: escreve nós necessários/tagged, ways incluídos e relations
    # multipolygon com membros incluídos.
    rel_count = 0
    with osmium.SimpleWriter(f"assets/map/osm/{name}.osm.gz") as w:
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
    print(f"{name}: done, {rel_count} relations", flush=True)


def main():
    for name, box in CITIES.items():
        extract(name, box)


if __name__ == "__main__":
    main()
