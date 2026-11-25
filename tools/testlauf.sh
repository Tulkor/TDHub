#!/usr/bin/env bash
# Automatische Testläufe: Bots spielen ganze Partien (tools/testlauf/), mehrere parallel.
# Aufruf: tools/testlauf.sh <modus|alle> [--stufen=1,2,3,4] [--seeds=1,2,3] [--schwierigkeiten=einfach,mittel,schwer]
#   [--aufstiege=0,5] [--jobs=3] [--tempo=4] [--extra="--rasse=punks"] [--aus=datei.jsonl]
# Modi: gemtd eevetd shoppingmaul randgruppen youtd. Standard: nur Mittel ohne Aufstieg. Aufstieg gilt nur auf Schwer.
# Logs unter /tmp/gemtd-testlauf/, Ergebnisse als JSON-Zeilen in /tmp/gemtd-testlauf/ergebnisse.jsonl (wird ergänzt).
# Auswertung: python3 tools/testlauf/auswerten.py [ergebnisse.jsonl] [--md=bericht.md] [--matrix]
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
MODUS="${1:-}"; shift || true
STUFEN="1,2,3,4"; SEEDS="1,2,3"; JOBS=3; TEMPO=4; EXTRA=""; DIFFS="mittel"; ASCS="0"
OUT=/tmp/gemtd-testlauf; AUS="$OUT/ergebnisse.jsonl"
for a in "$@"; do
	case "$a" in
		--stufen=*) STUFEN="${a#*=}" ;;
		--seeds=*) SEEDS="${a#*=}" ;;
		--jobs=*) JOBS="${a#*=}" ;;
		--tempo=*) TEMPO="${a#*=}" ;;
		--extra=*) EXTRA="${a#*=}" ;;
		--schwierigkeiten=*) DIFFS="${a#*=}" ;;
		--aufstiege=*) ASCS="${a#*=}" ;;
		--aus=*) AUS="${a#*=}" ;;
	esac
done
[ -z "$MODUS" ] && { sed -n 2,6p "$0"; exit 1; }
[ "$MODUS" = alle ] && MODUS="gemtd eevetd shoppingmaul randgruppen youtd"
mkdir -p "$OUT"
tools/godot_import.sh >/dev/null 2>&1
lauf() {
	local m=$1 s=$2 sd=$3 df=$4 as=$5 tag="$1_$2_$3_$4_$5${EXTRA:+_$(echo "$EXTRA" | tr -cd 'a-z0-9')}"
	timeout 5400 godot --headless --fixed-fps 60 --path . res://tools/testlauf/testlauf.tscn -- \
		--modus="$m" --stufe="$s" --seed="$sd" --tempo="$TEMPO" --schwierigkeit="$df" --aufstieg="$as" $EXTRA \
		> "$OUT/$tag.log" 2>&1
	local r; r=$(grep -m1 '^ERGEBNIS ' "$OUT/$tag.log" | sed 's/^ERGEBNIS //')
	if [ -n "$r" ]; then
		echo "$r" >> "$AUS"
		python3 -c "import json,sys;d=json.loads(sys.argv[1]);a=d.get('aufstieg',0);print('%-12s %-7s Stufe %d Seed %d: %s Welle %d/%d, Leben %s, %ds' % (d['modus'],d.get('schwierigkeit','mittel')+(' +%d' % a if a else ''),d['stufe'],d['seed'],'SIEG' if d['sieg'] else 'verloren',d['welle'],d['wellen'],round(float(d['leben'])),d['echtzeit_s']))" "$r"
	else
		echo "$tag: kein Ergebnis, Log $OUT/$tag.log"; grep -a -m3 -A1 'SCRIPT ERROR' "$OUT/$tag.log"
	fi
}
export -f lauf; export OUT TEMPO EXTRA AUS
# Kombinationen: Aufstieg > 0 nur auf Schwer (wie im Startfenster), sonst doppelte Läufe
for m in $MODUS; do for df in ${DIFFS//,/ }; do for as in ${ASCS//,/ }; do
	[ "$as" != 0 ] && [ "$df" != schwer ] && [ "$df" != 2 ] && continue
	for s in ${STUFEN//,/ }; do for sd in ${SEEDS//,/ }; do echo "$m $s $sd $df $as"; done; done
done; done; done | xargs -P "$JOBS" -L1 bash -c 'lauf $0 $1 $2 $3 $4'
