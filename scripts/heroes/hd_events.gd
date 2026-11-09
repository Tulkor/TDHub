class_name HdEvents
extends RefCounted
## Ereignisse während der Wellen (Bollwerk, Lukas 2026-11-09): alle 5 Minuten eins aus einem Pool von über
## 40 (data/heroes_ereignisse.json). Die Uhr und die Auswahl macht das gemeinsame System timed_events
## (scripts/systems/timed_events/, Haken event_* in HdGame), die Abläufe stehen hier:
## - die fünf aus Etappe 3 (Wanderhändler, Karawane, Blutmond, Gefangener, Schrein) direkt hier,
## - alle übrigen Arten (jagd, ueberleben, regen, sammeln, halten, segen, wahl) in HdEventKinds.
## Entscheidungen über act({"kind": "event", "pick": i}); ohne Antwort gilt nach choose_time die letzte Option.

var game  ## HdGame
var cfg: Dictionary            ## heroes.json → events (choose_time)
var kinds: HdEventKinds
var last_id := ""
var active: Dictionary = {}          ## laufendes Ereignis aus Etappe 3 {id, def, ...}
var choice: Dictionary = {}          ## offene Entscheidung {id, options: [text], until}
var history: Array = []                  ## [Welle, id] (Tests, Auswertung)
var _nodes: Array = []


func _init(g) -> void:
	game = g
	cfg = game.cfg.events
	kinds = HdEventKinds.new(g)


## Die Ereignis-Uhr (System timed_events), null in Tests ohne System.
func clock():
	return game.systems.get("timed_events")


## Tests/Bilder: dieses Ereignis als nächstes.
var force: String:
	get:
		return clock().force if clock() else ""
	set(v):
		if clock():
			clock().force = v


func def(id: String) -> Dictionary:
	return clock().def(id) if clock() else {}


func blood() -> Dictionary:
	return def("blutmond")


## Läuft gerade etwas, das kein neues Ereignis zulässt?
func busy() -> bool:
	return not active.is_empty() or not choice.is_empty() or kinds.busy()


## Neue Welle n: laufende Etappe-3-Ereignisse und Segen prüfen (neue Ereignisse kommen über die Uhr).
func on_wave(n: int) -> void:
	if str(active.get("id", "")) == "gefangener":
		if active.has("ally") and n > int(active.until):
			_end_prisoner(tr("Der Befreite zieht weiter."))
		elif not active.has("ally") and n > int(active.until):
			_end_prisoner(tr("Der Gefangene wurde verschleppt."))
	if not game.blessing.is_empty() and n > int(game.blessing.until):
		game.blessing = {}
		game.shop._changed()


## Darf das Ereignis jetzt kommen? (Blutmond nicht vor einer Kriegsherrn-Welle oder nach der letzten)
func allowed(d: Dictionary) -> bool:
	if str(d.id) == "blutmond":
		return not game.is_boss_wave(game.wave + 1) and game.wave + 1 <= game.wave_count()
	if str(d.get("kind", "")) == "jagd" and str(d.get("where", "")) == "strasse" and game.roads.is_empty():
		return false
	return true


func start(id: String) -> void:
	last_id = id
	history.append([game.wave, id])
	var d := def(id)
	game.message.emit(tr("Ereignis: %s") % tr(str(d.name)))
	var kind := str(d.get("kind", id))
	if kind in HdEventKinds.KINDS:
		if kind == "wahl":
			_ask(id, kinds.options(d))
		else:
			kinds.start(d)
		game.changed.emit()
		return
	match id:
		"haendler":
			_start_merchant(d)
		"karawane":
			_start_caravan(d)
		"blutmond":
			_ask(id, [tr("Ja, Blutmond"), tr("Nein")])
		"gefangener":
			_start_prisoner(d)
		"schrein":
			var g := _shrine_gold()
			_ask(id, [tr("%d Feste-Leben opfern") % int(d.lives), tr("%d Gold opfern") % g, tr("Ablehnen")])


func _ask(id: String, options: Array) -> void:
	choice = {"id": id, "options": options, "until": game.play_time + float(cfg.choose_time)}


func step(dt: float) -> void:
	if not choice.is_empty() and game.play_time >= float(choice.until):
		_decide(choice.options.size() - 1)
	kinds.step(dt)
	match str(active.get("id", "")):
		"haendler":
			if game.play_time >= float(active.until):
				game.shop.merchant = []
				active = {}
				game.message.emit(tr("Der Wanderhändler zieht weiter"))
				game.changed.emit()
		"karawane":
			_step_caravan(dt)
		"gefangener":
			_step_prisoner(dt)


func act(cmd: Dictionary) -> String:
	if choice.is_empty():
		return tr("Keine Entscheidung offen")
	var i := int(cmd.get("pick", -1))
	if i < 0 or i >= choice.options.size():
		return "?"
	if str(choice.id) == "schrein":
		var d := def("schrein")
		if i == 0 and game.lives <= int(d.lives):
			return tr("Die Feste hat zu wenig Leben")
		if i == 1 and game.shop.gold < _shrine_gold():
			return tr("Zu wenig Gold")
	elif str(def(str(choice.id)).get("kind", "")) == "wahl":
		var why := kinds.can_pick(def(str(choice.id)), i)
		if why != "":
			return why
	_decide(i)
	return ""


func _decide(i: int) -> void:
	var id := str(choice.id)
	choice = {}
	if str(def(id).get("kind", "")) == "wahl":
		kinds.pick(def(id), i)
		game.changed.emit()
		return
	match id:
		"blutmond":
			if i == 0:
				game.blood_wave = game.wave + 1
				game.message.emit(tr("Blutmond über Welle %d!") % (game.wave + 1))
			else:
				game.message.emit(tr("Kein Blutmond"))
		"schrein":
			var d := def("schrein")
			if i == 2:
				game.message.emit(tr("Der Schrein verblasst"))
				return
			if i == 0:
				game.lives -= int(d.lives)
			else:
				game.shop.gold -= _shrine_gold()
			game.blessing = {"stats": d.bonus, "until": game.wave + int(d.waves) - 1}
			game.message.emit(tr("Segen des Schreins: %s bis Welle %d") % [HdShop.stat_text(d.bonus), int(game.blessing.until)])
			game.shop._changed()
	game.changed.emit()


func _shrine_gold() -> int:
	var g: Array = def("schrein").gold
	return int(g[0]) + int(g[1]) * game.wave


# ---------------------------------------------------------------- Wanderhändler

func _start_merchant(d: Dictionary) -> void:
	var pool: Array = []
	var tiers: Array = d.tiers
	for it in game.shop.cfg.items:
		var t := int(it.get("tier", 1))
		if t >= int(tiers[0]) and t <= int(tiers[1]) and not it.has("trophy") and not it.has("marks") and not it.has("use"):
			pool.append(str(it.id))
	pool.shuffle()
	var offer: Array = []
	for k in mini(int(d.count), pool.size()):
		var id: String = pool[k]
		offer.append({"id": id, "price": roundi(game.shop.total_cost(id) * float(d.markup) / 10.0) * 10})
	game.shop.merchant = offer
	active = {"id": "haendler", "until": game.play_time + float(d.time)}
	game.changed.emit()


# ---------------------------------------------------------------- Karawane

func _start_caravan(d: Dictionary) -> void:
	var b: Array = game.bounds()
	var z := 36.0 if game.rng.randf() < 0.5 else -36.0
	var x0 := float(b[0]) + 4.0
	var x1 := float(b[2]) - 4.0
	if game.rng.randf() < 0.5:
		var t := x0
		x0 = x1
		x1 = t
	var c := HdAlly.new()
	var hp: float = float(d.hp) * (1.0 + 0.06 * game.wave)
	c.setup_ally(game, {"name": d.name, "hp": hp, "armor": 3, "radius": 1.3, "speed": float(d.speed), "range": 0, "damage": 0, "interval": 99}, "caravan", Vector3(x0, 0, z))
	c.route = [Vector3(x0 * 0.5, 0, z), Vector3(0, 0, z), Vector3(x1 * 0.5, 0, z), Vector3(x1, 0, z)]
	game.add_child(c)
	game.buildings.append(c)
	active = {"id": "karawane", "ally": c, "raid_t": 4.0, "def": d}


func _step_caravan(dt: float) -> void:
	var c: HdAlly = active.get("ally")
	if c == null or not is_instance_valid(c) or c.destroyed:
		return
	if c.arrived:
		var gd: Array = active.def.gold
		var g := roundi((int(gd[0]) + int(gd[1]) * game.wave) * c.hp / c.max_hp)
		game.shop.add_gold(g)
		game.message.emit(tr("Die Karawane ist angekommen: +%d Gold") % g)
		game.buildings.erase(c)
		c.queue_free()
		_clear_raiders()
		active = {}
		game.changed.emit()
		return
	active.raid_t = float(active.raid_t) - dt
	if active.raid_t <= 0.0:
		active.raid_t = float(active.def.raid_every)
		var rd: Array = active.def.raid
		var n := int(float(rd[0]) + float(rd[1]) * game.wave)
		var fwd: Vector3 = (c.route[mini(c.leg, c.route.size() - 1)] - c.position)
		fwd.y = 0.0
		var side := Vector3(-fwd.z, 0, fwd.x).normalized() * (1.0 if game.rng.randf() < 0.5 else -1.0)
		for k in n:
			var p := c.position + fwd.normalized() * 6.0 + side * (12.0 + k * 1.2)
			var e: HdEnemy = game.spawn_home(str(active.def.raiders), p, "raid")
			e.taunt(c, 999.0)


func _clear_raiders() -> void:
	for e in game.enemies:
		if not e.dead and e.zone == "raid":
			game._remove(e)


func on_ally_down(a: HdAlly) -> void:
	match str(active.get("id", "")):
		"karawane":
			if active.get("ally") == a:
				game.message.emit(tr("Die Karawane wurde geplündert!"))
				_clear_raiders()
				active = {}
		"gefangener":
			if active.get("ally") == a:
				_end_prisoner(tr("Der Befreite ist gefallen."))


func on_kill(e: HdEnemy) -> bool:
	if kinds.on_kill(e):
		return true
	return e.zone == "raid" or e.zone == "kerker"


# ---------------------------------------------------------------- Gefangener

func _start_prisoner(d: Dictionary) -> void:
	var r: HdRoad = game.roads[game.rng.randi() % game.roads.size()]
	var s: float = r.length * 0.3
	var p: Vector3 = r.point(s) + r.side(s) * 9.0
	p = game.free_point(p, 1.5)
	var cage := Node3D.new()
	cage.position = p
	for k in 8:
		var a := k * TAU / 8.0
		cage.add_child(HdDev.box(Vector3(0.15, 2.4, 0.15), HdDev.mat(Color("6a6a72"), 0.5), Vector3(cos(a), 1.2, sin(a)) * 1.0))
	cage.add_child(HdDev.cyl(1.1, 1.1, 0.15, HdDev.mat(Color("4a4a52"), 0.5), Vector3(0, 2.45, 0), 10))
	cage.add_child(HdDev.cyl(0.4, 0.5, 1.4, HdDev.mat(Color("5aa0e0"), 0.5), Vector3(0, 0.7, 0)))
	game.add_child(cage)
	_nodes.append(cage)
	for k in int(d.guard_count):
		var a := k * TAU / int(d.guard_count)
		game.spawn_home(str(d.guards), p + Vector3(cos(a), 0, sin(a)) * 3.0, "kerker")
	active = {"id": "gefangener", "def": d, "pos": p, "cage": cage, "hold": 0.0, "until": game.wave + 1}


func guards_left() -> int:
	var n := 0
	for e in game.enemies:
		if not e.dead and e.zone == "kerker":
			n += 1
	return n


func _step_prisoner(dt: float) -> void:
	if active.has("ally"):
		return
	var h = game.hero
	var near: bool = h.alive() and h.position.distance_to(active.pos) < 3.5
	if near and guards_left() == 0:
		active.hold = float(active.hold) + dt
		if active.hold >= float(active.def.free_time):
			_free_prisoner()
	else:
		active.hold = 0.0


func _free_prisoner() -> void:
	var d: Dictionary = active.def
	if is_instance_valid(active.cage):
		active.cage.queue_free()
	var a := HdAlly.new()
	var hp: float = float(d.hp) * (1.0 + 0.06 * game.wave)
	var dmg: float = float(d.damage) * (1.0 + 0.06 * game.wave)
	a.setup_ally(game, {"name": "Befreite Klingenmeisterin", "hp": hp, "armor": 4, "radius": 0.6, "speed": 6.5,
		"range": float(d.range), "damage": dmg, "interval": float(d.interval)}, "fighter", active.pos)
	game.add_child(a)
	game.buildings.append(a)
	active.ally = a
	active.until = game.wave + int(d.waves)
	game.message.emit(tr("Befreit! Sie kämpft bis Welle %d mit.") % int(active.until))
	game.changed.emit()


func _end_prisoner(text: String) -> void:
	var a = active.get("ally")
	if a != null and is_instance_valid(a):
		game.buildings.erase(a)
		a.queue_free()
	var cage = active.get("cage")
	if cage != null and is_instance_valid(cage):
		cage.queue_free()
	for e in game.enemies:
		if not e.dead and e.zone == "kerker":
			game._remove(e)
	active = {}
	game.message.emit(text)
	game.changed.emit()


## Zeile für die Seitenleiste ("" = nichts).
func status() -> String:
	var card := kinds.card()
	if not card.is_empty():
		return "%s: %s" % [card.title, card.line]
	match str(active.get("id", "")):
		"haendler":
			return tr("Wanderhändler: noch %d s") % ceili(float(active.until) - game.play_time)
		"karawane":
			var c = active.get("ally")
			if c != null and is_instance_valid(c):
				return tr("Karawane: %d %% Leben, %d %% des Wegs") % [roundi(c.hp / c.max_hp * 100.0), roundi(float(c.leg) / c.route.size() * 100.0)]
		"gefangener":
			if active.has("ally"):
				return tr("Befreite kämpft bis Welle %d") % int(active.until)
			if guards_left() > 0:
				return tr("Gefangener an der %s: %d Wachen") % [tr(game.nearest_road(active.pos).name), guards_left()]
			return tr("Gefangener: am Käfig stehen, um ihn zu befreien")
	if not game.blessing.is_empty():
		return tr("Segen des Schreins bis Welle %d") % int(game.blessing.until)
	return ""
