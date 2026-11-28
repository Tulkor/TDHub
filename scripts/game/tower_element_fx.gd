extends RefCounted
## Dauerhafte eeve-Effekte: Shaderanimation statt Prozess je Tower, keine Zusatzlichter.
## Maximale Höhe 1,9 CELL; acht Partikel auf Hoch, vier auf Niedrig.

const SHADER := preload("res://assets/shaders/tower_element.gdshader")
const KINDS := {"storm_cloud": 0, "radiating_cloud": 1, "tornado": 2, "natural_maelstrom": 3, "ball_lightning": 4, "geyser": 5, "small_geyser": 5, "lightning_field": 6}


class LiveParticles extends GPUParticles3D:
	func _ready() -> void:
		Display.quality_changed.connect(_quality)
		_quality()

	func _quality() -> void:
		amount = 4 if Display.quality == Display.LOW else 8


static func make(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "ElementEffekt"
	if not KINDS.has(id):
		return root
	var kind: int = KINDS[id]
	var cell := Board3D.CELL
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("kind", kind)
	var colors := [Color("536b89"), Color("fff2aa"), Color("839b94"), Color("6ecf8b"), Color("79cfff"), Color("64b9ee"), Color("70bbff")]
	mat.set_shader_parameter("tint", colors[kind])
	if kind <= 1:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(1.5, 0.85) * cell
		mat.set_shader_parameter("phase", 0.5)
		# Kreuzweise Billboards: Volumen bleibt aus jeder Spielkamera sichtbar.
		for i in 3:
			var cloud := _mesh(root, mesh, mat)
			cloud.position = Vector3(sin(i * 2.1) * 0.2, 1.1 + i * 0.08, cos(i * 2.1) * 0.15) * cell
			cloud.rotation.y = i * PI / 3.0
	elif kind in [3, 6]:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE * cell * 1.8
		_mesh(root, plane, mat).position.y = cell * 0.05
	elif kind == 4:
		var sphere := SphereMesh.new()
		sphere.radius = cell * 0.38
		sphere.height = cell * 0.76
		sphere.radial_segments = 12
		sphere.rings = 6
		_mesh(root, sphere, mat).position.y = cell * 0.9
	else:
		var cylinder := CylinderMesh.new()
		cylinder.height = cell * (1.7 if kind == 2 else 1.6)
		cylinder.top_radius = cell * (0.65 if kind == 2 else 0.18)
		cylinder.bottom_radius = cell * (0.12 if kind == 2 else 0.28)
		cylinder.radial_segments = 16
		cylinder.rings = 6
		var node := _mesh(root, cylinder, mat)
		node.position.y = cylinder.height * 0.5
	if kind in [2, 5]:
		_particles(root, kind, colors[kind])
	if id == "small_geyser":
		root.scale *= 0.65
	return root


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func _particles(parent: Node3D, kind: int, color: Color) -> void:
	var node := LiveParticles.new()
	node.amount = 4 if Display.quality == Display.LOW else 8
	node.lifetime = 1.0
	node.visibility_aabb = AABB(Vector3(-1, 0, -1) * Board3D.CELL, Vector3(2, 1.9, 2) * Board3D.CELL)
	var mesh := SphereMesh.new()
	mesh.radius = Board3D.CELL * 0.025
	mesh.height = mesh.radius * 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	node.draw_pass_1 = mesh
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = Board3D.CELL * 0.3
	process.emission_ring_inner_radius = Board3D.CELL * 0.1
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = Board3D.CELL * 0.5
	process.initial_velocity_max = Board3D.CELL * 1.2
	process.gravity = Vector3.ZERO
	process.orbit_velocity_min = 0.4 if kind == 2 else 0.0
	process.orbit_velocity_max = process.orbit_velocity_min
	node.process_material = process
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
