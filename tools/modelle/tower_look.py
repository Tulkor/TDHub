"""Werte für eine Tower-Definition aus data/tower_models.json (wie scripts/game/tower_models.gd), für die Generatoren."""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CRYSTAL = "res://assets/models/crystals/crystal_13.glb"
_data = json.load(open(os.path.join(ROOT, "data", "tower_models.json")))


def look(mode, key):
    """{"model", "model_tint", "model_solid", …} oder {} (fehlt, haus, kein Eintrag)."""
    v = _data.get(mode, {}).get(key)
    if isinstance(v, dict) and "effect_tower" in v:
        return {"model": "", "effect_tower": v["effect_tower"]}
    if v is None or v == "haus" or (isinstance(v, dict) and "fehlt" in v):
        return {}
    if isinstance(v, str):
        v = {"m": v}
    if "fog" in v and not v.get("m"):
        return {"model": "", "fog": v["fog"]}  # nur Nebeleffekt, kein Modell
    ref, tint = v.get("m", ""), bool(v.get("tint", False))
    if ref in ("", "kristall"):
        return {}  # Kristall des Generators bleibt
    path = ref if ref.startswith("res://") else "res://assets/models/towers/%s.glb" % ref
    out = {"model": path, "model_tint": tint, "model_solid": not tint}
    out.update({k: v[k] for k in ("flame", "flame_height", "hit_fx", "fog", "fog_height") if k in v})
    return out
