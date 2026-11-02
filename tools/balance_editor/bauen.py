#!/usr/bin/env python3
"""Baut den Balance-Editor als eine Datei mit eingebetteten Daten (Stand des Repos), zum Weitergeben an Lukas.

Aufruf aus dem Projektordner:
  python3 tools/balance_editor/bauen.py                      -> /mnt/project-files/balance-editor/balance_editor.html
  python3 tools/balance_editor/bauen.py --ziel=pfad.html     anderer Zielpfad
Die fertige Datei läuft ohne Installation im Browser (Doppelklick, Edge oder Chrome).
Eingebettet: Tower, Gegner, GemTD-Wellen, Maul-Shops und -Level, Fähigkeiten aus scripts/game/abilities.gd,
Level-Profile (data/leveling.json), die Schrift DejaVu Sans Mono.
"""
import base64
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
DEFAULT = Path("/mnt/project-files/balance-editor/balance_editor.html")
FILES = ["data/waves/classic.json", "data/maul/shops.json", "data/maul/waves.json", "data/roguelike_enemies.json", "data/eeve_items.json", "data/leveling.json", "data/ascension.json"]


def data_texts():
    paths = sorted(ROOT.glob("data/towers/*.json")) + sorted(ROOT.glob("data/enemies/*.json")) + [ROOT / f for f in FILES]
    return {p.relative_to(ROOT).as_posix(): p.read_text(encoding="utf-8") for p in paths}


def abilities():
    """SCHEMA und PARAM_LABELS aus abilities.gd; jede Zeile dort ist für sich gültiges JSON."""
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


def difficulties():
    """Namen der Schwierigkeiten je Modus (Reiter Aufstieg zeigt sie bei den angebotenen Stufen)."""
    out = {"gemtd": ["Einfach", "Mittel", "Schwer"]}
    m = re.search(r"const DIFFICULTIES := \[(.*?)\]", (ROOT / "scripts/autoload/session.gd").read_text(encoding="utf-8"), re.S)
    if m:
        out["gemtd"] = re.findall(r'"name": "([^"]+)"', m.group(1))
    for mode, rel in (("eeve", "data/eeve.json"), ("randgruppen", "data/randgruppen.json"), ("maul", "data/maul/rules.json"), ("youtd", "data/youtd/rules.json")):
        try:
            out[mode] = [d.get("name", "") for d in json.loads((ROOT / rel).read_text(encoding="utf-8")).get("difficulties", [])]
        except (OSError, ValueError):
            pass
    return out


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
    data = {"stand": stand(), "texts": data_texts(), "schema": schema, "labels": labels, "difficulties": difficulties()}
    html = (HERE / "balance_editor.html").read_text(encoding="utf-8")
    # </ im JSON würde das <script> beenden
    blob = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
    html = html.replace("/*DATEN*/null/*ENDE*/", blob, 1).replace("/*FONTS*/", font_css(), 1)
    ziel.parent.mkdir(parents=True, exist_ok=True)
    ziel.write_text(html, encoding="utf-8")
    print(f"Balance-Editor: {ziel} ({ziel.stat().st_size // 1024} KB, {len(data['texts'])} Dateien, {data['stand']})")


if __name__ == "__main__":
    main()
