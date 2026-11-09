class_name YoutdEnemy
extends Enemy
## Gegner in YouTD: Modell, Weg und Lebensbalken. Leben, Rüstung, Tempo und Buffs rechnet der Kern (YtCreep aus
## scripts/youtd/rt/, portiert aus YouTD 2): Größe (Masse, Normal, Luft, Champion, Boss, Challenge), Rasse,
## Rüstungstyp (Hel, Myt, Lua, Sol, Sif, Zod) und die Eigenschaften der Welle als Buffs (scripts/youtd/specials/).
## Leben spiegelt der Kern in hp/max_hp; stirbt er, legt yt_died() die Leiche ab und meldet den Kill.

var level := 1               ## Welle, aus der er stammt
var creep_size := "normal"
var race := "orc"
var specials: Array = []     ## Eigenschaften, die für ihn gelten
var base_hp := 0.0           ## Grundleben vor den Eigenschaften (Spielstand)
var base_armor := 0.0
var core: YtCreep = null
var asc_speed := 1.0         ## Tempo-Faktor der Aufstiegsstufe (ascension.gd)
var asc_speed_add := 0.0


## w: Welle aus YoutdWaves, size: Größe dieses Gegners. hp: eigene Leben (Kinder aus Eigenschaften), sonst aus der Welle.
func setup_youtd(g, w: Dictionary, size_id: String, p: PackedVector2Array, hp_factor: float, hp_override := -1.0, lane_id := 0) -> void:
	level = int(w.level)
	lane = lane_id
	if g != null and g.has_method("ascension_mods") and int(g.ascension) > 0:
		var m: Dictionary = g.ascension_mods()
		asc_speed = float(m.speed)
		asc_speed_add = float(m.speed_add)
	creep_size = size_id
	race = str(w.race)
	var rules := YoutdData.rules()
	var sz: Dictionary = rules.get("sizes", {}).get(size_id, {})
	for id in w.get("specials", []):
		if YoutdWaves.special_applies(id, size_id):
			specials.append(id)
	var hp_value := float(w.hp) * float(sz.get("hp", 1.0)) * (1.0 + YoutdWaves.hp_modifier(specials)) * hp_factor
	if hp_override > 0.0:
		hp_value = hp_override
	base_hp = hp_value
	base_armor = float(w.armor)
	setup(g, def_for(size_id, race, hp_value, float(w.armor), str(w.armor_type)), {}, p)
	core = YtCreep.new()
	core.body = self
	core.set_properties(YtPlayer.of(lane), YtCreepSize.from_string(size_id.replace("_", " ")), YtArmorType.from_string(armor_type),
			YtCreepCategory.from_string(race), hp_value, armor, level)
	add_child(core)
	if ground_y != 0.0:  # unten in der Schlucht: Geschosse zielen auf die richtige Höhe
		core.set_z(ground_y * YtWorld.WC3)
		core._target_height = core.get_z()
	YtWaveSpecial.apply_to_creep(specials, core)
	core.set_health(core.get_overall_health())


## Werte für Enemy.setup; Mitspieler im Koop legen ihre Anzeige-Gegner damit an (youtd_game.gd → enemy_def).
static func def_for(size_id: String, race_id: String, hp_value: float, armor_value: float, armor_type_id: String) -> Dictionary:
	var d := {
		"id": "youtd_%s:%s" % [size_id, race_id],
		"hp": hp_value,
		"speed": YoutdData.units(YtConstants.DEFAULT_MOVE_SPEED),
		"armor": armor_value,
		"armor_type": armor_type_id,
		"bounty": 0,
		"damage": 0,
		"flying": size_id == "air",
		"boss": size_id == "boss" or size_id == "challenge_boss",
		"color": _race_color(race_id),
		"size": _visual_size(size_id),
	}
	if size_id == "mass" or size_id == "challenge_mass":
		d["shape"] = "pyramid"
	return d


static func _visual_size(size_id: String) -> float:
	match size_id:
		"mass":
			return 0.8
		"champion":
			return 1.35
		"boss":
			return 1.25
		"challenge_mass":
			return 1.0
		"challenge_boss":
			return 1.6
	return 1.0


static func _race_color(r: String) -> String:
	match r:
		"undead":
			return "#9fb0a8"
		"magic":
			return "#b48cff"
		"nature":
			return "#6fbf5a"
		"orc":
			return "#c9764a"
		"humanoid":
			return "#d9c29a"
		"challenge":
			return "#ffd040"
	return "#cccccc"


## Anteil der Leben, die er schon verloren hat (0..1, niedrigster Stand wie in YouTD 2).
func damage_done() -> float:
	if core != null and is_instance_valid(core):
		return clampf(core.get_damage_done(), 0.0, 1.0)
	return clampf(1.0 - hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0


## Schaden von außerhalb der YouTD-Laufzeit (z. B. Debug): als Zauberschaden ohne Verursacher.
func take_damage(amount: float, _damage_type := "") -> float:
	return take_raw_damage(amount)


func take_raw_damage(amount: float) -> float:
	if dead or core == null:
		return 0.0
	var before := core.get_health()
	core.set_health(before - amount)
	if core.get_health() <= 0.0:
		core._killed_by_unit(null)
	return before - core.get_health()


## Nur Darstellung: der Modus-Kern hat Vorrang vor den allgemeinen Status-Timern.
func visual_status_flags() -> int:
	var flags := super.visual_status_flags()
	if core != null and is_instance_valid(core):
		if core.get_current_movespeed() < core.get_base_movespeed() - 0.1:
			flags |= 1
		if core.is_stunned():
			flags |= 4
		if core.get_overall_armor() < core.get_base_armor() - 0.01:
			flags |= 8
	return flags


## Tempo und Betäubung kommen jedes Bild aus dem Kern (Verlangsamung, Schnell usw. sind Modifikatoren).
func _process(delta: float) -> void:
	if core != null and is_instance_valid(core) and not dead:
		speed = YoutdData.units(core.get_current_movespeed()) * asc_speed + asc_speed_add
		if core.is_stunned():
			stun_time = maxf(stun_time, delta)
	super._process(delta)


## Der Kern ist gestorben (YtCreep._on_death): Leiche ablegen, Kill melden.
func yt_died() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	_leave_corpse()
	game.on_enemy_killed(self)


## Ein Skript hat den Gegner versetzt (pos ist schon neu): Weg ab dem nächsten Punkt, Strecke neu.
func yt_moved() -> void:
	if path.size() < 2:
		return
	var best := INF
	var best_i := 1
	var best_p := pos
	for i in range(1, path.size()):
		var q := Geometry2D.get_closest_point_to_segment(pos, path[i - 1], path[i])
		var d := q.distance_squared_to(pos)
		if d < best:
			best = d
			best_i = i
			best_p = q
	path_index = best_i
	traveled = 0.0
	for i in range(1, best_i):
		traveled += path[i - 1].distance_to(path[i])
	traveled += path[best_i - 1].distance_to(best_p)
	_sync_position()


## Lebensbalken: Bosse und Champions immer, Masse nie, die anderen auf dem letzten Stück wie in GemTD.
func bar_visible() -> bool:
	if creep_size == "champion":
		return true
	return super.bar_visible()


## Name fürs Gegner-Fenster: „Champion · Ork“.
func display_name() -> String:
	return "%s · %s" % [YoutdData.size_name(creep_size), YoutdData.race_name(race)]
