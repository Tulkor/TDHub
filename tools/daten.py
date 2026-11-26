#!/usr/bin/env python3
"""Kompakte Abfrage der JSON-Daten unter data/, damit Claude keine großen Dateien ganz lesen muss.

Große Werte (über --max Zeichen, Standard 1500) werden nicht ausgegeben, sondern als Gliederung:
Schlüssel mit Typ und Länge. Dann gezielt mit einem Pfad nachfragen.

Aufruf:
  python3 tools/daten.py tower:ruby                 ein Tower (data/towers/ruby.json)
  python3 tools/daten.py tower:ruby tiers.5         nur Stufe 6 (Pfade mit Punkten, Listen mit Zahlen)
  python3 tools/daten.py gegner:bat                 ein Gegner
  python3 tools/daten.py gegner [--suche=eeve]      alle Gegner als Tabelle (eine Zeile je Gegner)
  python3 tools/daten.py wellen [classic]           alle Wellen mit Gegnerwerten, eine Zeile je Welle
  python3 tools/daten.py map:classic                Map (Kacheln nur als Gliederung)
  python3 tools/daten.py data/maul/shops.json shops.media_markt.towers   beliebige Datei und Pfad (Listeneinträge auch über ihre id)
  python3 tools/daten.py data/maul/shops.json --suche=Rabatt     Pfade, unter denen der Text vorkommt
  --voll  gibt auch große Werte ganz aus, --max=N ändert die Grenze.
"""
import json
import signal
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ALIAS = {"tower": "towers", "gegner": "enemies", "map": "maps", "welle": "waves", "wellen": "waves"}


def compact(v):
    return json.dumps(v, ensure_ascii=False, separators=(",", ":"))


def outline(v, depth=0, maxdepth=2, prefix=""):
    pad = "  " * depth
    if isinstance(v, dict):
        for k, x in v.items():
            s = compact(x)
            if len(s) <= 80 or depth >= maxdepth:
                print(f"{pad}{prefix}{k}: {s if len(s) <= 80 else describe(x)}")
            else:
                print(f"{pad}{prefix}{k}: {describe(x)}")
                outline(x, depth + 1, maxdepth)
    elif isinstance(v, list):
        if v and all(isinstance(x, dict) for x in v):
            keys = {}
            for x in v:
                for k in x:
                    keys[k] = keys.get(k, 0) + 1
            print(f"{pad}[0..{len(v) - 1}] Schlüssel: " + ", ".join(k if n == len(v) else f"{k}({n}×)" for k, n in keys.items()))
            print(f"{pad}[0] = {compact(v[0])[:200]}")
        else:
            print(f"{pad}{compact(v)[:200]}")


def describe(x):
    if isinstance(x, dict):
        return f"{{{len(x)} Schlüssel}}"
    if isinstance(x, list):
        return f"[{len(x)} Einträge]"
    if isinstance(x, str):
        return compact(x[:70]) + f"… ({len(x)} Zeichen)"
    return type(x).__name__


def walk(v, path):
    for part in [p for p in path.split(".") if p]:
        if isinstance(v, list) and part.lstrip("-").isdigit():
            v = v[int(part)]
        elif isinstance(v, list):  # Listen von {id: ...} auch über die id: shops.media_markt
            match = [x for x in v if isinstance(x, dict) and x.get("id") == part]
            if not match:
                raise KeyError(f"keine id '{part}' in der Liste")
            v = match[0]
        elif isinstance(v, dict) and part in v:
            v = v[part]
        elif isinstance(v, dict):
            raise KeyError(f"'{part}' fehlt, vorhanden: {', '.join(list(v)[:30])}")
        else:
            raise KeyError(part)
    return v


def search(v, text, path=""):
    text = text.lower()
    if isinstance(v, dict):
        for k, x in v.items():
            p = f"{path}.{k}" if path else k
            if text in k.lower():
                print(f"{p}: {compact(x)[:120]}")
            elif not isinstance(x, (dict, list)) and text in str(x).lower():
                print(f"{p}: {compact(x)[:120]}")
            else:
                search(x, text, p)
    elif isinstance(v, list):
        for i, x in enumerate(v):
            p = f"{path}.{i}" if path else str(i)
            if not isinstance(x, (dict, list)) and text in str(x).lower():
                print(f"{p}: {compact(x)[:120]}")
            else:
                search(x, text, p)


def enemies():
    return {p.stem: json.loads(p.read_text(encoding="utf-8")) for p in sorted((ROOT / "data/enemies").glob("*.json"))}


def table_enemies(filt):
    print("id | name | hp | speed | armor | armor_type | bounty | dmg | flags")
    for k, e in enemies().items():
        line = f"{k} | {e.get('name','')} | {e.get('hp')} | {e.get('speed')} | {e.get('armor')} | {e.get('armor_type','')} | {e.get('bounty')} | {e.get('damage')}"
        flags = [f for f in ("flying", "boss", "invisible") if e.get(f)]
        extra = sorted(set(e) - {"id", "name", "hp", "speed", "armor", "armor_type", "bounty", "damage", "flying", "boss", "invisible", "color", "size", "model"})
        line += " | " + " ".join(flags + [f"{x}={compact(e[x])[:40]}" for x in extra])
        if not filt or filt.lower() in line.lower():
            print(line)


def table_waves(name):
    data = json.loads((ROOT / f"data/waves/{name}.json").read_text(encoding="utf-8"))
    en = enemies()
    for i, w in enumerate(data["waves"], 1):
        parts = []
        for g in w.get("groups", []):
            e = en.get(g.get("enemy"), {})
            fl = " Luft" if e.get("flying") else ""
            parts.append(f"{g.get('count')}× {g.get('enemy')} (hp {e.get('hp')}, rü {e.get('armor')}, v {e.get('speed')}{fl})")
        rest = {k: v for k, v in w.items() if k != "groups"}
        print(f"{i:3}: " + " + ".join(parts) + (f"  {compact(rest)}" if rest else ""))


def resolve(arg):
    if ":" in arg and not Path(arg).exists():
        kind, _, ident = arg.partition(":")
        return ROOT / "data" / ALIAS.get(kind, kind) / f"{ident}.json"
    p = Path(arg)
    return p if p.is_absolute() or p.exists() else ROOT / arg


def main():
    if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(signal, "SIGPIPE"):
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    pos = [a for a in sys.argv[1:] if not a.startswith("--")]
    opt = dict((a[2:].partition("=")[0], a[2:].partition("=")[2] or True) for a in sys.argv[1:] if a.startswith("--"))
    if not pos:
        print(__doc__)
        return 2
    if pos[0] == "gegner":
        table_enemies(opt.get("suche", ""))
        return 0
    if pos[0] == "wellen":
        table_waves(pos[1] if len(pos) > 1 else "classic")
        return 0
    f = resolve(pos[0])
    if not f.exists():
        print(f"Datei fehlt: {f}")
        return 1
    v = json.loads(f.read_text(encoding="utf-8"))
    try:
        v = walk(v, pos[1] if len(pos) > 1 else "")
    except (KeyError, IndexError, ValueError) as e:
        print(f"Pfad nicht gefunden: {e}")
        return 1
    if opt.get("suche"):
        search(v, opt["suche"])
        return 0
    s = compact(v)
    limit = int(opt.get("max", 1500))
    if opt.get("voll") or len(s) <= limit:
        if isinstance(v, dict) and len(s) > 200:
            for k, x in v.items():  # eine Zeile je Schlüssel, lange Listen eine Zeile je Eintrag
                if isinstance(x, list) and len(compact(x)) > 150:
                    print(f"{k}:")
                    for i, y in enumerate(x):
                        print(f"  [{i}] {compact(y)}")
                else:
                    print(f"{k}: {compact(x)}")
        else:
            print(s)
    else:
        print(f"# {len(s)} Zeichen, Gliederung (gezielt nachfragen mit Pfad, oder --voll):")
        outline(v)
    return 0


if __name__ == "__main__":
    sys.exit(main())
