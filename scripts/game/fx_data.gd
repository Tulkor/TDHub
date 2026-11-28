class_name FxData
## Treffer- und Schuss-Effekte: Daten aus data/fx/ und welcher Tower welchen Effekt bekommt.
##
## hits.json  – Treffer-Effekte (aus dem Kenney Particle Pack, CC0, tools/fx/kenney_effekte.py)
## shots.json – Schuss-Effekte als Sprite-Sheets (ebenfalls tools/fx/kenney_effekte.py) und die Regeln
##              für die automatische Wahl ("auto")
## Ein Tower kann in seiner Datei "hit_fx" und "shot_fx" setzen (Effekt-ID, "auto" oder "none").
## Ohne eigene Angabe: Element, Fähigkeit, schließlich Farbe. Schüsse bleiben in Towerfarbe.

const HITS := "res://data/fx/hits.json"
const SHOTS := "res://data/fx/shots.json"
const ELEMENTS := "res://data/fx/elements.json"
const AUTO := "auto"
const NONE := "none"
## Ab diesem Farbton-Abstand (0..1) wird ein Effekt auf die Towerfarbe gedreht.
const HUE_TOLERANCE := 0.04
## Tower mit weniger Sättigung gelten als weiß/grau und bekommen einen hellen Effekt.
const PALE := 0.25

static var _hits: Dictionary = {}
static var _shots: Dictionary = {}
static var _rules: Dictionary = {}
static var _elements: Dictionary = {}
static var _loaded := false
static var _cache: Dictionary = {}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_elements = _read(ELEMENTS)
	var h = _read(HITS)
	if h is Dictionary:
		_hits = h.get("effects", {})
	var s = _read(SHOTS)
	if s is Dictionary:
		_shots = s.get("effects", {})
		_rules = s.get("auto", {})


static func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func hits() -> Dictionary:
	_load()
	return _hits


static func shots() -> Dictionary:
	_load()
	return _shots


static func hit(id: String) -> Dictionary:
	return hits().get(id, {})


static func shot(id: String) -> Dictionary:
	return shots().get(id, {})


## IDs für Auswahllisten (Tower-Editor): Treffer bzw. Schüsse einer Art ("line", "projectile", "nova").
static func hit_ids() -> Array:
	var ids := hits().keys()
	ids.sort()
	return ids


static func shot_ids(kinds: Array = ["line", "projectile"]) -> Array:
	var ids := shots().keys().filter(func(id): return str(shots()[id].get("kind", "")) in kinds)
	ids.sort()
	return ids


## Effekte eines Towers auf einer Stufe:
## {hit, shot, nova} je als {"id", "shift", "sat"} oder leer. shift = Farbton-Drehung, sat = Sättigungsfaktor.
static func for_tower(tower_id: String, tier: int = 0) -> Dictionary:
	var key := "%s:%d" % [tower_id, tier]
	if _cache.has(key):
		return _cache[key]
	_load()
	var def := tower_def(tower_id)
	var element := element_for(def)
	var col := Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	var types := _ability_types(def, tier)
	var out := {}
	var hit_id := _pick(str(def.get("hit_fx", AUTO)), _hits, func(): return str(element.get("splash" if "splash" in types else "hit", _auto_hit_for(types, col))))
	if hit_id != "":
		out["hit"] = _tint(_hits[hit_id], hit_id, col)
		# Elementtreffer behalten ihre Bedeutung (Wasser blau, Eis hellblau).
		if not element.is_empty() and str(def.get("hit_fx", AUTO)) == AUTO:
			out["hit"] = {"id": hit_id, "shift": 0.0, "sat": 1.0}
	var shot_id := _pick(str(def.get("shot_fx", AUTO)), _shots, func(): return str(element.get("shot", _auto_shot(types, col))))
	if shot_id != "":
		out["shot"] = _tint(_shots[shot_id], shot_id, col)
	if "nova" in types:
		var nova_id := str(_rules.get("nova", ""))
		if _shots.has(nova_id):
			out["nova"] = _tint(_shots[nova_id], nova_id, col)
	_cache[key] = out
	return out


static func clear_cache() -> void:
	_cache.clear()
	_loaded = false


static func tower_def(id: String) -> Dictionary:
	var def: Dictionary = Database.towers.get(id, {})
	if not def.is_empty():
		return def
	if id.begins_with(YoutdTower.PREFIX):
		return YoutdTower.fx_def(id)
	return MaulData.tower(id)


static func element_for(def: Dictionary) -> Dictionary:
	_load()
	return _elements.get("blitz" if def.get("lightning", false) else str(def.get("element", "")), {})


static func _pick(wanted: String, pool: Dictionary, auto: Callable) -> String:
	if wanted == NONE or wanted == "":
		return ""
	if wanted != AUTO and pool.has(wanted):
		return wanted
	var id: String = auto.call()
	return id if pool.has(id) else ""


static func _ability_types(def: Dictionary, tier: int) -> Array:
	var list: Array = def.get("abilities", []).duplicate()
	var tiers: Array = def.get("tiers", [])
	if not tiers.is_empty():
		list.append_array(tiers[clampi(tier, 0, tiers.size() - 1)].get("abilities", []))
	return list.map(func(ab): return str(ab.get("type", "")) if ab is Dictionary else "")


## Treffer: erst nach Fähigkeit (shots.json → auto.hit_ability, z. B. Splash = Explosion), sonst nach Farbe.
static func _auto_hit_for(types: Array, col: Color) -> String:
	var by_ability: Dictionary = _rules.get("hit_ability", {})
	for t in types:
		if by_ability.has(t):
			var id := _by_warmth(by_ability[t], col)
			if _hits.has(id):
				return id
	return _auto_hit(col)


## Treffer: der Effekt mit dem nächsten Farbton; blasse Tower bekommen den blassesten Effekt.
static func _auto_hit(col: Color) -> String:
	var best := ""
	var best_d := INF
	for id in _hits:
		var e: Dictionary = _hits[id]
		if not bool(e.get("auto", true)):
			continue
		var d: float
		if col.s < PALE:
			d = float(e.get("saturation", 1.0))
		else:
			d = absf(_hue_diff(col.h, float(e.get("hue", 0.0)))) + maxf(0.0, 0.4 - float(e.get("saturation", 1.0)))
		if d < best_d:
			best_d = d
			best = id
	return best


## Schuss: nach Fähigkeit, dann nach Farbton (Regeln in shots.json → "auto"), sonst der Standard-Schuss.
static func _auto_shot(types: Array, col: Color) -> String:
	if "bounce" in types or "chain" in types:
		return str(_rules.get("ability", {}).get("chain", "lightning_arc"))
	var by_ability: Dictionary = _rules.get("ability", {})
	for t in types:
		if by_ability.has(t):
			return _by_warmth(by_ability[t], col)
	if col.s >= PALE:
		for r in _rules.get("hue", []):
			var lo := float(r[0])
			var hi := float(r[1])
			if (col.h >= lo and col.h <= hi) if lo <= hi else (col.h >= lo or col.h <= hi):
				return str(r[2])
	return str(_rules.get("default", ""))


## Regel-Eintrag: eine Effekt-ID oder {"warm": id, "sonst": id} (Feuer nur für rote bis gelbe Tower,
## sonst wirkt der auf Blau gedrehte Feuerball falsch).
static func _by_warmth(rule, col: Color) -> String:
	if not rule is Dictionary:
		return str(rule)
	var warm: Array = _rules.get("warm", [0.93, 0.16])
	var lo := float(warm[0])
	var hi := float(warm[1])
	var is_warm := col.s >= PALE and ((col.h >= lo and col.h <= hi) if lo <= hi else (col.h >= lo or col.h <= hi))
	return str(rule.get("warm" if is_warm else "sonst", ""))


static func _tint(e: Dictionary, id: String, col: Color) -> Dictionary:
	var shift := 0.0
	var sat := 1.0
	var fx_sat := maxf(float(e.get("saturation", 1.0)), 0.01)
	if col.s < PALE:
		sat = clampf(col.s / fx_sat, 0.0, 1.0)
	else:
		var d := _hue_diff(col.h, float(e.get("hue", 0.0)))
		if absf(d) > HUE_TOLERANCE:
			shift = d
	return {"id": id, "shift": shift, "sat": sat}


## kürzester Weg auf dem Farbkreis von b nach a, -0.5..0.5
static func _hue_diff(a: float, b: float) -> float:
	return wrapf(a - b, -0.5, 0.5)
