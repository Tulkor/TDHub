class_name HdZones
extends RefCounted
## Sonderzonen in den vier Ecken (Bollwerk Etappe 3, Design Abschnitt 7). Betreten über Teleport-Steine
## an der Feste (je Zone einer in ihrer Richtung) oder zu Fuß; wer drin ist, fehlt an den Straßen.
## - Arena: Kampf gegen den Arena-Wächter, jeder Sieg gibt dauerhaft Werte (game.perma), eine Arena-Marke
##   und Gold; der nächste Wächter ist stärker. Verlassen oder Tod = Kampf verloren (kein Verlust).
## - Holzhain: Hain-Geister (bis max) lassen Holz fallen; Holzfäller (Gold) bringen Holz, solange der Held
##   im Hain ist.
## - Schmiede: Items veredeln +1 bis +5 (Kosten = Anteil des Item-Werts, ab +3 Fehlschlag möglich, Item
##   bleibt), Edelsteine in Sockel (1 Sockel, ab Stufe Selten 2) – die Gem-Farben aus GemTD.
## - Prüfungen: Jagd (Prüflinge auf Zeit töten) und Funkentanz (Warnflächen ohne Treffer überstehen),
##   Belohnung ein seltenes Item ins Lager, danach cooldown Wellen Pause.
## Spieleraktionen über act(cmd) (von HdShop.act weitergereicht), Werte in data/heroes.json → zones.

var game  ## HdGame
var cfg: Dictionary
var list: Array = []                 ## Zonendaten
var arena_wins := 0
var arena_fight: HdEnemy = null
var arena_away := 0.0
var lumberjacks := 0
var _hain_t := 0.0
var _jack_t := 0.0
var trial: Dictionary = {}           ## laufende Prüfung {id, def, t, kills, failed}
var trial_done: Dictionary = {}      ## Prüfung → Welle des letzten Versuchs
var _jack_nodes: Array = []
var _root: Node3D


func _init(g) -> void:
	game = g
	cfg = game.cfg.zones
	list = cfg.list
	_root = Node3D.new()
	game.add_child(_root)
	for z in list:
		_build_zone(z)


func def(id: String) -> Dictionary:
	for z in list:
		if str(z.id) == id:
			return z
	return {}


func center(id: String) -> Vector3:
	var p: Array = def(id).pos
	return Vector3(float(p[0]), 0, float(p[1]))


func is_open(id: String) -> bool:
	return game.state == "play" and game.wave >= int(def(id).get("open", 1))


## Zone, in der der Punkt liegt ("" = keine).
func zone_at(pos: Vector3) -> String:
	for z in list:
		var c := center(str(z.id))
		if Vector2(pos.x - c.x, pos.z - c.z).length() <= float(cfg.radius):
			return str(z.id)
	return ""


func hero_zone() -> String:
	return zone_at(game.hero.position) if game.hero and game.hero.alive() else ""


func gem(id: String) -> Dictionary:
	for g in cfg.schmiede.gems:
		if str(g.id) == id:
			return g
	return {}


# ---------------------------------------------------------------- Welt

func _build_zone(z: Dictionary) -> void:
	var c := center(str(z.id))
	var r := float(cfg.radius)
	var col := Color(str(z.color))
	_root.add_child(HdDev.cyl(r, r, 0.02, HdDev.mat(col.darkened(0.72), 0.5), c + Vector3(0, 0.004, 0), 40))
	_root.add_child(HdDev.cyl(r, r, 0.03, HdDev.flat(col, 0.18), c + Vector3(0, 0.012, 0), 40))
	# Zaunpfähle, zur Feste hin offen
	var to_fort: Vector3 = (game.fortress_pos - c).normalized()
	for k in 28:
		var a := k * TAU / 28.0
		var d := Vector3(cos(a), 0, sin(a))
		if d.dot(to_fort) > 0.9:
			continue
		_root.add_child(HdDev.box(Vector3(0.35, 1.4, 0.35), HdDev.mat(col.darkened(0.4), 0.5), c + d * r + Vector3(0, 0.7, 0)))
	match str(z.id):
		"arena":
			for k in 8:
				var a := k * TAU / 8.0
				_root.add_child(HdDev.cyl(0.5, 0.6, 3.0, HdDev.mat(Color("8a7a8a"), 0.5), c + Vector3(cos(a), 0, sin(a)) * (r - 2.0) + Vector3(0, 1.5, 0), 8))
		"hain":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for k in 16:
				var a := rng.randf() * TAU
				var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(r * 0.45, r - 1.5)
				_root.add_child(HdDev.cyl(0.3, 0.4, 1.6, HdDev.mat(Color("6a4a2a"), 0.5), p + Vector3(0, 0.8, 0), 6))
				_root.add_child(HdDev.cyl(0.0, 1.4, 3.0, HdDev.mat(Color("2f7a3a"), 0.5), p + Vector3(0, 3.0, 0), 7))
		"schmiede":
			_root.add_child(HdDev.box(Vector3(4.0, 2.0, 3.0), HdDev.mat(Color("5a5a62"), 0.5), c + Vector3(0, 1.0, -2.0)))
			_root.add_child(HdDev.box(Vector3(1.6, 0.9, 0.8), HdDev.mat(Color("2a2a30"), 0.5), c + Vector3(2.5, 0.45, 1.5)))
			_root.add_child(HdDev.cyl(0.9, 0.9, 0.3, HdDev.mat(Color("ff7a2a"), 0.5, 2.0), c + Vector3(0, 2.1, -2.0), 12))
			var gems: Array = cfg.schmiede.gems
			for k in gems.size():
				var a := PI * 0.15 + k * PI * 0.14
				_root.add_child(HdDev.sphere(0.35, HdDev.mat(Color(str(gems[k].color)), 0.5, 1.4), c + Vector3(cos(a) * 5.0, 0.9, sin(a) * 5.0)))
		"pruefung":
			for k in 4:
				var a := k * TAU / 4.0 + PI * 0.25
				_root.add_child(HdDev.box(Vector3(0.8, 4.0, 0.8), HdDev.mat(Color("3a5a8a"), 0.5, 0.4), c + Vector3(cos(a), 0, sin(a)) * 6.0 + Vector3(0, 2.0, 0)))


## Teleport-Steine: an der Feste je Zone einer in ihrer Richtung, in der Zone einer zurück.
func add_stones() -> void:
	var root: Node3D = game._road_root
	for z in list:
		var id := str(z.id)
		var c := center(id)
		var dir: Vector3 = (c - game.fortress_pos).normalized()
		var home: Vector3 = game.fortress_pos + dir * float(cfg.stone_ring)
		var inside := c - dir * (float(cfg.radius) - 3.0)
		var back := inside + Vector3(-dir.z, 0, dir.x) * 3.0
		game.stones.append({"pos": home, "to": inside + dir * 2.0, "zone": id, "out": true})
		game.stones.append({"pos": back, "to": game.hero_spawn(), "zone": id, "out": false})
		for st in [home, back]:
			root.add_child(HdDev.cyl(1.0, 1.2, 0.3, HdDev.mat(Color("3a3f55"), 0.5), st + Vector3(0, 0.15, 0), 12))
			root.add_child(HdDev.cyl(0.7, 0.7, 0.06, HdDev.mat(Color(str(z.color)), 0.5, 1.6), st + Vector3(0, 0.34, 0), 12))


# ---------------------------------------------------------------- Takt

func step(dt: float) -> void:
	var hz := hero_zone()
	_step_arena(dt, hz)
	_step_hain(dt, hz)
	_step_trial(dt, hz)


func _step_arena(dt: float, hz: String) -> void:
	if arena_fight == null:
		return
	if arena_fight.dead:
		arena_fight = null
		return
	arena_away = arena_away + dt if hz != "arena" else 0.0
	if arena_away > 3.0 or not game.hero.alive():
		game._remove(arena_fight)
		arena_fight = null
		game.message.emit(tr("Arena-Kampf verloren"))


func _step_hain(dt: float, hz: String) -> void:
	if hz != "hain" or not is_open("hain"):
		return
	var h: Dictionary = cfg.hain
	_hain_t += dt
	var alive := 0
	for e in game.enemies:
		if not e.dead and e.zone == "hain":
			alive += 1
	if _hain_t >= float(h.respawn) and alive < int(h.max):
		_hain_t = 0.0
		var c := center("hain")
		var a: float = game.rng.randf() * TAU
		var p: Vector3 = c + Vector3(cos(a), 0, sin(a)) * game.rng.randf_range(2.0, float(cfg.radius) - 3.0)
		game.spawn_home(str(h.spirit), p, "hain")
	if lumberjacks > 0:
		_jack_t += dt
		var lj: Dictionary = h.lumberjack
		if _jack_t >= float(lj.interval):
			_jack_t = 0.0
			var n := lumberjacks * int(lj.wood)
			game.shop.add_wood(n)
			game.floater(center("hain") + Vector3(0, 3.0, 0), tr("+%d Holz") % n, UiTheme.HAVE)
			game.changed.emit()


func _step_trial(dt: float, hz: String) -> void:
	if trial.is_empty():
		return
	trial.t += dt
	var td: Dictionary = trial.def
	if hz != "pruefung" or not game.hero.alive():
		_end_trial(false, tr("Prüfung abgebrochen"))
		return
	match str(td.kind):
		"kills":
			var alive := 0
			for e in game.enemies:
				if not e.dead and e.zone == "pruefung":
					alive += 1
			if alive < int(td.batch):
				var c := center("pruefung")
				for k in int(td.batch) - alive:
					var a: float = game.rng.randf() * TAU
					game.spawn_home(str(td.enemy), c + Vector3(cos(a), 0, sin(a)) * game.rng.randf_range(4.0, float(cfg.radius) - 2.0), "pruefung")
			if int(trial.kills) >= int(td.count):
				_end_trial(true, "")
			elif trial.t >= float(td.time):
				_end_trial(false, tr("Zeit abgelaufen: %d / %d") % [int(trial.kills), int(td.count)])
		"dodge":
			trial.next = float(trial.get("next", 0.0)) - dt
			if trial.next <= 0.0 and trial.t < float(td.time) - float(td.windup):
				trial.next = float(td.every)
				var off := Vector3(game.rng.randf_range(-1, 1), 0, game.rng.randf_range(-1, 1)) * 1.5
				game.ground_blast(game.hero.position + off, float(td.radius), float(td.windup), 0.0, _trial_hit)
			if bool(trial.get("failed", false)):
				_end_trial(false, tr("Getroffen!"))
			elif trial.t >= float(td.time):
				_end_trial(true, "")


func _trial_hit() -> void:
	if not trial.is_empty():
		trial.failed = true


func _end_trial(won: bool, why: String) -> void:
	for e in game.enemies:
		if not e.dead and e.zone == "pruefung":
			game._remove(e)
	var name := tr(str(trial.def.name))
	trial = {}
	if not won:
		game.message.emit(tr("%s nicht bestanden. %s") % [name, why])
		return
	var pool: Array = []
	for it in game.shop.cfg.items:
		if int(it.get("tier", 1)) == int(cfg.pruefungen.reward_tier) and not it.has("trophy") and not it.has("marks") and not it.has("use"):
			pool.append(str(it.id))
	var id: String = pool[game.rng.randi() % pool.size()] if not pool.is_empty() else ""
	if id != "" and game.shop.count_free("stash") > 0:
		var i: int = game.shop._free("stash")
		game.shop.stash[i] = {"id": id, "n": 1}
		game.message.emit(tr("%s bestanden! %s liegt im Lager.") % [name, tr(str(game.shop.item(id).name))])
	else:
		game.shop.add_wood(4)
		game.message.emit(tr("%s bestanden! Lager voll: +4 Holz") % name)
	game.shop._changed()


## Getötete Gegner der Zonen: kein Gold, eigene Belohnung. true = behandelt.
func on_kill(e: HdEnemy) -> bool:
	match e.zone:
		"arena":
			if e == arena_fight:
				arena_fight = null
				arena_wins += 1
				game.shop.marks += 1
				var a: Dictionary = cfg.arena
				for k in a.bonus:
					game.perma[k] = float(game.perma.get(k, 0.0)) + float(a.bonus[k])
				var g := int(a.gold) * arena_wins
				game.shop.add_gold(g)
				game.message.emit(tr("Arena-Sieg %d! +1 Marke, +%d Gold, dauerhaft %s") % [arena_wins, g, HdShop.stat_text(a.bonus)])
				game.shop._changed()
			return true
		"hain":
			var w := int(cfg.hain.wood)
			game.shop.add_wood(w)
			game.floater(e.position + Vector3(0, e.height() + 1.0, 0), tr("+%d Holz") % w, UiTheme.HAVE)
			return true
		"pruefung":
			if not trial.is_empty():
				trial.kills = int(trial.kills) + 1
			return true
	return false


# ---------------------------------------------------------------- Befehle

func act(cmd: Dictionary) -> String:
	match str(cmd.kind):
		"upgrade":
			return upgrade(str(cmd.where), int(cmd.i))
		"socket":
			return socket(str(cmd.where), int(cmd.i), str(cmd.gem))
		"lumberjack":
			return buy_lumberjack()
		"arena":
			return start_arena()
		"trial":
			return start_trial(str(cmd.id))
	return "?"


func _need(id: String) -> String:
	if not is_open(id):
		return tr("Öffnet ab Welle %d") % int(def(id).open)
	if hero_zone() != id:
		return tr("Nur in der Zone %s") % tr(str(def(id).name))
	return ""


func upgrade_cost(x) -> int:
	var up := int(x.get("up", 0))
	var costs: Array = cfg.schmiede.cost
	return roundi(game.shop.total_cost(str(x.id)) * float(costs[clampi(up, 0, costs.size() - 1)]))


func fail_chance(x) -> float:
	var fails: Array = cfg.schmiede.fail
	return float(fails[clampi(int(x.get("up", 0)), 0, fails.size() - 1)])


func can_upgrade(where: String, i: int) -> String:
	var why := _need("schmiede")
	if why != "":
		return why
	var x = game.shop.at(where, i)
	if x == null or game.shop.consumable(str(x.id)):
		return "?"
	if int(x.get("up", 0)) >= int(cfg.schmiede.max):
		return tr("Höchste Stufe")
	if game.shop.gold < upgrade_cost(x):
		return tr("Zu wenig Gold")
	return ""


## Veredeln: Gold weg, mit Fehlschlag-Chance (ab +3) bleibt die Stufe, das Item geht nie verloren.
func upgrade(where: String, i: int) -> String:
	var why := can_upgrade(where, i)
	if why != "":
		return why
	var x = game.shop.at(where, i)
	game.shop.gold -= upgrade_cost(x)
	if game.rng.randf() < fail_chance(x):
		game.message.emit(tr("Fehlschlag! %s bleibt +%d") % [tr(str(game.shop.item(str(x.id)).name)), int(x.get("up", 0))])
	else:
		x.up = int(x.get("up", 0)) + 1
		game.message.emit(tr("%s ist jetzt +%d") % [tr(str(game.shop.item(str(x.id)).name)), int(x.up)])
	game.shop._changed()
	return ""


func sockets(x) -> int:
	return 2 if int(game.shop.item(str(x.id)).get("tier", 1)) >= 3 else 1


func can_socket(where: String, i: int, gid: String) -> String:
	var why := _need("schmiede")
	if why != "":
		return why
	var x = game.shop.at(where, i)
	if x == null or game.shop.consumable(str(x.id)) or gem(gid).is_empty():
		return "?"
	if game.shop.gold < int(cfg.schmiede.gem_price):
		return tr("Zu wenig Gold")
	return ""


## Edelstein einsetzen; sind alle Sockel voll, ersetzt er den ältesten.
func socket(where: String, i: int, gid: String) -> String:
	var why := can_socket(where, i, gid)
	if why != "":
		return why
	var x = game.shop.at(where, i)
	game.shop.gold -= int(cfg.schmiede.gem_price)
	var gl: Array = x.get("gems", []).duplicate()
	if gl.size() >= sockets(x):
		gl.pop_front()
	gl.append(gid)
	x.gems = gl
	game.shop._changed()
	return ""


func can_lumberjack() -> String:
	var why := _need("hain")
	if why != "":
		return why
	var lj: Dictionary = cfg.hain.lumberjack
	if lumberjacks >= int(lj.max):
		return tr("Höchstzahl erreicht")
	if game.shop.gold < int(lj.price):
		return tr("Zu wenig Gold")
	return ""


func buy_lumberjack() -> String:
	var why := can_lumberjack()
	if why != "":
		return why
	game.shop.gold -= int(cfg.hain.lumberjack.price)
	lumberjacks += 1
	var c := center("hain")
	var a := lumberjacks * 2.1
	var n := HdDev.box(Vector3(0.6, 1.1, 0.6), HdDev.mat(Color("c98a3a"), 0.5), c + Vector3(cos(a), 0, sin(a)) * 6.0 + Vector3(0, 0.55, 0))
	_root.add_child(n)
	_jack_nodes.append(n)
	game.shop._changed()
	return ""


func can_arena() -> String:
	var why := _need("arena")
	if why != "":
		return why
	if arena_fight != null:
		return tr("Der Kampf läuft")
	return ""


## Arena-Wächter rufen: jede Runde (Siege) mehr Leben und Schaden.
func start_arena() -> String:
	var why := can_arena()
	if why != "":
		return why
	var a: Dictionary = cfg.arena
	var c := center("arena")
	var e: HdEnemy = game.spawn_home(str(a.guardian), c, "arena")
	e.max_hp *= 1.0 + float(a.hp_step) * arena_wins
	e.hp = e.max_hp
	e.dmg_mult *= 1.0 + float(a.damage_step) * arena_wins
	e.provoke(game.hero)
	arena_fight = e
	arena_away = 0.0
	game.message.emit(tr("Arena: Wächter Runde %d") % (arena_wins + 1))
	return ""


func trial_def(id: String) -> Dictionary:
	for t in cfg.pruefungen.list:
		if str(t.id) == id:
			return t
	return {}


## Wellen, bis die Prüfung wieder geht (0 = jetzt).
func trial_wait(id: String) -> int:
	if not trial_done.has(id):
		return 0
	return maxi(0, int(trial_done[id]) + int(cfg.pruefungen.cooldown) - game.wave)


func can_trial(id: String) -> String:
	var why := _need("pruefung")
	if why != "":
		return why
	if not trial.is_empty():
		return tr("Eine Prüfung läuft")
	if trial_def(id).is_empty():
		return "?"
	var w := trial_wait(id)
	if w > 0:
		return tr("Wieder in %d Wellen") % w
	return ""


func start_trial(id: String) -> String:
	var why := can_trial(id)
	if why != "":
		return why
	trial = {"id": id, "def": trial_def(id), "t": 0.0, "kills": 0, "next": 1.0}
	trial_done[id] = game.wave
	game.message.emit(tr("Prüfung: %s") % tr(str(trial.def.name)))
	return ""
