#!/usr/bin/env python3
"""Gliederung einer GDScript-Datei: Signale, Konstanten, Variablen und Funktionen mit Zeilennummern.

Gedacht für Claude: statt game.gd (1800 Zeilen) ganz zu lesen, erst die Gliederung holen
und dann nur die gebrauchten Zeilen lesen (Read mit offset/limit, sed -n 'a,bp').

Aufruf:
  python3 tools/gliederung.py scripts/game/game.gd              Funktionen mit Zeilen und Kurzbeschreibung
  python3 tools/gliederung.py scripts/game/game.gd --alles      dazu Variablen und Konstanten
  python3 tools/gliederung.py scripts/game/game.gd --suche=gold  nur Funktionen, in denen "gold" vorkommt, mit Trefferzeilen
  python3 tools/gliederung.py scripts/game/game.gd --funktion=_execute   genau diese Funktion ausgeben
  python3 tools/gliederung.py scripts/ --suche=submit           mehrere Dateien (Ordner werden durchsucht)
"""
import re
import signal
import sys
from pathlib import Path

FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*\((.*)")
TOP = re.compile(r"^(signal|const|enum|class_name|extends|class|@export\S*\s+var|@onready\s+var|var)\b\s*(\w*)")


def parse(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    items, doc = [], []
    for i, line in enumerate(lines, 1):
        if line.startswith("##"):
            doc.append(line.lstrip("#").strip())
            continue
        m = FUNC.match(line)
        if m:
            sig = m.group(3).split(")")[0]
            ret = re.search(r"\)\s*->\s*([\w\[\]\.]+)", line)
            items.append({"kind": "func", "name": m.group(2), "start": i, "sig": sig,
                          "ret": ret.group(1) if ret else "", "doc": doc[0] if doc else ""})
        else:
            t = TOP.match(line)
            if t and not line.startswith(("\t", " ")):
                kind = t.group(1).split()[-1] if t.group(1).startswith("@") else t.group(1)
                items.append({"kind": kind, "name": t.group(2) or line.split()[-1], "start": i,
                              "line": line.strip(), "doc": doc[0] if doc else ""})
        if line.strip():
            doc = []
    # Ende jeder Funktion: bis zur nächsten Zeile auf oberster Ebene (Kommentare/Leerzeilen davor abziehen)
    funcs = [it for it in items if it["kind"] == "func"]
    for it in funcs:
        end = len(lines)
        for j in range(it["start"], len(lines)):
            s = lines[j]
            if s and not s.startswith(("\t", " ", "#")):
                end = j
                break
        while end > it["start"] and (not lines[end - 1].strip() or lines[end - 1].startswith("#")):
            end -= 1
        it["end"] = end
    return lines, items


def show(path, args):
    lines, items = parse(path)
    funcs = [it for it in items if it["kind"] == "func"]
    if args.get("funktion"):
        for it in funcs:
            if it["name"] == args["funktion"]:
                print(f"# {path}:{it['start']}-{it['end']}")
                for n in range(it["start"], it["end"] + 1):
                    print(f"{n:5}  {lines[n - 1]}")
                return True
        return False
    word = args.get("suche", "").lower()
    if word:
        hits = []
        for it in funcs:
            rows = [n for n in range(it["start"], it["end"] + 1) if word in lines[n - 1].lower()]
            if rows:
                hits.append((it, rows))
        if not hits:
            return False
        print(f"# {path} ({len(lines)} Zeilen)")
        for it, rows in hits:
            print(f"{it['start']:5}-{it['end']:<5} {it['name']}({it['sig']})")
            for n in rows[:6]:
                print(f"{n:9}  {lines[n - 1].strip()[:110]}")
            if len(rows) > 6:
                print(f"{'':9}  … {len(rows) - 6} weitere")
        return True
    print(f"# {path} ({len(lines)} Zeilen, {len(funcs)} Funktionen)")
    for it in items:
        if it["kind"] == "func":
            ret = f" -> {it['ret']}" if it["ret"] else ""
            doc = f"  ## {it['doc'][:70]}" if it["doc"] else ""
            print(f"{it['start']:5}-{it['end']:<5} {it['name']}({it['sig'][:60]}){ret}{doc}")
        elif it["kind"] in ("extends", "class_name", "signal", "class", "enum") or args.get("alles"):
            print(f"{it['start']:5}       {it['line'][:100]}")
    return True


def main():
    if hasattr(signal, "SIGPIPE"):
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # | head soll nicht mit Traceback enden
    paths, args = [], {}
    for a in sys.argv[1:]:
        if a.startswith("--"):
            k, _, v = a[2:].partition("=")
            args[k] = v or True
        else:
            paths.append(Path(a))
    if not paths:
        print(__doc__)
        return 2
    files = []
    for p in paths:
        files += sorted(p.rglob("*.gd")) if p.is_dir() else [p]
    found = False
    for f in files:
        found = show(f, args) or found
    if not found:
        print("Nichts gefunden.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
