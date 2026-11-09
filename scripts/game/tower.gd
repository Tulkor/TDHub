class_name Tower
extends Node3D
## Ein Tower (oder eine Falle) auf dem Feld. Alle Werte kommen aus data/towers/<id>.json.
## cell ist das Feld oben links der 2×2 belegten Felder. Logische Position `pos` in Einheiten
## (1 = eine Towerbreite) als Vector2, die 3D-Position folgt daraus.

const GEM_SHADER := preload("res://assets/shaders/gem.gdshader")
## Deckkraft für Modelle mit eigener Textur ("model_tint": false)
const GEM_OPACITY_TEXTURED := 0.85
## Helligkeit der Lichtscheibe im Sockel (über 1 = leuchtet im Glow)
const BASE_LIGHT_ENERGY := 1.3
## Drehgeschwindigkeit der Gems (rad/s): zur Auswahl in dieser Runde, und fixiert
const SPIN_NEW := 0.425
const SPIN_FIXED := 0.325
const BASE_HEIGHT := 0.12
const BASE_HEIGHT_SPECIAL := 0.18
## Höchstens so hoch (Towerbreiten) wird ein Special, auch wenn das Modell schmal und lang ist
const GEM_MAX_HEIGHT := 1.3
## Gems je Qualität (Splitter … Großartig): Anzahl Kristalle auf dem Sockel und die Kiste
## (Breite, Höhe in Sockelbreiten), in die jeder Kristall passt. Splitter sind viele kleine,
## mit jeder Stufe werden es weniger, dafür größere. Splitter liegen als kleine, matte Scherben
## umgekippt auf dem Sockel, Fehlerhafte stehen aufrecht und deutlich größer.
const GEM_CLUSTERS := [
	[5, 0.22, 0.27],
	[4, 0.37, 0.5],
	[3, 0.44, 0.6],
	[2, 0.56, 0.78],
	[1, 0.78, 1.0],
	[1, 0.92, 1.25],
]
## Platz der Kristalle auf dem Sockel (in Sockelbreiten) je Anzahl
const CLUSTER_SPOTS := {
	1: [Vector2.ZERO],
	2: [Vector2(-0.17, 0.15), Vector2(0.17, -0.15)],
	3: [Vector2(0.0, -0.22), Vector2(-0.19, 0.11), Vector2(0.19, 0.11)],
	4: [Vector2(-0.18, -0.18), Vector2(0.18, -0.18), Vector2(0.18, 0.18), Vector2(-0.18, 0.18)],
	5: [Vector2.ZERO, Vector2(-0.21, -0.21), Vector2(0.21, -0.21), Vector2(0.21, 0.21), Vector2(-0.21, 0.21)],
}
## Größenunterschiede innerhalb eines Clusters, damit es natürlicher aussieht
const CLUSTER_VARY := [1.0, 0.86, 0.94, 0.8, 0.9]
## Splitter: Neigung der umgekippten Scherben (Grad) und weniger Leuchten als heile Gems
const SHARD_TILT := [62.0, 74.0, 56.0, 80.0, 68.0]
const SHARD_GLOW := 0.4
static var _slab_cache := {}
## eeveTD: wie die Tower nachts hervorgehoben werden (Lukas, 2026-10-29, zur Wahl):
## "sockel" = vier Lampen in den Sockelecken leuchten den Tower an, "kontur" = weiße Kontur, "" = nichts.
static var eeve_accent := "sockel"
const SOCKEL_LIGHT := Color(1.0, 0.8, 0.55)

var game  # game.gd
var cell := Vector2i.ZERO
var pos := Vector2.ZERO
var tower_id := ""
var _spin := true  ## Modell dreht sich langsam (nicht bei Figuren und Gegenständen)
var tier := 0
var def: Dictionary = {}
var stats: Dictionary = {}
var color := Color.WHITE

var is_new := false   ## in dieser Runde gesetzt, noch nicht ausgewählt
var owner_player := 0  ## Spielernummer (Koop): nur er wählt, kombiniert und wertet auf, bekommt das Kopfgeld
var selected := false
var speed_bonus := 0.0   ## von Tempo-Auren anderer Tower
var damage_bonus := 0.0  ## von Schadens-Auren anderer Tower
var speed_source := ""   ## Name des Towers, dessen Tempo-Aura gerade wirkt (fürs Infofenster)
var damage_source := ""  ## Name des Towers, dessen Schadens-Aura gerade wirkt
var xp_factor := 1.0     ## Kills zählen so viel für die Kill-Ränge (eeveTD: schwarzer Marmor = 2)
var bounty_bonus := 0.0  ## Kopfgeld-Aura (eeveTD-Minen): so viel mehr Gold für Kills dieses Towers
var xp_bonus := 0.0      ## Erfahrungs-Aura (eeveTD-Weisheit): Kills zählen um so viel mehr
var speed_malus := 0.0   ## eeveTD-Gegner mit Tempo-Bremse: so viel weniger Angriffstempo (0.45 = −45 %)
var rooted_time := 0.0   ## eeveTD-Gegner Fesselnd: so lange greift der Tower nicht an
## Roguelike-Boni des Besitzers (rogue.gd), Zuschläge wie 0.2 = +20 %
var rogue_damage := 0.0
var rogue_speed := 0.0
var rogue_range := 0.0
var rogue_abilities: Array = []  ## Fähigkeiten aus Roguelike-Boni (zusätzlich zu stats.abilities)
var rogue_anti_air := false      ## Roguelike „Luftabwehr“: Bodentower greift auch Flieger an
var rogue_fx: Dictionary = {}    ## Roguelike: Flächen, Prozentschaden, Henker (rogue.gd → on_hit), leer = keine
var bonus_label := "Roguelike-Bonus"  ## Name der Boni aus set_rogue() im Infofenster (eeveTD: Items und Marktplatz)
var flat_damage := 0.0  ## fester Zusatzschaden je Schuss nach allen Prozenten (eeveTD-Items)
var _all_abilities: Array = []
var cooldown_left := 0.0
var kills := 0
## Level und EP (leveling.gd, data/leveling.json): EP kommen über gain_ep(), vor allem durch Kills
var ep := 0.0
var lvl := 0      ## Level (YouTD-Tower haben ihr eigenes level)
var level_damage := 0.0
var level_speed := 0.0
var level_range := 0.0
var level_abilities: Array = []  ## mit dem Level freigeschaltete Fähigkeiten (zusätzlich zu stats.abilities)
var _lv: Dictionary = {}         ## Level-Profil dieses Towers in diesem Modus ({} = keine Level)
var moves_left := 0  ## wie oft eine Falle noch verschoben werden darf
var total_damage := 0.0

var _visual: Node3D
var _gem: Node3D
var base_tint := Color(0, 0, 0, 0)  ## Sockel in dieser Farbe (eeveTD: Bonusfeld darunter), Alpha 0 = normal
var _base_mat: StandardMaterial3D
var _new_ring: MeshInstance3D
var _select_ring: MeshInstance3D
var _range_ring: MeshInstance3D
var _preview_ring: MeshInstance3D  ## Reichweite nach einem Upgrade (Hover über den Knopf)
var _time := 0.0

static var _octahedron: ArrayMesh


func setup(g, c: Vector2i, id: String, t: int) -> void:
	game = g
	cell = c
	set_tower(id, t)


func set_tower(id: String, t: int) -> void:
	tower_id = id
	tier = t
	def = Database.towers.get(id, {})
	stats = Database.tower_tier(id, t)
	color = Color.from_string(str(def.get("color", "#ffffff")), Color.WHITE)
	_lv = Leveling.for_game(game, id)
	_apply_level(false)
	place_at(cell)
	_build_visual()


## Felder pro Kante: Tower 2×2, Fallen 3×3 (ab dem Anker cell).
func footprint_size() -> int:
	return Board3D.TRAP_CELLS if is_trap() else Board3D.TOWER_CELLS


func place_at(c: Vector2i) -> void:
	cell = c
	pos = Board3D.footprint_center(c, footprint_size())
	position = Board3D.to_3d(pos)


func label() -> String:
	return Database.tower_label(tower_id, tier)


func is_trap() -> bool:
	return str(def.get("kind", "tower")) == "trap"


func range_cells() -> float:
	return float(stats.get("range", 3.0)) * range_mult()


## Faktor auf die Reichweite aus Roguelike-Boni/Items und Level.
func range_mult() -> float:
	return 1.0 + rogue_range + level_range


func abilities() -> Array:
	if rogue_abilities.is_empty() and level_abilities.is_empty():
		return stats.get("abilities", [])
	return _all_abilities


func _refresh_abilities() -> void:
	_all_abilities = stats.get("abilities", []) + rogue_abilities + level_abilities


func ability(type: String) -> Dictionary:
	for ab in abilities():
		if ab.get("type", "") == type:
			return ab
	return {}


func target_mode() -> String:
	var mode := str(stats.get("targets", def.get("targets", "both")))
	return "both" if rogue_anti_air and mode == "ground" else mode


func can_target(e) -> bool:
	match target_mode():
		"air":
			return e.flying
		"ground":
			return not e.flying
	return true


func can_attack() -> bool:
	var dmg: Array = stats.get("damage", [0, 0])
	return float(stats.get("cooldown", 0)) > 0.0 and (float(dmg[1]) > 0.0 or not ability("wave_damage").is_empty())


## Reichweite gegen ein bestimmtes Ziel (manche Fallen haben gegen Flieger mehr Reichweite).
func range_for(e) -> float:
	if e.flying and stats.has("range_air"):
		return float(stats.range_air) * range_mult()
	return range_cells()


## Fallen mit kurzer Reichweite treffen alles auf ihrer 3×3-Fläche, alle anderen im Kreis.
func in_range(e) -> bool:
	var r := range_for(e)
	if is_trap() and r <= Board3D.TRAP_CELLS * Board3D.CELL:
		var half := Board3D.TRAP_CELLS * Board3D.CELL / 2.0
		return absf(e.pos.x - pos.x) <= half and absf(e.pos.y - pos.y) <= half
	return e.pos.distance_to(pos) <= r


func damage_type() -> String:
	return str(stats.get("damage_type", def.get("damage_type", "")))


## Schadensbonus aus dem Level (in GemTD die Kill-Ränge wie in WC3: +10 % je 10 Kills, data/leveling.json).
func kill_bonus() -> float:
	return level_damage


func cooldown() -> float:
	return float(stats.get("cooldown", 1.0)) / (1.0 + speed_bonus + rogue_speed + level_speed) / maxf(1.0 - speed_malus, 0.1)


# --- Level und EP ----------------------------------------------------------------

## Steigt dieser Tower in diesem Modus im Level?
func has_levels() -> bool:
	return not _lv.is_empty()


func level_profile() -> Dictionary:
	return _lv


## EP gutschreiben (Erfahrungs-Auren und eeveTD-Marmor zählen mit). Gibt die Zahl gewonnener Level zurück.
func gain_ep(amount: float) -> int:
	if _lv.is_empty() or amount <= 0.0:
		return 0
	ep += amount * (xp_factor + xp_bonus) * float(_lv.get("ep_factor", 1.0))
	var before := lvl
	_apply_level(true)
	return lvl - before


## EP direkt setzen (Spielstand, Koop, Kombinieren), ohne Faktoren.
func set_ep(value: float) -> void:
	ep = maxf(value, 0.0)
	_apply_level(false)


## Ein Gegner zählt als Kill dieses Towers: Kill und EP.
func credit_kill(e) -> void:
	kills += 1
	if not _lv.is_empty():
		gain_ep(Leveling.kill_ep(_lv, e))


## Level aus den EP und die Boni daraus. announce: ein Aufstieg zeigt sich (Text über dem Tower).
func _apply_level(announce: bool) -> void:
	var old := lvl
	var old_abs := level_abilities
	var old_range := level_range
	if _lv.is_empty():
		lvl = 0
		level_damage = 0.0
		level_speed = 0.0
		level_range = 0.0
		level_abilities = []
	else:
		lvl = Leveling.level_at(_lv, ep)
		if lvl == old and announce:
			return
		var b := Leveling.bonuses(_lv, lvl)
		level_damage = b.damage
		level_speed = b.speed
		level_range = b.range
		level_abilities = b.abilities
	_refresh_abilities()
	if not is_equal_approx(old_range, level_range):
		_rebuild_range_ring()
	if lvl > old and announce:
		_level_up(old)
	# Neue Auren (Fähigkeiten aus dem Level) wirken erst nach dem nächsten Auren-Durchlauf
	if old_abs != level_abilities and game != null and game.has_method("_update_auras") and is_inside_tree():
		game._update_auras()


## Aufstieg sichtbar machen: „LEVEL n“ steigt über dem Tower auf und verblasst (Modi können mehr anhängen).
func _level_up(_old_level: int) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var l := Label3D.new()
	l.text = tr("LEVEL %d") % lvl
	l.font = UiTheme.font(true)
	l.font_size = 44
	l.pixel_size = 0.006
	l.modulate = UiTheme.GOLD
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, 1.6, 0)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", 2.4, 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.8)
	tw.chain().tween_callback(l.queue_free)


# --- Kampf -------------------------------------------------------------------

func _process(delta: float) -> void:
	_animate(delta)
	# Koop-Mitspieler: geschossen wird nur beim Host
	if game == null or game.mirror or not game.is_wave_running():
		return
	_apply_enemy_auras(delta)
	if rooted_time > 0.0:
		rooted_time -= delta
		return
	if not can_attack():
		return
	# höchstens ein Frame Rückstand, sonst feuert ein Tower nach langer Pause mehrfach hintereinander
	cooldown_left = maxf(cooldown_left - delta, -delta)
	# Geschossen wird am Bildende. Wird der Tower erst im nächsten halben Bild bereit, schießt er schon jetzt,
	# sonst kämen die Schüsse bei 4× im Mittel ein halbes Bild zu spät (und am Rand der Reichweite zu selten).
	if cooldown_left > delta * 0.5:
		return
	var count := 1
	var ms := ability("multishot")
	if not ms.is_empty():
		count = int(ms.targets)
	var targets: Array = game.find_targets(self, count)
	if targets.is_empty():
		return
	# Hat der Tower gewartet, zählt der Rückstand nur, solange ein Ziel schon in Reichweite war
	if cooldown_left < 0.0:
		var since := 0.0
		for e in targets:
			since = maxf(since, float(e.covered_for) if "covered_for" in e else delta)
		cooldown_left = maxf(cooldown_left, -since)
	for e in targets:
		_attack(e)
	# Überhang behalten, damit hohe Spielgeschwindigkeit (große Frames) die Feuerrate nicht senkt
	cooldown_left += cooldown()


## Auren, die auf Gegner in Reichweite wirken (z. B. Fallen oder Uran).
func _apply_enemy_auras(delta: float) -> void:
	for ab in abilities():
		var type := str(ab.get("type", ""))
		if not type in ["burn_aura", "slow_aura", "armor_aura"]:
			continue
		var mode := str(ab.get("targets", target_mode()))
		for e in game.enemies_in_radius(pos, float(ab.radius)):
			if (mode == "air" and not e.flying) or (mode == "ground" and e.flying):
				continue
			match type:
				"burn_aura":
					e.last_hit_by = owner_player
					e.last_tower = self
					total_damage += e.take_raw_damage(float(ab.dps) * delta)
					if e.dead:
						_killed(e)
				"slow_aura":
					e.apply_slow(float(ab.factor), 0.25)
				"armor_aura":
					e.apply_armor_reduction(float(ab.amount), 0.25)


func _roll_damage() -> float:
	var dmg: Array = stats.get("damage", [1, 1])
	var base := randf_range(float(dmg[0]), float(dmg[1]))
	var wd := ability("wave_damage")
	if not wd.is_empty():
		base += float(wd.per_wave) * game.current_wave()
	return base * (1.0 + damage_bonus + kill_bonus() + rogue_damage) + flat_damage


func _attack(e) -> void:
	var dmg := _roll_damage()
	var crit := ability("crit")
	var crit_chance := float(crit.get("chance", 0.0)) + float(e.crit_mark)
	if crit_chance > 0.0 and randf() < crit_chance:
		dmg *= float(crit.get("multiplier", 2.0))
	game.add_beam(position + Vector3(0, 0.9, 0), _hit_point(e), color, fx_key())
	var target_pos: Vector2 = e.pos
	_hit(e, dmg)
	var splash := ability("splash")
	if not splash.is_empty():
		for other in game.enemies_in_radius(target_pos, float(splash.radius)):
			if other != e and can_target(other):
				_hit(other, dmg * float(splash.factor))
	var cone := ability("cone")
	if not cone.is_empty() and (not cone.has("chance") or randf() < float(cone.chance)):
		_cone(target_pos, cone, dmg, e)
	var bounce := ability("bounce")
	if not bounce.is_empty():
		var hit := [e]
		var current = e
		var bdmg := dmg
		for i in int(bounce.targets):
			bdmg *= float(bounce.get("falloff", 0.8))
			var next = null
			var best := INF
			for other in game.enemies_in_radius(current.pos, float(bounce.get("radius", 2.5))):
				var d: float = other.pos.distance_to(current.pos)
				if not other in hit and can_target(other) and d < best:
					best = d
					next = other
			if next == null:
				break
			game.add_beam(_hit_point(current), _hit_point(next), color, fx_key())
			hit.append(next)
			_hit(next, bdmg)
			current = next
	if _has_projectile_mods():
		_projectile(e, target_pos, dmg)


## Treffer-Effekte. Jede Fähigkeit mit "chance" löst nur mit dieser Wahrscheinlichkeit aus.
func _hit(e, dmg: float) -> void:
	if e.dead:
		return
	if e.flying:
		var ab := ability("air_bonus")
		if not ab.is_empty():
			dmg *= float(ab.multiplier)
	for ab in abilities():
		var type := str(ab.get("type", ""))
		if not type in ON_HIT:
			continue
		if ab.has("chance") and randf() >= float(ab.chance):
			continue
		match type:
			"slow":
				e.apply_slow(float(ab.factor), float(ab.duration))
			"poison":
				e.apply_poison(float(ab.dps), float(ab.duration), self)
			"armor_reduce":
				e.apply_armor_reduction(float(ab.amount), float(ab.duration))
			"stun":
				e.apply_stun(float(ab.duration))
				dmg += float(ab.get("damage", 0.0))
			"gold_on_hit":
				game.add_gold(int(ab.get("gold", 0)) + floori(float(ab.get("gold_per_wave", 0)) * game.current_wave()), owner_player)
			"stacking_damage":
				var boom := {"damage": float(ab.death_damage), "radius": float(ab.get("death_radius", 2.0))} if float(ab.get("death_damage", 0.0)) > 0.0 else {}
				dmg += e.add_stack(float(ab.per_hit), float(ab.duration), boom, self)
			"nova":
				_nova(e, ab)
	e.last_hit_by = owner_player
	e.last_tower = self
	total_damage += e.take_damage(dmg, damage_type())
	if e.dead:
		_killed(e)
	if not rogue_fx.is_empty() and game.rogue != null:
		game.rogue.on_hit(self, e)


## Ein Gegner ist durch diesen Tower gestorben (Modi hängen hier Kill-Effekte an).
func _killed(e) -> void:
	credit_kill(e)


const ON_HIT := ["slow", "poison", "armor_reduce", "stun", "gold_on_hit", "stacking_damage", "nova"]

## Geschosse wie in Path of Exile (pierce, fork, chain). Bei jedem Treffer gilt die Reihenfolge aus PoE:
## 1. Durchbohren, solange noch Durchbohrungen übrig sind: weiter in derselben Richtung.
## 2. sonst Gabeln, solange noch Gabelungen übrig sind: zwei neue Geschosse schräg nach vorn.
## 3. sonst Verketten, solange noch Sprünge übrig sind: weiter zum nächsten Gegner im Radius.
## Nach dem ersten Ziel fliegt ein Geschoss noch eine Reichweite weit (Gabeln: "reach", Ketten: "radius").
## Jedes Geschoss trifft denselben Gegner nur einmal; Gabel-Geschosse erben die getroffenen Gegner
## und die übrigen Gabelungen und Sprünge. Die Schüsse sind sofort da (wie die Strahlen), Flächenschaden
## und Treffer-Effekte gelten bei jedem Treffer.
const SHOT_HIT_RADIUS := 0.35  ## so nah (Towerbreiten) muss ein Gegner an der Flugbahn sein
const SHOT_MAX_HITS := 64      ## Obergrenze pro Schuss, damit sich Gabeln und Ketten nicht aufschaukeln


func _has_projectile_mods() -> bool:
	return not (ability("pierce").is_empty() and ability("fork").is_empty() and ability("chain").is_empty())


## Weiter nach dem Treffer des ersten Ziels (das hat _attack schon getroffen).
func _projectile(first, at: Vector2, dmg: float) -> void:
	var pierce := ability("pierce")
	var fork := ability("fork")
	var chain := ability("chain")
	var dir := (at - pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var shot := {
		"pierce": int(pierce.get("count", 0)),
		"forks": int(fork.get("count", 0)),
		"chains": int(chain.get("count", 0)),
		"hit": [first],
		"dmg": dmg,
	}
	# Flüge: {from, from3, dir, reach} geradeaus oder {from3, target} auf einen Gegner, dazu der Zustand
	var flights := []
	_after_hit(shot, first, at, Board3D.to_3d(at, first.position.y), dir, range_cells(), flights)
	var hits := 1
	while not flights.is_empty() and hits < SHOT_MAX_HITS:
		var f: Dictionary = flights.pop_front()
		var e = f.get("target")
		var along := 0.0
		if e == null:
			var found := _first_on_line(f.from, f.dir, f.reach, f.hit)
			if found.is_empty():
				game.add_beam(f.from3, Board3D.to_3d(f.from + f.dir * f.reach, 0.5), color)
				continue
			e = found.enemy
			along = found.along
		elif e.dead:
			continue
		game.add_beam(f.from3, _hit_point(e), color, fx_key())
		var hit_dir: Vector2 = f.dir if f.has("dir") else (e.pos - f.from).normalized()
		hits += 1
		f.hit.append(e)
		_hit(e, f.dmg)
		var splash := ability("splash")
		if not splash.is_empty():
			for other in game.enemies_in_radius(e.pos, float(splash.radius)):
				if other != e and can_target(other):
					_hit(other, f.dmg * float(splash.factor))
		_after_hit(f, e, e.pos, e.position, hit_dir, float(f.get("reach", 0.0)) - along, flights)


## Entscheidet nach einem Treffer, wie das Geschoss weiterfliegt (Reihenfolge wie in PoE, siehe oben).
func _after_hit(shot: Dictionary, e, at: Vector2, at3: Vector3, dir: Vector2, reach_left: float, flights: Array) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	if int(shot.pierce) > 0:
		var ab := ability("pierce")
		var next := shot.duplicate()
		next.pierce = int(shot.pierce) - 1
		next.dmg = float(shot.dmg) * float(ab.get("factor", 1.0))
		next.merge({"from": at, "from3": at3, "dir": dir, "reach": maxf(reach_left, 0.0)}, true)
		next.erase("target")
		if next.reach > 0.0:
			flights.append(next)
		return
	if int(shot.forks) > 0:
		var ab := ability("fork")
		for side in [-1.0, 1.0]:
			var next := shot.duplicate()
			next.hit = (shot.hit as Array).duplicate()
			next.forks = int(shot.forks) - 1
			next.dmg = float(shot.dmg) * float(ab.get("factor", 1.0))
			next.merge({"from": at, "from3": at3, "dir": dir.rotated(deg_to_rad(float(ab.get("angle", 30.0))) * side),
					"reach": float(ab.get("reach", 3.0))}, true)
			next.erase("target")
			flights.append(next)
		return
	if int(shot.chains) > 0:
		var ab := ability("chain")
		var target = null
		var best := INF
		for other in game.enemies_in_radius(at, float(ab.get("radius", 2.5))):
			var d: float = other.pos.distance_to(at)
			if d < best and can_target(other) and not other in shot.hit:
				best = d
				target = other
		if target == null:
			return
		var next := shot.duplicate()
		next.chains = int(shot.chains) - 1
		next.dmg = float(shot.dmg) * float(ab.get("factor", 1.0))
		next.merge({"from": at, "from3": at3, "target": target}, true)
		next.erase("dir")
		next.erase("reach")
		flights.append(next)


## Erster Gegner auf der Flugbahn, der noch nicht getroffen wurde: {enemy, along} oder {}.
func _first_on_line(from: Vector2, dir: Vector2, reach: float, hit: Array) -> Dictionary:
	var best := {}
	for other in game.enemies_in_radius(from, reach + SHOT_HIT_RADIUS):
		if other in hit or not can_target(other):
			continue
		var rel: Vector2 = other.pos - from
		var along := rel.dot(dir)
		if along < 0.0 or along > reach or absf(rel.cross(dir)) > SHOT_HIT_RADIUS:
			continue
		if best.is_empty() or along < float(best.along):
			best = {"enemy": other, "along": along}
	return best


## Kegel vom Tower in Richtung Ziel: trifft alle Gegner darin. Breite (Radius quer zur Richtung) wächst
## von width_start am Tower bis width_end am Ende (length). Mit "damage" ein Zauber mit eigenem Schaden
## (das Ziel inklusive), sonst trifft der Angriff selbst alle weiteren Gegner im Kegel.
func _cone(target_pos: Vector2, ab: Dictionary, dmg: float, target) -> void:
	var dir := (target_pos - pos).normalized()
	if dir == Vector2.ZERO:
		return
	var length := float(ab.get("length", range_cells()))
	var w0 := float(ab.get("width_start", 0.5))
	var w1 := float(ab.get("width_end", 1.5))
	var spell := ab.has("damage")
	for other in game.enemies_in_radius(pos, length + w1):
		if not can_target(other) or (other == target and not spell):
			continue
		var rel: Vector2 = other.pos - pos
		var along := rel.dot(dir)
		if along < 0.0 or along > length:
			continue
		if absf(rel.cross(dir)) > lerpf(w0, w1, along / length):
			continue
		if spell:
			other.last_hit_by = owner_player
			other.last_tower = self
			total_damage += other.take_damage(float(ab.damage) * (1.0 + damage_bonus + kill_bonus() + rogue_damage), "spells")
			if other.dead:
				_killed(other)
		else:
			_hit(other, dmg)
	# Umriss des Kegels kurz aufblitzen lassen
	var side := Vector2(-dir.y, dir.x)
	var corners := [pos + side * w0, pos + dir * length + side * w1, pos + dir * length - side * w1, pos - side * w0]
	for i in 3:
		game.add_beam(Board3D.to_3d(corners[i], 0.15), Board3D.to_3d(corners[i + 1], 0.15), color)


## Schuss- und Treffer-Effekt dieses Towers (effects.gd, fx_data.gd)
func fx_key() -> String:
	return "t:%s:%d" % [tower_id, tier]


## Mitte des Gegnerkörpers, dort sitzt der Treffer-Effekt
func _hit_point(e) -> Vector3:
	return e.position + Vector3(0, 0.0 if e.flying else 0.2 * e.size, 0)


## Zauber um das Ziel herum (Frostnova, Blitz, Messerfächer …).
func _nova(target, ab: Dictionary) -> void:
	var center: Vector2 = target.pos
	for other in game.enemies_in_radius(center, float(ab.get("radius", 2.0))):
		if not can_target(other):
			continue
		if ab.has("slow"):
			other.apply_slow(float(ab.slow), 3.0)
		other.last_hit_by = owner_player
		other.last_tower = self
		total_damage += other.take_damage(float(ab.damage) * (1.0 + kill_bonus()), "spells")
		if other.dead:
			_killed(other)
	game.add_beam(Board3D.to_3d(center, 0.1), Board3D.to_3d(center, 1.5), Color.WHITE, "n:%s:%d:%s" % [tower_id, tier, float(ab.get("radius", 2.0))])


func info_text() -> String:
	var lines := [label()]
	if is_trap():
		lines.append(tr("Falle – Gegner laufen darüber") + (tr(", noch %d× verschiebbar") % moves_left if moves_left > 0 else ""))
	if can_attack():
		var dmg: Array = stats.get("damage", [0, 0])
		var bonus := tr("  (+%d%% Aura/Rang)") % int((damage_bonus + kill_bonus()) * 100) if damage_bonus + kill_bonus() > 0 else ""
		lines.append(tr("Schaden: %d–%d%s") % [int(dmg[0]), int(dmg[1]), bonus])
		lines.append(tr("Abklingzeit: %.2fs%s") % [cooldown(), tr("  (+%d%% Aura)") % int(speed_bonus * 100) if speed_bonus > 0 else ""])
		var reach := tr("Fläche %d×%d Felder") % [Board3D.TRAP_CELLS, Board3D.TRAP_CELLS] if _square_hitbox() else tr("%.1f Towerbreiten") % range_cells()
		lines.append(tr("Reichweite: %s%s") % [reach, tr(" (Luft %.1f)") % float(stats.range_air) if stats.has("range_air") else ""])
		if damage_type() != "":
			lines.append(tr("Schadensart: ") + tr(Database.DAMAGE_TYPE_NAMES.get(damage_type(), damage_type())))
	match target_mode():
		"air":
			lines.append(tr("Wirkt nur gegen Luft"))
		"ground":
			lines.append(tr("Wirkt nur gegen Boden"))
	for ab in abilities():
		lines.append("• " + Abilities.describe(ab))
	if def.has("description"):
		lines.append(tr(str(def.description)))
	if not is_new:
		lines.append(tr("Kills: %d   Schaden gesamt: %d") % [kills, int(total_damage)])
	return "\n".join(lines)


# --- Darstellung -------------------------------------------------------------

func set_selected(value: bool) -> void:
	selected = value
	if _select_ring:
		_select_ring.visible = value
		_range_ring.visible = (value or hovered) and (can_attack() or _aura_radius() > 0.0)
	if not value:
		show_preview_range(0.0)


var hovered := false  ## Maus liegt kurz darauf: Reichweitenring wie bei der Auswahl (game._update_tower_hover)


func set_hovered(value: bool) -> void:
	hovered = value
	if _range_ring != null and is_instance_valid(_range_ring):
		_range_ring.visible = (selected or value) and (can_attack() or _aura_radius() > 0.0)


## Türkiser Ring mit der Reichweite nach einem Upgrade; 0 blendet ihn aus.
func show_preview_range(radius: float) -> void:
	if _preview_ring != null and is_instance_valid(_preview_ring):
		_preview_ring.queue_free()
	_preview_ring = null
	if radius > 0.0 and _visual != null:
		_preview_ring = _ring(radius, 0.07, UiTheme.CYAN)


## Radius des Reichweitenrings für bestimmte Werte: Fallen mit Fläche zeigen nur Luft- oder Aurareichweite.
static func ring_radius(s: Dictionary, trap: bool) -> float:
	var aura := 0.0
	for ab in s.get("abilities", []):
		if str(ab.get("type", "")).ends_with("_aura"):
			aura = maxf(aura, float(ab.radius))
	var r := float(s.get("range", 3.0))
	if trap and r <= Board3D.TRAP_CELLS * Board3D.CELL:
		return maxf(float(s.get("range_air", 0.0)), aura)
	return maxf(r, aura)


func _square_hitbox() -> bool:
	return is_trap() and range_cells() <= Board3D.TRAP_CELLS * Board3D.CELL


## Größter Radius einer Aura, die auf diesen Gegner wirkt (Brand, Verlangsamung, Rüstung), 0 = keine.
func enemy_aura_radius(e) -> float:
	var r := 0.0
	for ab in abilities():
		if not str(ab.get("type", "")) in ["burn_aura", "slow_aura", "armor_aura"]:
			continue
		var mode := str(ab.get("targets", target_mode()))
		if (mode == "air" and not e.flying) or (mode == "ground" and e.flying):
			continue
		r = maxf(r, float(ab.radius))
	return r


func _aura_radius() -> float:
	var r := 0.0
	for ab in abilities():
		if str(ab.get("type", "")).ends_with("_aura"):
			r = maxf(r, float(ab.radius))
	return r


func _build_visual() -> void:
	if _visual:
		_visual.queue_free()
	_preview_ring = null
	_visual = Node3D.new()
	add_child(_visual)
	var mat := ShaderMaterial.new()
	mat.shader = GEM_SHADER
	mat.set_shader_parameter("color", color)
	if not FieldStyle.is_neon():
		# bei Tageslicht kaum Eigenleuchten, sonst wirken die Kristalle flach wie Plastik
		mat.set_shader_parameter("glow", 0.04)
		mat.set_shader_parameter("under_light", 0.1)
		mat.set_shader_parameter("daylight", 1.0)
		# Statuen und Steine aus der Natur-Sammlung: Stein mit farbigen Adern; Kristalle wachsen aus Fels
		if str(stats.get("model", def.get("model", ""))).contains("/nature/"):
			mat.set_shader_parameter("stone_height", 100.0)
			mat.set_shader_parameter("vein_amount", 0.55)
			mat.set_shader_parameter("stone_tint", 0.35)
	# "model_tint": false behält die Farben/Texturen des Modells (nur leicht durchsichtig gemacht)
	var tint: Material = mat if bool(def.get("model_tint", true)) else null

	var category := str(def.get("category", "gem"))
	_gem = null
	var model_path := str(stats.get("model", def.get("model", "")))
	# Figuren und Gegenstände aus assets/models/towers/ stehen still (Gems und Steine drehen sich)
	_spin = not model_path.contains("/models/towers/")
	if is_trap():
		var plate := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		# Platte deckt die 3×3-Fläche der Falle ab
		var plate_r := Board3D.TRAP_CELLS * Board3D.CELL / 2.0
		cyl.top_radius = plate_r * 0.98
		cyl.bottom_radius = plate_r * 1.05
		cyl.height = 0.08
		cyl.radial_segments = 6
		plate.mesh = cyl
		plate.material_override = mat
		plate.position.y = 0.04
		_visual.add_child(plate)
		if model_path != "":
			_gem = ModelLoader.instantiate(model_path, float(stats.get("model_scale", def.get("model_scale", 0.35))), mat)
			if _gem:
				_gem.position.y = 0.08
				_visual.add_child(_gem)
				_add_flame(_gem)
		_finish_visual()
		return
	# Sockel: eckige Glasplatte mit runden Ecken über die ganzen 2×2 Felder, von innen beleuchtet
	var foot := footprint_size() * Board3D.CELL
	var base_h := BASE_HEIGHT_SPECIAL if category == "special" else BASE_HEIGHT
	var base := MeshInstance3D.new()
	base.mesh = rounded_slab(foot * 0.96, base_h, 0.1)
	_base_mat = _glass_material()
	base.material_override = _base_mat
	_apply_base_tint()
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(base)
	ModelLoader.add_outline(base)
	var light := MeshInstance3D.new()
	light.mesh = rounded_slab(foot * 0.5, 0.012, 0.07)
	var light_mat := Board3D.make_material(color.lerp(Color.WHITE, 0.4) * BASE_LIGHT_ENERGY, true)
	if not FieldStyle.is_neon():
		# Druidenhain: farbige Rune im Stein statt Licht von unten
		light_mat = Board3D.make_material(color.darkened(0.15), false)
		light_mat.emission_enabled = true
		light_mat.emission = color
		light_mat.emission_energy_multiplier = 0.25
	light_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	light.material_override = light_mat
	light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.position.y = base_h - 0.025
	_visual.add_child(light)
	if mat is ShaderMaterial:
		mat.set_shader_parameter("base_top", base_h)
	# Special füllt die Sockelfläche: Breite (nicht Höhe) wird angepasst, höhere Stufen etwas breiter
	var width := minf(0.86 + 0.02 * tier, 0.92) * foot
	if category == "gem" and model_path != "":
		_gem = _gem_cluster(model_path, tint, foot, base_h)
		width = float(GEM_CLUSTERS[clampi(tier, 0, GEM_CLUSTERS.size() - 1)][1]) * foot
		if _gem:
			if tint == null:
				_texture_look(_gem)
			_visual.add_child(_gem)
	elif model_path != "":
		if stats.has("model_scale") or def.has("model_scale"):
			_gem = ModelLoader.instantiate(model_path, float(stats.get("model_scale", def.get("model_scale"))), tint)
		else:
			_gem = ModelLoader.instantiate_fit(model_path, width, GEM_MAX_HEIGHT, tint)
		if _gem:
			# "model_solid": true lässt Modelle mit eigenen Farben (Bäume, Steine) undurchsichtig
			if tint == null and not bool(def.get("model_solid", false)):
				_texture_look(_gem)
			_gem.position.y = base_h
			_visual.add_child(_gem)
	var size := width
	if _gem == null and float(def.get("fog", 0.0)) > 0.0:
		# Nur Nebel (Bühnennebel): kein Kristall auf dem Sockel
		_gem = Node3D.new()
		_gem.position.y = base_h
		_visual.add_child(_gem)
	if _gem == null:
		var oct := MeshInstance3D.new()
		oct.mesh = _gem_mesh()
		oct.material_override = mat
		var s := size * 0.45
		oct.scale = Vector3(s, s * 1.4, s)
		oct.position.y = base_h + s * 1.4 + 0.05
		_gem = Node3D.new()
		_gem.add_child(oct)
		_visual.add_child(_gem)
	ModelLoader.add_outline(_gem)
	if tower_id.begins_with("eeve_") and not is_trap():
		if eeve_accent == "kontur":
			ModelLoader.add_outline(_gem, "druid_white")
		elif eeve_accent == "sockel":
			_add_corner_lights(foot, base_h)
	_add_flame(_gem)
	_add_fog(foot, base_h)
	_finish_visual()


## "fog": Bodennebel über dem Sockel bzw. auf "fog_height" des Modells, Größe in Towerbreiten.
func _add_fog(foot: float, base_h: float) -> void:
	var size := float(def.get("fog", 0.0))
	if size <= 0.0:
		return
	var fog := FogFx.make(size * foot, Color(0.95, 0.92, 1.0).lerp(color, 0.3))
	fog.position.y = base_h
	# "fog_height": Anteil der Modellhöhe, auf dem der Nebel liegt (Bühnenboden), wie "flame_height"
	if def.has("fog_height") and _gem:
		var box := ModelLoader.aabb(_gem, Transform3D())
		if box.size.y > 0.0:
			fog.position = Vector3(box.get_center().x, box.position.y + box.size.y * float(def.fog_height), box.get_center().z)
	_visual.add_child(fog)


## Vier kleine Lampen in den Sockelecken, jede mit einem Spot schräg nach oben auf den Tower.
func _add_corner_lights(foot: float, base_h: float) -> void:
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = SOCKEL_LIGHT
	lamp_mat.emission_enabled = true
	lamp_mat.emission = SOCKEL_LIGHT
	lamp_mat.emission_energy_multiplier = 2.5
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.025
	lamp_mesh.height = 0.035
	var top := Vector3(0, base_h + 0.35, 0)
	var off := foot * 0.4
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p := Vector3(corner.x * off, base_h + 0.01, corner.y * off)
		var lamp := MeshInstance3D.new()
		lamp.mesh = lamp_mesh
		lamp.material_override = lamp_mat
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.position = p
		_visual.add_child(lamp)
		var spot := SpotLight3D.new()
		spot.light_color = SOCKEL_LIGHT
		spot.light_energy = 1.6
		spot.spot_range = foot * 1.6
		spot.spot_angle = 38.0
		spot.spot_attenuation = 0.8
		spot.shadow_enabled = false
		spot.position = p + Vector3(corner.x, 0, corner.y) * 0.03
		spot.basis = Basis.looking_at(top - spot.position)
		_visual.add_child(spot)


## "flame": Größe der Flamme in Towerbreiten, sitzt oben auf dem Modell (Lagerfeuer, Kohlenbecken).
func _add_flame(model: Node3D) -> void:
	var size := float(def.get("flame", 0.0))
	if size <= 0.0 or model == null:
		return
	var box := ModelLoader.aabb(model, Transform3D())
	var flame := FlameFx.make(size, Color(1.0, 0.75, 0.5) if not FieldStyle.is_neon() else Color.WHITE)
	if FieldStyle.current_name() == FieldStyle.DRUID:
		_add_embers(model, box)
	flame.position = Vector3(box.get_center().x, box.position.y + box.size.y * float(def.get("flame_height", 0.6)), box.get_center().z)
	_visual.add_child(flame)


## Druidenhain: glühende Kohlen oben im Becken bzw. in der Feuerstelle, damit man Feuer und kein Wasser sieht;
## Becken (pot) werden dunkle Bronze statt hellem Ton.
func _add_embers(model: Node3D, box: AABB) -> void:
	if str(stats.get("model", def.get("model", ""))).contains("pot_"):
		var bronze := StandardMaterial3D.new()
		bronze.albedo_color = Color("5a4030")
		bronze.metallic = 0.6
		bronze.roughness = 0.45
		Metall.veredeln(bronze)
		ModelLoader._apply_material(model, bronze)
	var coal := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = minf(box.size.x, box.size.z) * 0.32
	disk.bottom_radius = disk.top_radius
	disk.height = 0.02
	coal.mesh = disk
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color("16100c")
	hot.roughness = 0.95
	hot.emission_enabled = true
	hot.emission = Color("7a1a04")
	hot.emission_energy_multiplier = 0.5
	coal.material_override = hot
	coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coal.position = Vector3(box.get_center().x, box.position.y + box.size.y * float(def.get("flame_height", 0.6)) + 0.01, box.get_center().z)
	_visual.add_child(coal)
	# Kohlestücke auf der Asche, teils schwarz, teils glühend
	var lump_mat := StandardMaterial3D.new()
	lump_mat.albedo_color = Color("1a1410")
	lump_mat.roughness = 0.9
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color("3a1408")
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("ff6a18")
	glow_mat.emission_energy_multiplier = 1.6
	var r := disk.top_radius
	for i in 11:
		var lump := MeshInstance3D.new()
		var b := SphereMesh.new()
		var s := r * (0.2 + 0.06 * (i % 3))
		b.radius = s * 0.5
		b.height = s * 0.6
		b.radial_segments = 5
		b.rings = 2
		lump.mesh = b
		lump.material_override = glow_mat if i % 3 != 0 else lump_mat
		var a := TAU * i / 11.0 * 3.0 + 0.4
		lump.position = coal.position + Vector3(cos(a), 0.0, sin(a)) * r * (0.15 + 0.6 * fmod(i * 0.37, 1.0)) + Vector3(0, s * 0.1, 0)
		lump.rotation.y = a * 1.7
		_visual.add_child(lump)


## Mehrere Kristalle auf dem Sockel, Anzahl und Größe nach Qualität (GEM_CLUSTERS).
## Jeder Kristall passt in seine Kiste, schmale Modelle werden so nicht übermäßig hoch.
func _gem_cluster(model_path: String, tint: Material, foot: float, base_h: float) -> Node3D:
	var cfg: Array = GEM_CLUSTERS[clampi(tier, 0, GEM_CLUSTERS.size() - 1)]
	var n := int(cfg[0])
	var layout := _splinter_layout(tower_id, n) if tier <= 1 else []
	if layout.is_empty():
		# äußere Kristalle leicht nach außen geneigt wie bei einer Druse
		for i in n:
			var spot: Vector2 = CLUSTER_SPOTS[n][i]
			layout.append([spot, CLUSTER_VARY[i % CLUSTER_VARY.size()], 0.0 if spot == Vector2.ZERO else 12.0, -1.0])
	if tier == 0:
		layout = _shard_layout(layout)
		if tint is ShaderMaterial:
			var glow = tint.get_shader_parameter("glow")  # null = Standardwert des Shaders
			tint.set_shader_parameter("glow", (0.25 if glow == null else float(glow)) * SHARD_GLOW)
	var cluster := Node3D.new()
	for i in layout.size():
		var entry: Array = layout[i]
		var k := float(entry[1])
		var crystal := ModelLoader.instantiate_fit(model_path, float(cfg[1]) * foot * k, float(cfg[2]) * foot * k, tint)
		if crystal == null:
			break
		var spot: Vector2 = entry[0] * foot
		var tilt := deg_to_rad(float(entry[2]))
		var basis := Basis(Vector3.UP, i * 2.4)
		var lift := 0.0
		if tilt > 0.0:
			var dir := Vector3(spot.x, 0.0, spot.y)
			if float(entry[3]) >= 0.0 or dir.is_zero_approx():
				var a := deg_to_rad(maxf(float(entry[3]), 0.0))
				dir = Vector3(cos(a), 0.0, sin(a))
			basis = Basis(Vector3.UP.cross(dir.normalized()).normalized(), tilt) * basis
			# geneigte Kristalle anheben, damit die Unterkante nicht im Sockel verschwindet
			var box := ModelLoader.aabb(crystal, Transform3D())
			lift = maxf(box.size.x, box.size.z) * 0.5 * sin(tilt) * 0.8
		crystal.position = Vector3(spot.x, base_h + lift, spot.y)
		crystal.basis = basis
		cluster.add_child(crystal)
	if cluster.get_child_count() == 0:
		cluster.free()
		return null
	return cluster


## Anordnung der Splitter (Stufe 0 und 1, n Kristalle), je Grundgem eine eigene.
## Je Kristall: [Platz in Sockelbreiten, Größe, Neigung in Grad, Neigungsrichtung in Grad
## (0 = +X, 90 = +Z, nach vorne zur Kamera) oder -1 = vom Sockelmittelpunkt weg].
## Leer = Standardanordnung aus CLUSTER_SPOTS.
## Splitter: dieselben Plätze wie die Splitter-Form, aber jeder Kristall umgekippt in eine eigene Richtung.
static func _shard_layout(layout: Array) -> Array:
	var out := []
	for i in layout.size():
		var e: Array = layout[i]
		# etwas näher zur Mitte, damit umgekippte Scherben nicht über den Sockelrand ragen
		out.append([(e[0] as Vector2) * 0.8, float(e[1]), SHARD_TILT[i % SHARD_TILT.size()], fmod(40.0 + 137.0 * i, 360.0)])
	return out


static func _splinter_layout(id: String, n: int) -> Array:
	var out := []
	match id:
		"ruby":  # Krone: Ring mit freier Mitte, alle nach außen geneigt
			for i in n:
				var a := deg_to_rad(-90.0 + 360.0 * i / n)
				out.append([Vector2(cos(a), sin(a)) * 0.21, 1.0 - 0.1 * (i % 2), 22.0, -1.0])
		"sapphire":  # Reihe quer über den Sockel, nach hinten größer
			for i in n:
				var t := float(i) / (n - 1)
				out.append([Vector2(-0.28, 0.28).lerp(Vector2(0.28, -0.28), t), 0.75 + 0.4 * t, 6.0, 270.0])
		"emerald":  # Druse: ein großer in der Mitte, kleine rundherum stark geneigt
			out.append([Vector2.ZERO, 1.4, 0.0, -1.0])
			for i in n - 1:
				var a := deg_to_rad(45.0 + 360.0 * i / (n - 1))
				out.append([Vector2(cos(a), sin(a)) * 0.24, 0.7, 34.0, -1.0])
		"diamond":  # zwei Grüppchen in gegenüberliegenden Ecken
			var back := n - floori(n / 2.0)
			for i in n:
				var group := Vector2(-0.16, -0.15) if i < back else Vector2(0.19, 0.17)
				var j := i if i < back else i - back
				var a := deg_to_rad(200.0 + 120.0 * j)
				out.append([group + Vector2(cos(a), sin(a)) * 0.1, (0.95 if i < back else 0.78) - 0.06 * j, 10.0, -1.0])
		"topaz":  # Bogen hinten, nach vorne offen, die Mitte am größten
			for i in n:
				var t := float(i) / (n - 1)
				var a := deg_to_rad(lerpf(195.0, 345.0, t))
				out.append([Vector2(cos(a), sin(a)) * 0.25 + Vector2(0.0, 0.06), 0.8 + 0.35 * sin(t * PI), 14.0, -1.0])
		"amethyst":  # wie aus einer Wand gewachsen: hinten aufgereiht, alle nach vorne geneigt
			var spots := [Vector2(-0.26, -0.2), Vector2(0.24, -0.24), Vector2(-0.04, -0.27), Vector2(0.06, 0.02), Vector2(-0.2, 0.12)]
			var sizes := [1.0, 0.95, 1.1, 0.8, 0.72]
			for i in n:
				out.append([spots[i], sizes[i], 30.0, 70.0])
		"aquamarine":  # Strauß: alle aus der Mitte, nach außen gefächert
			out.append([Vector2.ZERO, 1.15, 0.0, -1.0])
			for i in n - 1:
				var a := deg_to_rad(20.0 + 360.0 * i / (n - 1))
				out.append([Vector2(cos(a), sin(a)) * 0.07, 0.95, 38.0, -1.0])
		"opal":  # verstreut liegend, einer steht
			var spots := [Vector2(0.02, -0.02), Vector2(-0.22, -0.19), Vector2(0.21, -0.2), Vector2(0.22, 0.19), Vector2(-0.2, 0.2)]
			var dirs := [0.0, 20.0, 150.0, 250.0, 300.0]
			for i in n:
				out.append([spots[i], 1.1 if i == 0 else 0.9, 0.0 if i == 0 else 62.0, dirs[i]])
	return out


## Quader mit abgerundeten senkrechten Kanten, Unterseite auf Y = 0, Mitte auf X/Z = 0.
static func rounded_slab(size: float, height: float, radius: float, segments := 6) -> ArrayMesh:
	var key := "%.3f/%.3f/%.3f" % [size, height, radius]
	if _slab_cache.has(key):
		return _slab_cache[key]
	var h := size / 2.0 - radius
	var outline: Array[Vector2] = []  # Umriss gegen den Uhrzeigersinn (von oben gesehen)
	var normals: Array[Vector2] = []
	var corners := [Vector2(h, h), Vector2(-h, h), Vector2(-h, -h), Vector2(h, -h)]
	for i in 4:
		for k in segments + 1:
			var a := (i + float(k) / segments) * PI / 2.0
			var n := Vector2(cos(a), sin(a))
			outline.append(corners[i] + n * radius)
			normals.append(n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := outline.size()
	for i in count:
		var j := (i + 1) % count
		var p0 := outline[i]
		var p1 := outline[j]
		var n0 := Vector3(normals[i].x, 0, normals[i].y)
		var n1 := Vector3(normals[j].x, 0, normals[j].y)
		# Seite
		for v in [[p0, n0, 0.0], [p1, n1, height], [p1, n1, 0.0], [p0, n0, 0.0], [p0, n0, height], [p1, n1, height]]:
			st.set_normal(v[1])
			st.add_vertex(Vector3(v[0].x, v[2], v[0].y))
		# Deckel und Boden als Fächer um die Mitte
		for v in [[Vector2.ZERO, height], [p0, height], [p1, height]]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(v[0].x, v[1], v[0].y))
		for v in [[Vector2.ZERO, 0.0], [p1, 0.0], [p0, 0.0]]:
			st.set_normal(Vector3.DOWN)
			st.add_vertex(Vector3(v[0].x, v[1], v[0].y))
	var mesh := st.commit()
	_slab_cache[key] = mesh
	return mesh


## Modell mit eigenen Farben: im Neon-Stil leicht durchsichtig mit Licht von unten, sonst
## (Natur-Modelle in eeveTD) deckend wie geliefert.
func _texture_look(n: Node) -> void:
	if FieldStyle.is_neon():
		ModelLoader.make_translucent(n, GEM_OPACITY_TEXTURED, color)
	elif FieldStyle.current_name() == FieldStyle.DRUID and bool(def.get("eeve", {}).get("barricade", false)):
		# Barrikaden: dunkler, bemooster Feldstein statt des hellen Fels-Texturfotos
		var stone := StandardMaterial3D.new()
		stone.albedo_color = Color("5c584c")
		stone.roughness = 0.95
		stone.metallic_specular = 0.12
		ModelLoader._apply_material(n, stone)


## Sockel einfärben (Alpha 0 = wieder normal); bleibt beim Aufwerten erhalten.
func set_base_tint(c: Color) -> void:
	if c == base_tint:
		return
	base_tint = c
	if _base_mat != null:
		var fresh := _glass_material()
		_base_mat.albedo_color = fresh.albedo_color
		_base_mat.roughness = fresh.roughness
		_base_mat.emission_enabled = fresh.emission_enabled
		_base_mat.emission = fresh.emission
		_base_mat.emission_energy_multiplier = fresh.emission_energy_multiplier
	_apply_base_tint()


func _apply_base_tint() -> void:
	if _base_mat == null or base_tint.a <= 0.0:
		return
	# poliert und leicht leuchtend in der Farbe, damit auch dunkler Marmor vom Stein absticht
	_base_mat.albedo_color = Color(base_tint, _base_mat.albedo_color.a)
	_base_mat.roughness = 0.3
	_base_mat.emission_enabled = true
	_base_mat.emission = base_tint
	_base_mat.emission_energy_multiplier = 0.35


func _glass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if FieldStyle.current_name() == FieldStyle.DRUID:
		# Sockel aus bemoostem Stein
		m.albedo_color = Color("4a4c42")
		m.roughness = 0.92
		m.metallic_specular = 0.12  # sonst spiegelt der helle Himmel und der Stein wirkt ausgebleicht
		return m
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 1.0, 0.16)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS  # damit die Kontur innen verdeckt wird
	m.roughness = 0.05
	m.metallic_specular = 0.9
	m.rim_enabled = true
	m.rim = 0.7
	m.rim_tint = 0.2
	m.emission_enabled = true
	m.emission = color.lerp(Color.WHITE, 0.5)
	m.emission_energy_multiplier = 0.35
	return m


func _finish_visual() -> void:
	ContactShadow.add(_visual, footprint_size() * Board3D.CELL)
	_new_ring = _ring(0.48, 0.05, Color(1, 1, 1, 0.9))
	_new_ring.visible = is_new
	_select_ring = _ring(0.52, 0.06, Color.YELLOW)
	# Fallen zeigen ihre Fläche über die Platte, der Ring nur Luft- oder Aurareichweite
	_range_ring = _ring(ring_radius(stats, is_trap()) * range_mult(), 0.05, Color(1, 1, 1, 0.6))
	set_selected(selected)


## Roguelike-Boni übernehmen ({damage, speed, range}, leer = keine); der Reichweitenring wächst mit.
func set_rogue(b: Dictionary) -> void:
	rogue_damage = float(b.get("damage", 0.0))
	rogue_speed = float(b.get("speed", 0.0))
	rogue_anti_air = bool(b.get("anti_air", false))
	rogue_fx = {}
	for k in ["flasks", "pct", "execute"]:
		if not b.get(k, {}).is_empty():
			rogue_fx[k] = b[k]
	# Gift aus dem Pool hat seinen Schaden als Anteil am Tower-Schaden (dps_factor)
	rogue_abilities = []
	for ab in b.get("abilities", []):
		var a: Dictionary = ab.duplicate()
		if a.has("dps_factor"):
			var dmg: Array = stats.get("damage", [0, 0])
			a.dps = snappedf((float(dmg[0]) + float(dmg[1])) / 2.0 * float(a.dps_factor) / maxf(float(stats.get("cooldown", 1.0)), 0.05), 0.1)
			a.erase("dps_factor")
		rogue_abilities.append(a)
	_refresh_abilities()
	var r := float(b.get("range", 0.0))
	if is_equal_approx(r, rogue_range):
		return
	rogue_range = r
	_rebuild_range_ring()


## Reichweitenring neu, wenn sich der Faktor auf die Reichweite geändert hat (Roguelike, Items, Level).
func _rebuild_range_ring() -> void:
	if _range_ring != null and is_instance_valid(_range_ring):
		var vis := _range_ring.visible
		_range_ring.queue_free()
		_range_ring = _ring(ring_radius(stats, is_trap()) * range_mult(), 0.05, Color(1, 1, 1, 0.6))
		_range_ring.visible = vis


func _ring(radius: float, thickness: float, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - thickness, 0.01)
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	m.mesh = torus
	m.material_override = Board3D.make_material(col, true)
	m.position.y = 0.05
	m.scale = Vector3(1, 0.3, 1)
	_visual.add_child(m)
	return m


func _animate(delta: float) -> void:
	_time += delta
	if _gem and _spin:
		_gem.rotation.y += delta * (SPIN_NEW if is_new else SPIN_FIXED)
	if _new_ring:
		_new_ring.visible = is_new
		if is_new:
			(_new_ring.material_override as StandardMaterial3D).albedo_color.a = 0.5 + 0.5 * sin(_time * 5.0)


static func _gem_mesh() -> ArrayMesh:
	if _octahedron != null:
		return _octahedron
	var top := Vector3(0, 1, 0)
	var bottom := Vector3(0, -1, 0)
	var ring := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		for v in [top, b, a, bottom, a, b]:
			st.add_vertex(v)
	st.generate_normals()
	_octahedron = st.commit()
	return _octahedron
