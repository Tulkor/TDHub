class_name HdEnemy
extends Node3D
## Gegner im Hero-Defense-Modus mit KI nach Design Abschnitt 15 (Lukas 2026-11-04):
## - läuft die Straße Richtung Feste (eigene Spur, damit sie nicht im Gänsemarsch laufen),
## - folgt einem Helden in Aggro-Reichweite, kehrt zur Straße zurück, wenn die Leine (Abstand zum
##   Punkt, an dem er die Straße verlassen hat) reißt,
## - greift den Angreifer immer an (auch außerhalb der Aggro-Reichweite, solange in Leine),
## - Helden vor Gebäuden: Gebäude nur, wenn kein Held in Reichweite ist,
## - Fähigkeiten mit eigenem internen Cooldown plus kurzem Abstand zwischen zwei Fähigkeiten; der
##   Cooldown startet beim Ansetzen, eine Betäubung während des Aufladens bricht nur ab,
## - bleibt nicht stecken: kaum Bewegung über stuck_check Sekunden → seitlich ausweichen, nach
##   mehreren Versuchen Ziel fallen lassen bzw. Straßenposition neu bestimmen.
## Geometrie (Hindernisse, Abstand zu anderen Gegnern) löst HdGame.move_unit.

var game  ## HdGame
var def: Dictionary
var id := ""
var rank := "normal"
var hp := 100.0
var max_hp := 100.0
var armor := 0.0
var speed := 3.5
var radius := 0.5
var dmg_mult := 1.0
var cc: HdCc
var dead := false
var state := "road"            ## road | chase | return
var road_s := 0.0
var lane := 0.0
var anchor_s := 0.0
var target: Node3D = null      ## HdHero oder HdBuilding
var provoked_hero := false
var provoked_building: Node3D = null
var reaggro_block := 0.0
var attack_cd := 0.0
var ab_ready: Dictionary = {}  ## Fähigkeit → frühester Zeitpunkt
var gap_until := 0.0
var cast: Dictionary = {}      ## laufende Fähigkeit
var casts_started := 0
var casts_interrupted := 0
var burn_dps := 0.0
var burn_until := 0.0
var facing := Vector3(0, 0, 1)
var knock := Vector3.ZERO
var knock_t := 0.0
var wants_move := false
var stuck_events := 0
var hit_flash := 0.0
## Schwächungen durch Helden (König Unrat, Vesna, Zix)
var rats := 0                  ## Ratten auf dem Gegner (Rattenschwarm)
var rats_until := 0.0
var rat_tick := 0.0
var rat_bite := 0.0            ## Schaden je Ratte und Biss
var rat_armor := 0.0           ## Rüstungssenkung je Biss-Stapel
var rat_stacks := 0
var plague_until := 0.0        ## Rattenseuche: weniger Schaden, weniger Heilung, springt beim Tod über
var plague := {}               ## Werte der Seuche (weaken, heal_cut, time, jumps, range)
var heal_cut_until := 0.0      ## Spritzengewehr/Seuche: erhaltene Heilung gesenkt (für künftige Heiler)
var taunt_src: Node3D = null   ## Schrottbot/Magnetköder: muss dieses Ziel angreifen
var taunt_until := 0.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _stuck_n := 0
var _side_dir := Vector3.ZERO
var _side_t := 0.0
var _last_dir := Vector3.FORWARD
var _body: Node3D


func setup(g, d: Dictionary, wave: int) -> void:
	game = g
	def = d
	id = str(d.id)
	rank = str(d.get("rank", "normal"))
	var diff: Dictionary = game.diff()
	var w: Dictionary = game.cfg.waves
	max_hp = float(d.hp) * float(diff.hp) * (1.0 + float(w.scale_hp) * (wave - 1))
	hp = max_hp
	armor = float(d.get("armor", 0))
	speed = float(d.speed)
	radius = float(d.radius)
	dmg_mult = float(diff.damage) * (1.0 + float(w.scale_damage) * (wave - 1))
	cc = HdCc.new(game.cfg.cc, rank)
	lane = game.rng.randf_range(-1.0, 1.0) * (float(game.cfg.arena.road_width) * 0.5 - radius - 0.3)
	var now: float = game.play_time
	for aid in d.get("abilities", []):
		ab_ready[aid] = now + game.rng.randf_range(1.5, 3.5)
	_build_body()


func _build_body() -> void:
	_body = Node3D.new()
	add_child(_body)
	var s: Array = def.get("size", [1, 1, 1])
	var size := Vector3(float(s[0]), float(s[1]), float(s[2]))
	var col := Color(str(def.get("color", "777777")))
	_body.add_child(HdDev.box(size, HdDev.mat(col, 0.5), Vector3(0, size.y * 0.5, 0)))
	# Gesicht/Blickrichtung: helle Leiste vorne
	_body.add_child(HdDev.box(Vector3(size.x * 0.6, size.y * 0.15, 0.12), HdDev.flat(Color("ffd37a")), Vector3(0, size.y * 0.72, size.z * 0.5 + 0.04)))
	if rank == "elite":
		_body.add_child(HdDev.box(Vector3(size.x + 0.08, 0.18, size.z + 0.08), HdDev.mat(UiTheme.COIN, 0.5, 0.6), Vector3(0, size.y * 0.85, 0)))
	elif rank == "boss":
		for k in 4:
			var a := k * PI * 0.5
			_body.add_child(HdDev.box(Vector3(0.35, 0.7, 0.35), HdDev.mat(UiTheme.COIN, 0.5, 0.8),
				Vector3(cos(a) * size.x * 0.32, size.y + 0.3, sin(a) * size.z * 0.32)))


func height() -> float:
	return float(def.get("size", [1, 1, 1])[1])


func alive() -> bool:
	return not dead


func casting() -> bool:
	return not cast.is_empty()


## Schadensfaktor nach Schwierigkeit, Welle und Rattenseuche.
func out_mult() -> float:
	if game.play_time < plague_until:
		return dmg_mult * (1.0 - float(plague.get("weaken", 0.0)))
	return dmg_mult


## Rattenschwarm: n Ratten springen auf (höchstens max), beißen jede Sekunde, senken je Biss die Rüstung.
func add_rats(n: int, cap: int, time: float, bite: float, armor_per: float, plague_def: Dictionary) -> void:
	rats = mini(cap, rats + n)
	rats_until = game.play_time + time
	rat_bite = bite
	rat_armor = armor_per
	plague = plague_def
	if rat_tick <= 0.0:
		rat_tick = 1.0


## Ratten fallen ab (Zeit um oder abgeschüttelt): Rattenseuche bleibt auf dem Ziel.
func drop_rats() -> void:
	if rats <= 0:
		return
	rats = 0
	rat_stacks = 0
	if not plague.is_empty():
		apply_plague(plague)


func apply_plague(p: Dictionary) -> void:
	plague = p
	plague_until = game.play_time + float(p.get("time", 6.0))
	heal_cut_until = maxf(heal_cut_until, plague_until)


func plagued() -> bool:
	return game.play_time < plague_until


## Ratten beißen, Spott läuft ab. Ansturm/Sprung schüttelt die Ratten ab.
func step_debuffs(dt: float, now: float) -> void:
	if taunt_src and (now >= taunt_until or not is_instance_valid(taunt_src) or not taunt_src.alive()):
		taunt_src = null
	if rats <= 0:
		return
	if now >= rats_until or (casting() and str(cast.ab.kind) == "charge"):
		drop_rats()
		return
	rat_tick -= dt
	if rat_tick <= 0.0:
		rat_tick += 1.0
		rat_stacks = mini(rat_stacks + rats, 25)
		cc.reduce_armor("ratten", rat_armor * rat_stacks, 4.0, now)
		game.hero_hit(self, rat_bite * rats, "rats", true)


## Spott: greift taunter für time Sekunden an (Leine gilt trotzdem).
func taunt(taunter: Node3D, time: float) -> void:
	if rank == "boss" and taunt_src == null and game.rng.randf() < 0.5:
		return
	taunt_src = taunter
	taunt_until = game.play_time + time
	if state == "road":
		anchor_s = road_s
	state = "chase"
	target = taunter


# ---------------------------------------------------------------- Schritt

func step(dt: float, now: float) -> void:
	if dead:
		return
	cc.update(now)
	hit_flash = maxf(0.0, hit_flash - dt)
	if knock_t > 0.0:
		knock_t -= dt
		game.move_unit(self, knock.normalized(), knock.length(), dt, true)
	if cc.stunned(now):
		if casting():
			cancel_cast()
		wants_move = false
		_stuck_t = 0.0
		_body.rotation.z = sin(now * 18.0) * 0.08
		return
	_body.rotation.z = 0.0
	if casting():
		_step_cast(dt, now)
		return
	attack_cd -= dt
	reaggro_block -= dt
	wants_move = false
	_choose_target()
	if _try_ability(now):
		return
	if target:
		var reach: float = float(def.attack.range) + radius + target.radius
		var d := _flat_dist(target.position)
		_face(target.position - position)
		if d <= reach:
			if attack_cd <= 0.0:
				_attack()
		else:
			_move(target.position - position, dt, now)
	elif state == "return":
		var p: Vector3 = game.road_point(anchor_s, lane)
		if _flat_dist(p) < 1.5:
			state = "road"
			road_s = anchor_s
		else:
			_move(p - position, dt, now)
	else:
		_follow_road(dt, now)
	_check_stuck(dt, now)


func _follow_road(dt: float, now: float) -> void:
	road_s = maxf(road_s, game.road_project(position, road_s - 2.0, road_s + 8.0))
	if road_s >= game.road_len - 1.0:
		game.leak(self)
		return
	var ahead: float = road_s + float(game.cfg.ai.road_lookahead)
	_move(game.road_point(ahead, lane) - position, dt, now)


func _move(v: Vector3, dt: float, now: float) -> void:
	v.y = 0.0
	if v.length_squared() < 0.0001:
		return
	var dir := v.normalized()
	_last_dir = dir
	if _side_t > 0.0:
		_side_t -= dt
		dir = (dir * 0.35 + _side_dir).normalized()
	wants_move = true
	_face(dir)
	game.move_unit(self, dir, speed * cc.speed_factor(now), dt)


func _face(v: Vector3) -> void:
	v.y = 0.0
	if v.length_squared() > 0.0001:
		facing = v.normalized()
		rotation.y = atan2(facing.x, facing.z)


func _flat_dist(p: Vector3) -> float:
	return Vector2(position.x - p.x, position.z - p.z).length()


# ---------------------------------------------------------------- Ziele

func _choose_target() -> void:
	if state == "chase":
		var anchor: Vector3 = game.road_point(anchor_s, lane)
		var lost: bool = target == null or not is_instance_valid(target) or not target.alive()
		if lost or _flat_dist(anchor) > float(def.leash):
			drop_target(float(game.cfg.ai.reaggro_block))
			return
	var want: Node3D = null
	var hero = game.hero
	if taunt_src and is_instance_valid(taunt_src) and taunt_src.alive():
		want = taunt_src
	elif hero and hero.alive() and reaggro_block <= 0.0 and (provoked_hero or _flat_dist(hero.position) <= float(def.aggro) + hero.radius):
		want = hero
	elif provoked_building and is_instance_valid(provoked_building) and provoked_building.alive():
		want = provoked_building
	elif reaggro_block <= 0.0:
		want = game.building_near(position, float(def.aggro))
	if want:
		if state == "road":
			anchor_s = road_s
		state = "chase"
		target = want
	else:
		target = null
		if state == "chase":
			state = "return"


## Ziel fallen lassen und zur Straße zurück (Leine gerissen, Ziel tot, festgehangen).
func drop_target(block := 0.0) -> void:
	target = null
	taunt_src = null
	provoked_hero = false
	provoked_building = null
	reaggro_block = block
	if state == "chase":
		state = "return"


## Von jemandem angegriffen: Held → immer angreifen (solange in Leine), Gebäude → wenn kein Held da ist.
func provoke(source: Node3D) -> void:
	if source == game.hero:
		provoked_hero = true
		reaggro_block = 0.0
	elif source != null:
		provoked_building = source


func _attack() -> void:
	var a: Dictionary = def.attack
	attack_cd = float(a.interval)
	var dmg := float(a.damage) * out_mult()
	if bool(a.get("ranged", false)):
		game.fx.tracer(position + Vector3(0, height() * 0.7, 0), target.position + Vector3(0, 1.0, 0), Color("c9a35a"))
	if target == game.hero:
		game.damage_hero(dmg, self)
	else:
		game.damage_building(target, dmg)


# ---------------------------------------------------------------- Festhängen

func _check_stuck(dt: float, now: float) -> void:
	if not wants_move:
		_stuck_t = 0.0
		_stuck_pos = position
		return
	var ai: Dictionary = game.cfg.ai
	_stuck_t += dt
	if _stuck_t < float(ai.stuck_check):
		return
	var moved := _flat_dist(_stuck_pos)
	var expect := speed * cc.speed_factor(now) * _stuck_t
	if moved < expect * float(ai.stuck_ratio):
		_stuck_n += 1
		stuck_events += 1
		var side := 1.0 if (_stuck_n % 2 == 1) == (game.rng.randf() < 0.5) else -1.0
		_side_dir = Vector3(-_last_dir.z, 0, _last_dir.x) * side
		_side_t = float(ai.sidestep_time)
		if _stuck_n >= 3:
			if state == "chase":
				drop_target(2.0)
			else:
				road_s = game.road_project(position, 0.0, game.road_len)
				anchor_s = road_s
				lane = game.rng.randf_range(-0.5, 0.5)
				if state == "return":
					state = "road"
		if _stuck_n >= 5:
			# letzte Rettung: ein Stück direkt Richtung Straßenmitte schieben, Hindernisse lösen danach auf
			var p: Vector3 = game.road_point(road_s + 2.0, 0.0)
			position += (p - position).limit_length(1.5)
			_stuck_n = 0
	else:
		_stuck_n = 0
	_stuck_t = 0.0
	_stuck_pos = position


# ---------------------------------------------------------------- Fähigkeiten

func _try_ability(now: float) -> bool:
	if now < gap_until:
		return false
	for aid in def.get("abilities", []):
		if now < float(ab_ready.get(aid, 0.0)):
			continue
		var ab: Dictionary = game.ability_defs[aid]
		if _can_cast(ab):
			start_cast(str(aid), now)
			return true
	return false


func _can_cast(ab: Dictionary) -> bool:
	if str(ab.kind) == "summon":
		var h = game.hero
		return h != null and h.alive() and _flat_dist(h.position) <= 24.0
	if target == null or target != game.hero:
		return false
	var d: float = _flat_dist(target.position) - target.radius
	return d <= float(ab.get("cast_range", 5.0)) and d >= float(ab.get("min_range", 0.0))


## Fähigkeit ansetzen: Cooldown läuft ab sofort (Lukas: auch bei Betäubung während des Aufladens).
func start_cast(aid: String, now: float) -> void:
	var ab: Dictionary = game.ability_defs[aid]
	ab_ready[aid] = now + float(ab.cooldown)
	gap_until = now + float(ab.windup) + float(game.cfg.ai.ability_gap)
	casts_started += 1
	var tpos: Vector3 = target.position if target else position
	var dir := tpos - position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = facing
	cast = {"id": aid, "ab": ab, "t": 0.0, "windup": float(ab.windup), "phase": "windup", "n": 0,
		"rep": int(ab.get("repeat", 1)), "dir": dir.normalized(), "point": tpos, "tele": []}
	_face(dir)
	_make_teles()


func _make_teles() -> void:
	var ab: Dictionary = cast.ab
	var n: int = cast.n
	var dir: Vector3 = cast.dir.rotated(Vector3.UP, deg_to_rad(float(ab.get("rotate", 0.0)) * n))
	var teles: Array = []
	match str(ab.kind):
		"circle":
			var count := int(ab.get("count", 1))
			for k in count:
				var p: Vector3 = cast.point
				if k > 0:
					p += Vector3(game.rng.randf_range(-1, 1), 0, game.rng.randf_range(-1, 1)).normalized() * game.rng.randf_range(1.5, float(ab.get("scatter", 3.0)))
				var t := HdTelegraph.circle(float(ab.radius))
				t.position = p
				teles.append(t)
		"cone":
			var t := HdTelegraph.cone(float(ab.range), float(ab.angle))
			t.position = position
			t.aim(dir)
			teles.append(t)
		"ring":
			var g := float(ab.get("grow", 0.0)) * n
			var t := HdTelegraph.ring(float(ab.inner) + g, float(ab.radius) + g)
			t.position = position
			teles.append(t)
		"charge":
			var t := HdTelegraph.line(float(ab.length), float(ab.width))
			t.position = position
			t.aim(dir)
			teles.append(t)
		"skillshot":
			var count := int(ab.get("count", 1))
			var spread := float(ab.get("spread", 0.0))
			for k in count:
				var off := (k - (count - 1) * 0.5) * spread
				var t := HdTelegraph.line(float(ab.length), float(ab.width))
				t.position = position
				t.aim(dir.rotated(Vector3.UP, deg_to_rad(off)))
				teles.append(t)
		"whirl":
			var t := HdTelegraph.circle(float(ab.radius))
			t.position = position
			t.follow = self
			teles.append(t)
		"summon":
			var t := HdTelegraph.circle(float(ab.radius), HdTelegraph.SUMMON)
			t.position = position
			t.follow = self
			teles.append(t)
	for t in teles:
		game.add_tele(t)
	cast.tele = teles
	cast.cur_dir = dir


## Betäubt oder unterbrochen: Warnfläche weg, Cooldown bleibt (startete beim Ansetzen).
func cancel_cast() -> void:
	for t in cast.get("tele", []):
		if is_instance_valid(t):
			t.queue_free()
	cast = {}
	casts_interrupted += 1
	game.floater(position + Vector3(0, height() + 0.6, 0), tr("Unterbrochen"), UiTheme.CYAN)


func _step_cast(dt: float, now: float) -> void:
	var ab: Dictionary = cast.ab
	cast.t += dt
	match str(cast.phase):
		"windup":
			var p: float = cast.t / maxf(float(cast.windup), 0.01)
			for t in cast.tele:
				if is_instance_valid(t):
					t.progress = p
			if cast.t >= cast.windup:
				_fire(now)
		"dash":
			var step_len := minf(float(cast.left), 22.0 * dt)
			cast.left -= step_len
			game.move_unit(self, cast.cur_dir, step_len / dt, dt, true)
			if cast.left <= 0.01:
				_next_or_end()
		"whirl":
			var h = game.hero
			if h and h.alive():
				var v: Vector3 = h.position - position
				v.y = 0.0
				if v.length() > 0.5:
					game.move_unit(self, v.normalized(), speed * float(ab.get("speed_mult", 1.0)) * cc.speed_factor(now), dt)
			_body.rotation.y += dt * 14.0
			var tick := float(ab.tick)
			cast.tick_t += dt
			for t in cast.tele:
				if is_instance_valid(t):
					t.progress = cast.tick_t / tick
					t.flash = maxf(0.0, t.flash - dt * 4.0)
			if cast.tick_t >= tick:
				cast.tick_t = 0.0
				for t in cast.tele:
					if is_instance_valid(t):
						t.flash = 0.7
				game.ability_hit_area(self, HdTelegraph.CIRCLE, position, facing, float(ab.radius), 0, 0, 0, 0, float(ab.damage) * out_mult(), 0.0)
			if cast.t >= float(ab.duration):
				_body.rotation.y = 0.0
				_next_or_end()


func _fire(_now: float) -> void:
	var ab: Dictionary = cast.ab
	var dmg := float(ab.get("damage", 0.0)) * out_mult()
	var kind := str(ab.kind)
	match kind:
		"circle", "cone", "ring":
			for t in cast.tele:
				game.tele_hit(self, t, dmg, 0.0)
				if kind == "circle" and float(ab.get("pool", 0.0)) > 0.0:
					game.add_pool(t.position, float(ab.radius), float(ab.pool_dps) * out_mult(), float(ab.pool), self)
		"charge":
			for t in cast.tele:
				game.tele_hit(self, t, dmg, float(ab.get("knockdown", 0.0)))
			cast.phase = "dash"
			cast.left = float(ab.length) - radius
		"skillshot":
			for t in cast.tele:
				game.enemy_projectile(self, t.position, t.forward(), float(ab.speed), float(ab.length), float(ab.width), dmg)
		"whirl":
			cast.phase = "whirl"
			cast.t = 0.0
			cast.tick_t = 0.0
			for t in cast.tele:
				t.progress = 0.0
			return
		"summon":
			game.summon(self, str(ab.summon), int(ab.count), float(ab.radius))
	for t in cast.tele:
		if is_instance_valid(t):
			t.trigger()
	if kind != "charge":
		_next_or_end()


func _next_or_end() -> void:
	for t in cast.get("tele", []):
		if is_instance_valid(t) and t.fade < 0.0:
			t.trigger()
	cast.n += 1
	if cast.n < int(cast.rep):
		cast.t = 0.0
		cast.phase = "windup"
		cast.windup = float(cast.ab.get("repeat_windup", cast.ab.windup))
		if str(cast.ab.kind) == "circle":
			var h = game.hero
			if h and h.alive():
				cast.point = h.position
		_make_teles()
	else:
		cast = {}
