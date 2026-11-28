extends RefCounted
## Gemeinsame Mesh-Batches für prozedurale Geschosse; keine Knoten pro Schuss.
## Alle Maße relativ zu CELL. Höchstens 12 Segmente/Partikel, Niedrig halbiert Spuren.

const CELL := Board3D.CELL
const WATER := preload("res://assets/shaders/fx_water_jet.gdshader")
var batches := {}
var host: Node3D


func _init(parent: Node3D) -> void:
	host = parent


func begin_frame() -> void:
	for b in batches.values():
		b.items.clear()
		b.node.multimesh.visible_instance_count = 0


static func position_at(from: Vector3, to: Vector3, t: float, arc: float) -> Vector3:
	return from.lerp(to, t) + Vector3.UP * (4.0 * t * (1.0 - t) * arc * CELL)


func draw(s: Dictionary, camera: Basis) -> void:
	var kind := str(s.shot.procedural)
	var t := clampf(float(s.age) / float(s.life), 0.0, 1.0)
	var from: Vector3 = s.from
	var to: Vector3 = s.to
	if from.distance_squared_to(to) < 0.000001:
		return
	var arc := float(s.shot.get("arc", 0.0))
	var pos := position_at(from, to, t, arc)
	var dir := (to - from + Vector3.UP * (4.0 * (1.0 - 2.0 * t) * arc * CELL)).normalized()
	if kind == "water_jet":
		var axis := (to - from).normalized()
		var side := axis.cross(camera.z).normalized()
		_push(kind, Transform3D(Basis(axis * from.distance_to(to), side * CELL * 0.18, axis.cross(side)), (from + to) * 0.5), Color.WHITE)
		return
	if kind == "chain_lightning":
		var previous := from
		var count := 6 if Display.quality == Display.LOW else 12
		var side := dir.cross(Vector3.UP).normalized()
		if side.is_zero_approx():
			side = Vector3.RIGHT
		for i in range(1, count + 1):
			var f := float(i) / count
			var next := from.lerp(to, f)
			if i < count:
				next += (side * sin(i * 17.0 + floor(t * 12.0)) + Vector3.UP * cos(i * 9.0 + floor(t * 12.0))) * CELL * 0.11
			_rod("lightning", previous, next, CELL * 0.018, Color(0.55, 0.85, 1.0, 1.0 - t * 0.5))
			previous = next
		return
	if kind == "arrow":
		_rod("shaft", pos - dir * CELL * 0.24, pos + dir * CELL * 0.13, CELL * 0.018, Color("b99661"))
		_push("tip", Transform3D(_along(dir) * Basis.from_scale(Vector3(0.075, 0.15, 0.075) * CELL), pos + dir * CELL * 0.2), Color("d4dce3"))
		return
	var color := Color("777b83")
	var size := Vector3(0.19, 0.15, 0.16) * CELL
	if kind == "cannonball":
		color = Color("292e38")
		size = Vector3.ONE * CELL * 0.19
	elif kind == "frost_bolt":
		color = Color("a1edff")
		size = Vector3(0.11, 0.32, 0.11) * CELL
	elif kind == "poison_glob":
		color = Color(0.25, 0.85, 0.12, 0.72)
		size = Vector3(0.15, 0.22, 0.15) * CELL
	_push(kind, Transform3D(_along(dir) * Basis.from_scale(size), pos), color)
	var count := 3 if Display.quality == Display.LOW else 6
	for i in count:
		var lag := (i + 1.0) * 0.035
		if t < lag:
			continue
		var p := position_at(from, to, t - lag, arc)
		var c := color
		c.a = (1.0 - float(i) / count) * 0.35
		if kind in ["stone_arc", "cannonball"]:
			c = Color(0.48, 0.45, 0.40, c.a)
		if kind == "poison_glob":
			p.y -= lag * CELL
		if kind == "cannonball":
			p = from + Vector3(sin(i * 4.0), float(i) * 0.3 + t, cos(i * 4.0)) * CELL * 0.12
		var radius := CELL * (0.035 if kind == "frost_bolt" else 0.07)
		_push("trail", Transform3D(Basis().scaled(Vector3.ONE * radius), p), c)


static func _along(dir: Vector3) -> Basis:
	var x := dir.cross(Vector3.FORWARD).normalized()
	if x.is_zero_approx():
		x = dir.cross(Vector3.RIGHT).normalized()
	return Basis(x, dir, x.cross(dir).normalized())


func _rod(key: String, from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var d := to - from
	if d.length_squared() < 0.000001:
		return
	_push(key, Transform3D(_along(d.normalized()) * Basis.from_scale(Vector3(width, d.length(), width)), (from + to) * 0.5), color)


func _push(key: String, transform: Transform3D, color: Color) -> void:
	if not batches.has(key):
		_create_batch(key)
	batches[key].items.append([transform, color])


func _create_batch(key: String) -> void:
	var mesh: Mesh
	if key == "water_jet":
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		mesh = quad
	elif key in ["shaft", "tip", "lightning", "frost_bolt"]:
		var cylinder := CylinderMesh.new()
		cylinder.height = 1.0
		cylinder.top_radius = 0.0 if key in ["tip", "frost_bolt"] else 0.5
		cylinder.bottom_radius = 0.5
		cylinder.radial_segments = 5
		mesh = cylinder
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 6
		sphere.rings = 3
		mesh = sphere
	var node := MultiMeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if key == "water_jet":
		var mat := ShaderMaterial.new()
		mat.shader = WATER
		node.material_override = mat
	else:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if key == "lightning":
			mat.emission_enabled = true
			mat.emission = Color("75caff")
			mat.emission_energy_multiplier = 2.0
		node.material_override = mat
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = true
	node.multimesh.mesh = mesh
	host.add_child(node)
	batches[key] = {"node": node, "items": []}


func flush() -> void:
	for b in batches.values():
		var mm: MultiMesh = b.node.multimesh
		if mm.instance_count < b.items.size():
			mm.instance_count = maxi(b.items.size(), mm.instance_count * 2)
		mm.visible_instance_count = b.items.size()
		for i in b.items.size():
			mm.set_instance_transform(i, b.items[i][0])
			mm.set_instance_color(i, b.items[i][1])
