class_name SystemHost
extends RefCounted
## Legt die Spielsysteme eines Modus an: Liste "systems" des Modus in data/modes.json, je Name das Skript
## res://scripts/systems/<name>/<name>.gd (GameSystem). Systeme, die noch nicht aus den Modi herausgezogen
## sind, haben kein Skript und werden übersprungen (Umbau in Etappen, siehe docs/claude/systeme.md).
## Das Spiel bekommt die Systeme als Kind-Knoten mit ihrem Namen und in game.systems (falls vorhanden).

const DIR := "res://scripts/systems/"


static func script_path(system_name: String) -> String:
	return DIR + system_name + "/" + system_name + ".gd"


## Namen der Systeme, die der Modus in data/modes.json ankreuzt.
static func declared(mode_id: String) -> Array:
	for m in Database.modes:
		if str(m.get("id", "")) == mode_id:
			return m.get("systems", [])
	return []


## Einstellungen eines Systems für einen Modus, wie CSS kaskadiert (Lukas 2026-11-08): erst die Basiswerte des
## Systems (scripts/systems/<name>/<name>.json), darüber die Modus-Daten (modes.json → system_cfg.<name>).
## Was der Modus angibt, gewinnt immer; verschachtelte Dictionaries werden Schlüssel für Schlüssel gemischt,
## Listen und einfache Werte ersetzt. Schlüssel mit "_" vorn (z. B. _info) bleiben draußen.
static func config(mode_id: String, system_name: String) -> Dictionary:
	var base = Database.load_json(DIR + system_name + "/" + system_name + ".json")
	var out: Dictionary = cascade({}, base if typeof(base) == TYPE_DICTIONARY else {})
	for m in Database.modes:
		if str(m.get("id", "")) == mode_id:
			var c = m.get("system_cfg", {}).get(system_name, {})
			if typeof(c) == TYPE_DICTIONARY:
				out = cascade(out, c)
	return out


## over über base legen (base bleibt unverändert): over gewinnt, Dictionaries werden tief gemischt.
static func cascade(base: Dictionary, over: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for k in over:
		if str(k).begins_with("_"):
			continue
		var v = over[k]
		if typeof(v) == TYPE_DICTIONARY and typeof(out.get(k)) == TYPE_DICTIONARY:
			out[k] = cascade(out[k], v)
		else:
			out[k] = v.duplicate(true) if typeof(v) in [TYPE_DICTIONARY, TYPE_ARRAY] else v
	return out


## Systeme für game anlegen. names leer = laut modes.json für mode_id. Gibt {name: GameSystem} zurück.
static func attach(game: Node, mode_id: String, names: Array = []) -> Dictionary:
	var out := {}
	for n in (names if not names.is_empty() else declared(mode_id)):
		var path := script_path(str(n))
		if not ResourceLoader.exists(path):
			continue
		var obj = load(path).new()
		if not obj is GameSystem:
			continue  # gemeinsame Bibliothek ohne Knoten (z. B. Leveling mit static func)
		var sys: GameSystem = obj
		sys.name = str(n)
		sys.set_meta("mode_id", mode_id)
		sys.setup(game, config(mode_id, str(n)))
		game.add_child(sys)
		out[str(n)] = sys
	if "systems" in game:
		game.systems = out
	return out
