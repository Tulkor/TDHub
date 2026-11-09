class_name HdGadget
extends HdBuilding
## Gebäude aus Zix' Baukasten (data/heroes_helden.json → gadgets, hero-defense-helden.md Nr. 16).
## Steht in HdGame.buildings: Gegner greifen es an (Helden vor Gebäuden), es blockiert den Weg,
## Vesnas Schüsse und Zix' Funkenpistole heilen es. Stärke wächst mit Zix' Stufe, Überspannung
## (zix.over_t > 0) verdoppelt Tempo und Wirkung und schaltet die Sonderwirkung je Art frei.

var kind := ""
var zix  ## HdHeroZix
var placed := 0.0
var hits := 0                 ## Tesla: Treffer für jede 4. Betäubung
var contact: Dictionary = {}  ## Elektrozaun: Gegner → Sekunden auf der Linie
var mast_b := Vector3.ZERO    ## Elektrozaun: zweiter Mast
var rockets: Array = []       ## Raketenwerfer: {pos, t, tele}
var _tick := 0.0
var _top: Node3D
var _dome: MeshInstance3D


func setup_gadget(g, id: String, d: Dictionary, at: Vector3, owner_hero, dir: Vector3) -> void:
	game = g
	def = d
	kind = id
	zix = owner_hero
	var lvl_mult: float = 1.0 + 0.1 * (owner_hero.level - 1)
	max_hp = float(d.hp) * lvl_mult
	hp = max_hp
	armor = float(d.get("armor", 0))
	radius = float(d.radius)
	position = Vector3(at.x, 0, at.z)
	placed = g.play_time
	if kind == "elektrozaun":
		var lat := Vector3(-dir.z, 0, dir.x).normalized()
		position = at - lat * float(d.length) * 0.5
		mast_b = at + lat * float(d.length) * 0.5
	_build()


func _build() -> void:
	var metal := HdDev.metall(Color("8a7a5a"), 0.5)
	var accent := HdDev.mat(Color("ffb040"), 0.5, 0.8)
	add_child(HdDev.cyl(radius, radius * 1.1, 0.3, HdDev.mat(Color("5a5048"), 0.5), Vector3(0, 0.15, 0), 8))
	_top = Node3D.new()
	_top.position = Vector3(0, 0.3, 0)
	add_child(_top)
	match kind:
		"bolzenturm":
			_top.add_child(HdDev.cyl(0.3, 0.4, 1.2, metal, Vector3(0, 0.6, 0), 6))
			_top.add_child(HdDev.box(Vector3(0.18, 0.18, 1.0), accent, Vector3(0, 1.2, -0.4)))
		"flammenspeier":
			_top.add_child(HdDev.box(Vector3(0.8, 0.7, 0.8), metal, Vector3(0, 0.35, 0)))
			_top.add_child(HdDev.cyl(0.12, 0.25, 0.7, HdDev.mat(Color("ff6a2a"), 0.5, 1.0), Vector3(0, 0.6, -0.6)))
		"raketenwerfer":
			_top.add_child(HdDev.box(Vector3(1.1, 0.5, 1.1), metal, Vector3(0, 0.25, 0)))
			for k in [-0.3, 0.3]:
				_top.add_child(HdDev.cyl(0.15, 0.15, 0.9, accent, Vector3(k, 0.9, 0), 6))
		"teslaspule":
			_top.add_child(HdDev.cyl(0.2, 0.35, 1.6, metal, Vector3(0, 0.8, 0), 6))
			_top.add_child(HdDev.sphere(0.35, HdDev.mat(UiTheme.CYAN, 0.5, 1.4), Vector3(0, 1.8, 0)))
		"sanitaetsmast":
			_top.add_child(HdDev.box(Vector3(0.2, 2.2, 0.2), metal, Vector3(0, 1.1, 0)))
			_top.add_child(HdDev.box(Vector3(0.7, 0.2, 0.08), HdDev.mat(UiTheme.HAVE, 0.5, 1.0), Vector3(0, 2.1, 0)))
			_top.add_child(HdDev.box(Vector3(0.2, 0.7, 0.08), HdDev.mat(UiTheme.HAVE, 0.5, 1.0), Vector3(0, 2.1, 0)))
		"heilsprinkler":
			_top.add_child(HdDev.cyl(0.15, 0.3, 0.6, metal, Vector3(0, 0.3, 0), 6))
			_top.add_child(HdDev.cyl(0.4, 0.4, 0.08, HdDev.mat(UiTheme.HAVE, 0.5, 0.8), Vector3(0, 0.65, 0), 8))
		"schrottbot":
			_top.add_child(HdDev.box(Vector3(1.0, 0.9, 0.8), metal, Vector3(0, 0.6, 0)))
			_top.add_child(HdDev.box(Vector3(0.6, 0.12, 0.05), accent, Vector3(0, 0.8, -0.42)))
		"elektrozaun":
			_top.add_child(HdDev.box(Vector3(0.2, 1.8, 0.2), metal, Vector3(0, 0.9, 0)))
			var other := Node3D.new()
			other.position = mast_b - position
			other.add_child(HdDev.box(Vector3(0.2, 1.8, 0.2), metal, Vector3(0, 1.2, 0)))
			add_child(other)
		"schildkuppel":
			_top.add_child(HdDev.cyl(0.25, 0.35, 0.8, metal, Vector3(0, 0.4, 0), 6))
			_dome = HdDev.sphere(float(def.area), HdDev.flat(Color(0.4, 0.75, 1.0), 0.16))
			_dome.scale = Vector3(1, 0.6, 1)
			add_child(_dome)
		"magnetkoeder":
			_top.add_child(HdDev.box(Vector3(0.9, 0.3, 0.3), HdDev.mat(Color("d04040"), 0.5, 0.4), Vector3(0, 0.6, 0)))
			for k in [-0.35, 0.35]:
				_top.add_child(HdDev.box(Vector3(0.22, 0.6, 0.3), HdDev.mat(Color("c8c8d0"), 0.5), Vector3(k, 0.3, 0)))


func height() -> float:
	return 2.0


func over() -> bool:
	return zix != null and is_instance_valid(zix) and zix.over_t > 0.0


## Stärke: Zix' Stufe, Hochdosis, Überspannung.
func power() -> float:
	var p: float = zix.power() if zix and is_instance_valid(zix) else 1.0
	p *= out_mult()
	if over():
		p *= float(zix.ultimate().get("power", 2.0))
	return p


func _speed() -> float:
	return float(zix.ultimate().get("speed", 2.0)) if over() else 1.0


func blocks(p: Vector3) -> bool:
	return kind == "schildkuppel" and not destroyed and Vector2(p.x - position.x, p.z - position.z).length() <= float(def.area)


func _face_to(p: Vector3) -> void:
	var v := p - position
	v.y = 0.0
	if v.length_squared() > 0.0001:
		_top.rotation.y = atan2(v.x, v.z) + PI


func _hit(e, amount: float) -> void:
	game.building_hit(e, amount, self)


func step(dt: float) -> void:
	if destroyed:
		return
	var now: float = game.play_time
	cd -= dt * _speed()
	_tick -= dt
	_top.scale = Vector3.ONE * (1.12 if over() else 1.0)
	match kind:
		"bolzenturm":
			_step_bolt()
		"flammenspeier":
			_step_flame()
		"raketenwerfer":
			_step_rockets(now)
		"teslaspule":
			_step_tesla()
		"sanitaetsmast":
			_step_mast(dt)
		"heilsprinkler":
			_step_sprinkler(dt, now)
		"schrottbot":
			_step_bot(dt, now)
		"elektrozaun":
			_step_fence(dt, now)
		"schildkuppel":
			_step_dome(dt)
		"magnetkoeder":
			_step_magnet()


func _step_bolt() -> void:
	if cd > 0.0:
		return
	var e = game.nearest_enemy(position, float(def.reach))
	if e == null:
		return
	cd = float(def.interval)
	_face_to(e.position)
	var top := position + Vector3(0, 1.6, 0)
	if over():
		var dir: Vector3 = e.position - position
		dir.y = 0.0
		game.fx.tracer(top, top + dir.normalized() * float(def.reach), Color("ffd070"))
		for x in game.enemies_in(HdTelegraph.LINE, position, dir.normalized(), 0, 0, 0, float(def.reach), 0.8):
			_hit(x, float(def.damage) * power())
	else:
		game.fx.tracer(top, e.position + Vector3(0, e.height() * 0.6, 0), Color("ffd070"))
		_hit(e, float(def.damage) * power())


func _step_flame() -> void:
	var e = game.nearest_enemy(position, float(def.reach))
	if e == null or cd > 0.0:
		return
	cd = float(def.interval)
	_face_to(e.position)
	var dir: Vector3 = e.position - position
	dir.y = 0.0
	var ang := float(def.angle) * (2.0 if over() else 1.0)
	game.fx.flash_shape(HdTelegraph.cone(float(def.reach), ang, Color(1.0, 0.5, 0.15)), position, dir)
	for x in game.enemies_in(HdTelegraph.CONE, position, dir.normalized(), float(def.reach), 0, ang, 0, 0):
		_hit(x, float(def.damage) * power())
		if not x.dead:
			x.burn_dps = maxf(x.burn_dps if x.burn_until > game.play_time else 0.0, float(def.burn) * power())
			x.burn_until = game.play_time + float(def.burn_time)


## Mörser: Ziel mit den meisten Nachbarn, blauer Warnkreis, Einschlag nach windup.
func _step_rockets(now: float) -> void:
	for i in range(rockets.size() - 1, -1, -1):
		var r: Dictionary = rockets[i]
		var t: HdTelegraph = r.tele
		t.progress = clampf(1.0 - (float(r.t) - now) / float(def.windup), 0.0, 1.0)
		if now < float(r.t):
			continue
		game.fx.nova(r.pos, float(def.blast), Color("ff9a40"))
		for x in game.enemies_in(HdTelegraph.CIRCLE, r.pos, Vector3.FORWARD, float(def.blast), 0, 0, 0, 0):
			_hit(x, float(def.damage) * power())
		t.trigger(0.2)
		rockets.remove_at(i)
	if cd > 0.0:
		return
	var best = null
	var best_n := -1
	for e in game.enemies:
		if e.dead or Vector2(e.position.x - position.x, e.position.z - position.z).length() > float(def.reach):
			continue
		var n: int = game.enemies_in(HdTelegraph.CIRCLE, e.position, Vector3.FORWARD, float(def.blast), 0, 0, 0, 0).size()
		if n > best_n:
			best_n = n
			best = e
	if best == null:
		return
	cd = float(def.interval)
	_face_to(best.position)
	var count := 3 if over() else 1
	for k in count:
		var p: Vector3 = best.position
		if k > 0:
			var a: float = game.rng.randf() * TAU
			p += Vector3(cos(a), 0, sin(a)) * float(def.blast) * 1.2
		var t := HdTelegraph.circle(float(def.blast), HdTelegraph.BLUE)
		t.position = Vector3(p.x, 0.05, p.z)
		game.add_child(t)
		rockets.append({"pos": Vector3(p.x, 0, p.z), "t": now + float(def.windup), "tele": t})


func _step_tesla() -> void:
	if cd > 0.0:
		return
	var e = game.nearest_enemy(position, float(def.reach))
	if e == null:
		return
	cd = float(def.interval)
	var from: Vector3 = position + Vector3(0, 1.9, 0)
	var done: Array = []
	for k in int(def.hops):
		if e == null:
			break
		game.fx.bolt(from, e.position + Vector3(0, e.height() * 0.6, 0))
		_hit(e, float(def.damage) * power())
		hits += 1
		if not e.dead:
			if over():
				game.stun(e, float(def.over_stun))
			elif hits % int(def.stun_every) == 0:
				game.stun(e, float(def.stun))
		done.append(e)
		from = e.position + Vector3(0, 1.0, 0)
		e = game.nearest_enemy(e.position, float(def.hop_range), done)


## Heilstrahl auf die am stärksten verletzten Mitspieler in Reichweite.
func _step_mast(dt: float) -> void:
	var hurt: Array = []
	for a in game.allies():
		if a == self or a.hp >= a.max_hp:
			continue
		if Vector2(a.position.x - position.x, a.position.z - position.z).length() <= float(def.reach):
			hurt.append(a)
	if hurt.is_empty():
		return
	hurt.sort_custom(func(x, y): return x.hp / x.max_hp < y.hp / y.max_hp)
	for k in mini(3 if over() else 1, hurt.size()):
		var t = hurt[k]
		game.heal_target(t, float(def.heal) * power() * dt, true)
		game.fx.beam(position + Vector3(0, 2.3, 0), t.position + Vector3(0, 1.2, 0), UiTheme.HAVE, 0.09)


func _step_sprinkler(dt: float, now: float) -> void:
	if _tick <= 0.0:
		_tick = 1.0
		game.fx.disc(position, float(def.area), Color(0.3, 0.9, 0.5), 0.5)
	for a in game.allies():
		if a == self or Vector2(a.position.x - position.x, a.position.z - position.z).length() > float(def.area) + a.radius:
			continue
		game.heal_target(a, float(def.heal) * power() * dt, true)
		if over() and a.shield_left() < float(def.over_shield) * 0.5:
			a.add_shield(float(def.over_shield), 2.0)


## Schrottbot: folgt Zix, spottet Gegner in der Nähe, haut zu.
func _step_bot(dt: float, now: float) -> void:
	var sc := float(def.over_scale) if over() else 1.0
	scale = Vector3.ONE * sc
	if zix and is_instance_valid(zix) and zix.alive():
		var to: Vector3 = zix.position - position
		to.y = 0.0
		if to.length() > float(def.follow):
			game.move_unit(self, to.normalized(), float(def.speed), dt, true)
	if _tick <= 0.0:
		_tick = float(def.taunt_every)
		var r := float(def.over_taunt) if over() else float(def.taunt_radius)
		game.fx.nova(position, r, UiTheme.GOLD)
		for e in game.enemies_in(HdTelegraph.CIRCLE, position, Vector3.FORWARD, r, 0, 0, 0, 0):
			e.taunt(self, float(def.taunt))
	if cd <= 0.0:
		var e = game.nearest_enemy(position, 1.8 * sc)
		if e:
			cd = float(def.interval)
			_face_to(e.position)
			_hit(e, float(def.damage) * power())


## Stromlinie: verlangsamt, senkt Rüstung, nach stun_after s Kontakt (Überspannung: sofort) Betäubung.
func _step_fence(dt: float, now: float) -> void:
	var dir := mast_b - position
	dir.y = 0.0
	game.fx.beam(position + Vector3(0, 1.4, 0), mast_b + Vector3(0, 1.4, 0), UiTheme.CYAN, 0.06)
	var on: Array = game.enemies_in(HdTelegraph.LINE, position, dir.normalized(), 0, 0, 0, dir.length(), float(def.width))
	for e in contact.keys():
		if not is_instance_valid(e) or not on.has(e):
			contact.erase(e)
	for e in on:
		e.cc.slow("elektrozaun", float(def.slow), 0.4, now)
		e.cc.reduce_armor("elektrozaun", float(def.armor_cut), 0.4, now)
		var t: float = contact.get(e, -1.0)
		var first := t < 0.0
		t = maxf(t, 0.0) + dt
		if (over() and (first or t >= 2.0)) or (not over() and t >= float(def.stun_after)):
			game.stun(e, float(def.stun))
			t = 0.0
		contact[e] = t


func _step_dome(dt: float) -> void:
	if not over():
		return
	for a in game.allies():
		if a != self and Vector2(a.position.x - position.x, a.position.z - position.z).length() <= float(def.area):
			game.heal_target(a, float(def.over_heal) * dt * zix.power(), true)


func _step_magnet() -> void:
	if _tick > 0.0:
		return
	_tick = float(def.every)
	var pull := float(def.over_pull) if over() else float(def.pull)
	game.fx.nova(position, float(def.reach), Color("d04040"))
	for e in game.enemies_in(HdTelegraph.CIRCLE, position, Vector3.FORWARD, float(def.reach), 0, 0, 0, 0):
		var to: Vector3 = position - e.position
		to.y = 0.0
		if e.rank != "boss" and to.length() > radius + e.radius + 0.5:
			e.knock = to.normalized() * minf(pull, to.length() - radius - e.radius) / 0.3
			e.knock_t = 0.3
		e.taunt(self, float(def.taunt))


## Überspannung endet: der Magnetköder explodiert.
func over_end() -> void:
	if kind != "magnetkoeder" or destroyed:
		return
	game.fx.nova(position, float(def.reach), Color("ff5040"))
	for e in game.enemies_in(HdTelegraph.CIRCLE, position, Vector3.FORWARD, float(def.reach), 0, 0, 0, 0):
		_hit(e, float(def.over_blast) * zix.power())
	hp = 0.0
	destroy()
	game.buildings.erase(self)


func destroy() -> void:
	destroyed = true
	for r in rockets:
		if is_instance_valid(r.tele):
			r.tele.queue_free()
	rockets.clear()
	queue_free()
