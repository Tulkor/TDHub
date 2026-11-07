class_name HdAlly
extends HdBuilding
## Verbündete Einheit aus Ereignissen (Bollwerk Etappe 3): die Goldene Karawane (zieht eine Route ab,
## kämpft nicht) und der befreite Gefangene (folgt dem Helden, schießt auf Gegner). Wie ein Gebäude:
## steht in game.buildings, Gegner greifen sie an (Helden vor Gebäuden), Vesna kann sie heilen.

var kind := "caravan"          ## caravan | fighter
var route: Array = []          ## Vector3, Karawane
var leg := 0
var speed := 2.4
var arrived := false
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO


## d: {name, hp, armor, radius, range, damage, interval, speed}
func setup_ally(g, d: Dictionary, k: String, at: Vector3) -> void:
	game = g
	def = d
	kind = k
	gate_kind = k
	max_hp = float(d.hp)
	hp = max_hp
	armor = float(d.get("armor", 2))
	radius = float(d.get("radius", 0.8))
	speed = float(d.get("speed", 2.4))
	position = at
	if kind == "caravan":
		var wood := HdDev.mat(Color("8a5a2a"), 0.5)
		_meshes.append(HdDev.box(Vector3(1.6, 1.0, 2.4), wood, Vector3(0, 0.9, 0)))
		_meshes.append(HdDev.box(Vector3(1.2, 0.7, 1.4), HdDev.mat(UiTheme.COIN, 0.5, 0.9), Vector3(0, 1.75, -0.2)))
		for sx in [-0.85, 0.85]:
			for sz in [-0.8, 0.8]:
				_meshes.append(HdDev.cyl(0.35, 0.35, 0.15, HdDev.mat(Color("3a2a1a"), 0.5), Vector3(sx, 0.35, sz), 10))
	else:
		_meshes.append(HdDev.cyl(0.5, 0.6, 1.5, HdDev.mat(Color("5aa0e0"), 0.5), Vector3(0, 0.75, 0)))
		_meshes.append(HdDev.sphere(0.35, HdDev.mat(Color("e0c8a0"), 0.5), Vector3(0, 1.75, 0)))
		_meshes.append(HdDev.box(Vector3(0.12, 0.12, 1.3), HdDev.mat(UiTheme.CYAN, 0.5, 1.2), Vector3(0.55, 1.1, 0.4)))
	for m in _meshes:
		add_child(m)


func label() -> String:
	return tr(str(def.get("name", "")))


func height() -> float:
	return 2.4 if kind == "caravan" else 2.0


func step(dt: float) -> void:
	if destroyed:
		return
	if kind == "caravan":
		_step_route(dt)
		return
	# Kämpfer: in der Nähe des Helden bleiben, sonst wie ein Turm schießen
	var h = game.hero
	if h and h.alive():
		var v: Vector3 = h.position - position
		v.y = 0.0
		if v.length() > 5.0:
			game.move_unit(self, v.normalized(), speed, dt)
			_face(v)
	super.step(dt)


func _face(v: Vector3) -> void:
	if v.length_squared() > 0.001:
		rotation.y = atan2(v.x, v.z)


func _step_route(dt: float) -> void:
	if arrived or leg >= route.size():
		arrived = true
		return
	var v: Vector3 = route[leg] - position
	v.y = 0.0
	if v.length() < 1.0:
		leg += 1
		return
	game.move_unit(self, v.normalized(), speed, dt)
	_face(v)
	# Festhängen an Felsen/Torwerken: seitlich versetzen
	_stuck_t += dt
	if _stuck_t >= 1.0:
		if position.distance_to(_stuck_pos) < speed * 0.25:
			var side := Vector3(-v.z, 0, v.x).normalized()
			position += side * 1.5
			game.place_free(self)
		_stuck_t = 0.0
		_stuck_pos = position


func destroy() -> void:
	destroyed = true
	game.events.on_ally_down(self)
	queue_free()
