class_name YoutdTower
extends Tower
## Tower in YouTD: Modell und Platz auf dem Feld. Werte, Angriff, Erfahrung und Fähigkeiten rechnet der Kern
## (YtTower aus scripts/youtd/rt/, portiert aus YouTD 2) mit dem Tower-Skript scripts/youtd/towers/<script>.gd.
## Werte aus data/youtd/towers.json (WC3-Einheiten, umgerechnet über YoutdData.units). Items und Öle liegen hier
## und wirken über einen Modifikator im Kern; Weisheits-Boni des Spielers bringt der Kern selbst mit.

const PREFIX := "youtd_"
## Modelle je Element (Stylized Nature MegaKit und Kristalle, CC0). solid = eigene Farben, sonst in Elementfarbe.
const N := "res://assets/models/nature/%s.glb"
const C := "res://assets/models/crystals/%s.glb"
const LOOKS := {
	"nature": [["bush_common_flowers", true], ["pine_5", true], ["mushroom_red_group", true], ["plant_1_big", true],
		["common_tree_3", true], ["fern_1", true], ["mushroom_tan_group", true], ["pine_2", true], ["lily_large", true]],
	"ice": [["crystal_08", false], ["crystal_11", false], ["crystal_13", false], ["crystal_19", false], ["crystal_23", false]],
	"fire": [["campfire_pit", true, 0.5, 0.3], ["pot_large", true, 0.5, 0.7], ["campfire_stones", true, 0.45, 0.2],
		["campfire_bricks", true, 0.35, 0.2], ["rock_tall_e", true, 0.45, 0.95]],
	"astral": [["statue_obelisk", false], ["statue_ring", false], ["crystal_20", false], ["statue_column", false]],
	"darkness": [["statue_column_damaged", false], ["statue_head", false], ["mushroom_laetiporus", false], ["stone_tall_g", false]],
	"iron": [["rock_tall_a", true], ["statue_block", false], ["rock_medium_3", true], ["stone_tall_a", false]],
	"storm": [["stone_tall_a", false], ["crystal_24", false], ["statue_obelisk", false], ["crystal_18", false]],
}

var yid := ""              ## Tower-ID aus YouTD 2
var yt: Dictionary = {}    ## Werte aus towers.json
var core: YtTower = null   ## Werte, Angriff und Fähigkeiten (YouTD-2-Laufzeit)
var items: Array = []      ## eingelegte Items (YtItem, höchstens slots())
var oils: Array = []       ## verbrauchte Öle (YtItem, wirken dauerhaft)
var spent := 0             ## Gold, das in diesen Tower geflossen ist (Verkaufswert)

var xp: float:
	get:
		return core.get_exp() if core != null else 0.0
var level: int:
	get:
		return core.get_level() if core != null else 0

static var _mod_defaults := {}


## Tower aus YouTD setzen (Bauen und Aufwerten). Beim Aufwerten übernimmt der neue Kern Erfahrung, Level,
## Kills und Mana vom alten (YtTower._ready mit preceding_tower).
func set_youtd(id: String) -> void:
	yid = id
	yt = YoutdData.tower(id)
	set_tower(PREFIX + id, maxi(int(yt.get("tier", 1)) - 1, 0))
	var old := core
	# Items und Öle gehen vom alten Kern auf den neuen über (wie YtTower._ready mit Vorgänger in YouTD 2)
	var carried: Array = oils + items
	for it in carried:
		it._remove_from_tower()
	var player := YtPlayer.of(owner_player)
	core = YtTower.make(int(id), player, old)
	core.body = self
	add_child(core)
	if old != null:
		old.remove_from_game()
	items = []
	oils = []
	for it in carried:
		if it.is_oil() or items.size() < slots():
			it.add_to_tower(core)
		else:
			it.place = YtItem.Place.GROUND
			it.fly_to_stash(0.0)


func set_tower(id: String, t: int) -> void:
	tower_id = id
	tier = t
	var el := str(yt.get("element", ""))
	color = YoutdData.element_color(el)
	def = _look()
	def["name"] = str(yt.get("name", id))
	def["color"] = "#" + color.to_html(false)
	def["category"] = "special"
	stats = {
		"range": range_cells(),
		"cooldown": float(yt.get("cooldown", 1.0)) if can_attack() else 0.0,
		"damage": yt.get("damage", [0, 0]),
		"targets": str(yt.get("targets", "both")),
		"damage_type": str(yt.get("attack_type", "")),
		"abilities": [],
	}
	place_at(cell)
	_build_visual()


func _look() -> Dictionary:
	# Passendes Modell je Familie aus data/tower_models.json, sonst Element-Modell (Kristall bleibt Element-Kristall)
	var own := TowerModels.look("youtd", str(int(yt.get("family", 0))))
	if not own.is_empty() and own.model != TowerModels.CRYSTAL:
		return own
	var list: Array = LOOKS.get(str(yt.get("element", "")), [])
	if list.is_empty():
		return {}
	var l: Array = list[int(yt.get("family", 0)) % list.size()]
	var path: String = (C if str(l[0]).begins_with("crystal") else N) % l[0]
	var d := {"model": path, "model_tint": not bool(l[1]), "model_solid": bool(l[1])}
	if l.size() > 2:
		d["flame"] = l[2]
		d["flame_height"] = l[3]
	return d


## Werte für FxData und Sfx (Schuss- und Treffereffekte nach Elementfarbe).
static func fx_def(id: String) -> Dictionary:
	var t := YoutdData.tower(id.trim_prefix(PREFIX))
	if t.is_empty():
		return {}
	var aliases := {"ice": "eis", "nature": "natur", "fire": "feuer", "astral": "licht", "darkness": "dunkel", "iron": "physisch", "storm": "blitz"}
	var out := {"color": "#" + YoutdData.element_color(str(t.get("element", ""))).to_html(false), "element": aliases.get(str(t.get("element", "")), "")}
	for key in ["lightning", "shot_fx", "hit_fx", "shot_sfx"]:
		if t.has(key):
			out[key] = t[key]
	return out


func label() -> String:
	return str(yt.get("name", tower_id))


# --- Werte (aus dem Kern) ---------------------------------------------------------

## Items wurden eingelegt oder herausgenommen (YtItem): Auswahlkarte neu zeichnen.
func items_changed() -> void:
	if game != null and game.selected == self:
		game._refresh_hud()


## Zauber des Towers und seiner Items (Autocasts), in dieser Reihenfolge.
func autocasts() -> Array:
	if core == null:
		return []
	var list: Array = core.get_autocast_list().duplicate()
	for it in items:
		var ac: YtAutocast = it.get_autocast()
		if ac != null and ac.get_caster() == core:
			list.append(ac)
	return list


## Modifikator k als Abweichung vom Grundwert (0 = keiner), z. B. 0.25 für +25 % Schaden.
func mod(k: String) -> float:
	if core == null:
		return 0.0
	if _mod_defaults.is_empty():
		var u := YtUnit.new()
		_mod_defaults = u._mod_value_map.duplicate()
		u.free()
	var t := YtModificationType.from_string(k)
	return float(core._mod_value_map.get(t, 0.0)) - float(_mod_defaults.get(t, 0.0))


func range_cells() -> float:
	var r := core.get_range() if core != null else float(yt.get("range", 800))
	return YoutdData.units(r + YtConstants.RANGE_CHECK_BONUS_FOR_TOWERS)


func can_attack() -> bool:
	return bool(yt.get("attack", true)) and float(yt.get("cooldown", 0)) > 0.0


func damage_type() -> String:
	return str(yt.get("attack_type", ""))


func target_mode() -> String:
	return str(yt.get("targets", "both"))


func kill_bonus() -> float:
	return 0.0


## Zeit zwischen zwei Angriffen mit allen Tempo-Boni.
func cooldown() -> float:
	return core.get_current_attack_speed() if core != null else float(yt.get("cooldown", 1.0))


## Schaden eines Angriffs vor Krit und Rüstung, kleinster und größter Wert.
func base_damage_range() -> Array:
	if core == null:
		return yt.get("damage", [0, 0])
	var out := []
	for d in [core.get_damage_min(), core.get_damage_max()]:
		var b := (float(d) + core.get_base_damage_bonus()) * core.get_base_damage_bonus_percent()
		out.append(maxf(0.0, (b + core.get_damage_add_overall()) * core.get_damage_add_percent()))
	return out


func crit_chance() -> float:
	return minf(core.get_prop_atk_crit_chance(), YtConstants.ATK_CRIT_CHANCE_CAP) if core != null else 0.0


func crit_damage() -> float:
	return core.get_prop_atk_crit_damage() if core != null else 1.0


## Erfahrung dazu (mit dem Erfahrungs-Faktor des Towers), Level bis zum höchsten Tower-Level des Spielers.
func add_exp(amount: float) -> void:
	if core != null and amount > 0.0:
		core.add_exp(amount)


## Item-Plätze dieses Towers.
func slots() -> int:
	return core.get_inventory_capacity() if core != null else YoutdData.item_slots(yid)


# --- Kampf läuft im Kern -------------------------------------------------------------

func _process(delta: float) -> void:
	_animate(delta)
	if core != null:
		kills = core.get_kills()
		total_damage = core.get_total_damage()


## Der Kern greift an: Schussgeräusch (das Geschoss zeichnet YtProjectileView).
func yt_attacked(_target) -> void:
	if game != null and game.effects != null and game.effects.sounds:
		Sfx.play_shot(tower_id, tier)



## Verkaufen: Kern abmelden (Fähigkeit räumt auf), dann den Tower entfernen.
func remove_core() -> void:
	if core != null and is_instance_valid(core) and core.is_inside_tree():
		core.remove_from_game()
	core = null


# --- Darstellung -------------------------------------------------------------

## Kein Drehen: Bäume und Statuen stehen, jeder Tower leicht anders ausgerichtet.
func _animate(delta: float) -> void:
	_time += delta
	if _gem and _gem.rotation.y == 0.0:
		_gem.rotation.y = float(hash(cell)) / float(1 << 31) * TAU
	if _new_ring:
		_new_ring.visible = false


## Werte fürs Infofenster (Aufbau wie TowerStats.view).
func view() -> Dictionary:
	var tiles := []
	var r := range_cells()
	tiles.append({"key": "range", "caption": tr("Reichweite"), "value": TowerStats.num(r), "mod": false,
			"rows": [[tr("Grundwert"), str(int(yt.get("range", 0))), ""]], "total": []})
	if can_attack():
		var srows := [[tr("Grundwert"), TowerStats.num(float(yt.get("cooldown", 1.0)), 2) + " s", ""]]
		var speed := core.get_attack_speed_modifier() - 1.0 if core != null else 0.0
		if absf(speed) > 0.0001:
			srows.append([tr("Level, Items und Boni"), TowerStats.pct(speed), "up" if speed > 0.0 else "down"])
		tiles.append({"key": "speed", "caption": tr("Tempo"), "value": TowerStats.num(cooldown(), 2) + " s",
				"mod": srows.size() > 1, "rows": srows, "total": [tr("Gesamt"), TowerStats.num(cooldown(), 2) + " s"]})
		var dmg: Array = yt.get("damage", [0, 0])
		var now := base_damage_range()
		var drows := [[tr("Grundwert"), TowerStats.dmg_text(float(dmg[0]), float(dmg[1])), ""]]
		var extra := float(now[0]) / maxf(float(dmg[0]), 1.0) - 1.0
		if absf(extra) > 0.0001:
			drows.append([tr("Level, Items und Boni"), TowerStats.pct(extra), "up" if extra > 0.0 else "down"])
		var total := TowerStats.dmg_text(float(now[0]), float(now[1]))
		tiles.append({"key": "damage", "caption": tr("Schaden"), "value": total, "mod": drows.size() > 1, "rows": drows,
				"total": [tr("Gesamt"), total]})
		tiles.append({"key": "type", "caption": tr("Angriff"), "value": YoutdData.attack_name(damage_type()), "mod": false,
				"rows": [], "total": []})
	if core != null and core.get_base_mana() > 0.0:
		tiles.append({"key": "mana", "caption": tr("Mana"), "value": "%d / %d" % [floori(core.get_mana()), floori(core.get_overall_mana())],
				"mod": false, "rows": [], "total": []})
	var abilities := []
	abilities.append(tr("Kritisch: %s %% Chance, ×%s Schaden") % [TowerStats.num(crit_chance() * 100.0), TowerStats.num(crit_damage(), 2)])
	for line in ability_lines():
		abilities.append(line)
	if int(yt.get("multishot", 0)) > 1:
		abilities.append(tr("Mehrfachschuss: %d Ziele") % int(yt.multishot))
	for ring in yt.get("splash", []):
		abilities.append(tr("Flächenschaden: %d %% im Umkreis %d") % [roundi(float(ring[1]) * 100), int(ring[0])])
	var bounce: Array = yt.get("bounce", [])
	if not bounce.is_empty():
		abilities.append(tr("Abpraller: %d Ziele, −%d %% je Sprung") % [int(bounce[0]), roundi(float(bounce[1]) * 100 if bounce.size() > 1 else 0.0)])
	for k in ["MOD_DMG_TO_MASS", "MOD_DMG_TO_NORMAL", "MOD_DMG_TO_AIR", "MOD_DMG_TO_CHAMPION", "MOD_DMG_TO_BOSS",
			"MOD_DMG_TO_UNDEAD", "MOD_DMG_TO_MAGIC", "MOD_DMG_TO_NATURE", "MOD_DMG_TO_ORC", "MOD_DMG_TO_HUMANOID"]:
		var v := mod(k)
		if absf(v) > 0.0001:
			abilities.append(tr("%s Schaden gegen %s") % [TowerStats.pct(v), YoutdData.target_name(k.trim_prefix("MOD_DMG_TO_"))])
	var kills_info := {"kills": kills, "rank": level, "bonus": 0.0, "per_rank": 1, "step": 0.0, "max": 0.0, "maxed": true,
			"next_at": 0, "missing": 0, "next_bonus": 0.0, "progress": 0, "total_damage": total_damage}
	return {"subtitle": "%s · %s · %s" % [YoutdData.element_name(str(yt.get("element", ""))), YoutdData.rarity_name(str(yt.get("rarity", ""))),
			TowerStats.targets_text(target_mode())], "tiles": tiles, "kills": kills_info, "abilities": abilities, "description": YoutdData.description("towers", yid)}


## Fähigkeiten des Towers mit Namen (aus YouTD 2, englisch wie die Tower-Namen), Auren, Zauber mit Abklingzeit
## und Mana, dazu die Werte, die das Tower-Skript selbst meldet (on_tower_details).
func ability_lines() -> Array:
	var out := []
	for id in yt.get("abilities", []):
		var a := YtAbilityData.ability(int(id))
		if not a.is_empty():
			out.append(_with_text(tr("Fähigkeit: %s") % str(a.get("name", "")), "abilities", str(id)))
	for id in yt.get("auras", []):
		var a := YtAbilityData.aura(int(id))
		if not a.is_empty() and not bool(a.get("hidden", false)) and str(a.get("name", "")) != "":
			out.append(_with_text(tr("Aura: %s (Umkreis %d)") % [str(a.name), int(a.get("range", 0))], "auras", str(id)))
	if core != null:
		for ac in core.get_autocast_list():
			var line := tr("Zauber: %s") % ac.get_autocast_name()
			var parts := []
			if ac.get_cooldown() > 0.0:
				parts.append(tr("alle %s s") % TowerStats.num(ac.get_cooldown(), 1))
			if ac.get_mana_cost() > 0:
				parts.append(tr("%d Mana") % ac.get_mana_cost())
			if not ac.can_use_auto_mode():
				parts.append(tr("von Hand"))
			if not parts.is_empty():
				line += " (" + ", ".join(parts) + ")"
			out.append(_with_text(line, "autocasts", str(ac.get_id())))
		var board := core.on_tower_details()
		if board != null:
			for i in board.size():
				if board.get_key(i) != "":
					out.append("%s: %s" % [board.get_key(i), board.get_value(i)])
	return out


## Zeile mit der Beschreibung aus YouTD 2 darunter (falls vorhanden).
static func _with_text(line: String, kind: String, id: String) -> String:
	var text := YoutdData.description(kind, id)
	return line + ("\n" + text if text != "" else "")


## Der Kern hat den Tower versetzt (Chrono Jumper): Modell mitnehmen.
func yt_moved() -> void:
	position = Board3D.to_3d(pos)
