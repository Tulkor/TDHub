extends Node3D
## GPU material QA: procedural normals/specular and city-bank texture bindings.

func _ready() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("293442")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("bbcce0")
	world.environment.ambient_light_energy = 0.4
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25,-40,0)
	sun.light_energy = 1.6
	add_child(sun)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,10,12)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14
	camera.current = true
	for i in 6:
		var mat := ShaderMaterial.new()
		var shader_path: String = ["rock","city","natural_bank","natural_bank","water_pavement","neon_floor_lit"][i]
		mat.shader = load("res://assets/shaders/"+shader_path+".gdshader")
		var mesh := MeshInstance3D.new()
		if i in [0,1,3]:
			var shape := BoxMesh.new()
			shape.size = Vector3(2.4,1.4,2.4)
			mesh.mesh = shape
		else:
			var shape := PlaneMesh.new()
			shape.size = Vector2(2.4,2.4)
			mesh.mesh = shape
		if i == 2:
			mat.set_shader_parameter("vertex_colors",false)
			mat.set_shader_parameter("stone_color",Color("66523f"))
		elif i == 3:
			mat.set_shader_parameter("vertex_colors",false)
		elif i == 4:
			mat.set_shader_parameter("cobble_tex",load("res://assets/textures/ground/cobble.jpg"))
			mat.set_shader_parameter("cobble_normal",load("res://assets/textures/ground/cobble_normal.jpg"))
			mat.set_shader_parameter("cobble_specular",load("res://assets/textures/ground/cobble_specular.png"))
		elif i == 5:
			mat.set_shader_parameter("marble",1.0)
			mat.set_shader_parameter("cell",0.5)
			mat.set_shader_parameter("cells",Vector2(100,100))
			var black := Image.create(100,100,false,Image.FORMAT_RGBA8)
			black.fill(Color.BLACK)
			mat.set_shader_parameter("blocked",ImageTexture.create_from_image(black))
		mesh.material_override = mat
		mesh.position = Vector3((i%3-1)*4.0,0.7 if i in [0,1,3] else 0,-2.3 if i<3 else 2.3)
		add_child(mesh)
		var label := Label3D.new()
		label.text = ["Neonfels","Kalkstein/Glas","Ufererde","Uferstein","Pflaster PBR","Marmor/Messing"][i]
		label.font_size = 28
		label.pixel_size = 0.006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = mesh.position + Vector3(0,1.4,0)
		add_child(label)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/terrain-material-probe.png"
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("BILD ",ProjectSettings.globalize_path(path)," exit=",error)
	print("GPU calculated terrain relief/specular and mapped city pavement compiled")
	get_tree().quit(error)
