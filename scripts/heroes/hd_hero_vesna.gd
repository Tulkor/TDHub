class_name HdHeroVesna
extends HdHero
## Oberschwester Vesna, Feldärztin (Hüter, hero-defense-helden.md Nr. 15). Vorbilder Nurse Harrow
## (Deadlock) und Ana (Overwatch). Grundangriff Spritzengewehr: sichtbare Geschosse, heilen eigene
## Gebäude, schaden Gegnern und senken deren Heilung; 8 Schuss, dann Nachladen.
## Einzelspieler: „Mitspieler“ sind Vesna selbst und eigene Gebäude (HdGame.ally_near).
## Ergänzung zum Design: W Betäubungspfeil (im Entwurf war W frei), damit sie unterbrechen kann.

const SHOT := Color("7ad8c8")

var ammo := 8
var reload_t := 0.0
var link: Dictionary = {}     ## Aderlass {enemy, until}
var capsules: Array = []      ## {target, until, node}


func _build_body() -> void:
	var coat := HdDev.mat(Color("3a3e46"), 0.5)
	_body.add_child(HdDev.cyl(0.38, 0.55, 1.6, coat, Vector3(0, 0.8, 0), 10))
	_body.add_child(HdDev.sphere(0.32, HdDev.mat(Color("d8d0c0"), 0.5), Vector3(0, 1.85, 0)))
	# Pestmaske (Schnabel) und Spritzengewehr
	_body.add_child(HdDev.box(Vector3(0.14, 0.14, 0.45), HdDev.mat(Color("e8e0d0"), 0.5), Vector3(0, 1.8, -0.4)))
	_body.add_child(HdDev.box(Vector3(0.14, 0.14, 1.1), HdDev.mat(Color("8a9aa8"), 0.5, 0.2), Vector3(0.45, 1.2, -0.45)))
	_body.add_child(HdDev.cyl(0.11, 0.11, 0.35, HdDev.mat(SHOT, 0.5, 1.0), Vector3(0.45, 1.38, -0.2), 8))


func ready_to_shoot() -> bool:
	return reload_t <= 0.0 and ammo > 0


func _ranged_shot(dir: Vector3, target) -> void:
	if not ready_to_shoot():
		return
	var at: Dictionary = def.attack
	attack_cd = float(at.interval)
	if target:
		dir = target.position - position
		dir.y = 0.0
		dir = dir.normalized()
	var pw := power()
	var dmg := float(at.damage) * pw
	var heal_amt := float(at.heal) * pw * out_mult()
	var on_hit := func(e):
		game.hero_hit(e, dmg, "attack")
		if not e.dead:
			e.heal_cut_until = maxf(e.heal_cut_until, game.play_time + float(at.heal_cut_time))
	var on_ally := func(b) -> bool:
		if b.hp >= b.max_hp:
			return false
		game.heal_target(b, heal_amt)
		return true
	game.shoot(position + dir * (radius + 0.2), dir, float(at.speed), float(at.range), float(at.width), dmg,
		{"color": SHOT, "size": 0.18, "hit": on_hit, "ally": on_ally})
	ammo -= 1
	if ammo <= 0:
		reload_t = float(at.reload)


## Nachladen von Hand nicht nötig: nach 2 s ohne Schuss lädt sie selbst nach.
func _kit_step(dt: float, now: float) -> void:
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			ammo = int(def.attack.mag)
	elif ammo < int(def.attack.mag) and attack_cd < -2.0:
		reload_t = float(def.attack.reload)
	_step_link(dt, now)
	_step_capsules(now)


func _step_link(dt: float, now: float) -> void:
	if link.is_empty():
		return
	var a := ability(0)
	var e = link.enemy
	if dead or not is_instance_valid(e) or e.dead or now >= float(link.until) \
			or Vector2(e.position.x - position.x, e.position.z - position.z).length() > float(a.break_range):
		link = {}
		return
	var amt := float(a.dps) * float(link.pw) * dt
	game.hero_hit(e, amt, "q", true)
	game.heal_target(self, amt * out_mult(), true)
	game.fx.beam(position + Vector3(0, 1.2, 0), e.position + Vector3(0, e.height() * 0.6, 0), Color("c02040"), 0.1)


func _step_capsules(now: float) -> void:
	var a := ability(2)
	for i in range(capsules.size() - 1, -1, -1):
		var c: Dictionary = capsules[i]
		var t = c.target
		var gone: bool = not is_instance_valid(t) or not t.alive()
		if not gone:
			c.node.position = t.position + Vector3(0, (t.height() if t is HdBuilding else 2.0) + 0.9, 0)
		if gone:
			pass
		elif t.hp < t.max_hp * float(a.threshold):
			game.heal_target(t, t.max_hp * float(a.heal))
			t.add_shield(t.max_hp * float(a.shield), float(a.shield_time))
			game.floater(t.position + Vector3(0, 2.8, 0), tr("Kapsel platzt"), UiTheme.HAVE)
		elif now >= float(c.until):
			game.heal_target(t, t.max_hp * float(a.end_heal))
			cd[2] *= float(a.refund)
		else:
			continue
		c.node.queue_free()
		capsules.remove_at(i)


## Mitspieler am Zielpunkt (eigenes Gebäude) oder Vesna selbst.
func _ally_at(at: Vector3, a: Dictionary) -> Node3D:
	var p := clamp_point(at, float(a.range))
	var t = game.ally_near(p, float(a.radius))
	return t if t else self


func _cast(slot: int, a: Dictionary, dir: Vector3, at: Vector3) -> bool:
	var pw := power()
	match slot:
		0:
			var p := clamp_point(at, float(a.range))
			var e = game.nearest_enemy(p, float(a.radius) + 1.5)
			if e == null:
				e = game.nearest_enemy(position, float(a.range))
			if e == null:
				return false
			link = {"enemy": e, "until": game.play_time + float(a.duration), "pw": pw}
		1:
			var dmg := float(a.damage) * pw
			var on_hit := func(e):
				game.hero_hit(e, dmg, "w")
				if not e.dead:
					game.stun(e, float(a.stun))
			game.shoot(position + dir * (radius + 0.2), dir, float(a.speed), float(a.range), float(a.width), dmg,
				{"color": Color("e0d070"), "size": 0.22, "hit": on_hit})
		2:
			var t := _ally_at(at, a)
			for c in capsules:
				if c.target == t:
					return false
			var node := HdDev.sphere(0.25, HdDev.mat(UiTheme.HAVE, 0.5, 1.2))
			game.add_child(node)
			capsules.append({"target": t, "until": game.play_time + float(a.time), "node": node})
			game.fx.tracer(position + Vector3(0, 1.3, 0), t.position + Vector3(0, 1.5, 0), UiTheme.HAVE)
		3:
			var t := _ally_at(at, a)
			game.heal_target(t, t.max_hp * float(a.heal))
			if t == self:
				add_buff("hochdosis", {"dmg_out": float(a.dmg_out), "dmg_in": float(a.dmg_in), "speed": float(a.speed)}, float(a.duration))
			else:
				t.boost_until = game.play_time + float(a.duration)
			game.fx.nova(t.position, 2.0, UiTheme.GOLD)
			game.floater(t.position + Vector3(0, 3.0, 0), tr("Hochdosis"), UiTheme.GOLD)
	return true


func free_kit() -> void:
	for c in capsules:
		if is_instance_valid(c.node):
			c.node.queue_free()
	capsules.clear()
	link = {}


func _on_death() -> void:
	link = {}


func status_lines() -> Array:
	var st := super.status_lines()
	if reload_t > 0.0:
		st.append(tr("Lädt nach"))
	else:
		st.append(tr("Schuss %d / %d") % [ammo, int(def.attack.mag)])
	if has_buff("hochdosis"):
		st.append(tr("Hochdosis %d s") % ceili(float(buffs.hochdosis.until) - game.play_time))
	if not link.is_empty():
		st.append(tr("Aderlass"))
	return st


func bot_act(e, _to: Vector3, d: float, near: int) -> float:
	if e.casting() and d < 15.0:
		cast(1, e.position)
	if d < 12.0 and (e.rank != "normal" or hp < max_hp * 0.8):
		cast(0, e.position)
	if hp < max_hp * 0.6:
		cast(2, position)
	if unlocked(3) and (near >= 3 or e.rank == "boss" or hp < max_hp * 0.4):
		cast(3, position)
	return 9.0
