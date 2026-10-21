#!/usr/bin/env bash
# F.O.G.O. — Aquisição reproduzível da base cartográfica real.
# Fonte: extrato regional oficial da Geofabrik (OpenStreetMap).
# Nenhuma consulta repetida a servidores públicos durante o uso da app.
set -euo pipefail
cd "$(dirname "$0")/../.."

PBF=tool/map_data/raw/sudeste-latest.osm.pbf
URL="https://download.geofabrik.de/south-america/brazil/sudeste-latest.osm.pbf"

mkdir -p tool/map_data/raw assets/map

if [ ! -f "$PBF" ]; then
  echo "Baixando extrato do OSM (Geofabrik, ~860 MB)…"
  curl -L -C - -o "$PBF" "$URL"
fi

echo "Processando região Marília-SP + Garça-SP…"
python3 tool/map_data/build_map_data.py --pbf "$PBF" --out assets/map

echo "Concluído: assets/map/manifest.json + células."
