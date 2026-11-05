class_name HdHero
extends Node3D
## Der Held im Hero-Defense-Modus. Etappe 1: Torvik Sturmruf (hero-defense-helden.md, Nr. 13).
## Steuerung kommt von HdGame (WASD-Modus: move_dir + aim + attack_held; Maus-Modus: order) oder
## vom Bot. Fähigkeiten über cast(slot, punkt), Ausweichen über dodge(richtung).
## Ergänzung zum Design: der zweite Blitz von Donnerhieb betäubt kurz (0,6 s), damit Torvik
## Gegner beim Aufladen unterbrechen kann (sonst kann er das nur mit der Ultimativen).

var game  ## HdGame
var def: Dictionary
var level := 1
var xp := 0.0
var hp := 100.0
var max_hp := 100.0
var mana := 100.0
var max_mana := 100.0
var armor := 0.0
var speed := 6.0
var radius := 0.7
var cc: HdCc
var dead := false
var respawn_t := 0.0
var facing := Vector3(0, 0, -1)
var move_dir := Vector3.ZERO    ## WASD (Weltrichtung, Länge 0–1)
var aim := Vector3.ZERO         ## Mauspunkt am Boden
var attack_held := false        ## WASD: Linksklick gehalten
var order: Dictionary = {}      ## Maus-Modus: {kind: move, point} | {kind: attack, target}
var auto_attack := false        ## Maus-Modus: in der Nähe selbst angreifen
var attack_cd := 0.0
var cd: Array = [0.0, 0.0, 0.0, 0.0]
var dodge_cd := 0.0
var dodge_t := 0.0
var dodge_dir := Vector3.ZERO
var form_t := 0.0               ## Windaufstieg läuft
var empowered := false          ## nächster Donnerhieb verstärkt (Sturmbrandung)
var gust_ready := 0.0
var nova_discount := false
var damage_done := 0.0
var damage_taken := 0.0
var kills := 0
var deaths := 0
var dodges := 0
var _body: Node3D
var _axes: Array = []
var _form_glow: MeshInstance3D


func setup(g, d: Dictionary) -> void:
	game = g
	def = d
	radius = float(d.radius)
	speed = float(d.speed)
	cc = HdCc.new(game.cfg.cc, "hero")
	_apply_level()
	hp = max_hp
	mana = max_mana
	_build_body()


func _build_body() -> void:
	_body = Node3D.new()
	add_child(_body)
	var steel := HdDev.mat(Color("3d8fd6"), 0.5)
	_body.add_child(HdDev.cyl(0.55, 0.65, 1.5, steel, Vector3(0, 0.75, 0)))
	_body.add_child(HdDev.sphere(0.38, HdDev.mat(Color("d8b48a"), 0.5), Vector3(0, 1.75, 0)))
	_body.add_child(HdDev.box(Vector3(1.5, 0.25, 0.5), HdDev.mat(Color("2b5f96"), 0.5), Vector3(0, 1.38, 0)))
	for side in [-1.0, 1.0]:
		var axe := Node3D.new()
		axe.position = Vector3(0.85 * side, 0.9, -0.25)
		axe.add_child(HdDev.box(Vector3(0.1, 1.1, 0.1), HdDev.mat(Color("6b4a2a"), 0.5), Vector3(0, 0, 0)))
		axe.add_child(HdDev.box(Vector3(0.12, 0.45, 0.5), HdDev.mat(UiTheme.CYAN, 0.5, 1.2), Vector3(0, 0.4, -0.2)))
		_body.add_child(axe)
		_axes.append(axe)
	_form_glow = HdDev.cyl(1.1, 1.1, 0.05, HdDev.flat(Color(0.6, 0.9, 1.0), 0.35), Vector3(0, 0.05, 0), 24)
	_form_glow.visible = false
	_body.add_child(_form_glow)


func _apply_level() -> void:
	var lv: Dictionary = def.level
	var k := level - 1
	var old_max := max_hp
	max_hp = float(def.hp) + float(lv.hp) * k
	max_mana = float(def.mana) + float(lv.mana) * k
	armor = float(def.armor) + float(lv.armor) * k
	if old_max > 0.0 and hp > 0.0:
		hp += max_hp - old_max


func xp_needed(lvl: int) -> float:
	var lv: Dictionary = def.level
	return float(lv.xp_base) * pow(float(lv.xp_growth), lvl - 1)


func add_xp(amount: float) -> void:
	var lv: Dictionary = def.level
	xp += amount
	while level < int(lv.max) and xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		_apply_level()
		mana = max_mana
		game.on_level_up()


func power() -> float:
	return 1.0 + float(def.level.damage) * (level - 1)


func alive() -> bool:
	return not dead


func dodging() -> bool:
	return dodge_t > 0.0


func ability(slot: int) -> Dictionary:
	var a: Dictionary = def.abilities[slot]
	if slot == 0 and form_t > 0.0:
		var asc: Dictionary = a.ascended.duplicate()
		asc.merge(a)
		return asc
	return a


func ability_cost(slot: int) -> float:
	var c := float(def.abilities[slot].mana)
	if slot == 1 and nova_discount:
		c *= 1.0 - float(def.abilities[1].discount)
	return c


func unlocked(slot: int) -> bool:
	return level >= int(def.abilities[slot].get("unlock", 1))


# ---------------------------------------------------------------- Schritt

func step(dt: float, now: float) -> void:
	for i in 4:
		cd[i] = maxf(0.0, cd[i] - dt)
	dodge_cd = maxf(0.0, dodge_cd - dt)
	attack_cd -= dt
	if form_t > 0.0:
		form_t -= dt
	_form_glow.visible = form_t > 0.0
	_body.scale = Vector3.ONE * (1.12 if form_t > 0.0 else 1.0)
	if dead:
		respawn_t -= dt
		if respawn_t <= 0.0:
			_respawn()
		return
	hp = minf(max_hp, hp + float(def.hp_regen) * dt)
	mana = minf(max_mana, mana + float(def.mana_regen) * dt)
	cc.update(now)
	if dodge_t > 0.0:
		dodge_t -= dt
		var dd: Dictionary = def.dodge
		game.move_unit(self, dodge_dir, float(dd.distance) / float(dd.time), dt, true)
		return
	if cc.stunned(now):
		_body.rotation.x = -0.5
		return
	_body.rotation.x = 0.0
	var spd := speed * cc.speed_factor(now)
	if move_dir.length_squared() > 0.01:
		order = {}
		game.move_unit(self, move_dir.limit_length(1.0), spd, dt)
		_face(move_dir)
	elif order.get("kind", "") == "move":
		var to: Vector3 = order.point - position
		to.y = 0.0
		if to.length() < 0.3:
			order = {}
		else:
			game.move_unit(self, to.normalized(), minf(spd, to.length() / dt), dt)
			_face(to)
	elif order.get("kind", "") == "attack":
		var e = order.target
		if e == null or not is_instance_valid(e) or not e.alive():
			order = {}
		else:
			var to: Vector3 = e.position - position
			to.y = 0.0
			if to.length() > float(def.attack.range) + e.radius + radius:
				game.move_unit(self, to.normalized(), spd, dt)
				_face(to)
			else:
				_try_swing(e)
	# Grundangriff
	if attack_held:
		var aim_dir := aim - position
		aim_dir.y = 0.0
		_face(aim_dir)
		var e = game.enemy_in_arc(position, aim_dir, float(def.attack.range) + radius, float(def.attack.arc))
		if e:
			_try_swing(e)
	elif auto_attack and order.is_empty() and move_dir.length_squared() < 0.01:
		var e = game.nearest_enemy(position, 4.5)
		if e:
			order = {"kind": "attack", "target": e}


func _face(v: Vector3) -> void:
	v.y = 0.0
	if v.length_squared() > 0.0001:
		facing = v.normalized()
		rotation.y = atan2(facing.x, facing.z) + PI


func _try_swing(e) -> void:
	if attack_cd > 0.0:
		return
	attack_cd = float(def.attack.interval)
	_face(e.position - position)
	_swing_fx()
	game.hero_hit(e, float(def.attack.damage) * power(), "attack")
	# Sturmbrandung: Windstoß = 2 Zusatzangriffe, je Windstoß Chance auf verstärkten, zurückgesetzten Donnerhieb
	var p: Dictionary = def.passive
	var chance := float(p.chance) * (float(def.abilities[3].gust_mult) if form_t > 0.0 else 1.0)
	if game.play_time >= gust_ready and game.rng.randf() < chance:
		gust_ready = game.play_time + float(p.icd)
		game.floater(position + Vector3(0, 2.4, 0), tr("Windstoß"), UiTheme.CYAN)
		for k in int(p.extra):
			if e.alive():
				game.hero_hit(e, float(def.attack.damage) * power(), "gust")
			if game.rng.randf() < float(p.reset_chance):
				cd[0] = 0.0
				empowered = true


func _swing_fx() -> void:
	for a in _axes:
		var tw := create_tween()
		tw.tween_property(a, "rotation:x", -1.4, 0.08)
		tw.tween_property(a, "rotation:x", 0.0, 0.14)


func _respawn() -> void:
	dead = false
	visible = true
	hp = max_hp
	mana = max_mana
	position = game.hero_spawn()
	order = {}
	game.message.emit(tr("%s ist zurück") % tr(str(def.name)))


func die() -> void:
	dead = true
	deaths += 1
	visible = false
	order = {}
	form_t = 0.0
	respawn_t = float(def.respawn.base) + float(def.respawn.per_level) * level
	game.message.emit(tr("%s ist gefallen") % tr(str(def.name)))


# ---------------------------------------------------------------- Fähigkeiten

## Fähigkeit in Richtung/auf den Punkt at wirken. Gibt false zurück, wenn es nicht geht.
func cast(slot: int, at: Vector3) -> bool:
	if dead or dodging() or cc.stunned(game.play_time) or slot < 0 or slot > 3:
		return false
	if cd[slot] > 0.0 or not unlocked(slot) or mana < ability_cost(slot):
		return false
	var a := ability(slot)
	var dir := at - position
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = facing
	dir = dir.normalized()
	_face(dir)
	mana -= ability_cost(slot)
	cd[slot] = float(a.cooldown)
	var pw := power()
	match slot:
		0:
			if form_t > 0.0:
				# Windschlag: Linie, durchschlägt alle
				game.fx.flash_shape(HdTelegraph.line(float(a.range), float(a.width), HdTelegraph.BLUE), position, dir)
				for e in game.enemies_in(HdTelegraph.LINE, position, dir, 0, 0, 0, float(a.range), float(a.width)):
					game.hero_hit(e, float(a.damage[0]) * pw, "q")
			else:
				var mult := pw * ((1.0 + float(def.passive.empower)) if empowered else 1.0)
				var hits: Array = game.enemies_in(HdTelegraph.CONE, position, dir, float(a.range), 0, float(a.angle), 0, 0)
				game.fx.flash_shape(HdTelegraph.cone(float(a.range), float(a.angle), HdTelegraph.BLUE), position, dir)
				for e in hits:
					game.hero_hit(e, float(a.damage[0]) * mult, "q")
					if e.alive():
						game.hero_hit(e, float(a.damage[1]) * mult, "q")
						game.fx.bolt(position + Vector3(0, 1.4, 0), e.position + Vector3(0, e.height(), 0))
					if e.alive():
						game.stun(e, float(a.stun))
				if empowered and not hits.is_empty():
					var done: Array = hits.duplicate()
					var from = hits[0]
					for k in int(def.passive.empower_hops):
						var nxt = game.nearest_enemy(from.position, float(def.passive.hop_range), done)
						if nxt == null:
							break
						game.fx.bolt(from.position + Vector3(0, 1.0, 0), nxt.position + Vector3(0, 1.0, 0))
						game.hero_hit(nxt, float(a.damage[0]) * mult, "q")
						done.append(nxt)
						from = nxt
				empowered = false
		1:
			var hits: Array = game.enemies_in(HdTelegraph.CIRCLE, position, dir, float(a.radius), 0, 0, 0, 0)
			game.fx.nova(position, float(a.radius), Color("ff8a3a"))
			for e in hits:
				game.hero_hit(e, float(a.damage) * pw, "w")
				e.burn_dps = float(a.burn) * pw
				e.burn_until = game.play_time + float(a.burn_time)
			nova_discount = hits.size() >= int(a.discount_hits)
		2:
			game.hero_projectile(position + dir * radius, dir, a, pw)
		3:
			form_t = float(a.duration)
			cd[0] = minf(cd[0], float(def.abilities[0].ascended.cooldown))
			game.fx.nova(position, float(a.radius), Color(0.7, 0.95, 1.0))
			for e in game.enemies_in(HdTelegraph.CIRCLE, position, dir, float(a.radius), 0, 0, 0, 0):
				var away: Vector3 = e.position - position
				away.y = 0.0
				if away.length_squared() < 0.01:
					away = dir
				var stun_t: float = game.stun(e, float(a.stun))
				if stun_t > 0.0:
					e.knock = away.normalized() * float(a.knockback) / 0.25
					e.knock_t = 0.25
				game.hero_hit(e, 40.0 * pw, "r")
	return true


func dodge(dir: Vector3) -> bool:
	if dead or dodge_cd > 0.0 or cc.stunned(game.play_time):
		return false
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = facing
	dodge_dir = dir.normalized()
	dodge_t = float(def.dodge.time)
	dodge_cd = float(def.dodge.cooldown)
	order = {}
	dodges += 1
	game.fx.dash_trail(position, dodge_dir * float(def.dodge.distance))
	return true
