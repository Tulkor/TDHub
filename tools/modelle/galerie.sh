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
