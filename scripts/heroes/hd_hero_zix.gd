class_name HdHeroZix
extends HdHero
## Zix Funkenkurbel, Mechagoblin (Spezialist, hero-defense-helden.md Nr. 16). Baukasten: 3 von 10
## Gebäuden (HdGame.zix_kit) liegen auf Q W E, R Überspannung verstärkt alle. Passiv
## Schraubenschlüssel: die Funkenpistole repariert eigene Gebäude. Gebäude: HdGadget.

const PLACE_RANGE := 9.0

var over_t := 0.0
var gadgets: Array = []       ## eigene HdGadget, älteste zuerst


func _build_body() -> void:
	var frame := HdDev.mat(Color("7a6a4a"), 0.5)
	_body.add_child(HdDev.box(Vector3(1.2, 0.5, 1.0), frame, Vector3(0, 0.45, 0)))
	for side in [-1.0, 1.0]:
		_body.add_child(HdDev.cyl(0.25, 0.25, 0.2, HdDev.mat(Color("3a3a3e"), 0.5), Vector3(0.62 * side, 0.25, 0), 10))
	_body.add_child(HdDev.sphere(0.36, HdDev.mat(Color("7ab04a"), 0.5), Vector3(0, 1.05, 0)))
	_body.add_child(HdDev.box(Vector3(0.9, 0.1, 0.12), HdDev.mat(Color("7ab04a"), 0.5), Vector3(0, 1.15, 0)))
	_body.add_child(HdDev.box(Vector3(0.12, 0.12, 1.2), HdDev.mat(Color("ffb040"), 0.5, 0.6), Vector3(0.5, 1.2, -0.3)))


func ultimate() -> Dictionary:
	return skills.resolve(def.abilities[0], 3, _rank_preview)


func kit() -> Array:
	return game.zix_kit


func ability(slot: int) -> Dictionary:
	if slot == 3:
		return ultimate()
	var id: String = kit()[slot] if slot < kit().size() else ""
	var g: Dictionary = game.gadget_defs.get(id, {})
	var a := {"kind": "gadget", "gadget": id, "at_point": true, "range": PLACE_RANGE,
		"radius": maxf(1.0, float(g.get("area", g.get("radius", 1.0)))),
		"name": g.get("name", "?"), "cooldown": g.get("cooldown", 8.0), "mana": g.get("mana", 40)}
	a.summary = g.get("summary", g.get("desc", ""))
	a.tags = g.get("tags", ["spell", "construct", "minion"])
	a.gadget_stats = g.duplicate(true)
	a.desc = "%s %s\n%s %s\n%s" % [tr(str(g.get("role", ""))) + ":", tr(str(g.get("desc", ""))),
		tr("Überspannung:"), tr(str(g.get("over", ""))), tr("höchstens %d") % int(g.get("max", 1))]
	if id == "elektrozaun":
		a.preview = "line"
		a.at_point = false
		a.width = float(g.width)
	return skills.resolve(a, slot, _rank_preview)


func count(id: String) -> int:
	var n := 0
	for g in gadgets:
		if g.kind == id:
			n += 1
	return n


func kit_changed() -> void:
	for i in 3:
		cd[i] = 0.0


func _cast(slot: int, a: Dictionary, dir: Vector3, at: Vector3) -> bool:
	if slot == 3:
		over_t = float(a.duration)
		for g in gadgets:
			g.hp = g.max_hp
		game.fx.play("overcharge", position, dir, 6.0, UiTheme.CYAN)
		for g in gadgets:
			if is_instance_valid(g) and not g.destroyed and g.position.distance_to(position) < 30.0:
				game.fx.bolt(position + Vector3(0, 1.4, 0), g.position + Vector3(0, 1.0, 0), UiTheme.CYAN)
		game.floater(position + Vector3(0, 2.6, 0), tr("Überspannung!"), UiTheme.CYAN)
		return true
	var id := str(a.gadget)
	var gd: Dictionary = a.get("gadget_stats", game.gadget_defs.get(id, {}))
	if gd.is_empty():
		return false
	_prune()
	if count(id) >= int(gd.max):
		for g in gadgets:
			if g.kind == id:
				_remove_gadget(g)
				break
	var p := clamp_point(at, float(a.range))
	if id == "elektrozaun":
		p = clamp_point(position + dir * minf(position.distance_to(at), 5.0), PLACE_RANGE)
	var g := HdGadget.new()
	g.setup_gadget(game, id, gd, p, self, dir)
	game.add_child(g)
	if id != "elektrozaun":
		game.place_free(g)
	game.buildings.append(g)
	gadgets.append(g)
	game.fx.tracer(position + Vector3(0, 1.2, 0), g.position + Vector3(0, 0.5, 0), Color("ffb040"))
	game.fx.play("build", g.position, dir, 1.0, Color("ffb040"))
	return true


func _remove_gadget(g) -> void:
	gadgets.erase(g)
	game.buildings.erase(g)
	if is_instance_valid(g):
		g.destroy()


func _prune() -> void:
	gadgets = gadgets.filter(func(g): return is_instance_valid(g) and not g.destroyed)


func _kit_step(dt: float, _now: float) -> void:
	if over_t > 0.0:
		if alive():
			game.fx.hold("over:%d" % get_instance_id(), "aura", position, 1.2, UiTheme.CYAN)
		over_t -= dt
		if over_t <= 0.0:
			_prune()
			for g in gadgets.duplicate():
				g.over_end()
	_prune()
	# Maus-Modus und Bot: ohne Gegner in Reichweite selbst reparieren
	if dead or attack_cd > 0.0 or attack_held or not (auto_attack or game.bot):
		return
	if not order.is_empty() and order.get("kind", "") != "":
		return
	if game.nearest_enemy(position, attack_range()) != null:
		return
	var g = _damaged_gadget(position, attack_range())
	if g:
		_repair(g)


func _damaged_gadget(at: Vector3, r: float):
	var best = null
	var best_q := 0.999
	for g in gadgets:
		if g.destroyed or Vector2(g.position.x - at.x, g.position.z - at.z).length() > r + g.radius:
			continue
		var q: float = g.hp / g.max_hp
		if q < best_q:
			best_q = q
			best = g
	return best


func _repair(g) -> void:
	attack_cd = attack_interval()
	_face(g.position - position)
	game.fx.tracer(position + Vector3(0, 1.2, 0), g.position + Vector3(0, 0.8, 0), Color("ffd070"))
	game.fx.play("heal", g.position, Vector3.FORWARD, 1.0, Color("ffd070"))
	game.heal_target(g, g.max_hp * float(def.attack.repair))


## Funkenpistole: zielt sie (WASD) auf ein beschädigtes eigenes Gebäude, repariert sie es.
func _ranged_shot(dir: Vector3, target) -> void:
	if target == null:
		for g in gadgets:
			if g.destroyed or g.hp >= g.max_hp:
				continue
			if HdTelegraph.in_shape(HdTelegraph.CONE, position, dir, attack_range() + radius, 0, 25.0, 0, 0, g.position, g.radius):
				_repair(g)
				return
	attack_cd = attack_interval()
	var e = target if target else game.enemy_in_arc(position, dir, attack_range() + radius, 20.0)
	var endpoint := Vector3.INF
	if e:
		endpoint = e.position + Vector3.UP * e.height() * 0.6
	shock_fx(game.fx, position, dir, endpoint)
	if e:
		game.hero_hit(e, float(def.attack.damage) * power(), "attack")
		on_hit(e)


## Gleiche Entladung für Spiel und Animationsvorschau; bestehende FX-Budgets/Netzwerkereignisse.
static func shock_fx(fx: HdFx, at: Vector3, direction: Vector3, endpoint := Vector3.INF) -> void:
	var dir := Vector3(direction.x, 0, direction.z).normalized()
	if dir.is_zero_approx():
		dir = Vector3.FORWARD
	var side := Vector3(-dir.z, 0, dir.x)
	var emitter := at + dir * 0.55 + Vector3.UP * 1.15
	var front := at + dir * 1.4 + Vector3.UP * 1.15
	var color := Color("b6edff")
	fx.bolt(emitter, front, color)
	for sign_value in [-1.0, 1.0]:
		fx.bolt(front, front + dir * 0.5 + side * sign_value * 0.55 + Vector3.UP * sign_value * 0.3, color)
	fx.impact(front, "lightning", dir)
	if endpoint.is_finite() and endpoint.distance_to(front) > 0.3:
		fx.bolt(front, endpoint, color)


func free_kit() -> void:
	for g in gadgets.duplicate():
		_remove_gadget(g)


func status_lines() -> Array:
	var st := super.status_lines()
	if over_t > 0.0:
		st.append(tr("Überspannung %d s") % ceili(over_t))
	_prune()
	st.append(tr("Gebäude %d") % gadgets.size())
	return st


func slot_glow(slot: int) -> bool:
	return over_t > 0.0 and slot < 3


func bot_act(e, to: Vector3, d: float, near: int) -> float:
	# Gebäude zwischen Zix und Gegner stellen
	var front: Vector3 = position + to.normalized() * minf(d * 0.5, 5.0)
	for i in 3:
		var id: String = kit()[i]
		if count(id) < int(game.gadget_defs[id].max) or cd[i] <= 0.0 and mana > max_mana * 0.6:
			if id in ["sanitaetsmast", "heilsprinkler", "schildkuppel"]:
				cast(i, position)
			else:
				cast(i, front)
	if unlocked(3) and (near >= 3 or e.rank != "normal") and gadgets.size() >= 2:
		cast(3, position)
	return attack_range() - 1.0
