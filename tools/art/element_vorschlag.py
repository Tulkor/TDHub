#!/usr/bin/env python3
"""DE/EN-Namenshinweise anzeigen; mit --anwenden nur die kuratierte Freigabeliste schreiben."""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from werte_setzen import detect_format

WORDS = {
    "feuer": r"fire|flame|lava|volcano|phoenix|feuer|flammen",
    "blitz": r"lightning|storm|blitz|donner",
    "wasser": r"water|geyser|hydro|tsunami|wasser|geysir",
    "eis": r"ice|icy|glacier|permafrost|eis|frost",
    "gift": r"acid|poison|toxic|corrosion|noxious|gift|säure",
    "erde": r"rock|crater|earth|stone|stein|krater",
    "licht": r"moonlight|sacred|radiant|licht",
    "dunkel": r"darkness|corruption|dunkel",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--anwenden", action="store_true", help="nur kuratierte Freigabeliste anwenden")
    args = parser.parse_args()
    approved = json.loads((ROOT / "data/fx/tower_elements.json").read_text(encoding="utf-8"))
    changed = 0
    for path in sorted((ROOT / "data/towers").glob("*.json")):
        raw = path.read_text(encoding="utf-8")
        tower = json.loads(raw)
        ident = tower["id"]
        if args.anwenden and ident in approved:
            fmt = detect_format(raw, tower)
            if fmt is None:
                raise ValueError(f"Unbekanntes Format: {path}")
            tower.update(approved[ident])
            indent, ascii_only, newline = fmt
            updated = json.dumps(tower, indent=indent, ensure_ascii=ascii_only) + ("\n" if newline else "")
            if updated != raw:
                path.write_text(updated, encoding="utf-8", newline="\n")
                changed += 1
        if ident.startswith(("eeve_", "rg_")) and not tower.get("element"):
            name = " ".join(str(tower.get(k, "")) for k in ("id", "name", "name_original"))
            words = re.sub(r"[_\W]+", " ", name.lower())
            hits = [e for e, pattern in WORDS.items() if re.search(r"\b(?:" + pattern + r")\b", words)]
            if hits:
                print(f"{ident}: {', '.join(hits)} – {tower.get('name', '')}")
    if args.anwenden:
        print(f"Kuratierte Dateien geändert: {changed}")


if __name__ == "__main__":
    main()
