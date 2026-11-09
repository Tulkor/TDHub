extends Node
## Lädt alle Spieldaten aus JSON-Dateien.
##
## res://data/<typ>/*.json  -> mitgelieferte Daten
## user://data/<typ>/*.json -> eigene Daten (überschreiben gleiche IDs)
##
## Typen: towers, enemies, waves, maps. Dazu res://data/balance.json und res://data/modes.json (TD-Modi).

const RES_DATA := "res://data/"
const USER_DATA := "user://data/"
const TIER_NAMES := ["Splitter", "Fehlerhafter", "Normaler", "Makelloser", "Perfekter", "Großartiger"]
const DAMAGE_TYPE_NAMES := {"pierce": "Durchbohrend", "magic": "Magie", "normal": "Normal", "siege": "Belagerung",
		"hero": "Held", "spells": "Zauber", "chaos": "Chaos",
		"physical": "Physisch", "electric": "Elektrisch", "elemental": "Elementar"}

var towers: Dictionary = {}
var enemies: Dictionary = {}
var wave_sets: Dictionary = {}
var balance: Dictionary = {}
## Regeln für eeveTD (res://data/eeve.json): Wirtschaft, Elemente, Schwierigkeiten, Wellen, Schadenstabelle.
var eeve: Dictionary = {}
## Regeln für Randgruppen TD (res://data/randgruppen.json): Rassen, Level, Wirtschaft, Schadenstabelle.
var randgruppen: Dictionary = {}
## Items und Marktplatz in eeveTD (res://data/eeve_items.json), siehe eeve_items.gd.
var eeve_items: Dictionary = {}
## GemTD-Variante Roguelike (res://data/roguelike.json): Boni alle zehn Wellen, siehe rogue.gd.
var roguelike: Dictionary = {}
## Gegnerwerte im Roguelike (res://data/roguelike_enemies.json), über die normalen gelegt (Rogue.enemy_def).
var roguelike_enemies: Dictionary = {}
## Level und EP der Tower in allen Modi (res://data/leveling.json), siehe leveling.gd.
var leveling: Dictionary = {}
## Aufstiegsstufen nach der höchsten Schwierigkeit, je Modus (res://data/ascension.json), siehe ascension.gd.
var ascension: Dictionary = {}
## TD-Modi aus data/modes.json, in der Reihenfolge der Datei (siehe mode()).
var modes: Array = []


func _ready() -> void:
	reload()


func reload() -> void:
	towers = _load_dir("towers")
	enemies = _load_dir("enemies")
	wave_sets = _load_dir("waves")
	var b = load_json(RES_DATA + "balance.json")
	balance = b if typeof(b) == TYPE_DICTIONARY else {}
	var e = load_json(RES_DATA + "eeve.json")
	eeve = e if typeof(e) == TYPE_DICTIONARY else {}
	var rg = load_json(RES_DATA + "randgruppen.json")
	randgruppen = rg if typeof(rg) == TYPE_DICTIONARY else {}
	var ei = load_json(RES_DATA + "eeve_items.json")
	eeve_items = ei if typeof(ei) == TYPE_DICTIONARY else {}
	var rl = load_json(RES_DATA + "roguelike.json")
	roguelike = rl if typeof(rl) == TYPE_DICTIONARY else {}
	var re = load_json(RES_DATA + "roguelike_enemies.json")
	roguelike_enemies = re if typeof(re) == TYPE_DICTIONARY else {}
	var lv = load_json(RES_DATA + "leveling.json")
	leveling = lv if typeof(lv) == TYPE_DICTIONARY else {}
	Leveling.reset()
	var asc = load_json(RES_DATA + "ascension.json")
	ascension = asc if typeof(asc) == TYPE_DICTIONARY else {}
	var m = load_json(RES_DATA + "modes.json")
	modes = m.get("modes", []) if typeof(m) == TYPE_DICTIONARY else []
	if modes.is_empty():
		modes = [{"id": "gemtd", "name": "GemTD", "ready": true, "min_players": 1, "max_players": 8}]


# --- Dateien -----------------------------------------------------------------

func load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	var err := json.parse(FileAccess.get_file_as_string(path))
	if err != OK:
		push_error("JSON-Fehler in %s (Zeile %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func save_json(path: String, data: Variant) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Kann %s nicht schreiben (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	return true


## Wohin Editoren speichern: im Godot-Editor direkt ins Projekt, sonst ins Benutzerverzeichnis.
func writable_path(kind: String, id: String) -> String:
	var base := RES_DATA if OS.has_feature("editor") else USER_DATA
	return base + kind + "/" + id + ".json"


func json_files(kind: String) -> PackedStringArray:
	var result := PackedStringArray()
	for base in [RES_DATA, USER_DATA]:
		var dir: String = base + kind
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f in files:
			if f.ends_with(".json"):
				result.append(dir + "/" + f)
	return result


func _load_dir(kind: String) -> Dictionary:
	var out := {}
	for path in json_files(kind):
		var d = load_json(path)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := str(d.get("id", path.get_file().get_basename()))
		d["id"] = id
		d["_path"] = path
		out[id] = d
	return out


## Liste aller Maps: [{id, name, path}], user:// überschreibt res:// bei gleicher ID.
func list_maps() -> Array:
	var by_id := {}
	for path in json_files("maps"):
		var d = load_json(path)
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var id := str(d.get("id", path.get_file().get_basename()))
		by_id[id] = {"id": id, "name": str(d.get("name", id)), "path": path, "game": str(d.get("game", "gemtd"))}
	var list := by_id.values()
	list.sort_custom(func(a, b): return a.name < b.name)
	return list


## Erste Map eines Modus (nach Namen), z. B. als Vorgabe; {} wenn es keine gibt.
func first_map(game := "gemtd") -> Dictionary:
	for m in list_maps():
		if m.game == game:
			return m
	return {}


# --- TD-Modi ---------------------------------------------------------------------

func mode(id: String) -> Dictionary:
	for m in modes:
		if str(m.get("id", "")) == id:
			return m
	return {}


## Modus spielbar und für so viele Spieler erlaubt?
func mode_allows(id: String, players: int) -> bool:
	var m := mode(id)
	return not m.is_empty() and bool(m.get("ready", false)) \
		and players >= int(m.get("min_players", 1)) and players <= int(m.get("max_players", 8))


## Erlaubte Spielerzahl als Text, z. B. "1–8 Spieler".
func mode_players_text(id: String) -> String:
	var m := mode(id)
	var lo := int(m.get("min_players", 1))
	var hi := int(m.get("max_players", 8))
	return tr("%d Spieler") % lo if lo == hi else tr("%d–%d Spieler") % [lo, hi]


## Maps, die zum Modus passen (Einträge wie list_maps()): Feld "game" der Map, Standard "gemtd".
func maps_for_mode(id: String, all_maps: Array) -> Array:
	return all_maps.filter(func(mp): return str(mp.get("game", "gemtd")) == id)


## Schadensfaktor Schadensart gegen Rüstungsart, 1.0 wenn nichts eingetragen ist.
## eeveTD-Gegner (Rüstungsart "eeve_…") nutzen die Tabelle aus eeve.json, Randgruppen TD ("rg_…") die aus randgruppen.json.
func damage_factor(damage_type: String, armor_type: String) -> float:
	if damage_type == "" or armor_type == "":
		return 1.0
	var table: Dictionary = balance.get("damage_table", {})
	if armor_type.begins_with("eeve_"):
		table = eeve.get("damage_table", {})
	elif armor_type.begins_with("rg_"):
		table = randgruppen.get("damage_table", {})
	return float(table.get(damage_type, {}).get(armor_type, 1.0))


# --- Tower -------------------------------------------------------------------

func tower_ids() -> Array:
	var ids := towers.keys()
	ids.sort()
	return ids


func gem_ids() -> Array:
	return tower_ids().filter(func(id): return towers[id].get("category", "gem") == "gem")


func special_ids() -> Array:
	return tower_ids().filter(func(id): return towers[id].get("category", "gem") == "special")


func tier_count(id: String) -> int:
	return (towers.get(id, {}).get("tiers", []) as Array).size()


func tower_tier(id: String, tier: int) -> Dictionary:
	var tiers: Array = towers.get(id, {}).get("tiers", [])
	if tiers.is_empty():
		return {}
	return tiers[clampi(tier, 0, tiers.size() - 1)]


func tower_label(id: String, tier: int) -> String:
	var def: Dictionary = towers.get(id, {})
	var stats := tower_tier(id, tier)
	# Namen kommen deutsch aus den Daten und werden erst für die Anzeige übersetzt
	if stats.has("name"):
		return tr(str(stats.name))
	var name := tr(str(def.get("name", id)))
	if def.get("category", "gem") == "gem":
		return "%s %s" % [tr(TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]), name]
	if tier_count(id) > 1:
		return tr("%s (Stufe %d)") % [name, tier + 1]
	return name


## Würfelt einen zufälligen Gem. Rückgabe: [id, tier]
func roll_gem(chance_level: int, rng: RandomNumberGenerator) -> Array:
	var ids := gem_ids()
	if ids.is_empty():
		return ["", 0]
	var id: String = ids[rng.randi() % ids.size()]
	var levels: Array = balance.get("chance_levels", [{"weights": [1]}])
	var weights: Array = levels[clampi(chance_level, 0, levels.size() - 1)].get("weights", [1])
	var total := 0.0
	for wgt in weights:
		total += float(wgt)
	var roll := rng.randf() * total
	var tier := 0
	for i in weights.size():
		roll -= float(weights[i])
		if roll < 0.0:
			tier = i
			break
	return [id, mini(tier, tier_count(id) - 1)]
