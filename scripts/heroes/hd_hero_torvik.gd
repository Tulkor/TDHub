class_name HdHeroTorvik
extends HdHero
## Torvik Sturmruf, Elementarkrieger (hero-defense-helden.md Nr. 13).
## Ergänzung zum Design: der zweite Blitz von Donnerhieb betäubt kurz (0,6 s), damit Torvik
## Gegner beim Aufladen unterbrechen kann (sonst kann er das nur mit der Ultimativen).

var form_t := 0.0               ## Windaufstieg läuft
var empowered := false          ## nächster Donnerhieb verstärkt (Sturmbrandung)
var gust_ready := 0.0
var nova_discount := false
var _axes: Array = []
var _form_glow: MeshInstance3D


func _build_body() -> void:
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


func ability(slot: int) -> Dictionary:
	var a: Dictionary = def.abilities[slot]
	if slot == 0 and form_t > 0.0:
		var asc: Dictionary = a.ascended.duplicate()
		asc.merge(a)
		return skills.resolve(asc, slot, _rank_preview)
	return skills.resolve(a, slot, _rank_preview)


func ability_cost(slot: int) -> float:
	var c := float(ability(slot).mana)
	if slot == 1 and nova_discount:
		c *= 1.0 - float(def.abilities[1].discount)
	return c


func _kit_step(dt: float, _now: float) -> void:
	if form_t > 0.0:
		form_t -= dt
	if form_t > 0.0 and alive():
		game.fx.hold("wind:%d" % get_instance_id(), "wind_aura", position, 1.0, Color(0.5, 0.88, 1.0))
	_body.scale = Vector3.ONE * (1.12 if form_t > 0.0 else 1.0)


func _on_death() -> void:
	form_t = 0.0


func on_hit(e) -> void:
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
	game.fx.swing(position, facing, attack_range(), UiTheme.CYAN if form_t > 0 else Color("c9d8ec"))
	swing_motion()
	for a in _axes:
		a.rotation.y = -1.25
		var tw := create_tween()
		tw.tween_property(a, "rotation:y", 1.8, 0.12)
		tw.tween_property(a, "rotation:y", 0.0, 0.18)


func ranged() -> bool:
	return form_t > 0


func attack_range() -> float:
	return float(def.abilities[3].get("attack_range", 14.0)) if form_t > 0 else super.attack_range()


func _ranged_shot(dir: Vector3, _target) -> void:
	attack_cd = attack_interval()
	_swing_fx()
	var hit := func(enemy):
		game.hero_hit(enemy, float(def.attack.damage) * power(), "wind")
		if not enemy.dead:
			on_hit(enemy)
	game.shoot(position + dir * (radius + 0.2), dir, 28, attack_range(), 0.8, 0, {"hit":hit, "color":Color(0.6, 0.95, 1.0), "size":0.24, "look":"wind"})


func _cast(slot: int, a: Dictionary, dir: Vector3, _at: Vector3) -> bool:
	var pw := power()
	match slot:
		0:
			if form_t > 0.0:
				# Windschlag: Linie, durchschlägt alle
				game.fx.play("gust_line", position, dir, float(a.range), Color(0.6, 0.95, 1.0), Vector3(float(a.width), 0, 0))
				for e in game.enemies_in(HdTelegraph.LINE, position, dir, 0, 0, 0, float(a.range), float(a.width)):
					game.hero_hit(e, float(a.damage[0]) * pw, "q")
			else:
				var mult := pw * ((1.0 + float(def.passive.empower)) if empowered else 1.0)
				var hits: Array = game.enemies_in(HdTelegraph.CONE, position, dir, float(a.range), 0, float(a.angle), 0, 0)
				game.fx.play("thunder", position, dir, float(a.range), Color.WHITE, Vector3(float(a.angle), 0, 0))
				var strikes := 0
				for e in hits:
					game.hero_hit(e, float(a.damage[0]) * mult, "q")
					if e.alive():
						game.hero_hit(e, float(a.damage[1]) * mult, "q")
						if strikes < 4:
							strikes += 1
							game.fx.play("strike", e.position, dir, 1.0, Color(0.62, 0.84, 1.0))
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
			game.fx.play("fire_nova", position, dir, float(a.radius))
			for e in hits:
				game.hero_hit(e, float(a.damage) * pw, "w")
				e.burn_dps = float(a.burn) * pw
				e.burn_until = game.play_time + float(a.burn_time)
			nova_discount = hits.size() >= int(a.discount_hits)
		2:
			game.hero_projectile(position + dir * radius, dir, a, pw)
			game.fx.play("muzzle", position + dir * (radius + 0.3) + Vector3(0, 0.6, 0), dir, 1.4, Color("d9b98a"))
		3:
			form_t = float(a.duration)
			cd[0] = minf(cd[0], float(def.abilities[0].ascended.cooldown))
			game.fx.play("ascend", position, dir, float(a.radius))
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


func status_lines() -> Array:
	var st := super.status_lines()
	if form_t > 0.0:
		st.append(tr("Windaufstieg %d s") % ceili(form_t))
	if empowered:
		st.append(tr("Donnerhieb verstärkt"))
	return st


func slot_glow(slot: int) -> bool:
	return slot == 0 and empowered


func bot_act(e, _to: Vector3, d: float, near: int) -> float:
	if near >= 3 and unlocked(3):
		cast(3, e.position)
	if near >= 2:
		cast(1, e.position)
	if d < 3.4 + e.radius:
		cast(0, e.position)
	if d < 14.0 and e.hp > 90.0:
		cast(2, e.position)
	return attack_range()
