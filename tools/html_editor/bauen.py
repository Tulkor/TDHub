#!/usr/bin/env python3
"""Baut den Map- und Tower-Editor als eine HTML-Datei mit eingebetteten Daten (Stand des Repos) zum Weitergeben.

Aufruf aus dem Projektordner:
  python3 tools/html_editor/bauen.py                      -> /mnt/project-files/editoren/td_editor.html
  python3 tools/html_editor/bauen.py --ziel=pfad.html     anderer Zielpfad
Die fertige Datei läuft ohne Installation im Browser (Doppelklick).
Eingebettet: alle Maps und Tower als Vorlagen, Wellen-Sets, Modi, Effekt-IDs, Fähigkeiten aus
scripts/game/abilities.gd, Schadensarten und Stufennamen aus scripts/autoload/database.gd, Schrift DejaVu Sans Mono.
"""
import base64
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DEFAULT = Path("/mnt/project-files/editoren/td_editor.html")


def texts(kind):
    return {p.relative_to(ROOT).as_posix(): p.read_text(encoding="utf-8") for p in sorted((ROOT / "data" / kind).glob("*.json"))}


def abilities():
    """SCHEMA und PARAM_LABELS aus abilities.gd; jede Zeile dort ist für sich gültiges JSON (wie im Balance-Editor)."""
    schema, labels = {}, {}
    for line in (ROOT / "scripts/game/abilities.gd").read_text(encoding="utf-8").splitlines():
        m = re.match(r'^\t"(\w+)": (\{"label".*\}),\s*$', line)
        if m:
            raw = json.loads(m.group(2))
            params_text = re.search(r'"params": (\{.*?\})', m.group(2)).group(1)
            params = {}
            for k, v in raw["params"].items():
                num = re.search(r'"%s": ([-0-9.eE+]+)' % re.escape(k), params_text)
                params[k] = {"value": v, "float": bool(num and re.search(r"[.eE]", num.group(1)))}
            schema[m.group(1)] = {"label": raw["label"], "params": params}
            continue
        m = re.match(r'^\t"(\w+)": ("[^"]*"),\s*$', line)
        if m:
            labels[m.group(1)] = json.loads(m.group(2))
    return schema, labels


def database_consts():
    """TIER_NAMES und DAMAGE_TYPE_NAMES aus database.gd."""
    src = (ROOT / "scripts/autoload/database.gd").read_text(encoding="utf-8")
    tiers = json.loads(re.search(r"const TIER_NAMES := (\[.*?\])", src).group(1))
    block = re.search(r"const DAMAGE_TYPE_NAMES := \{(.*?)\}", src, re.S).group(1)
    return tiers, dict(re.findall(r'"(\w+)": "([^"]*)"', block))


def fx_ids():
    hits = json.loads((ROOT / "data/fx/hits.json").read_text(encoding="utf-8")).get("effects", {})
    shots = json.loads((ROOT / "data/fx/shots.json").read_text(encoding="utf-8")).get("effects", {})
    # wie FxData.hit_ids() / shot_ids(): Schüsse nur Linien und Geschosse
    return sorted(hits), sorted(k for k, v in shots.items() if v.get("kind") in ("line", "projectile"))


def modes():
    data = json.loads((ROOT / "data/modes.json").read_text(encoding="utf-8"))
    lst = data if isinstance(data, list) else data.get("modes", [])
    return [[m["id"], m.get("name", m["id"])] for m in lst if m.get("needs_map", True)]


def waves():
    return sorted(json.loads(p.read_text(encoding="utf-8")).get("id", p.stem) for p in (ROOT / "data/waves").glob("*.json"))


def invoke_catalog():
    """Real Bollwerk IDs; references only, execution remains in the game's bridge."""
    kits = json.loads((ROOT / "data/heroes_helden.json").read_text(encoding="utf-8"))
    cfg = json.loads((ROOT / "data/heroes.json").read_text(encoding="utf-8"))
    refs = []
    for hero in kits.get("heroes", []):
        refs.extend({"id": a["id"], "name": a.get("name", a["id"]), "group": "Eigener Held: " + hero.get("name", hero["id"])}
                    for a in hero.get("abilities", []) if a.get("id"))
    for group, definitions in (("Gadgets (eigenes Kit)", kits.get("gadgets", {})),
                               ("Gegnerfähigkeiten (freundlicher Einsatz)", cfg.get("abilities", {}))):
        refs.extend({"id": key, "name": value.get("name", key), "group": group} for key, value in definitions.items())
    return refs


def stand():
    try:
        rev = subprocess.run(["git", "log", "-1", "--format=%h %cd", "--date=format:%d.%m.%Y %H:%M"],
                             cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
        return "Stand " + rev
    except (OSError, subprocess.CalledProcessError):
        return "Stand unbekannt"


def font_css():
    css = []
    for name, weight in (("DejaVuSansMono.ttf", "normal"), ("DejaVuSansMono-Bold.ttf", "bold")):
        f = ROOT / "assets/fonts" / name
        if f.exists():
            b64 = base64.b64encode(f.read_bytes()).decode()
            css.append('@font-face { font-family: "DejaVu Sans Mono"; font-weight: %s; '
                       'src: url(data:font/ttf;base64,%s) format("truetype"); }' % (weight, b64))
    return "\n".join(css)


def main():
    ziel = DEFAULT
    for a in sys.argv[1:]:
        if a.startswith("--ziel="):
            ziel = Path(a.split("=", 1)[1])
    schema, labels = abilities()
    tier_names, damage_types = database_consts()
    hit_fx, shot_fx = fx_ids()
    data = {"stand": stand(), "maps": texts("maps"), "towers": texts("towers"), "waves": waves(), "modes": modes(),
            "hit_fx": hit_fx, "shot_fx": shot_fx, "schema": schema, "labels": labels,
            "damage_types": damage_types, "tier_names": tier_names,
            "items": (ROOT / "data/heroes_items.json").read_text(encoding="utf-8"),
            "invoke_catalog": invoke_catalog(),
            "effect_catalog": json.loads((ROOT / "scripts/systems/effect_script/catalog.json").read_text(encoding="utf-8"))}
    html = (HERE / "editor.html").read_text(encoding="utf-8")
    # </ im JSON würde das <script> beenden
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    html = html.replace("/*DATEN*/null/*ENDE*/", blob, 1).replace("/*FONTS*/", font_css(), 1)
    for filename, marker in (("effect_script.js", "/*EFFECT_SCRIPT*/"), ("item_editor.js", "/*ITEM_EDITOR*/")):
        html = html.replace(marker, (HERE / filename).read_text(encoding="utf-8"), 1)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_text(html, encoding="utf-8")
    print(f"TD-Editor: {ziel} ({ziel.stat().st_size // 1024} KB, {len(data['maps'])} Maps, "
          f"{len(data['towers'])} Tower, {data['stand']})")


if __name__ == "__main__":
    main()
