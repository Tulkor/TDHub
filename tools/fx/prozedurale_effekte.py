#!/usr/bin/env python3
"""Registriert A2-Geometrie und begrenzte Treffer nach dem Kenney-Import erneut."""
import argparse
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "data/fx"
SHOTS = [("stone_arc", .8, "projectile"), ("arrow", 0, "projectile"),
         ("cannonball", .25, "projectile"), ("frost_bolt", 0, "projectile"),
         ("poison_glob", .35, "projectile"), ("water_jet", 0, "line"),
         ("chain_lightning", 0, "line")]
HITS = [("frost_ring", "blue_ring", .9, True),
        ("acid_cloud", "green_poison", 1.3, False),
        ("stone_dust", "brown_dirt", .7, True)]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pruefen", action="store_true")
    args = parser.parse_args(argv)
    data = {name: json.loads((ROOT / f"{name}.json").read_text(encoding="utf-8")) for name in ["shots", "hits"]}
    before = copy.deepcopy(data)
    shots, hits = data["shots"], data["hits"]
    shots["_quelle"] = "Sprite-Sheets: Kenney Particle Pack 1.1 (CC0); prozedurale Geometrie: scripts/game/fx_procedural.gd (Projektcode)."
    for key, arc, kind in SHOTS:
        shots["effects"][key] = dict(name=key, kind=kind, procedural=key, arc=arc,
                                     length=.42 if kind == "projectile" else .22,
                                     hue=.55, saturation=.6, width=.15)
    shots["auto"]["ability"].update(bounce="chain_lightning", chain="chain_lightning")
    for key, source, length, ground in HITS:
        effect = copy.deepcopy(hits["effects"][source])
        effect.update(name=key, length=length, budget=24, ground=ground, light=False, auto=False)
        effect["layers"] = effect["layers"][:2]
        for i, layer in enumerate(effect["layers"]):
            layer.update(max=12, bursts=[[0, 1 if i == 0 and ground else 8, 1, 0]],
                         rate=0, life=[length * .8, length], light=False)
            if ground and i == 0:
                layer.update(mode="flat", align="local")
        hits["effects"][key] = effect
    if args.pruefen:
        if data != before:
            raise SystemExit("Prozedurale Effekte veraltet: tools/fx/prozedurale_effekte.py")
        print("Prozedurale Effekte aktuell")
        return
    for name, value in data.items():
        (ROOT / f"{name}.json").write_text(json.dumps(value, ensure_ascii=False, indent="\t") + "\n", encoding="utf-8")
    print("Prozedurale Effekte: 7 Geschosse, 3 Treffer registriert")


if __name__ == "__main__":
    main()
