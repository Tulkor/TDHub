#!/usr/bin/env python3
"""Bollwerk-Endbosse prüfen; --bericht zeigt Themen und Rotationen kompakt."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bericht", action="store_true")
    args = parser.parse_args()
    data = json.loads((ROOT / "data/heroes_bosse.json").read_text(encoding="utf-8"))
    base = json.loads((ROOT / "data/heroes.json").read_text(encoding="utf-8"))
    english = json.loads((ROOT / "data/i18n/en.json").read_text(encoding="utf-8"))
    errors = []
    def check(ok, message):
        if not ok:
            errors.append(message)
    ids = [b["id"] for b in data["bosses"]]
    check(len(ids) == len(set(ids)) == 5, "genau fünf eindeutige Endbosse erforderlich")
    check(set(data["final_bosses"]) == set(ids), "Endboss-Pool muss alle fünf Bosse enthalten")
    check(len({b["visual"]["theme"] for b in data["bosses"]}) == 5, "jeder Boss braucht ein eigenes Design-Thema")
    existing = {e["id"] for e in base["enemies"]} | {e["id"] for e in data["adds"]}
    known = set(data["abilities"])
    check(not (known & set(base["abilities"])), "neue Fähigkeiten dürfen vorhandene nicht überschreiben")
    for aid, ab in data["abilities"].items():
        check(ab["kind"] in {"circle", "echo", "cone", "ring", "line", "charge", "skillshot", "whirl", "summon"}, aid + ": unbekannte Form")
        check(ab.get("windup", 0) >= 0.9, aid + ": Warnzeit zu kurz")
        check(ab.get("repeat_windup", 1) >= 0.8, aid + ": Folge-Warnzeit zu kurz")
        check(ab.get("cooldown", 0) > ab["windup"], aid + ": ungültige Abklingzeit")
        check(1 <= ab.get("repeat", 1) <= 6 and 1 <= ab.get("count", 1) <= 12, aid + ": Muster überschreitet Budget")
        for field in ["name", "hint"]:
            check(bool(english.get(ab.get(field, ""))), aid + ": Übersetzung fehlt für " + field)
        if ab["kind"] == "summon":
            check(ab["summon"] in existing, aid + ": Beschwörung fehlt")
        if ab["kind"] == "ring":
            for n in range(ab.get("repeat", 1)):
                inner = ab["inner"] + ab.get("grow", 0) * n
                outer = ab["radius"] + ab.get("grow", 0) * n
                check(0 <= inner < outer, aid + ": ungültiger Folge-Ring")
    for boss in data["bosses"]:
        check(len(boss["phases"]) == 2 and 0 < boss["phases"][1]["at"] < boss["phases"][0]["at"] < 1, boss["id"] + ": ungültige Phasen")
        unlocked = set(boss["abilities"])
        for stage in [boss, *boss["phases"]]:
            unlocked.update(stage.get("add", []))
            rotation = stage.get("rotation", [])
            check(bool(rotation) and set(rotation) <= unlocked <= known, boss["id"] + ": Rotation verweist auf gesperrte/fehlende Fähigkeiten")
            if "name" in stage:
                check(bool(english.get(stage["name"])), boss["id"] + ": Phasen-/Namensübersetzung fehlt")
        check(len(unlocked) >= 6, boss["id"] + ": zu wenige unterschiedliche Moves")
        check(bool(english.get(boss["theme"])), boss["id"] + ": Themenübersetzung fehlt")
        if args.bericht:
            print(f"{boss['name']}: {boss['theme']}; 3 Phasen, {len(unlocked)} Moves")
    for error in errors:
        print("FAIL " + error)
    print(f"Bossdaten: {len(ids)} Bosse, {len(known)} Moves, {len(errors)} Fehler")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
