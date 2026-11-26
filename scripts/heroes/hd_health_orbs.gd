extends Node3D
## Host entscheidet über Drops und Aufnahme; Clients zeigen nur replizierte Orbs.
## Keine eigenen Lichter: Emission und budgetierter Heil-FX halten größere Kämpfe günstig.
const COLOR := Color("57ff23")
var game
var orbs: Dictionary = {}
var fields: Dictionary = {}
var serial := 0


func setup(owner_game) -> void:
	game = owner_game
	name = "HealthOrbs"
	game.add_child(self)


func drop_for(enemy: HdEnemy) -> void:
	if enemy.gold_free or (game.coop and not game.coop.host):
		return
	var config: Dictionary = game.cfg.get("health_orbs", {})
	var chance := float(config.get(enemy.rank, 0.12))
	if game.rng.randf() >= chance:
		return
	spawn(enemy.position)


func spawn(at: Vector3) -> void:
	if game.coop and not game.coop.host:
		return
	var config: Dictionary = game.cfg.get("health_orbs", {})
	var limit := maxi(1, int(config.get("limit", 32)))
	while orbs.size() >= limit:
		_remove(int(orbs.keys()[0]))
	serial += 1
	_create(serial, Vector3(at.x, 0, at.z), game.play_time + float(config.get("lifetime", 30.0)))


func _create(id: int, at: Vector3, expires: float) -> void:
	var node := Node3D.new()
	add_child(node)
	var glow := HdGothic.glow(COLOR, 1.5)
	node.add_child(HdDev.sphere(.23, glow))
	var hoop := HdFxParts.halo(.42, COLOR)
	hoop.rotation.x = PI * .5
	node.add_child(hoop)
	# Ein kleines Heilkreuz im eisernen Reliquiar ist auch ohne Farbe erkennbar.
	var iron := HdGothic.iron()
	node.add_child(HdDev.box(Vector3(.12, .76, .12), iron))
	node.add_child(HdDev.box(Vector3(.52, .12, .12), iron, Vector3(0, .1, 0)))
	orbs[id] = {"pos":at, "expires":expires, "node":node}
	node.position = at + Vector3.UP * .65


func _remove(id: int) -> void:
	orbs[id].node.queue_free()
	orbs.erase(id)


func step(now: float) -> void:
	if game.coop and not game.coop.host:
		return
	for id in orbs.keys():
		var orb: Dictionary = orbs[id]
		if now >= float(orb.expires):
			_remove(id)
			continue
		var heal_radius := float(game.cfg.get("health_orbs", {}).get("heal_radius", 5.0))
		var activated := false
		var targets: Array[HdHero] = []
		for actor: HdHero in game.playing_heroes():
			if not actor.alive():
				continue
			var delta: Vector3 = actor.position - orb.pos
			delta.y = 0
			var distance := delta.length()
			if distance <= 1.2 + actor.radius:
				activated = true
			if actor.hp < actor.max_hp and distance <= heal_radius + actor.radius:
				targets.append(actor)
		if activated and not targets.is_empty():
			_create_field(id, orb.pos, now, heal_radius)
			game.fx.play("heal", orb.pos, Vector3.UP, 1.0, COLOR)
			_remove(id)
	for id in fields.keys():
		var field: Dictionary = fields[id]
		while int(field.tick) <= 3 and now + .00001 >= float(field.started) + int(field.tick):
			for actor: HdHero in game.playing_heroes():
				if not actor.alive():
					continue
				var delta: Vector3 = actor.position - field.pos
				delta.y = 0
				if delta.length() <= float(field.radius) + actor.radius:
					actor.heal(actor.max_hp * .05)
			field.tick += 1
		if now >= float(field.started) + 3.0:
			field.node.queue_free()
			fields.erase(id)


func _create_field(id: int, at: Vector3, started: float, radius: float) -> void:
	var node := HdFxParts.heal_area(radius)
	node.position = at + Vector3.UP * .12
	add_child(node)
	game.conform_ground_effect(node)
	fields[id] = {"pos":at, "started":started, "radius":radius, "tick":1, "node":node}


func field_snapshot() -> Array:
	var rows: Array = []
	for id in fields:
		var field: Dictionary = fields[id]
		rows.append({"id":id, "pos":field.pos, "started":field.started, "radius":field.radius})
	return rows


func snapshot() -> Array:
	var rows: Array = []
	for id in orbs:
		rows.append({"id":id, "pos":orbs[id].pos, "expires":orbs[id].expires})
	return rows


func apply_state(rows: Array, field_rows: Array = []) -> void:
	var keep := {}
	for row in rows:
		var id := int(row.id)
		keep[id] = true
		if not orbs.has(id):
			_create(id, row.pos, float(row.expires))
	for id in orbs.keys():
		if not keep.has(id):
			_remove(id)
	keep.clear()
	for row in field_rows:
		var id := int(row.id)
		keep[id] = true
		if not fields.has(id):
			_create_field(id, row.pos, float(row.started), float(row.radius))
	for id in fields.keys():
		if not keep.has(id):
			fields[id].node.queue_free()
			fields.erase(id)


func _process(_dt: float) -> void:
	for field in fields.values():
		var age := maxf(0, game.play_time - float(field.started))
		field.node.material_override.set_shader_parameter("progress", clampf(age / .35, 0, 1))
		field.node.material_override.set_shader_parameter("fade", clampf((3.0 - age) / .25, 0, 1))
	for id in orbs:
		var orb: Dictionary = orbs[id]
		var height := 0.0
		if game is HdGame and not game.final.active and not game.event_arena.active:
			height = HdArenaMountains.ground_height(game.arena_layout,orb.pos)
		orb.node.position = orb.pos + Vector3.UP * (height + .65 + sin(game.play_time * 3 + id) * .12)
		orb.node.rotation.y = game.play_time * .8 + id
		orb.node.scale = Vector3.ONE * (.85 + .15 * sin(game.play_time * 8)) if float(orb.expires) - game.play_time < 4 else Vector3.ONE
