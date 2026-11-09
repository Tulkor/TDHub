class_name HdFinal
extends RefCounted
## Endgebiet „Der Schlund“ (Lukas 2026-11-09): nach der letzten Welle (Großangriff W40) kommt der Held in ein
## eigenes Gebiet neben der Karte. Dort stehen Challenges (data/heroes_endgebiet.json) und das Tor zum
## Verschlinger, das von Anfang an offen ist. Zustand und Regeln (offen/geschafft, Belohnungen sammeln,
## Boss erwacht nach awaken s) hält das gemeinsame System challenges, hier stehen Gebiet und Abläufe:
## - echos: Kriegsherren-Echos nacheinander besiegen (Tod des Helden = gescheitert)
## - siegel: Runensteine in der Reihenfolge der Wandtafel berühren, Fehler ruft Wächter und mischt neu
## - glutpfad: durch einen Gang voller Glutflächen zum Altar, höchstens max_hits Treffer
## - halten: time s im Kreis bleiben, Gegner stürmen an
## - wagnis: sofort annehmen (Belohnung plus Fluch im Endkampf)
## Belohnungen: boss {hp, remove} schwächen den Verschlinger, hero {Werte, shield, dmg_in} gelten im
## Endkampf, alles andere (item, perma, gold …) gibt HdReward sofort. Jeder Tod im Schlund kostet
## death_lives Feste-Leben, die Feste bleibt also wichtig.

var game  ## HdGame
var data: Dictionary
var active := false
var center := Vector3.ZERO
var boss: HdEnemy
var boss_dead := false
var run: Dictionary = {}       ## laufende Challenge {id, def, kind, …}
var _root: Node3D
var _stations: Dictionary = {}  ## id → {pos, node, ring}
var _hold: Dictionary = {}      ## id → Sekunden draufstehen
var _deaths := 0


func _init(g) -> void:
	game = g


func sys():
	return game.systems.get("challenges")


func _rel(p: Array) -> Vector3:
	return center + Vector3(float(p[0]), 0, float(p[1]))


## Grenzen des Gebiets [x0, z0, x1, z1].
func bounds() -> Array:
	var h: Array = data.area.half
	return [center.x - float(h[0]), center.z - float(h[1]), center.x + float(h[0]), center.z + float(h[1])]


func start_pos() -> Vector3:
	return _rel(data.start)


func station_pos(id: String) -> Vector3:
	return _stations[id].pos if _stations.has(id) else center


func gate_pos() -> Vector3:
	return _rel(data.gate.pos)


func arena_pos() -> Vector3:
	return _rel(data.arena.pos)


## Nach der letzten Welle: Gebiet bauen, Held hinüber, System starten.
func enter() -> void:
	if active:
		return
	data = sys().data if sys() else Database.load_json("res://data/heroes_endgebiet.json")
	var c: Array = data.area.center
	center = Vector3(float(c[0]), 0, float(c[1]))
	active = true
	game.events.kinds.clear()
	_build()
	_deaths = game.hero.deaths
	if not game.hero.alive():
		game.hero._respawn()
	game.teleport_hero(start_pos())
	game.message.emit(tr("Ihr betretet %s. Löst Challenges oder geht direkt durch das Tor.") % tr(str(data.name)))
	if sys():
		sys().enter()
	game.changed.emit()


func _build() -> void:
	_root = Node3D.new()
	game.add_child(_root)
	var b := bounds()
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(b[2] - b[0] + 8.0, b[3] - b[1] + 8.0)
	ground.mesh = gm
	ground.position = center + Vector3(0, -0.02, 0)
	ground.material_override = HdDev.mat(Color(str(data.area.ground)))
	_root.add_child(ground)
	# Rand aus Felszacken
	var edge := HdDev.mat(Color(str(data.area.edge)), 0.5, 0.3)
	for k in 64:
		var t := k / 64.0
		var p: Vector3
		if t < 0.25:
			p = Vector3(lerpf(b[0], b[2], t * 4.0), 0, b[1])
		elif t < 0.5:
			p = Vector3(b[2], 0, lerpf(b[1], b[3], (t - 0.25) * 4.0))
		elif t < 0.75:
			p = Vector3(lerpf(b[2], b[0], (t - 0.5) * 4.0), 0, b[3])
		else:
			p = Vector3(b[0], 0, lerpf(b[3], b[1], (t - 0.75) * 4.0))
		var h := 2.0 + fmod(k * 1.37, 2.5)
		_root.add_child(HdDev.cyl(0.8, 1.8, h, edge, p + Vector3(0, h * 0.5, 0), 5))
	# Kampfplatz und Tor
	var ap := arena_pos()
	var ar := float(data.arena.radius)
	_root.add_child(HdDev.cyl(ar, ar, 0.08, HdDev.mat(Color("2a1a40"), 0.5, 0.2), ap + Vector3(0, 0.02, 0), 32))
	var gp := gate_pos()
	var stone := HdDev.mat(Color("4a3a6a"), 0.5)
	for sx in [-3.2, 3.2]:
		_root.add_child(HdDev.box(Vector3(1.2, 6.0, 1.2), stone, gp + Vector3(sx, 3.0, 0)))
	_root.add_child(HdDev.box(Vector3(7.6, 1.0, 1.4), stone, gp + Vector3(0, 6.3, 0)))
	_root.add_child(HdDev.box(Vector3(5.2, 5.2, 0.2), HdDev.mat(UiTheme.PURPLE_LIGHT, 0.5, 1.4), gp + Vector3(0, 2.8, 0)))
	_station_ring(gp, 2.0, UiTheme.PURPLE_LIGHT)
	# Stationen
	for cd in data.list:
		var p := _rel(cd.pos)
		var col := Color(str(cd.get("color", "ffffff")))
		var n := Node3D.new()
		n.position = p
		n.add_child(HdDev.cyl(1.6, 1.9, 0.5, stone, Vector3(0, 0.25, 0), 8))
		n.add_child(HdDev.box(Vector3(0.6, 3.2, 0.6), HdDev.mat(col, 0.5, 1.0), Vector3(0, 2.1, 0)))
		_root.add_child(n)
		var ring := _station_ring(p, 2.2, col)
		_stations[str(cd.id)] = {"pos": p, "node": n, "ring": ring}


func _station_ring(p: Vector3, r: float, c: Color) -> HdTelegraph:
	var t := HdTelegraph.ring(r - 0.25, r, c)
	t.progress = 1.0
	t.position = p
	_root.add_child(t)
	return t


# ---------------------------------------------------------------- Ablauf

func step(dt: float) -> void:
	if not active:
		return
	if game.hero.deaths > _deaths:
		_deaths = game.hero.deaths
		var n := int(data.get("death_lives", 3))
		game.lives -= n
		game.message.emit(tr("Gefallen im Schlund: −%d Feste-Leben") % n)
		if str(run.get("kind", "")) == "echos":
			_end_run(false, tr("Der Held ist gefallen."))
		if game.lives <= 0:
			game.lives = 0
			game._finish(false)
			return
	if sys():
		sys().tick(dt)
	_step_stands(dt)
	match str(run.get("kind", "")):
		"echos":
			_step_echos()
		"siegel":
			_step_seals(dt)
		"glutpfad":
			_step_path(dt)
		"halten":
			_step_hold(dt)
	if boss != null and not boss_dead and boss.dead:
		boss_dead = true
	if boss_dead and game.state == "play":
		game._finish(true)


## Draufstehen auf Stationen und Tor (station_hold / gate.hold Sekunden).
func _step_stands(dt: float) -> void:
	var h = game.hero
	if not h.alive():
		_hold = {}
		return
	var spots := {"_tor": [gate_pos(), float(data.gate.hold)]}
	if sys() and not sys().boss_started and run.is_empty():
		for id in _stations:
			if sys().can_begin(id) == "":
				spots[id] = [_stations[id].pos, float(data.get("station_hold", 1.0))]
	for id in spots:
		var p: Vector3 = spots[id][0]
		if Vector2(h.position.x - p.x, h.position.z - p.z).length() < 2.2:
			_hold[id] = float(_hold.get(id, 0.0)) + dt
			if float(_hold[id]) >= float(spots[id][1]):
				_hold = {}
				if id == "_tor":
					_gate()
				else:
					begin(id)
				return
		else:
			_hold.erase(id)


## Fortschritt des Draufstehens 0–1 (Anzeige).
func stand_frac(id: String) -> float:
	return clampf(float(_hold.get(id, 0.0)) / maxf(0.1, float(data.get("station_hold", 1.0))), 0.0, 1.0)


func _gate() -> void:
	if sys() and not sys().boss_started:
		sys().start_boss("gate")
	else:
		game.teleport_hero(arena_pos() + Vector3(0, 0, float(data.arena.radius) - 3.0))


func begin(id: String) -> String:
	if not sys():
		return "?"
	return sys().begin(id)


## Haken challenge_begin: Ablauf aufsetzen.
func on_begin(d: Dictionary) -> void:
	run = {"id": str(d.id), "def": d, "kind": str(d.kind), "t": 0.0}
	game.message.emit(tr("Challenge: %s") % tr(str(d.name)))
	var p := station_pos(str(d.id))
	match str(d.kind):
		"echos":
			run.left = (d.bosses as Array).duplicate()
			run.cur = null
		"siegel":
			_setup_seals(d, p)
		"glutpfad":
			run.hits = 0
			run.next = 0.0
			run.from = p
			run.to = p + Vector3(0, 0, -float(d.length))
			run.altar = HdDev.cyl(1.0, 1.2, 1.4, HdDev.mat(UiTheme.GOLD, 0.5, 1.0), run.to + Vector3(0, 0.7, 0), 8)
			_root.add_child(run.altar)
		"halten":
			run.held = 0.0
			run.wave_t = 1.5
		"wagnis":
			sys().finish(str(d.id), true)
	game.changed.emit()


func _end_run(ok: bool, why := "") -> void:
	if run.is_empty():
		return
	var id := str(run.id)
	var name := tr(str(run.def.name))
	_clean_run()
	if not ok:
		game.message.emit(tr("%s gescheitert. %s") % [name, why])
	sys().finish(id, ok)


func _clean_run() -> void:
	for e in game.enemies:
		if not e.dead and e.zone == "final_run":
			game._remove(e)
	for k in ["altar", "board"]:
		if run.has(k) and is_instance_valid(run[k]):
			run[k].queue_free()
	for s in run.get("stones", []):
		if is_instance_valid(s.node):
			s.node.queue_free()
	run = {}


## Haken challenge_finished: Belohnung (sofortiger Teil) und Anzeige.
func on_finished(d: Dictionary, ok: bool) -> void:
	run = {} if str(run.get("id", "")) == str(d.id) else run
	if _stations.has(str(d.id)):
		var ring: HdTelegraph = _stations[str(d.id)].ring
		if is_instance_valid(ring) and ok:
			ring.visible = false
	if not ok:
		game.changed.emit()
		return
	var r: Dictionary = d.get("reward", {}).duplicate()
	for k in ["boss", "hero", "text"]:
		r.erase(k)
	var txt := HdReward.grant(game, r) if not r.is_empty() else ""
	var desc := tr(str(d.reward.get("text", "")))
	game.message.emit(tr("%s geschafft! %s") % [tr(str(d.name)), desc if txt == "" else desc + " · " + txt])
	game.changed.emit()


func on_abort(_d: Dictionary) -> void:
	_clean_run()


# ---------------------------------------------------------------- Echos

func _step_echos() -> void:
	var cur = run.get("cur")
	if cur != null and is_instance_valid(cur) and not cur.dead:
		return
	if (run.left as Array).is_empty():
		_end_run(true)
		return
	var id := str(run.left.pop_front())
	var p := station_pos(str(run.id)) + Vector3(0, 0, -8.0)
	var e: HdEnemy = game.spawn_home(id, game.free_point(p, 2.0), "final_run")
	e.max_hp *= float(run.def.get("hp", 0.6))
	e.hp = e.max_hp
	e.gold_free = true
	game.fx.nova(e.position, 5.0, UiTheme.PURPLE_LIGHT)
	game.message.emit(tr("Echo: %s") % tr(str(e.def.name)))
	run.cur = e


# ---------------------------------------------------------------- Siegel

const SEAL_COLORS := ["ff5c8a", "3ab8ff", "5ce08a", "ffd34a", "c07aff", "ff9a40"]


func _setup_seals(d: Dictionary, p: Vector3) -> void:
	var n := int(d.get("stones", 4))
	run.stones = []
	for k in n:
		var a := k * TAU / n + PI * 0.25
		var sp = game.free_point(p + Vector3(cos(a), 0, sin(a)) * 7.0, 1.0)
		var c := Color(SEAL_COLORS[k % SEAL_COLORS.size()])
		var node := Node3D.new()
		node.position = sp
		node.add_child(HdDev.box(Vector3(1.0, 1.8, 1.0), HdDev.mat(Color("4a4a5a"), 0.5), Vector3(0, 0.9, 0)))
		var rune := HdDev.box(Vector3(0.6, 0.6, 1.05), HdDev.mat(c, 0.5, 0.2), Vector3(0, 1.2, 0))
		node.add_child(rune)
		_root.add_child(node)
		run.stones.append({"node": node, "rune": rune, "color": c, "pos": sp})
	run.board = Node3D.new()
	run.board.position = p + Vector3(0, 0, 4.0)
	_root.add_child(run.board)
	_shuffle_seals()


func _shuffle_seals() -> void:
	var order: Array = range(run.stones.size())
	order.shuffle()
	run.order = order
	run.step = 0
	run.touch = -1
	for c in run.board.get_children():
		c.queue_free()
	run.board.add_child(HdDev.box(Vector3(run.stones.size() * 1.4 + 0.6, 1.8, 0.2), HdDev.mat(Color("2a2a36"), 0.5), Vector3(0, 1.6, 0)))
	for k in order.size():
		var c: Color = run.stones[order[k]].color
		run.board.add_child(HdDev.box(Vector3(0.9, 0.9, 0.25), HdDev.mat(c, 0.5, 1.0), Vector3((k - (order.size() - 1) * 0.5) * 1.4, 1.6, -0.05)))
	for s in run.stones:
		s.rune.material_override = HdDev.mat(s.color, 0.5, 0.2)


func _step_seals(_dt: float) -> void:
	var h = game.hero
	var near := -1
	for k in run.stones.size():
		var p: Vector3 = run.stones[k].pos
		if Vector2(h.position.x - p.x, h.position.z - p.z).length() < 1.9:
			near = k
	if near == run.touch:
		return
	run.touch = near
	if near < 0:
		return
	if near == int(run.order[run.step]):
		var s: Dictionary = run.stones[near]
		s.rune.material_override = HdDev.mat(s.color, 0.5, 2.0)
		game.fx.nova(s.pos, 2.0, s.color)
		run.step = int(run.step) + 1
		if int(run.step) >= run.stones.size():
			_end_run(true)
		return
	game.message.emit(tr("Falsches Siegel! Die Wächter erwachen."))
	var w: Dictionary = run.def.get("wrong", {})
	for k in int(w.get("count", 3)):
		var a := k * TAU / maxf(1.0, float(w.get("count", 3)))
		var e: HdEnemy = game.spawn_home(str(w.get("base", "leerling")), game.free_point(run.stones[near].pos + Vector3(cos(a), 0, sin(a)) * 4.0, 1.0), "final_run")
		e.gold_free = true
	_shuffle_seals()


# ---------------------------------------------------------------- Glutpfad

func _step_path(dt: float) -> void:
	var d: Dictionary = run.def
	var h = game.hero
	run.t = float(run.t) + dt
	run.next = float(run.next) - dt
	if run.next <= 0.0:
		run.next = float(d.every)
		var f = game.rng.randf()
		var p: Vector3 = run.from.lerp(run.to, f) + Vector3(game.rng.randf_range(-1, 1) * float(d.width) * 0.5, 0, 0)
		if game.rng.randf() < 0.4:
			p = h.position + Vector3(game.rng.randf_range(-1.5, 1.5), 0, game.rng.randf_range(-2.5, 0.5))
		game.ground_blast(p, float(d.radius), float(d.windup), float(d.damage) * h.max_hp, _path_hit)
	if Vector2(h.position.x - run.to.x, h.position.z - run.to.z).length() < 2.0:
		_end_run(true)


func _path_hit() -> void:
	if str(run.get("kind", "")) != "glutpfad":
		return
	run.hits = int(run.hits) + 1
	if int(run.hits) > int(run.def.max_hits):
		game.teleport_hero(start_pos())
		_end_run(false, tr("Zu oft getroffen."))


# ---------------------------------------------------------------- Halten

func _step_hold(dt: float) -> void:
	var d: Dictionary = run.def
	var p := station_pos(str(run.id))
	var h = game.hero
	if h.alive() and Vector2(h.position.x - p.x, h.position.z - p.z).length() <= float(d.radius):
		run.held = float(run.held) + dt
	run.wave_t = float(run.wave_t) - dt
	if run.wave_t <= 0.0:
		run.wave_t = float(d.every)
		var sp: Dictionary = d.spawn
		var a0 = game.rng.randf() * TAU
		for k in int(sp.get("count", 3)):
			var a = a0 + k * 0.7
			var e: HdEnemy = game.spawn_home(str(sp.base), game.free_point(p + Vector3(cos(a), 0, sin(a)) * (float(d.radius) + 10.0), 1.0), "final_run", p)
			e.gold_free = true
	if float(run.held) >= float(d.time):
		_end_run(true)


# ---------------------------------------------------------------- Endboss

## Haken final_boss_start: Verschlinger mit allen Schwächungen, Held mit allen Endkampf-Werten.
func start_boss(mods: Dictionary, reason: String) -> void:
	_clean_run()
	var bd: Dictionary = data.boss
	var base: Dictionary = game.enemy_defs[str(bd.id)].duplicate(true)
	base.id = "final_" + str(bd.id)
	base.erase("land")
	base.erase("siege")
	var bm: Dictionary = mods.get("boss", {})
	var removed: Array = bm.get("remove", [])
	base.abilities = (base.abilities as Array).filter(func(a): return not (a in removed))
	for ph in base.get("phases", []):
		ph.add = (ph.get("add", []) as Array).filter(func(a): return not (a in removed))
	base.aggro = 40.0
	base.leash = 60.0
	game.enemy_defs[base.id] = base
	var ap := arena_pos()
	boss = game.spawn_home(base.id, ap, "final", ap)
	boss.max_hp *= maxf(0.2, 1.0 + float(bm.get("hp", 0.0))) * float(bd.get("hp", 1.0))
	boss.hp = boss.max_hp
	boss.max_shield *= maxf(0.2, 1.0 + float(bm.get("hp", 0.0)))
	boss.shield = boss.max_shield
	game.fx.nova(ap, 10.0, UiTheme.PURPLE_LIGHT)
	var hm: Dictionary = mods.get("hero", {})
	var stats := {}
	for k in hm:
		if k in HdShop.STAT_TEXT:
			stats[k] = hm[k]
	if not stats.is_empty():
		game.add_event_buff(tr("Endkampf"), stats, 99999.0)
	if hm.has("dmg_in"):
		game.hero.add_buff("endkampf", {"dmg_in": float(hm.dmg_in)}, 99999.0)
	if hm.has("shield"):
		game.hero.add_shield(float(hm.shield), 99999.0)
	game.teleport_hero(ap + Vector3(0, 0, float(data.arena.radius) - 3.0))
	if reason == "awaken":
		game.message.emit(tr("Der Verschlinger erwacht! Der Endkampf beginnt."))
	else:
		game.message.emit(tr("Endkampf gegen den Verschlinger (%d Challenges geschafft)") % (sys().done_count() if sys() else 0))
	game.changed.emit()


## Bossphase im Schlund: Gegner um den Boss statt über die Straßen.
func summon(e: HdEnemy, sm: Dictionary) -> void:
	for k in int(sm.count):
		var a := k * TAU / maxf(1.0, float(sm.count))
		var s: HdEnemy = game.spawn_home(str(sm.id), game.free_point(e.position + Vector3(cos(a), 0, sin(a)) * 7.0, 1.0), "final_run", arena_pos())
		s.gold_free = true


## Kills im Schlund geben kein Wellengold und keine Trophäen.
func on_kill(e: HdEnemy) -> bool:
	return active and (e.zone == "final" or e.zone == "final_run")


## Stand der laufenden Challenge für die Anzeige {text, frac} ({} = keine).
func run_state() -> Dictionary:
	if run.is_empty():
		return {}
	var d: Dictionary = run.def
	match str(run.kind):
		"echos":
			var total := (d.bosses as Array).size()
			var left := (run.left as Array).size() + (1 if run.get("cur") != null and is_instance_valid(run.cur) and not run.cur.dead else 0)
			return {"text": tr("Echo %d / %d") % [total - left + 1, total], "frac": float(total - left) / maxf(1.0, total)}
		"siegel":
			var cols: Array = []
			for k in run.order:
				cols.append(_seal_name(int(k)))
			return {"text": tr("Siegel %d / %d · Tafel: %s") % [int(run.step), run.stones.size(), " · ".join(cols)], "frac": float(run.step) / maxf(1.0, run.stones.size())}
		"glutpfad":
			var dist: float = run.from.distance_to(run.to)
			var h = game.hero
			var f := clampf(1.0 - Vector2(h.position.x - run.to.x, h.position.z - run.to.z).length() / maxf(1.0, dist), 0.0, 1.0)
			return {"text": tr("Treffer %d / %d") % [int(run.hits), int(d.max_hits)], "frac": f}
		"halten":
			return {"text": tr("Halten %d / %d s") % [floori(float(run.held)), int(d.time)], "frac": clampf(float(run.held) / float(d.time), 0.0, 1.0)}
	return {}


const SEAL_NAMES := ["Rot", "Blau", "Grün", "Gold", "Violett", "Orange"]


func _seal_name(k: int) -> String:
	return tr(SEAL_NAMES[k % SEAL_NAMES.size()])


## Zeilen für die Seitenleiste.
func lines() -> Array:
	var out: Array = []
	if not active or sys() == null:
		return out
	var s = sys()
	if s.boss_started:
		if boss and is_instance_valid(boss) and not boss.dead:
			out.append(tr("Endkampf: Verschlinger %d %%") % roundi(boss.hp / boss.max_hp * 100.0))
		return out
	out.append(tr("%s · Verschlinger erwacht in %d:%02d") % [tr(str(data.name)), int(s.awaken_left()) / 60, int(s.awaken_left()) % 60])
	for cd in data.list:
		var st: String = s.state_of(str(cd.id))
		var mark: String = {"done": "✓", "failed": "✗", "active": "▶"}.get(st, "○")
		out.append("%s %s" % [mark, tr(str(cd.name))])
	return out
