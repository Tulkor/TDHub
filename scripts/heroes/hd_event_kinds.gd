class_name HdEventKinds
extends RefCounted
## Abläufe der Ereignisse aus dem Pool data/heroes_ereignisse.json (System timed_events, alle 5 Minuten).
## Je Art (kind) ein Ablauf, die Inhalte stehen nur in den Daten:
## - jagd: Ziel(e) besiegen (Champion mit Leibwache, fliehende Bestie, Rammbock auf der Straße, Farmgrund
##   mit nachwachsenden Kobolden). Optionen: count, guards, flee, passive, revive, impact, respawn, each,
##   hit_gold, leak_penalty, fail (false = Zeitablauf ist kein Scheitern).
## - ueberleben: im Kreis bleiben, während ein unbesiegbarer Gegner (enemy) bzw. Rudel (packs) angreifen.
##   per_sec = Belohnung je Sekunde im Kreis, leave = so lange darf man draußen sein.
## - regen: Warnflächen regnen herab (auch auf Gegner, foe_damage), höchstens max_hits Treffer.
## - sammeln: Lichter einsammeln (each je Stück, all = Belohnung nur für alle), mimic = Chance auf Gegner.
## - halten: time Sekunden im Kreis stehen (innerhalb limit), alle every s stürmen Gegner an (spawn).
## - segen: sofort, Werte auf Zeit (stats) oder Gegner-/Gold-/EP-Faktoren (foes, gold, xp).
## - wahl: eine Option wählen (HdEvents.choice), Kosten cost/wood_cost/cost_lives, chance, stake.
## Gegner der Ereignisse: zone "ereignis" (ohne Straße, kein Wellengold) oder auf der Straße, immer mit
## event_tag = id des Ereignisses.

const KINDS := ["jagd", "ueberleben", "regen", "sammeln", "halten", "segen", "wahl"]

var game  ## HdGame
var task: Dictionary = {}     ## laufende Aufgabe {id, def, kind, until, …}
var _nodes: Array = []
var _hit_cd := 0.0


func _init(g) -> void:
	game = g


func busy() -> bool:
	return not task.is_empty()


func start(d: Dictionary) -> void:
	var kind := str(d.kind)
	if kind == "segen":
		_bless(d)
		return
	task = {"id": str(d.id), "def": d, "kind": kind, "t": 0.0, "until": game.play_time + float(d.get("time", 0.0)) if float(d.get("time", 0.0)) > 0.0 else -1.0}
	match kind:
		"jagd":
			_start_hunt(d)
		"ueberleben":
			_start_survive(d)
		"regen":
			task.hits = 0
			task.next = 0.0
			task.pending = []
		"sammeln":
			_start_collect(d)
		"halten":
			_start_hold(d)
	game.changed.emit()


func step(dt: float) -> void:
	_hit_cd = maxf(0.0, _hit_cd - dt)
	if task.is_empty():
		return
	task.t = float(task.t) + dt
	match str(task.kind):
		"jagd":
			_step_hunt(dt)
		"ueberleben":
			_step_survive(dt)
		"regen":
			_step_rain(dt)
		"sammeln":
			_step_collect(dt)
		"halten":
			_step_hold(dt)
	if not task.is_empty() and float(task.until) > 0.0 and game.play_time >= float(task.until):
		_timeout()


# ---------------------------------------------------------------- Hilfen

## Gegner-Daten für ein Ereignis: base (id, wave_normal, wave_elite) plus Änderungen; hp ist ein Faktor.
func make_def(spec: Dictionary, suffix := "") -> String:
	var base := str(spec.get("base", "moorklauer"))
	if base == "wave_normal" or base == "wave_elite":
		base = _wave_enemy("elite" if base == "wave_elite" else "normal")
	var d: Dictionary = game.enemy_defs[base].duplicate(true)
	var id := "ev_%s%s" % [str(task.get("id", "x")), suffix]
	d.id = id
	for k in ["name", "color", "size", "speed", "rank", "abilities", "aggro", "leash"]:
		if spec.has(k):
			d[k] = spec[k]
	d.hp = float(d.hp) * float(spec.get("hp", 1.0))
	d.erase("faction")
	d.erase("land")
	d.erase("siege")
	d.erase("phases")
	d.lives = 0
	game.enemy_defs[id] = d
	return id


func _wave_enemy(rank: String) -> String:
	var fac := ""
	if game.wave >= 1:
		var w: Dictionary = game.cfg.waves.list[clampi(game.wave, 1, game.cfg.waves.list.size()) - 1]
		fac = str(game.enemy_defs[str(w.groups[0][0])].get("faction", ""))
	var pool: Array = []
	for id in game.enemy_defs:
		var e: Dictionary = game.enemy_defs[id]
		if str(e.get("faction", "")) == fac and str(e.get("rank", "normal")) == rank and not bool(e.get("fly", false)):
			pool.append(id)
	if pool.is_empty():
		return "moorhauptmann" if rank == "elite" else "moorklauer"
	return pool[game.rng.randi() % pool.size()]


## Ort nach where: held, feld, ecke, hain, vorwerk.
func place(where: String) -> Vector3:
	var p := Vector3.ZERO
	match where:
		"held":
			var a = game.rng.randf() * TAU
			p = game.hero.position + Vector3(cos(a), 0, sin(a)) * 10.0
		"hain":
			p = game.zones.center("hain") * 0.82
		"ecke":
			var a = (game.rng.randi() % 4) * PI * 0.5 + PI * 0.25
			p = Vector3(cos(a), 0, sin(a)) * 36.0
		"vorwerk":
			var r: HdRoad = game.roads[game.rng.randi() % game.roads.size()]
			var s: float = r.length * 0.3
			p = r.point(s) + r.side(s) * 10.0
		_:
			var a = game.rng.randf() * TAU
			p = Vector3(cos(a), 0, sin(a)) * game.rng.randf_range(26.0, 46.0)
	var b: Array = game.bounds()
	p.x = clampf(p.x, float(b[0]) + 6.0, float(b[2]) - 6.0)
	p.z = clampf(p.z, float(b[1]) + 6.0, float(b[3]) - 6.0)
	return game.free_point(p, 2.0)


func _spawn(def_id: String, at: Vector3, home = null) -> HdEnemy:
	var e: HdEnemy = game.spawn_home(def_id, at, "ereignis", home)
	e.event_tag = str(task.id)
	return e


func event_enemies() -> Array:
	var out: Array = []
	if task.is_empty():
		return out
	for e in game.enemies:
		if not e.dead and e.event_tag == str(task.id):
			out.append(e)
	return out


func _ring(at: Vector3, r: float, c: Color) -> Node3D:
	var n := Node3D.new()
	n.position = at
	var ring := HdTelegraph.ring(r - 0.3, r, c)
	ring.progress = 1.0
	n.add_child(ring)
	game.add_child(n)
	_nodes.append(n)
	return n


func _orb(at: Vector3, c: Color) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.add_child(HdDev.sphere(0.55, HdDev.mat(c, 0.3, 1.6), Vector3(0, 1.2, 0)))
	n.add_child(HdDev.cyl(0.08, 0.08, 6.0, HdDev.flat(c, 0.35), Vector3(0, 3.0, 0), 6))
	game.add_child(n)
	_nodes.append(n)
	return n


func _hero_in(at: Vector3, r: float) -> bool:
	var h = game.hero
	return h.alive() and Vector2(h.position.x - at.x, h.position.z - at.z).length() <= r


## Aufgabe beenden: ok → Belohnung reward (falls vorhanden). Gegner und Knoten des Ereignisses verschwinden.
func finish(ok: bool, why := "") -> void:
	if task.is_empty():
		return
	var d: Dictionary = task.def
	var name := tr(str(d.name))
	for e in event_enemies():
		if e.zone == "ereignis":
			game._remove(e)
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes = []
	var extra := float(task.get("earned", 0.0))
	task = {}
	if ok:
		var r: Dictionary = d.get("reward", {})
		var txt := HdReward.grant(game, r) if not r.is_empty() else ""
		if extra > 0.0:
			game.shop.add_gold(roundi(extra))
			txt = (txt + " · " if txt != "" else "") + tr("+%d Gold") % roundi(extra)
		game.message.emit(tr("%s geschafft! %s") % [name, txt])
	else:
		if extra > 0.0:
			game.shop.add_gold(roundi(extra))
		game.message.emit(tr("%s vorbei. %s") % [name, why])
	game.shop._changed()


func _timeout() -> void:
	match str(task.kind):
		"jagd":
			if bool(task.def.get("fail", true)):
				finish(false, tr("Die Zeit ist um."))
			else:
				finish(false, "")
		"ueberleben":
			finish(true)
		"regen":
			var mx := int(task.def.get("max_hits", 99))
			finish(int(task.hits) <= mx, tr("Zu oft getroffen (%d)") % int(task.hits))
		"sammeln":
			finish(not bool(task.def.get("all", false)) and int(task.got) > 0, tr("%d von %d gesammelt") % [int(task.got), int(task.count)])
		"halten":
			finish(false, tr("Nicht lange genug gehalten."))


## Auch beim Run-Ende/Endgebiet: laufende Aufgabe ohne Belohnung abbrechen.
func clear() -> void:
	if not task.is_empty():
		finish(false, tr("Abgebrochen."))


# ---------------------------------------------------------------- Jagd

func _start_hunt(d: Dictionary) -> void:
	var where := str(d.get("where", "feld"))
	var spec: Dictionary = d.get("enemy", {}).duplicate()
	if bool(d.get("passive", false)):
		spec.aggro = 0.0
	var did := make_def(spec)
	var n := int(d.get("count", 1))
	task.targets = n
	task.revives = int(d.get("revive", 0))
	task.wood_n = 0
	if where == "strasse":
		var r: HdRoad = game.roads[game.rng.randi() % game.roads.size()]
		for k in n:
			var e: HdEnemy = game.spawn(did, null, 0.0, r)
			e.event_tag = str(task.id)
			e.lane = 0.0
		task.pos = r.point(0.0)
		game.message.emit(tr("%s auf der %s!") % [tr(str(d.name)), tr(r.name)])
	else:
		var at := place(where)
		task.pos = at
		if bool(d.get("impact", false)):
			game.fx.nova(at, 7.0, UiTheme.CYAN)
		for k in n:
			var off := Vector3.ZERO if n == 1 else Vector3(cos(k * TAU / n), 0, sin(k * TAU / n)) * (4.0 if n < 8 else 9.0)
			var e := _spawn(did, game.free_point(at + off, 1.0))
			e.flee = bool(d.get("flee", false))
			if bool(spec.get("mirror", false)):
				e.max_hp = game.hero.max_hp * 3.0
				e.hp = e.max_hp
				e.dmg_mult *= 1.0 + game.hero.level * 0.04
		var g: Dictionary = d.get("guards", {})
		if not g.is_empty():
			var gid := make_def(g, "_w")
			for k in int(g.get("count", 2)):
				var a := k * TAU / int(g.count) + 0.4
				var w := _spawn(gid, game.free_point(at + Vector3(cos(a), 0, sin(a)) * 3.5, 1.0))
				w.set_meta("guard", true)
		_ring(at, 3.0, UiTheme.GOLD)


func _targets_left() -> Array:
	return event_enemies().filter(func(e): return not e.has_meta("guard"))


func _step_hunt(dt: float) -> void:
	var d: Dictionary = task.def
	# Leibgarde mit heal: solange sie lebt, heilt sich das Ziel
	if bool(d.get("guards", {}).get("heal", false)):
		var guards := event_enemies().filter(func(e): return e.has_meta("guard"))
		if not guards.is_empty():
			for e in _targets_left():
				e.hp = minf(e.max_hp, e.hp + e.max_hp * 0.015 * dt)
	if bool(d.get("respawn", false)):
		return
	if _targets_left().is_empty() and float(task.t) > 0.5:
		finish(true)


func on_kill(e: HdEnemy) -> bool:
	if task.is_empty() or e.event_tag != str(task.id):
		return e.zone == "ereignis"
	var d: Dictionary = task.def
	if str(task.kind) == "jagd" and not e.has_meta("guard"):
		if int(task.get("revives", 0)) > 0:
			task.revives = int(task.revives) - 1
			var r := _spawn(e.id, e.position)
			game.fx.nova(e.position, 4.0, UiTheme.PURPLE_LIGHT)
			game.message.emit(tr("%s steht wieder auf!") % tr(str(e.def.name)))
			r.max_hp = e.max_hp
			r.hp = r.max_hp
		if d.has("each"):
			var txt := HdReward.grant(game, d.each)
			game.floater(e.position + Vector3(0, 2.4, 0), txt, UiTheme.COIN)
			task.wood_n = int(task.wood_n) + 1
			var ev := int(d.get("each_wood_every", 0))
			if ev > 0 and int(task.wood_n) % ev == 0:
				game.shop.add_wood(1)
		if bool(d.get("respawn", false)) and float(task.until) - game.play_time > 2.0:
			_spawn(e.id, place(str(d.get("where", "feld"))).lerp(task.pos, 0.85))
	return e.zone == "ereignis"


## Treffer des Helden (hit_gold: Schatzgoblin wirft Gold ab).
func on_hit(e: HdEnemy) -> void:
	if task.is_empty() or e.event_tag != str(task.id) or not task.def.has("hit_gold") or _hit_cd > 0.0:
		return
	_hit_cd = 0.3
	var g := HdReward.amount(game, task.def.hit_gold)
	game.shop.add_gold(g)
	game.floater(e.position + Vector3(0, 2.0, 0), "+%d" % g, UiTheme.COIN)


## Ereignis-Gegner erreicht die Feste (Rammbock): Strafe und Ende.
func on_leak(e: HdEnemy) -> void:
	if task.is_empty() or e.event_tag != str(task.id):
		return
	var pen: Dictionary = task.def.get("leak_penalty", {})
	game.lives -= int(pen.get("lives", 0))
	finish(false, tr("Er hat die Feste erreicht."))


# ---------------------------------------------------------------- Überleben

func _start_survive(d: Dictionary) -> void:
	var at := place("held").lerp(game.hero.position, 0.6)
	task.pos = at
	task.out = 0.0
	task.earned = 0.0
	task.pack_t = 1.0
	_ring(at, float(d.radius), UiTheme.GOLD)
	if d.has("enemy"):
		var spec: Dictionary = d.enemy.duplicate()
		spec.aggro = float(d.radius) * 2.5
		spec.leash = float(d.radius) * 3.0
		var e := _spawn(make_def(spec), at + Vector3(float(d.radius) * 0.6, 0, 0), at)
		e.immortal = true


func _step_survive(dt: float) -> void:
	var d: Dictionary = task.def
	var inside := _hero_in(task.pos, float(d.radius))
	if inside:
		task.out = 0.0
		if d.has("per_sec"):
			task.earned = float(task.earned) + float(HdReward.amount(game, d.per_sec.gold)) * dt
	else:
		task.out = float(task.out) + dt
		if float(task.out) > float(d.get("leave", 3.0)):
			finish(false, tr("Den Kreis verlassen."))
			return
	if d.has("packs"):
		task.pack_t = float(task.pack_t) - dt
		if float(task.pack_t) <= 0.0:
			var p: Dictionary = d.packs
			task.pack_t = float(p.get("every", 7.0))
			var spec: Dictionary = p.duplicate()
			spec.aggro = float(d.radius) * 3.0
			spec.leash = float(d.radius) * 3.0
			var pid := make_def(spec, "_r")
			var a0 = game.rng.randf() * TAU
			for k in int(p.get("count", 3)):
				var a = a0 + k * 0.5
				_spawn(pid, game.free_point(task.pos + Vector3(cos(a), 0, sin(a)) * (float(d.radius) + 2.0), 1.0), task.pos)


# ---------------------------------------------------------------- Regen

func _step_rain(dt: float) -> void:
	var d: Dictionary = task.def
	task.next = float(task.next) - dt
	if float(task.next) <= 0.0:
		task.next = float(d.get("every", 0.8))
		var at: Vector3
		var roll = game.rng.randf()
		if str(d.get("around", "")) == "feste":
			var a = game.rng.randf() * TAU
			at = game.fortress_pos + Vector3(cos(a), 0, sin(a)) * game.rng.randf_range(float(game.cfg.arena.fortress_radius) + 2.0, 22.0)
		elif roll < 0.6 or game.enemies.is_empty():
			at = game.hero.position + Vector3(game.rng.randf_range(-7, 7), 0, game.rng.randf_range(-7, 7))
		else:
			var e: HdEnemy = game.enemies[game.rng.randi() % game.enemies.size()]
			at = e.position
		var dmg = float(d.get("damage", 0.1)) * game.hero.max_hp
		var r := float(d.get("radius", 2.5))
		game.ground_blast(at, r, float(d.get("windup", 1.2)), dmg, _rain_hit)
		if d.has("foe_damage"):
			task.pending.append({"at": at, "r": r, "t": float(d.get("windup", 1.2))})
	for i in range(task.pending.size() - 1, -1, -1):
		var p: Dictionary = task.pending[i]
		p.t = float(p.t) - dt
		if p.t <= 0.0:
			task.pending.remove_at(i)
			var fd := float(HdReward.amount(game, d.foe_damage))
			for e in game.enemies.duplicate():
				if not e.dead and Vector2(e.position.x - p.at.x, e.position.z - p.at.z).length() <= p.r + e.radius:
					e.take(fd)
					if e.hp <= 0.0:
						game._kill(e)


func _rain_hit() -> void:
	if task.is_empty():
		return
	task.hits = int(task.hits) + 1
	if task.def.has("slow"):
		game.hero.add_buff("ereignis_frost", {"speed": -float(task.def.slow)}, 1.5)


# ---------------------------------------------------------------- Sammeln

func _start_collect(d: Dictionary) -> void:
	task.count = int(d.get("count", 6))
	task.got = 0
	task.orbs = []
	var c := Color(str(d.get("color", "9ad8ff")))
	for k in int(task.count):
		var a = game.rng.randf() * TAU
		var p = game.hero.position + Vector3(cos(a), 0, sin(a)) * game.rng.randf_range(10.0, 34.0)
		var b: Array = game.bounds()
		p.x = clampf(p.x, float(b[0]) + 4.0, float(b[2]) - 4.0)
		p.z = clampf(p.z, float(b[1]) + 4.0, float(b[3]) - 4.0)
		var n := _orb(game.free_point(p, 1.0), c)
		task.orbs.append({"node": n, "vel": Vector3(game.rng.randf_range(-1, 1), 0, game.rng.randf_range(-1, 1)).normalized() * 1.6})


func _step_collect(dt: float) -> void:
	var d: Dictionary = task.def
	for o in task.orbs.duplicate():
		var n: Node3D = o.node
		if not is_instance_valid(n):
			task.orbs.erase(o)
			continue
		if bool(d.get("drift", false)):
			n.position += o.vel * dt
			n.position = game.free_point(n.position, 0.5)
		n.get_child(0).position.y = 1.2 + sin(game.play_time * 3.0 + n.position.x) * 0.25
		if _hero_in(n.position, 1.8):
			task.orbs.erase(o)
			task.got = int(task.got) + 1
			if game.rng.randf() < float(d.get("mimic", 0.0)):
				var spec: Dictionary = d.mimic_enemy.duplicate()
				spec.aggro = 14.0
				_spawn(make_def(spec, "_m"), n.position).event_tag = "mimik"
				game.message.emit(tr("Eine Mimik!"))
			elif d.has("each"):
				game.floater(n.position + Vector3(0, 2.0, 0), HdReward.grant(game, d.each), UiTheme.CYAN)
			game.fx.nova(n.position, 2.0, UiTheme.CYAN)
			n.queue_free()
	if int(task.got) >= int(task.count):
		finish(true)


# ---------------------------------------------------------------- Halten

func _start_hold(d: Dictionary) -> void:
	var at := place("vorwerk")
	task.pos = at
	task.held = 0.0
	task.wave_t = 2.0
	_ring(at, float(d.radius), UiTheme.CYAN)
	var n := Node3D.new()
	n.position = at
	n.add_child(HdDev.cyl(0.5, 0.7, 1.6, HdDev.mat(Color("8a8a9a"), 0.5), Vector3(0, 0.8, 0), 8))
	task.fire = HdDev.sphere(0.5, HdDev.mat(UiTheme.GOLD, 0.3, 0.2), Vector3(0, 2.0, 0))
	n.add_child(task.fire)
	game.add_child(n)
	_nodes.append(n)


func _step_hold(dt: float) -> void:
	var d: Dictionary = task.def
	if _hero_in(task.pos, float(d.radius)):
		task.held = float(task.held) + dt
	var f: MeshInstance3D = task.fire
	if is_instance_valid(f):
		f.scale = Vector3.ONE * (0.6 + 1.2 * held_frac())
	task.wave_t = float(task.wave_t) - dt
	if float(task.wave_t) <= 0.0:
		task.wave_t = float(d.get("every", 5.0))
		var spec: Dictionary = d.spawn.duplicate()
		spec.aggro = 30.0
		spec.leash = 40.0
		var sid := make_def(spec, "_s")
		var a0 = game.rng.randf() * TAU
		for k in int(spec.get("count", 2)):
			var a = a0 + k * 0.6
			_spawn(sid, game.free_point(task.pos + Vector3(cos(a), 0, sin(a)) * (float(d.radius) + 9.0), 1.0), task.pos)
	if float(task.held) >= float(d.time):
		finish(true)


func held_frac() -> float:
	if task.is_empty() or not task.has("held"):
		return 0.0
	return clampf(float(task.held) / float(task.def.time), 0.0, 1.0)


# ---------------------------------------------------------------- Segen

func _bless(d: Dictionary) -> void:
	var t := float(d.get("time", 60.0))
	if d.has("stats"):
		game.add_event_buff(str(d.name), d.stats, t)
	if d.has("foes") or d.has("gold") or d.has("xp"):
		game.event_mods.append({"name": str(d.name), "foes": d.get("foes", {}), "gold": float(d.get("gold", 1.0)), "xp": float(d.get("xp", 1.0)), "until": game.play_time + t})
	game.message.emit(tr("%s: %s") % [tr(str(d.name)), tr(str(d.desc))])
	game.shop._changed()


# ---------------------------------------------------------------- Wahl

func options(d: Dictionary) -> Array:
	var out: Array = []
	for o in d.options:
		var t := tr(str(o.text))
		var r: Dictionary = o.get("reward", {})
		var extra := HdReward.text(game, r)
		if o.has("cost"):
			t += " (%d Gold)" % HdReward.amount(game, o.cost)
		if extra != "" and not str(o.text).contains("Holz"):
			t += ": " + extra
		out.append(t)
	return out


## Kann Option i gewählt werden? "" = ja.
func can_pick(d: Dictionary, i: int) -> String:
	var o: Dictionary = d.options[i]
	if o.has("cost") and game.shop.gold < HdReward.amount(game, o.cost):
		return tr("Zu wenig Gold")
	if o.has("wood_cost") and game.shop.wood < int(o.wood_cost):
		return tr("Zu wenig Holz")
	if o.has("cost_lives") and game.lives <= int(o.cost_lives):
		return tr("Die Feste hat zu wenig Leben")
	return ""


func pick(d: Dictionary, i: int) -> void:
	var o: Dictionary = d.options[i]
	if can_pick(d, i) != "":
		game.message.emit(tr("%s: nichts gewählt") % tr(str(d.name)))
		return
	if o.has("cost"):
		game.shop.gold -= HdReward.amount(game, o.cost)
	if o.has("wood_cost"):
		game.shop.wood -= int(o.wood_cost)
	if o.has("cost_lives"):
		game.lives -= int(o.cost_lives)
	if o.has("stake"):
		var s := int(game.shop.gold * float(o.stake))
		if game.rng.randf() < float(o.get("chance", 0.5)):
			game.shop.add_gold(s)
			game.message.emit(tr("Gewonnen! +%d Gold") % s)
		else:
			game.shop.gold -= s
			game.message.emit(tr("Verloren! −%d Gold") % s)
		game.shop._changed()
		return
	if o.has("chance") and game.rng.randf() >= float(o.chance):
		game.message.emit(tr("%s: kein Glück") % tr(str(d.name)))
		return
	var r: Dictionary = o.get("reward", {})
	if r.is_empty():
		game.message.emit(tr("%s: abgelehnt") % tr(str(d.name)))
		return
	game.message.emit(tr("%s: %s") % [tr(str(d.name)), HdReward.grant(game, r)])


# ---------------------------------------------------------------- Anzeige

## {title, line, frac} der laufenden Aufgabe für die Seitenleiste ({} = nichts).
func card() -> Dictionary:
	if task.is_empty():
		return {}
	var d: Dictionary = task.def
	var left := ceili(float(task.until) - game.play_time) if float(task.until) > 0.0 else -1
	var line := ""
	var frac := -1.0
	match str(task.kind):
		"jagd":
			var n := _targets_left().size()
			line = tr("Noch %d Ziel(e)") % n if not bool(d.get("respawn", false)) else tr("Farmen!")
		"ueberleben":
			line = tr("Im Kreis bleiben · %d Gold") % roundi(float(task.earned))
			frac = clampf(float(task.t) / maxf(1.0, float(d.time)), 0.0, 1.0)
		"regen":
			line = tr("Treffer %d / %d") % [int(task.hits), int(d.get("max_hits", 99))]
			frac = clampf(float(task.t) / maxf(1.0, float(d.time)), 0.0, 1.0)
		"sammeln":
			line = tr("%d / %d gesammelt") % [int(task.got), int(task.count)]
			frac = float(task.got) / maxf(1.0, float(task.count))
		"halten":
			line = tr("Halten %d / %d s") % [floori(float(task.held)), int(d.time)]
			frac = held_frac()
	if left >= 0:
		line += " · " + tr("%d s") % left
	return {"title": tr(str(d.name)), "line": line, "frac": frac, "desc": tr(str(d.desc))}
