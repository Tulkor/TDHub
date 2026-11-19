extends Node3D
## Galerie aller Bollwerk-Helden in Ruhepose (je Bild acht Helden). Ergebnis: .godot/kader-<n>.png
## Aufruf: kader_probe.tscn [-- --ab=4 --anzahl=8 --rueck]


func _ready() -> void:
	var first := 0
	var count := 8
	var back := OS.get_cmdline_user_args().has("--rueck")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ab="):
			first = int(arg.trim_prefix("--ab="))
		if arg.begins_with("--anzahl="):
			count = int(arg.trim_prefix("--anzahl="))
	get_window().size = Vector2i(1600, 620)
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("141922")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a96b0")
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	Metall.spiegel_himmel(e, Color("5a6a86"), Color("a8b0bc"), Color("2a2e26"))
	world.environment = e
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 150, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	add_child(HdDev.box(Vector3(40, 0.2, 12), HdDev.mat(Color("3a4150")), Vector3(0, -0.1, 0)))
	var heroes: Array = Database.load_json("res://data/heroes_helden.json").heroes
	var shown := 0
	for i in range(first, mini(first + count, heroes.size())):
		var h: Dictionary = heroes[i]
		var model: Node3D = load(str(h.model)).instantiate()
		model.scale = Vector3.ONE * float(h.get("model_scale", 1.0))
		model.position = Vector3((shown - (count - 1) * 0.5) * 2.5, 0, 0)
		model.rotation.y = PI if back else 0.0
		add_child(model)
		Metall.modell(model)
		for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
			if player.has_animation("idle"):
				player.play("idle")
		var label := Label3D.new()
		label.text = str(h.id)
		label.font_size = 64
		label.position = model.position + Vector3(0, -0.02, -1.6)
		label.rotation_degrees = Vector3(-90, 180, 0)
		add_child(label)
		shown += 1
	var camera := Camera3D.new()
	camera.fov = 24.0
	camera.position = Vector3(0, 4.6, -15.5)
	add_child(camera)
	camera.look_at(Vector3(0, 1.5, 0))
	camera.current = true
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/kader-%d%s.png" % [first, "-rueck" if back else ""]
	get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	get_tree().quit()