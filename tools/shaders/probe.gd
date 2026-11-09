extends Node3D
## Deterministische Shader-Vitrine. Rendert alle Qualitätsstufen und meldet Draw Calls/Bildzeit.
## godot --path . res://tools/shaders/probe.tscn
## Ausgabe: .godot/shader-probe-0.png bis -2.png; Exit 0 ersetzt keine Sichtprüfung.


func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("18212e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.0
	add_child(camera)
	camera.position = Vector3(0, 14, 13)
	camera.look_at(Vector3(0, 0, -0.5))
	camera.current = true
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(21, 13)
	_mesh(floor_mesh, Board3D.make_material(Color("293344")), Vector3(0, -0.03, 0))

	var states := ["frost", "poison", "burning", "armor_break", "stun", "invulnerable"]
	var names := ["Frost", "Gift", "Feuer", "Rüstungsbruch", "Betäubt", "Schutz"]
	for i in states.size():
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		var node := _mesh(sphere, Board3D.make_material(Color("566176")), Vector3(-7.5 + i * 3.0, 0.6, -3.5))
		var mat := VisualFx.status(self, sphere.get_aabb())
		mat.set_shader_parameter(states[i], 1.0)
		mat.set_shader_parameter("base_y", node.position.y - 0.5)
		node.material_overlay = mat
		_label(names[i], node.position + Vector3(0, 0.8, 0))

	var rock := PrismMesh.new()
	rock.size = Vector3(1.3, 1.1, 1.1)
	var rockmat := ShaderMaterial.new()
	rockmat.shader = preload("res://assets/shaders/rock.gdshader")
	_mesh(rock, rockmat, Vector3(-7.5, 0.6, 0))
	_label("Felsadern", Vector3(-7.5, 1.5, 0))
	var gem := VisualFx.gem_material(self, true)
	gem.set_shader_parameter("color", Color("e55cb5"))
	gem.set_shader_parameter("facet_strength", 0.5)
	_mesh(Tower._gem_mesh(), gem, Vector3(-4.5, 1.0, 0))
	_label("Hoher Gem", Vector3(-4.5, 2.0, 0))
	var box := BoxMesh.new()
	var death := ShaderMaterial.new()
	death.shader = VisualFx.DISSOLVE
	death.set_shader_parameter("progress", 0.45)
	death.set_shader_parameter("albedo_color", Color("7286a2"))
	_mesh(box, death, Vector3(-1.5, 0.6, 0))
	_label("Auflösen", Vector3(-1.5, 1.5, 0))
	var hidden := _mesh(SphereMesh.new(), Board3D.make_material(Color("d76c41")), Vector3(1.5, 0.6, -0.4))
	hidden.material_overlay = VisualFx.status(self, hidden.mesh.get_aabb())
	var cover := BoxMesh.new()
	cover.size = Vector3(1.6, 1.3, 0.8)
	_mesh(cover, Board3D.make_material(Color("34485c")), Vector3(1.5, 0.7, 0.2))
	_label("Verdeckt", Vector3(1.5, 1.7, 0))
	var foliage := ModelLoader.mesh_with_transform("res://assets/models/nature/common_tree_3.glb", 1.0)
	if not foliage.is_empty():
		var tree_mesh: Mesh = foliage[0].duplicate()
		for i in tree_mesh.get_surface_count():
			var base := tree_mesh.surface_get_material(i) as BaseMaterial3D
			if base != null:
				tree_mesh.surface_set_material(i, VisualFx.wind_material(base, tree_mesh.get_aabb(), self))
		var tree := _mesh(tree_mesh, null, Vector3(4.5, 0, 0))
		tree.transform = Transform3D(Basis().scaled(Vector3.ONE * 2.0), tree.position) * foliage[1]
	_label("Wind", Vector3(4.5, 2.0, 0))
	var all := _mesh(SphereMesh.new(), Board3D.make_material(Color("566176")), Vector3(7.5, 0.6, 0))
	var combined := VisualFx.status(self, all.mesh.get_aabb())
	for state in ["frost", "poison", "armor_break"]:
		combined.set_shader_parameter(state, 1.0)
	combined.set_shader_parameter("hit", 0.6)
	all.material_overlay = combined
	_label("Kombiniert + Treffer", Vector3(7.5, 1.6, 0))

	for i in 3:
		var area := VisualFx.area(1.1, [Color.CYAN, Color.GREEN, Color.SKY_BLUE][i], self, float(i))
		add_child(area)
		area.position = Vector3(-7.5 + i * 3.0, 0.08, 3.5)
		_label(["Reichweite", "Fläche", "Frostfläche"][i], area.position + Vector3(0, 0.3, 0))
	for i in 2:
		var preview := PlaneMesh.new()
		preview.size = Vector2.ONE * 1.7
		var mat := ShaderMaterial.new()
		mat.shader = VisualFx.BUILD
		mat.set_shader_parameter("valid", i == 0)
		_mesh(preview, mat, Vector3(1.5 + i * 3.0, 0.08, 3.5))
		_label("Bauplatz" if i == 0 else "Gesperrt", Vector3(1.5 + i * 3.0, 0.3, 3.5))
	var arrow := PlaneMesh.new()
	arrow.size = Vector2.ONE * 1.4
	var arrowmat := ShaderMaterial.new()
	arrowmat.shader = preload("res://assets/shaders/path_arrow.gdshader")
	_mesh(arrow, arrowmat, Vector3(7.5, 0.08, 3.5))
	_label("Wegpfeil", Vector3(7.5, 0.3, 3.5))
	# Die seltene Bildschirmverzerrung separat im rechten Rand testen.
	var shock := QuadMesh.new()
	shock.size = Vector2.ONE * 2.0
	var shockmat := ShaderMaterial.new()
	shockmat.shader = VisualFx.SHOCK
	shockmat.set_shader_parameter("progress", 0.5)
	var shocknode := _mesh(shock, shockmat, Vector3(8.2, 1.1, -1.5))
	shocknode.basis = camera.basis
	for quality in [Display.LOW, Display.MEDIUM, Display.HIGH]:
		Display.quality = quality
		Display.apply_quality()
		shocknode.visible = quality == Display.HIGH
		for frame in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := "res://.godot/shader-probe-%d.png" % quality
		var error := get_viewport().get_texture().get_image().save_png(output)
		print("BILD ", ProjectSettings.globalize_path(output), " exit=", error)
		print("GPU quality=", quality, " Shader-Vitrine gerendert")
	get_tree().quit()


func _mesh(shape: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material
	node.position = at
	add_child(node)
	return node


func _label(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	add_child(label)
