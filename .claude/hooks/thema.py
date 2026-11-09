#!/usr/bin/env python3
"""PostToolUse-Hook: blendet die passende Bereichsnotiz aus docs/claude/ ein, sobald ein Thread
Dateien eines Bereichs anfasst (einmal pro Sitzung und Notiz).

So bleibt CLAUDE.md klein (wird bei jedem Schritt mitgeschickt), und das Wissen zu YouTD, Maul usw.
kommt nur in Threads, die dort wirklich arbeiten.
Aufruf mit --zuruecksetzen (SessionStart nach /compact): Notizen dürfen wieder eingeblendet werden.
"""
import json
import os
import re
import sys

# Notiz -> Muster auf Pfade/Befehle. Reihenfolge egal, mehrere Treffer = mehrere Notizen.
THEMEN = {
    "youtd": r"youtd|tests/yt|/yt_",
    "maul": r"/maul|maul_",
    "eeve": r"eeve",
    "randgruppen": r"randgruppen|/rg_|\brg_",
    "heroes": r"scripts/heroes/|/hd_|heroes",
    "survivors": r"survivors|scripts/survivors/|/sv_",
    "netz": r"scripts/net/|net\.gd|coop|lobby|gemischt|sitzung_test|relay",
    "gemtd": r"scripts/game/(game|tower|enemy|abilities|effects|fx_|rogue|player_state|run_stats|profile)"
             r"|scripts/ui/hud|scripts/map/|roguelike|profile",
    "systeme": r"scripts/systems/|tools/systeme\.py|tests/systems/",
    "werkzeuge": r"build_windows|release|screenshot\.(sh|gd)|tools/(fx|modelle|wc3|balance_editor|html_editor)/"
                 r"|balance_bericht|tower_tabelle|pruefe_ui|map_check|tests/\w+_test\.gd",
}
STAND = "/tmp/gemtd-thema"


def stand_datei(sid):
    return os.path.join(STAND, re.sub(r"[^\w-]", "_", sid or "ohne"))


def texte(inp):
    t = [str(inp.get(k, "")) for k in ("file_path", "path", "pattern", "glob", "command", "notebook_path")]
    return "\n".join(x for x in t if x)


def main():
    try:
        d = json.load(sys.stdin)
    except ValueError:
        return 0
    datei = stand_datei(d.get("session_id", ""))
    if "--zuruecksetzen" in sys.argv:
        try:
            os.remove(datei)
        except OSError:
            pass
        return 0
    text = texte(d.get("tool_input") or {})
    if not text:
        return 0
    try:
        gezeigt = set(open(datei).read().split())
    except OSError:
        gezeigt = set()
    root = os.environ.get("CLAUDE_PROJECT_DIR") or d.get("cwd") or "."
    neu = []
    for name, muster in THEMEN.items():
        if name in gezeigt or not re.search(muster, text, re.I):
            continue
        pfad = os.path.join(root, "docs", "claude", name + ".md")
        if os.path.isfile(pfad):
            neu.append((name, open(pfad, encoding="utf-8").read()))
    if not neu:
        return 0
    os.makedirs(STAND, exist_ok=True)
    with open(datei, "a") as f:
        f.write("".join(n + "\n" for n, _ in neu))
    kontext = "\n\n".join("Bereichsnotiz docs/claude/%s.md (einmal pro Thread eingeblendet):\n%s" % (n, t) for n, t in neu)
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": kontext}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
