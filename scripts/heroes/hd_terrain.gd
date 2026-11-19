class_name HdTerrain
extends RefCounted
## Bollwerk-Oberflächen mit Weltkoordinaten: Fels, Basaltvorplätze, Baumerde.
static var _materials := {}


## Dieselben Integer-Masken wie hd_ground_blend.gdshaderinc, für das echte Höhenfeld.
static func _ground_hash(grid: Vector2i) -> float:
	var value := ((grid.x * 1597334677) ^ (grid.y * 3812015801)) & 0xffffffff
	value = value ^ (value >> 16)
	# 16-Bit-Teile vermeiden einen Überlauf beim uint32-Produkt im int64-Skript.
	value = ((value & 65535) * 2246822519 + ((value >> 16) * (2246822519 & 65535) << 16)) & 0xffffffff
	value = value ^ (value >> 13)
	return float(value & 16777215) / 16777216.0


static func _ground_noise(at: Vector2) -> float:
	var grid := Vector2i(floori(at.x), floori(at.y))
	var f := at - Vector2(grid)
	f = f * f * (Vector2.ONE * 3.0 - f * 2.0)
	return lerpf(lerpf(_ground_hash(grid), _ground_hash(grid + Vector2i.RIGHT), f.x),
		lerpf(_ground_hash(grid + Vector2i.DOWN), _ground_hash(grid + Vector2i.ONE), f.x), f.y)


static func material_masks(at: Vector2) -> Vector3:
	var warp := Vector2(_ground_noise(at * .065 + Vector2(17,31)), _ground_noise(at * .073 + Vector2(43,7))) - Vector2.ONE * .5
	var area := at + warp * 12.0
	return Vector3(smoothstep(.36,.61,_ground_noise(area * .115 + Vector2(11,37))),
		smoothstep(.35,.65,_ground_noise(area * .18 + Vector2(29,3))),
		smoothstep(.38,.72,_ground_noise(area * .065 + Vector2(5,83))))


static func plaza_radius(game) -> float:
	return float(game.cfg.arena.get("fortress_plaza_radius",14.0))


## Dasselbe weltkoordinatenbasierte Pflaster wie auf den Lanes, unter deren Oberfläche und Basalt.
static func fortress_plaza(game, parent: Node3D, paving_material: Material) -> MeshInstance3D:
	var radius := plaza_radius(game)
	var disc := CylinderMesh.new()
	disc.top_radius=radius
	disc.bottom_radius=radius
	disc.height=.002
	disc.radial_segments=128
	disc.cap_bottom=false
	var node := MeshInstance3D.new()
	node.name="FortressLightPaving"
	node.mesh=disc
	node.material_override=paving_material
	node.position=game.fortress_pos+Vector3(0,.003,0)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


static func material(kind: String) -> ShaderMaterial:
	if _materials.has(kind):
		return _materials[kind]
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/hd_terrain.gdshader")
	m.set_shader_parameter("surface", {"rock":0, "basalt":1, "soil":2}[kind])
	m.set_shader_parameter("albedo_map", preload("res://assets/textures/rock/rock_face_03_diff_1k.jpg"))
	m.set_shader_parameter("normal_map", preload("res://assets/textures/rock/rock_face_03_nor_gl_1k.jpg"))
	m.set_shader_parameter("rough_map", preload("res://assets/textures/rock/rock_face_03_rough_1k.jpg"))
	m.set_shader_parameter("soil_map", preload("res://assets/textures/ground/dirt.jpg"))
	m.set_shader_parameter("soil_normal", preload("res://assets/textures/ground/dirt_normal.jpg"))
	m.set_shader_parameter("soil_specular", preload("res://assets/textures/ground/dirt_specular.png"))
	m.set_shader_parameter("scree_map", preload("res://assets/textures/ground/gravel.jpg"))
	m.set_shader_parameter("scree_normal", preload("res://assets/textures/ground/gravel_normal.jpg"))
	m.set_shader_parameter("scree_specular", preload("res://assets/textures/ground/gravel_specular.png"))
	_materials[kind] = m
	return m


static func patch(parent: Node3D, at: Vector3, radius: float, kind := "basalt") -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	mesh.mesh = plane
	mesh.material_override = material(kind)
	mesh.position = at + Vector3(0, 0.006 if kind == "basalt" else 0.043, 0)
	mesh.name = "Basaltvorplatz" if kind == "basalt" else "Baumerde"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


static func soil_on_slope(parent: Node3D, at: Vector3, radius: float, height: Callable) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var resolution := 8
	for z in resolution:
		for x in resolution:
			for offset in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var uv := Vector2(x + offset.x, z + offset.y) / resolution
				var p := at + Vector3((uv.x-.5)*radius*2,0,(uv.y-.5)*radius*2)
				p.y = float(height.call(p)) + .045
				surface.set_uv(uv)
				surface.add_vertex(p)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = "Baumerde"
	node.mesh = surface.commit()
	node.material_override = material("soil")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
