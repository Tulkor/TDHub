class_name HdEnemyGuide
extends RefCounted
## Lokaler Wegweiser: nächster lebender Gegner, solange er außerhalb der Kamera liegt.
## Suche gedrosselt; Position/Richtung und Sichtbarkeit folgen der Kamera jeden Frame.

const SEARCH_INTERVAL := 0.15
var game
var target: HdEnemy
var _remaining := 0.0
var _phase := 0.0


func _init(owner_game) -> void:
	game = owner_game


func step(dt: float) -> void:
	_phase += dt
	_remaining -= dt
	if _remaining <= 0.0:
		refresh_target()
		_remaining = SEARCH_INTERVAL


func _eligible(enemy) -> bool:
	return is_instance_valid(enemy) and not enemy.dead and enemy.is_visible_in_tree() and not game.event_arena.frozen(enemy)


func refresh_target() -> void:
	target = null
	if not is_instance_valid(game.hero) or game.hero.dead or game.state != "play":
		return
	var best := INF
	for enemy in game.enemies:
		if not _eligible(enemy):
			continue
		var distance: float = game.hero.position.distance_squared_to(enemy.position)
		if distance < best:
			best = distance
			target = enemy


func indicated_enemy() -> HdEnemy:
	if not _eligible(target) or not is_instance_valid(game.hero) or game.hero.dead or game.state != "play" or game.camera == null:
		return null
	# Körpermitte, Kopf oder Füße sichtbar: der Hinweis wird nicht mehr gebraucht.
	for elevation in [0.1, target.height() * 0.5, target.height()]:
		if game.camera.is_position_in_frustum(target.position + Vector3.UP * elevation):
			return null
	return target


func draw_on(canvas: Control) -> void:
	var enemy := indicated_enemy()
	if enemy == null:
		return
	var camera: Camera3D = game.camera
	var anchor: Vector3 = game.hero.position + Vector3.UP * 1.7
	if not camera.is_position_in_frustum(anchor):
		return
	var delta: Vector3 = enemy.position - game.hero.position
	delta.y = 0.0
	# Kamerabasis statt Projektion des entfernten Ziels: bleibt auch hinter der Kamera korrekt.
	var direction := Vector2(delta.dot(camera.global_basis.x), -delta.dot(camera.global_basis.y)).normalized()
	if direction.is_zero_approx():
		return
	var screen_anchor := camera.unproject_position(anchor)
	var beside := camera.unproject_position(anchor + camera.global_basis.x * (game.hero.radius + 0.55))
	var clearance := clampf(screen_anchor.distance_to(beside), 36.0, 120.0)
	var center := screen_anchor + direction * clearance + Vector2(0, sin(_phase * 3.5) * 2.5)
	var points := PackedVector2Array()
	for point in [Vector2(10, 0), Vector2(-7, -6), Vector2(-3, 0), Vector2(-7, 6)]:
		points.append(center + point.rotated(direction.angle()))
	canvas.draw_colored_polygon(points, Color("ec3546"))
	points.append(points[0])
	canvas.draw_polyline(points, Color("390e19"), 2.0, true)
