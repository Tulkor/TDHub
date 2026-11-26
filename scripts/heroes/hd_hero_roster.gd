class_name HdHeroRoster
extends HdHero
## Gemeinsame native Bausteine, individuelle Kits aus heroes_helden.json.
## Alle Timer laufen auf der autoritativen Spielzeit, nicht auf SceneTree-Timern.
var fields: Array = []
var pending: Array = []
var servants: Array = []
var marks: Dictionary = {}
var stance: Dictionary = {}
var stance_until := 0.0
var critical := 1.0
var flow := 0
var flow_until := 0.0
var charge := 0.0
var last_proc := -10.0
var still_time := 0.0
var old_position := Vector3.ZERO
var hit_count := 0
var cast_serial := 0
var field_serial := 0


func tint() -> Color:
	return Color(str(def.get("color", "b6a37b")))


func passive_kind() -> String:
	return str(def.get("passive_kind", ""))


func lantern_lights(at: Vector3) -> bool:
	return passive_kind() == "shine" and fields.any(func(f): return str(f.a.op) == "beacon" and game.play_time < float(f.until) and at.distance_to(f.pos) <= float(f.a.radius))


func power() -> float:
	var value := super.power()
	if passive_kind() == "berserk":
		value *= 1.0 + 0.4 * (1.0 - hp / max_hp)
	return value


func _apply_level() -> void:
	super._apply_level()
	if passive_kind() == "pack":
		var current := servants.filter(func(p): return is_instance_valid(p) and p.alive()).size() * 2.0
		armor += current
		set_meta("pack_armor",current)


func attack_interval() -> float:
	return super.attack_interval() / (1.0 + 0.03 * flow if game.play_time < flow_until else 1.0)


func movement_speed(now: float) -> float:
	if now < stance_until and bool(stance.get("root", false)):
		return 0.0
	return super.movement_speed(now)


func incoming(amount: float) -> float:
	if dodge_invulnerable():
		return 0.0
	if passive_kind() == "charge":
		charge = minf(100, charge + amount * 0.2)
	if passive_kind() == "front":
		var origin: Vector3 = get_meta("damage_origin", Vector3.INF)
		if origin.is_finite() and facing.dot((origin - position).normalized()) > 0.35:
			amount *= 0.65
	if passive_kind() == "anchor" and still_time > 0.25:
		amount *= 0.85
	if passive_kind() == "mirror" and servants.any(func(p): return is_instance_valid(p) and p.alive()):
		amount *= 0.85
	if game.play_time < stance_until and bool(stance.get("invulnerable", false)):
		if stance.has("counter") and not bool(stance.get("triggered", false)):
			stance.triggered = true
			var e = game.nearest_enemy(position, 5)
			if e:
				game.hero_hit(e, amount * float(stance.counter), "physical")
		return 0.0
	return super.incoming(amount)


func _cast(slot: int, a: Dictionary, dir: Vector3, at: Vector3) -> bool:
	var point := clamp_point(at, float(a.range))
	var op := str(a.op)
	if op == "beacon_blink":
		var nearest: Dictionary = {}
		var distance := 7.0
		for f in fields:
			if str(f.a.op) != "beacon":
				continue
			var d: float = point.distance_to(f.pos)
			if d < distance:
				distance = d
				nearest = f
		if nearest.is_empty():
			return false
		point = nearest.pos
	if op in ["command", "swap"] and not servants.any(func(p): return is_instance_valid(p) and p.alive()):
		return false
	if op == "rescue" and game.ally_near(point, 3) == null:
		return false
	cast_serial += 1
	var data := a.duplicate(true)
	if charge >= 100 and float(data.get("damage", 0)) > 0:
		data.damage *= 1.5
		charge = 0
	match op:
		"shot", "shots":
			var count := int(data.get("count", 1))
			for k in count:
				var direction := dir.rotated(Vector3.UP, (k - (count - 1) * 0.5) * 0.22)
				_shot(data, direction)
		"cone", "blast", "line", "pull", "detonate":
			_area(data, position, dir)
		"taunt":
			var hits: Array = game.enemies_in(HdTelegraph.CIRCLE, position, dir, float(data.radius), 0, 0, 0, 0)
			for e in hits:
				e.taunt(self, float(data.duration))
				if data.has("heal"):
					_heal(self, float(data.heal) * power())
			_support(data, position, float(data.radius))
			game.fx.play("nova", position, dir, float(data.radius), tint())
		"meteor":
			for k in int(data.get("count", 1)):
				var offset := Vector3.ZERO if k == 0 else Vector3(cos(k * 2.4), 0, sin(k * 2.4)) * 2.2
				var when := float(data.get("delay", 0.8)) + k * float(data.get("gap", 0.5))
				_schedule(data, point + offset, dir, when)
		"zone", "whirl", "beacon":
			if op == "beacon":
				var own: Array = fields.filter(func(f): return str(f.a.op) == "beacon")
				if own.size() >= int(data.limit):
					fields.erase(own[0])
			_field(data, position if op == "whirl" else point, dir, op == "whirl")
		"sun":
			for f in fields:
				if str(f.a.op) == "beacon":
					_field(data, f.pos, dir)
		"guard", "form":
			var target = game.ally_near(point, 3) if bool(data.get("ally", false)) else self
			if target == null:
				return false
			if target is HdHeroRoster:
				target.stance = data.duplicate(true)
				target.stance_until = game.play_time + float(data.duration)
			elif target is HdHero and bool(data.get("invulnerable", false)):
				target.add_buff("ice_guard", {"dmg_in":1.0,"speed":-1.0}, float(data.duration))
			_give(data, target)
			if float(data.get("damage", 0)) > 0:
				_schedule(data, position, dir, float(data.duration))
			game.fx.play("robe", target.position, dir, 2, tint())
		"buff":
			var target = game.ally_near(point, 3)
			if target == null:
				return false
			_give(data, target)
		"dash", "blink", "beacon_blink":
			var start := position
			if op == "dash":
				var direction := -dir if bool(data.get("backward", false)) else dir
				var length := float(data.range)
				# Kleine Schritte respektieren dieselben Wände/Kollisionen wie normales Laufen.
				for k in ceili(length / 0.3):
					game.move_unit(self, direction, 1, minf(0.3, length - k * 0.3), true)
				if data.get("trap", false) or data.get("trail", false):
					var trail := data.duplicate(true)
					trail.op = "zone"
					trail.duration = float(data.get("duration", 5))
					trail.radius = 2.0
					_field(trail, start, dir)
				else:
					var line := data.duplicate(true)
					line.op = "line"
					line.range = start.distance_to(position)
					_area(line, start, direction)
			else:
				# Kein Blink durch Arena-Wände oder in getrennte Erkundungsgebiete.
				var destination: Vector3 = game.free_point(point, radius)
				if (position.x < -400) != (destination.x < -400) and not game.final.active and not game.event_arena.active:
					return false
				position = destination
			critical = float(data.get("critical", 1))
			_give(data, self)
			game.fx.dash_trail(start, position - start)
		"chain":
			var done := []
			var origin := position
			for k in int(data.count):
				var e = game.nearest_enemy(point if k == 0 else origin, float(data.range) if k == 0 else float(data.jump), done)
				if e == null:
					break
				game.fx.bolt(origin + Vector3.UP, e.position + Vector3.UP, tint())
				_hit(e, data, dir)
				origin = e.position
				done.append(e)
		"summon", "turret", "wall":
			_construct(data, point, dir)
		"command":
			for p in servants:
				if is_instance_valid(p) and p.alive():
					p.position = game.free_point(point + Vector3(game.rng.randf_range(-1, 1), 0, game.rng.randf_range(-1, 1)), p.radius)
			_area(data, point, dir)
		"swap":
			for p in servants:
				if is_instance_valid(p) and p.alive():
					var previous := position
					position = game.free_point(p.position, radius)
					p.position = previous
					break
			_give(data, self)
		"strikes":
			stance = {"invulnerable":true}
			stance_until = game.play_time + int(data.count) * float(data.gap)
			for k in int(data.count):
				var strike := data.duplicate(true)
				strike.seek = true
				_schedule(strike, position, dir, k * float(data.gap))
		"rescue":
			var ally = game.ally_near(point, 3)
			if ally is HdHero:
				ally.position = game.free_point(position + dir * 1.6, ally.radius)
			_give(data, ally)
		"revive":
			for h in game.playing_heroes():
				if h.dead:
					h.respawn_t = 0
					h._respawn()
				_give(data, h)
			game.fx.play("heal", position, dir, 10, tint())
	if _anim and _anim.has_animation("cast_%d" % slot):
		_play("cast_%d" % slot, 0.65)
	var fx_position := point if bool(data.get("at_point", false)) or op in ["zone", "beacon", "turret", "wall"] else position
	game.fx.play("roster:%s:%d:cast" % [def.id,slot],fx_position,dir,float(data.radius),tint(),point)
	return true


func _shot(a: Dictionary, dir: Vector3) -> void:
	var hit := func(e):
		if float(a.get("blast", 0)) > 0:
			var blast := a.duplicate(true)
			blast.op = "blast"
			blast.radius = a.blast
			_area(blast, e.position, dir)
		else:
			_hit(e, a, dir)
	game.shoot(position + dir * (radius + 0.15), dir, float(a.get("speed", 26)), float(a.range), float(a.get("width", 0.8)), 0,
		{"hit":hit, "pierce":bool(a.get("pierce", false)), "max_hits":int(a.get("pierce", 0)) if typeof(a.get("pierce")) == TYPE_INT else 0,
		"look":"roster_" + str(def.id), "color":tint(), "size":0.28})
	game.fx.play("muzzle", position + Vector3.UP, dir, 1, tint())


func _area(a: Dictionary, at: Vector3, dir: Vector3) -> void:
	var op := str(a.op)
	var shape := HdTelegraph.CONE if op in ["cone", "pull"] else (HdTelegraph.LINE if op == "line" or a.get("shape", "") == "line" else HdTelegraph.CIRCLE)
	var hits: Array = game.enemies_in(shape, at, dir, float(a.get("range", 4)) if shape == HdTelegraph.CONE else float(a.radius), 0, float(a.get("angle", 100)), float(a.range), float(a.get("width", 2)))
	for e in hits:
		if op == "detonate":
			var key := str(e.get_instance_id())
			if marks.has(key):
				game.hero_hit(e, float(a.damage) * int(marks[key].stacks) * power(), "poison")
				marks.erase(key)
		else:
			_hit(e, a, dir)
		if op == "pull" or (float(a.get("pull", 0)) > 0 and str(a.op) != "shot"):
			game.move_unit(e, (at - e.position).normalized(), 1, minf(float(a.get("pull", 3)), e.position.distance_to(at)), true)
	if float(a.get("heal", 0)) > 0 or a.has("dmg_out") or a.has("shield") or a.has("dmg_in"):
		for ally in game.allies():
			if HdTelegraph.in_shape(shape, at, dir, float(a.range) if shape == HdTelegraph.CONE else float(a.radius), 0, float(a.get("angle", 100)), float(a.range), float(a.get("width", 2)), ally.position, ally.radius):
				_give(a, ally)
	game.fx.play("roster:%s:%d:impact" % [def.id,int(a.get("slot",0))],at,dir,float(a.radius),tint())


func _hit(e, a: Dictionary, dir: Vector3) -> void:
	if not is_instance_valid(e) or not e.alive():
		return
	var damage := float(a.get("damage", 0)) * power()
	game.hero_hit(e, damage, str((a.get("elements", ["physical"]) as Array)[0]))
	if float(a.get("leech", 0)) > 0:
		_heal(self, damage * float(a.leech))
	if e.dead:
		return
	if float(a.get("stun", 0)) > 0:
		game.stun(e, float(a.stun))
	if float(a.get("slow", 0)) > 0:
		e.cc.slow("roster", float(a.slow), 2.0, game.play_time)
	if float(a.get("armor_cut", 0)) > 0:
		e.cc.reduce_armor("roster", float(a.armor_cut), float(a.get("duration", 4)), game.play_time)
	if float(a.get("weaken", 0)) > 0:
		e.set_meta("roster_weaken", {"value":float(a.weaken), "until":game.play_time + 1.5})
	if float(a.get("expose", 0)) > 0:
		e.set_meta("roster_expose", {"value":float(a.expose), "until":game.play_time + float(a.get("duration", 4))})
	if float(a.get("knockback", 0)) > 0:
		game.move_unit(e, dir, 1, float(a.knockback), true)
	if float(a.get("pull", 0)) > 0:
		game.move_unit(e, (position - e.position).normalized(), 1, float(a.pull), true)
	if int(a.get("poison", 0)) > 0:
		_poison(e, int(a.poison))
	if passive_kind() == "frost":
		var stacks := int(e.get_meta("frost_count", 0)) + 1
		e.set_meta("frost_count", stacks % 5)
		e.cc.slow("frost", .2, 3, game.play_time)
		if stacks >= 5:
			game.stun(e, 1)


func _heal(target, amount: float) -> void:
	var got: float = game.heal_target(target, amount)
	if passive_kind() == "grace" and amount > got:
		target.add_shield(minf(amount - got, target.max_hp * 0.15), 5)


func _give(a: Dictionary, target) -> void:
	if not is_instance_valid(target) or not target.alive():
		return
	var duration := float(a.get("duration", 4))
	if str(a.get("op", "")) in ["zone", "whirl", "beacon", "sun"]:
		duration = float(a.get("interval", 1)) + .25
	if float(a.get("heal", 0)) > 0:
		_heal(target, float(a.heal) * power())
	if float(a.get("shield", 0)) > 0:
		target.add_shield(target.max_hp * float(a.shield), duration)
	if target is HdHero:
		var buff := {}
		for key in ["dmg_in", "dmg_out", "speed", "attack_speed", "lifesteal", "slow_immune"]:
			if a.has(key):
				buff[key] = a[key]
		if a.has("speed_buff"):
			buff.speed = a.speed_buff
		if not buff.is_empty():
			target.add_buff("roster:%d:%s" % [get_instance_id(), str(a.get("id", "field"))], buff, duration)
	elif float(a.get("dmg_out", 0)) > 0 or float(a.get("dmg_in", 0)) > 0:
		target.boost_until = maxf(target.boost_until, game.play_time + duration)


func _support(a: Dictionary, at: Vector3, r: float) -> void:
	for target in game.allies():
		if at.distance_to(target.position) <= r + target.radius:
			_give(a, target)


func _field(a: Dictionary, at: Vector3, dir: Vector3, follow := false) -> void:
	field_serial += 1
	fields.append({"uid":field_serial,"a":a.duplicate(true), "pos":at, "dir":dir, "follow":follow,
		"until":game.play_time + float(a.get("duration", 5)), "next":game.play_time})


func _schedule(a: Dictionary, at: Vector3, dir: Vector3, delay: float) -> void:
	var tele := HdTelegraph.circle(float(a.radius), tint())
	tele.position = at + Vector3(0, .035, 0)
	game.add_child(tele)
	game.fx.play("lob", position + Vector3.UP, dir, maxf(.8, float(a.radius) * .3), tint(), at)
	pending.append({"a":a.duplicate(true), "pos":at, "dir":dir, "at":game.play_time + delay, "start":game.play_time, "tele":tele})


func _construct(a: Dictionary, at: Vector3, dir: Vector3) -> void:
	var wall := str(a.op) == "wall"
	var pet := "wall" if wall else str(a.get("pet", "wolf"))
	var active: Array = servants.filter(func(p): return is_instance_valid(p) and p.alive() and str(p.def.pet) == pet)
	var count := ceili(float(a.radius)) if wall else int(a.get("count", 1))
	var limit := count if wall else int(a.get("limit", 4))
	while active.size() + count > limit and not active.is_empty():
		var first = active.pop_front()
		first.retire()
	for k in mini(count, limit):
		var p := HdRosterConstruct.new()
		var offset := Vector3(-dir.z, 0, dir.x) * (k - (count - 1) * 0.5) * 1.65 if wall else Vector3(cos(k * 2.4), 0, sin(k * 2.4)) * 1.6
		var point: Vector3 = game.free_point(at + offset, 0.75)
		var stats := {"name":str(a.name), "pet":pet,"roster_construct":true,"hp":float(a.get("hp", 350)),
			"armor":4,"radius":0.8,"range":18 if str(a.op) == "turret" else 3.0,"damage":float(a.get("damage", 30)) * power(),
			"interval":1.0,"blast":float(a.get("blast", 0)),"duration":float(a.get("duration", 20)),
			"mobile":str(a.op) == "summon","color":str(def.color),"owner_slot":game.hero_slot(self),"source_slot":int(a.get("slot", 0))}
		p.setup_construct(game, stats, point, self)
		game.add_child(p)
		game.buildings.append(p)
		servants.append(p)
		game.fx.play("build", point, dir, 2, tint())


func _kit_step(dt: float, now: float) -> void:
	still_time = still_time + dt if position.distance_to(old_position) < 0.01 else 0.0
	old_position = position
	if passive_kind() == "moss" and still_time >= 2:
		heal(max_hp * 0.03 * dt, true)
	servants = servants.filter(func(p): return is_instance_valid(p) and p.alive())
	if passive_kind() == "pack":
		var previous := float(get_meta("pack_armor", 0))
		var current := servants.size() * 2.0
		armor += current - previous
		set_meta("pack_armor", current)
	for f in fields.duplicate():
		if now >= float(f.until):
			fields.erase(f)
			continue
		if f.follow:
			f.pos = position
		game.fx.hold("roster:%d:%d" % [get_instance_id(),int(f.uid)], "roster:%s:%d:hold" % [def.id,int(f.a.get("slot",0))], f.pos, float(f.a.radius), tint())
		if now >= float(f.next):
			f.next = now + float(f.a.get("interval", 1))
			_area(f.a, f.pos, f.dir)
	for p in pending.duplicate():
		if is_instance_valid(p.tele):
			p.tele.progress = clampf((now - float(p.start)) / maxf(.01, float(p.at) - float(p.start)), 0, 1)
		if now < float(p.at):
			continue
		pending.erase(p)
		if is_instance_valid(p.tele):
			p.tele.queue_free()
		if bool(p.a.get("seek", false)):
			var e = game.nearest_enemy(position, float(p.a.radius))
			if e:
				position = game.free_point(e.position - facing * 1.2, radius)
				_hit(e, p.a, facing)
		else:
			_area(p.a, p.pos, p.dir)
	for key in marks.keys():
		var m: Dictionary = marks[key]
		if not is_instance_valid(m.enemy) or not m.enemy.alive() or now >= float(m.until):
			marks.erase(key)
		elif now >= float(m.next):
			m.next = now + 1
			game.hero_hit(m.enemy, 5 * int(m.stacks) * power(), "dot", true)
	if now < stance_until:
		game.fx.hold("stance:%d" % get_instance_id(), "roster:%s:%d:hold" % [def.id,int(stance.get("slot",2))], position, 1.5, tint())


func _poison(e, stacks: int) -> void:
	var key := str(e.get_instance_id())
	var old: Dictionary = marks.get(key, {})
	marks[key] = {"enemy":e,"stacks":mini(10,int(old.get("stacks",0)) + stacks),"until":game.play_time + 6,"next":float(old.get("next",game.play_time + 1))}


func on_hit(e) -> void:
	if not is_instance_valid(e):
		return
	hit_count += 1
	if critical > 1 and e.alive():
		game.hero_hit(e, float(def.attack.damage) * power() * (critical - 1), "physical")
		critical = 1
	match passive_kind():
		"poison": _poison(e, 1)
		"frost":
			if e.alive():
				_hit(e, {"damage":0,"slow":.2}, facing)
		"flow":
			flow = mini(10, flow + 1) if game.play_time < flow_until else 1
			flow_until = game.play_time + 3
		"ember":
			_field({"op":"zone","damage":18,"range":3,"radius":1.6,"duration":2,"elements":["fire"]},e.position,facing)
		"curse":
			e.set_meta("roster_expose", {"value":.1,"until":game.play_time + 4})
		"brew":
			if game.play_time >= last_proc + 1:
				_heal(self, max_hp * .02)
				last_proc = game.play_time
		"tailwind": add_buff("tailwind", {"speed":.15}, 2)
		"souls":
			var allies: Array = game.allies().filter(func(t): return t.position.distance_to(position) < 10)
			allies.sort_custom(func(a,b): return a.hp / a.max_hp < b.hp / b.max_hp)
			if not allies.is_empty(): _heal(allies[0], 18 * power())
		"resonance":
			if hit_count % 4 == 0: add_shield(max_hp * .08, 5)


func _ranged_shot(dir: Vector3, _target) -> void:
	attack_cd = attack_interval()
	var hit := func(e):
		game.hero_hit(e, float(def.attack.damage) * power(), "attack")
		on_hit(e)
	game.shoot(position + dir * (radius + .1), dir, 32, attack_range(), .55, 0,
		{"hit":hit,"look":"roster_" + str(def.id),"color":tint(),"size":.17})
	game.fx.play("muzzle", position + Vector3.UP, dir, .7, tint())


func bot_act(e, _to: Vector3, distance: float, _near: int) -> float:
	if e:
		for slot in 4:
			cast(slot, e.position)
	elif hp < max_hp * .7:
		for slot in 4:
			if ability(slot).has("heal"): cast(slot, position)
	return attack_range() * .8 if distance > 0 else 3.0


func _on_death() -> void:
	free_kit()
	stance_until = 0
	critical = 1
	flow = 0
	charge = 0


func free_kit() -> void:
	for f in fields:
		game.fx.release("roster:%d:%d" % [get_instance_id(),int(f.uid)])
	game.fx.release("stance:%d" % get_instance_id())
	for p in pending:
		if is_instance_valid(p.tele): p.tele.queue_free()
	pending.clear()
	fields.clear()
	marks.clear()
	for p in servants:
		if is_instance_valid(p): p.retire()
	servants.clear()
