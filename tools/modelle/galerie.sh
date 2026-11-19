#!/usr/bin/env bash
# Bollwerk-Gegner-Galerie rendern (vorn-oben, Spielbeleuchtung, HdStoffe). Gibt nur die Bildzeile aus.
#   tools/modelle/galerie.sh [--ids=a,b] [--name=x] [--spalten=6]
set -uo pipefail
cd "$(dirname "$0")/../.."
export PATH="$HOME/.local/bin:$PATH"
tools/godot_import.sh /tmp/galerie-import.log
xvfb-run -a -s "-screen 0 1800x1400x24" godot --rendering-driver opengl3 --path . res://tools/modelle/gegner_galerie.tscn -- "$@" \
  > /tmp/galerie.log 2>&1
grep -E "^BILD|SCRIPT ERROR|ERROR:" /tmp/galerie.log | head -8
# Mit --bilder=N zusätzlich eine GIF-Animation (Wabbeln prüfen)
for a in "$@"; do
  case "$a" in --bilder=*) N=${a#--bilder=};; --name=*) NAME=${a#--name=};; esac
done
if [ -n "${N:-}" ]; then
  python3 - "${NAME:-gegner}" <<'P'
import sys, glob
from PIL import Image
n = sys.argv[1]
fs = sorted(glob.glob(f'.godot/galerie-{n}-[0-9][0-9].png'))
ims = [Image.open(f).convert('RGB') for f in fs]
w = 900
ims = [i.resize((w, int(i.height * w / i.width))) for i in ims]
ims[0].save(f'.godot/galerie-{n}.gif', save_all=True, append_images=ims[1:], duration=100, loop=0)
print('GIF', f'.godot/galerie-{n}.gif', len(ims))
P
fi
