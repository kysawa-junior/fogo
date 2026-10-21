#!/usr/bin/env bash
# Validação visual ISOLADA do F.O.G.O. em display virtual (Xvfb).
# Uso: ./validate_visual.sh <lat> <lng> <zoom> <tag>
set -euo pipefail
cd "$(dirname "$0")/.."

LAT=${1:?lat}; LNG=${2:?lng}; ZOOM=${3:?zoom}; TAG=${4:?tag}
P="$HOME/.local/share/com.instrum.fogo.fogo/shared_preferences.json"

export DISPLAY=:99
pkill -f "Xvfb :99" 2>/dev/null || true; sleep 0.5
Xvfb :99 -screen 0 1440x900x24 -nolisten tcp &
XVFB_PID=$!
trap 'kill $XVFB_PID 2>/dev/null || true' EXIT
sleep 1.5

mkdir -p "$(dirname "$P")"
printf '{"flutter.fogo.camera.lat":%s,"flutter.fogo.camera.lng":%s,"flutter.fogo.camera.zoom":%s}' \
  "$LAT" "$LNG" "$ZOOM" > "$P"

GDK_BACKEND=x11 ./build/linux/x64/debug/bundle/fogo > "/tmp/opencode/iso_${TAG}.log" 2>&1 &
APP_PID=$!
sleep 14

WID=$(xwininfo -root -children | grep '"F.O.G.O."' | head -1 | awk '{print $1}')
xwd -id "$WID" -silent > "/tmp/opencode/iso_${TAG}.xwd"

kill $APP_PID 2>/dev/null || true
sleep 0.5
echo "captura: /tmp/opencode/iso_${TAG}.xwd"
