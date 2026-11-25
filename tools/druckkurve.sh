#!/usr/bin/env bash
# Druckkurve aller Modi ohne Simulation (tools/testlauf/druck.gd): effektive Gegner-Leben je Welle für jede
# Schwierigkeit und Aufstiegsstufe, in Sekunden statt Minuten. Prüft die Schwierigkeitsleiter und meldet Ausreißer-Wellen.
# Aufruf: tools/druckkurve.sh [modus …|alle] [--aufstiege=5,10] [--jobs=4] [--md=bericht.md] [--html=bericht.html]
# Ausgabe: Tabelle je Modus; Rohdaten /tmp/gemtd-druck/druck.jsonl. Exit 1, wenn eine Stufe nicht schwerer ist als die davor.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
MODI=""; ASCS="5,10"; JOBS=4; REST=()
for a in "$@"; do
	case "$a" in
		--aufstiege=*) ASCS="${a#*=}" ;;
		--jobs=*) JOBS="${a#*=}" ;;
		--*) REST+=("$a") ;;
		alle) MODI="gemtd eevetd shoppingmaul randgruppen youtd" ;;
		*) MODI="$MODI $a" ;;
	esac
done
[ -z "$MODI" ] && MODI="gemtd eevetd shoppingmaul randgruppen youtd"
OUT=/tmp/gemtd-druck; mkdir -p "$OUT"; : > "$OUT/druck.jsonl"
tools/godot_import.sh >/dev/null 2>&1
probe() {
	local log="$OUT/$1_$2_$3.log"
	timeout 600 godot --headless --path . res://tools/testlauf/druck.tscn -- --modus="$1" --schwierigkeit="$2" --aufstieg="$3" \
		> "$log" 2>&1
	grep -a -m1 '^DRUCK ' "$log" | sed 's/^DRUCK //' >> "$OUT/druck.jsonl" || echo "$1 $2 +$3: kein Ergebnis, Log $log"
}
export -f probe; export OUT
for m in $MODI; do
	for d in einfach mittel schwer; do echo "$m $d 0"; done
	for a in ${ASCS//,/ }; do echo "$m schwer $a"; done
done | xargs -P "$JOBS" -L1 bash -c 'probe $0 $1 $2'
python3 tools/testlauf/druck_auswerten.py "$OUT/druck.jsonl" "${REST[@]}"
