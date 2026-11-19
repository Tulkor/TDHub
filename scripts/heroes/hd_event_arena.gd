class_name HdEventArena
extends RefCounted
## Getrennter Ereignisraum. Die gesamte Wellen-Simulation einschließlich ihrer Uhr bleibt eingefroren.

var game
var active := false
var center := Vector3(-320, 0, 0)
var returning := Vector3.ZERO
var elapsed := 0.0
var timeout := 180.0
var frozen_enemies: Array = []
var frozen_buildings: Array = []
var saved_hazards := {}
var visibility := {}
var ground: Node3D
var saved_kit := {}
var return_positions := {}
var script_states := {}
var saved_script_actions: Array = []
var saved_telegraphs := {}
var kit_nodes := {}


func _init(g) -> void:
	game = g


func bounds() -> Array:
	return [center.x - 42, -42, center.x + 42, 42]


func point(_where := "feld") -> Vector3:
	return center + Vector3(game.rng.randf_range(-15, 15), 0, game.rng.randf_range(-15, 15))


func route() -> HdRoad:
	return HdRoad.new({"id":"ereignis", "name":"Ereignisroute", "points":[[center.x - 32, -20], [center.x, 0], [center.x + 32, 20]]}, {})


func enter() -> void:
	if active:
		return
	active = true
	elapsed = 0.0
	returning = game.hero.position
	frozen_enemies = game.enemies.duplicate()
	frozen_buildings = game.buildings.duplicate()
	visibility.clear()
	for actor in frozen_enemies + frozen_buildings:
		visibility[actor] = actor.visible
		actor.hide()
	saved_hazards = {"projectiles":game.projectiles, "pools":game.pools, "blasts":game.blasts}
	for kind in saved_hazards:
		for hazard in saved_hazards[kind]:
			var node = hazard.get("node", hazard.get("tele"))
			if is_instance_valid(node):
				node.hide()
	game.projectiles = []
	game.pools = []
	game.blasts = []
	saved_script_actions = game._script_actions
	game._script_actions = []
	for node in game.get_children():
		if node is HdTelegraph:
			saved_telegraphs[node] = node.visible
			node.hide()
	for actor: HdHero in game.playing_heroes():
		return_positions[actor] = actor.position
		script_states[actor] = actor.get_meta(EffectScript.STATE) if actor.has_meta(EffectScript.STATE) else null
		if actor.has_meta(EffectScript.STATE):
			actor.remove_meta(EffectScript.STATE)
		var kit := {}
		var keys: Array = ["bombs", "banner"] if actor is HdHeroUnrat else (["capsules", "link"] if actor is HdHeroVesna else (["gadgets"] if actor is HdHeroZix else []))
		if actor is HdHeroRoster:
			keys = ["fields", "pending", "marks", "servants"]
		for key in keys:
			kit[key] = actor.get(key)
			_kit_visuals(kit[key], true)
			actor.set(key, [] if kit[key] is Array else {})
		saved_kit[actor] = kit
		actor.position = center + Vector3(game.hero_slot(actor) * 1.5, 0, 0)
		actor.order = {}
		actor.move_dir = Vector3.ZERO
		actor.attack_held = false
	ensure_ground()
	game.teleport_hero(center)
	game.hero.attack_held = false
	game.hero.move_dir = Vector3.ZERO
	game.changed.emit()


func frozen(actor) -> bool:
	return active and (visibility.has(actor))


func step(dt: float) -> void:
	if not active:
		return
	elapsed += dt
	var rescued: bool = str(game.events.active.get("id", "")) == "gefangener" and game.events.active.has("ally")
	if game.playing_heroes().all(func(h): return not h.alive()) or elapsed >= timeout:
		game.events.kinds.finish(false, tr("Ereignis fehlgeschlagen"))
		game.events.choice = {}
		if not rescued:
			game.events._end_prisoner("")
		game.shop.merchant = []
		game.events.active = {}
		leave()
	elif rescued or not game.events.busy():
		leave()


func leave() -> void:
	if not active:
		return
	for actor in saved_kit:
		if actor is HdHeroRoster:
			actor.free_kit()
		if actor is HdHeroZix:
			for gadget in actor.gadgets.duplicate():
				actor._remove_gadget(gadget)
		for key in saved_kit[actor]:
			_kit_visuals(actor.get(key), false)
			_shift_kit(saved_kit[actor][key])
			actor.set(key, saved_kit[actor][key])
		actor.skills.refresh_constructs()
	for node in kit_nodes:
		if is_instance_valid(node):
			node.visible = kit_nodes[node]
	for actor in script_states:
		if script_states[actor] != null:
			actor.set_meta(EffectScript.STATE, script_states[actor])
		elif actor.has_meta(EffectScript.STATE):
			actor.remove_meta(EffectScript.STATE)
	script_states.clear()
	for action in game._script_actions:
		if is_instance_valid(action.caster):
			action.caster.queue_free()
	game._script_actions = saved_script_actions
	saved_script_actions = []
	for node in saved_telegraphs:
		if is_instance_valid(node):
			node.visible = saved_telegraphs[node]
	saved_telegraphs.clear()
	saved_kit.clear()
	kit_nodes.clear()
	game.hero.skills.refresh_constructs()
	for enemy in game.enemies.duplicate():
		if not visibility.has(enemy) and not enemy.dead:
			game._remove(enemy)
	for building in game.buildings.duplicate():
		if not visibility.has(building):
			building.position = returning + Vector3(2, 0, 0)
	for actor in frozen_enemies + frozen_buildings:
		if not is_instance_valid(actor):
			continue
		actor.visible = visibility[actor]
		for key in ["script_until", "root_until"]:
			if actor.has_meta(key):
				actor.set_meta(key, float(actor.get_meta(key)) + elapsed)
		if actor is HdGadget:
			actor.placed += elapsed
		if actor is HdAlly and actor.until_time > 0:
			actor.until_time += elapsed
		if actor is HdRosterConstruct:
			actor.until_time += elapsed
		if actor is HdBuilding:
			actor.boost_until += elapsed
			actor.shield_until += elapsed
			if actor.capsule.has("until"):
				actor.capsule.until += elapsed
		if actor is HdEnemy:
			actor.cc.shift_time(elapsed)
			for key in ["burn_until", "rats_until", "plague_until", "heal_cut_until", "taunt_until", "gap_until"]:
				actor.set(key, float(actor.get(key)) + elapsed)
			for key in actor.ab_ready:
				actor.ab_ready[key] += elapsed
	for kind in saved_hazards:
		for hazard in game.get(kind):
			var node = hazard.get("node", hazard.get("tele"))
			if is_instance_valid(node):
				node.queue_free()
		for hazard in saved_hazards[kind]:
			if hazard.has("until"):
				hazard.until += elapsed
			var node = hazard.get("node", hazard.get("tele"))
			if is_instance_valid(node):
				node.show()
		game.set(kind, saved_hazards[kind])
	active = false
	visibility.clear()
	frozen_enemies.clear()
	frozen_buildings.clear()
	saved_hazards.clear()
	for actor in return_positions:
		actor.position = return_positions[actor]
		game._resolve(actor)
	return_positions.clear()
	game.teleport_hero(game.hero.position)
	game.changed.emit()


func _kit_visuals(value, saving: bool) -> void:
	if value is Array:
		for item in value:
			_kit_visuals(item, saving)
	elif value is Dictionary:
		for key in ["tele", "node", "pole"]:
			var node = value.get(key)
			if is_instance_valid(node):
				if saving:
					kit_nodes[node] = node.visible
					node.hide()
				else:
					node.queue_free()


func _shift_kit(value) -> void:
	if value is Array:
		for item in value:
			_shift_kit(item)
	elif value is Dictionary:
		for key in ["until", "next"]:
			if value.has(key):
				value[key] += elapsed
		for key in ["at", "start"]:
			if value.get(key) is float:
				value[key] += elapsed
		for nested in value.values():
			if nested is Dictionary or nested is Array:
				_shift_kit(nested)


func ensure_ground() -> void:
	if not is_instance_valid(ground):
		ground = Node3D.new()
		ground.name = "Ereignisgebiet"
		game.add_child(ground)
		ground.add_child(HdDev.box(Vector3(84, 0.5, 84), HdDev.mat(Color("293b45"), 0.8), center - Vector3.UP * 0.3))
		for side in [-1, 1]:
			ground.add_child(HdDev.box(Vector3(85, 3, 1), HdDev.mat(Color("766343"), 0.8), center + Vector3(0, 1, side * 42)))
			ground.add_child(HdDev.box(Vector3(1, 3, 85), HdDev.mat(Color("766343"), 0.8), center + Vector3(side * 42, 1, 0)))
