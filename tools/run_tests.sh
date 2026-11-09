#!/usr/bin/env bash
# Führt die Tests aus und gibt nur eine Zusammenfassung aus. Volle Ausgaben liegen in $LOG_DIR.
# Aufruf: tools/run_tests.sh [schnell|alle|<name> ...]
#   schnell (Standard): Prüfskripte (Tower-Tabelle, Texte, Maps, Werkzeuge) und alle Tests unter tests/
#                       außer den langen ("## Lauf: fest": Balance, Tempo, späte Wellen)
#   alle:               dazu die langen
#   geaendert [--basis=REF] [--ohne-fest] [--erklaeren]:
#                       nur die Tests der Modi, deren Dateien sich gegenüber origin/main (oder REF) geändert
#                       haben, plus Prüfskripte; gemeinsamer Code -> schnell. Regeln: tests/bereiche.json,
#                       Modus je Test: "## Modi: …" im Testkopf. Warum welcher Test: --erklaeren
#   <name>:             einzelne Tests, z. B. tools/run_tests.sh smoke koop
# Pro Test eine Zeile mit Dauer. "⚠" darunter = Godot meldet Fehler, obwohl der Test grün ist
# (ERROR/WARNING außerhalb von NOISE/EXPECTED); das sind meist echte, nur unbemerkte Fehler.
# Exit-Code 0 = alles grün.
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"
# Tests prüfen deutsche Texte; das Spiel startet sonst auf Englisch (Loc.DEFAULT)
export GEMTD_SPRACHE="${GEMTD_SPRACHE:-de}"
GODOT="${GODOT:-godot}"
LOG_DIR="${LOG_DIR:-/tmp/gemtd-tests}"
mkdir -p "$LOG_DIR"
command -v "$GODOT" >/dev/null || { echo "Godot fehlt: tools/setup_godot.sh --ohne-vorlage"; exit 2; }

FAILED=0
# Zeilen, die headless immer kommen und nichts bedeuten.
NOISE='Parameter "m" is null|^Godot Engine|^\s*at: |^$'
# Von Tests absichtlich ausgelöst (Smoke: veränderte Spielstand-Datei wird abgelehnt; Boss: fehlendes Gegner-Modell).
EXPECTED='MD5 sum of the decrypted file|Modell nicht gefunden: res://gibt/es/nicht.glb|Profil-Siegel passt nicht|Profil beschädigt, nehme Sicherung'

summary() {  # name log exit start
  local name=$1 log=$2 code=$3 ok fail secs warn
  secs=$(( SECONDS - ${4:-$SECONDS} ))
  ok=$(grep -c '^OK' "$log" 2>/dev/null || true)
  fail=$(grep -cE '^FAIL|SCRIPT ERROR|Parse Error' "$log" 2>/dev/null || true)
  if [ "$code" -eq 0 ] && [ "$fail" -eq 0 ]; then
    printf '✓ %-14s %-12s %3ss\n' "$name" "$( [ "$ok" -gt 0 ] && echo "$ok OK" || tail -n1 "$log")" "$secs"
    warn=$(grep -E '^(ERROR|WARNING|USER ERROR|USER WARNING):' "$log" | grep -vE "$NOISE|$EXPECTED" | sort | uniq -c | sort -rn)
    [ -z "$warn" ] || echo "$warn" | head -n 3 | sed 's/^ */    ⚠ /'
  else
    FAILED=1
    printf '✗ %-14s Exit %s, %s Fehler (mehr: tools/log_auszug.sh %s)\n' "$name" "$code" "$fail" "$name"
    grep -E '^FAIL|SCRIPT ERROR|Parse Error|ERROR' "$log" | grep -vE "$NOISE" | head -n 15 | sed 's/^/    /'
  fi
}

run_one() {  # name scene [args...]
  local name=$1 scene=$2; shift 2
  local log="$LOG_DIR/$name.log"
  local t0=$SECONDS
  timeout 900 "$GODOT" --headless --path . "res://tests/$scene.tscn" "$@" >"$log" 2>&1
  summary "$name" "$log" $? $t0
}

run_fixed() {  # Balance-Tests mit fester Bildrate
  local name=$1 scene=$2; shift 2
  local log="$LOG_DIR/$name.log"
  local t0=$SECONDS
  timeout 1800 "$GODOT" --headless --fixed-fps 60 --path . "res://tests/$scene.tscn" "$@" >"$log" 2>&1
  summary "$name" "$log" $? $t0
}

run_pair() {  # name scene: Host und Client als zwei Prozesse
  local name=$1 scene=$2
  local hl="$LOG_DIR/$name-host.log" cl="$LOG_DIR/$name-client.log" t0=$SECONDS
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=host >"$hl" 2>&1 &
  local hp=$!
  sleep 1
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=client >"$cl" 2>&1
  local cc=$?
  wait $hp; local hc=$?
  cat "$hl" "$cl" > "$LOG_DIR/$name.log"
  summary "$name" "$LOG_DIR/$name.log" $(( hc != 0 ? hc : cc )) $t0
}

run_trio() {  # name scene: Host und zwei Mitspieler (a, b) als drei Prozesse
  local name=$1 scene=$2
  local hl="$LOG_DIR/$name-host.log" al="$LOG_DIR/$name-a.log" bl="$LOG_DIR/$name-b.log" t0=$SECONDS
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=host >"$hl" 2>&1 &
  local hp=$!
  sleep 1
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=a >"$al" 2>&1 &
  local ap=$!
  timeout 600 "$GODOT" --headless --path . "res://tests/$scene.tscn" -- --role=b >"$bl" 2>&1
  local bc=$?
  wait $ap; local ac=$?
  wait $hp; local hc=$?
  cat "$hl" "$al" "$bl" > "$LOG_DIR/$name.log"
  summary "$name" "$LOG_DIR/$name.log" $(( hc != 0 ? hc : (ac != 0 ? ac : bc) )) $t0
}

run_check() {  # name command...
  local name=$1; shift
  local log="$LOG_DIR/$name.log"
  "$@" >"$log" 2>&1
  local code=$?
  if [ $code -eq 0 ]; then printf '✓ %-14s %s\n' "$name" "$(tail -n1 "$log")"
  else FAILED=1; printf '✗ %-14s\n' "$name"; head -n 15 "$log" | sed 's/^/    /'; fi
}

check_tools() {  # Python- und Shell-Werkzeuge unter tools/ auf Syntaxfehler prüfen (ohne __pycache__ zu schreiben)
  local py sh bad=0
  py=$(git ls-files 'tools/*.py' '.claude/hooks/*.py'); sh=$(git ls-files 'tools/*.sh' '.claude/hooks/*.sh'; git ls-files tools/git-hooks/ | grep -v '\.py$')
  python3 -c 'import ast, sys
for f in sys.argv[1:]: ast.parse(open(f, encoding="utf-8").read(), f)' $py || bad=1
  for f in $sh; do bash -n "$f" || bad=1; done
  [ $bad -eq 0 ] && echo "Werkzeuge: $(echo $py | wc -w) Python, $(echo $sh | wc -w) Shell ohne Syntaxfehler"
  return $bad
}

# Tests finden sich selbst: jede tests/<stamm>_test.tscn ist ein Test (auch in Unterordnern, z. B. tests/systems/). Die zweite Zeile der .gd sagt, wie er läuft:
#   ## Lauf: einzeln|paar|trio|fest [Argumente] [(Name kurzname)]
# paar = Host + Client, trio = Host + a + b, fest = feste Bildrate, nur in "alle". Ohne Zeile: einzeln.
# Ein neuer Test braucht also keinen Eintrag hier.
test_info() {  # stamm -> ART ARGS NAME
  local line
  line=$(sed -n '2,6{s/^## Lauf: *//p}' "tests/$1_test.gd" 2>/dev/null | head -n1)
  NAME=${1##*/}
  if [[ $line =~ \(Name\ ([a-z_]+)\) ]]; then NAME=${BASH_REMATCH[1]}; line=${line%%(*}; fi
  read -r ART ARGS <<<"${line:-einzeln}"
}

test_files() { find tests -name '*_test.tscn' | sort; }

all_tests() {  # Kurznamen aller Tests; $1 = "ohne_fest" lässt die langen Balance-Läufe weg
  local f stem
  for f in $(test_files); do
    stem=${f#tests/}; stem=${stem%_test.tscn}; test_info "$stem"
    [ "${1:-}" = ohne_fest ] && [ "$ART" = fest ] && continue
    echo "$NAME"
  done
}

resolve() {  # Kurzname oder Stamm -> STEM (leer, wenn unbekannt)
  local f stem
  STEM=""
  for f in $(test_files); do
    stem=${f#tests/}; stem=${stem%_test.tscn}; test_info "$stem"
    if [ "$1" = "$stem" ] || [ "$1" = "$NAME" ]; then STEM=$stem; return; fi
  done
}

do_test() {
  case $1 in
    tabelle) run_check tabelle python3 tools/tower_tabelle.py --pruefen ;;
    ui)      run_check ui python3 tools/pruefe_ui.py ;;
    maps)    run_check maps python3 tools/map_check.py --kurz ;;
    marken)  run_check marken python3 tools/wc3/maul_namen.py --pruefe ;;
    werkzeuge) run_check werkzeuge check_tools ;;
    auswahl) run_check auswahl python3 tools/test_auswahl.py --pruefen ;;
    systeme_pruefen) run_check systeme_pruefen python3 tools/systeme.py pruefen ;;
    balanceeditor) run_check balanceeditor node tools/balance_editor/pruefen.mjs ;;
    htmleditor) run_check htmleditor node tools/html_editor/pruefen.mjs ;;
    *)
      resolve "$1"
      [ -n "$STEM" ] || { echo "Unbekannter Test: $1 (vorhanden: $(all_tests | tr '\n' ' '))"; FAILED=1; return; }
      test_info "$STEM"
      # shellcheck disable=SC2086
      case $ART in
        paar) run_pair "$NAME" "${STEM}_test" ;;
        trio) run_trio "$NAME" "${STEM}_test" ;;
        fest) if [ -n "$ARGS" ]; then run_fixed "$NAME" "${STEM}_test" -- $ARGS; else run_fixed "$NAME" "${STEM}_test"; fi ;;
        *)    if [ -n "$ARGS" ]; then run_one "$NAME" "${STEM}_test" -- $ARGS; else run_one "$NAME" "${STEM}_test"; fi ;;
      esac ;;
  esac
}

tools/godot_import.sh "$LOG_DIR/import.log"

MODE=${1:-schnell}
if [ "$MODE" = geaendert ]; then
  # Zuordnung Dateien -> Modi -> Tests: tests/bereiche.json und "## Modi:" im Testkopf (tools/test_auswahl.py)
  shift
  MODE=$(python3 tools/test_auswahl.py "$@") || { echo "Testauswahl fehlgeschlagen"; exit 2; }
  echo "Geänderte Dateien -> Tests: $MODE"
  # shellcheck disable=SC2086
  set -- $MODE
fi
case $MODE in
  # shellcheck disable=SC2046
  schnell) set -- tabelle ui maps marken werkzeuge auswahl systeme_pruefen $(all_tests ohne_fest) ;;
  # shellcheck disable=SC2046
  alle)    set -- tabelle ui maps marken werkzeuge auswahl systeme_pruefen $(all_tests) ;;
esac
# Prüfskripte, Smoke und die Host/Client-Paare (eigene Ports) laufen parallel, Balance-Läufe danach einzeln.
PAR=(); SEQ=(); declare -A WEIGHT
for t in "$@"; do
  resolve "$t"; ART=""; [ -z "$STEM" ] || test_info "$STEM"
  if [ "$ART" = fest ]; then SEQ+=("$t"); else PAR+=("$t"); fi
  case $ART in paar) WEIGHT[$t]=2 ;; trio) WEIGHT[$t]=3 ;; *) WEIGHT[$t]=1 ;; esac
done
# Höchstens JOBS Godot-Prozesse gleichzeitig (Standard: Anzahl Kerne; ein Paar zählt 2, ein Trio 3): bei
# Überlast verpasst der Netz-Test Meldungen und misst scheinbare Korrektursprünge. Die längsten zuerst,
# damit sie nicht am Ende allein laufen.
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}
ORDER=()
for t in smoke maul eeve koop netz sitzung gemischt; do [[ " ${PAR[*]} " == *" $t "* ]] && ORDER+=("$t"); done
for t in "${PAR[@]}"; do [[ " ${ORDER[*]} " == *" $t "* ]] || ORDER+=("$t"); done
declare -A RUNNING  # pid -> Gewicht
busy() {  # Summe der Gewichte noch laufender Tests
  local pid n=0
  for pid in "${!RUNNING[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then n=$((n + RUNNING[$pid])); else unset "RUNNING[$pid]"; fi
  done
  echo $n
}
for t in "${ORDER[@]}"; do
  w=${WEIGHT[$t]:-1}; [ "$w" -gt "$JOBS" ] && w=$JOBS
  while [ "$(busy)" -gt $((JOBS - w)) ]; do wait -n; done
  ( FAILED=0; do_test "$t" > "$LOG_DIR/$t.sum"; echo $FAILED > "$LOG_DIR/$t.rc" ) &
  RUNNING[$!]=$w
done
wait
for t in "${PAR[@]}"; do
  cat "$LOG_DIR/$t.sum"
  [ "$(cat "$LOG_DIR/$t.rc")" = 0 ] || FAILED=1
done
for t in "${SEQ[@]}"; do do_test "$t"; done
echo "Gesamt: ${SECONDS}s"
exit $FAILED
