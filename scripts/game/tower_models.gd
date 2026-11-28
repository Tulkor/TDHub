class_name TowerModels
extends RefCounted
## Tower-Modelle je Modus aus data/tower_models.json (Zuordnung von Hand, Werkzeug tools/modelle/tower_modelle.py).
## Shopping Maul und YouTD lesen sie zur Laufzeit; eeveTD und Randgruppen backen sie beim Erzeugen in data/towers/.

const PATH := "res://data/tower_models.json"
const CRYSTAL := "res://assets/models/crystals/crystal_13.glb"

static var _data: Dictionary = {}


## Werte für die Tower-Definition ("model", "model_tint", "model_solid", optional "flame", "flame_height", "hit_fx", "fog", "fog_height")
## oder leer, wenn der Modus für key kein Modell hat ("fehlt", "haus" oder kein Eintrag).
static func look(mode: String, key: String) -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text()) if f else {}
		if _data == null:
			_data = {}
	var v = _data.get(mode, {}).get(key)
	if v is Dictionary and v.has("effect_tower"):
		return {"model": "", "effect_tower": v.effect_tower}
	if v == null or (v is String and v == "haus") or (v is Dictionary and v.has("fehlt")):
		return {}
	if v is String:
		v = {"m": v}
	if v.has("fog") and str(v.get("m", "")) == "":
		return {"model": "", "fog": v["fog"]}  # nur Nebeleffekt, kein Modell
	var ref := str(v.get("m", ""))
	var tint := bool(v.get("tint", false))
	if ref == "" or ref == "kristall":
		ref = CRYSTAL
		tint = true
	var path := ref if ref.begins_with("res://") else "res://assets/models/towers/%s.glb" % ref
	var out := {"model": path, "model_tint": tint, "model_solid": not tint}
	for k in ["flame", "flame_height", "hit_fx", "fog", "fog_height"]:
		if v.has(k):
			out[k] = v[k]
	return out
