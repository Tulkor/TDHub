extends Node3D
## Bollwerk-Gegner in Spielbeleuchtung nebeneinander, je Gegner Ruhe und Angriff.
## Aufruf: gegner_probe.tscn -- --ids=a,b,c [--clip=attack] [--zeit=0.45]  ->  .godot/gegner-<erster>.png


func _ready() -> void:
	var ids: PackedStringArray = []
	var clip := "attack"
	var at := 0.45
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			ids = arg.trim_prefix("--ids=").split(",")
		if arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
		if arg.begins_with("--zeit="):
			at = float(arg.trim_prefix("--zeit="))
	get_window().size = Vector2i(1600, 700)
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("10131a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a96b0")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	Metall.spiegel_himmel(e, Color("5a6a86"), Color("a8b0bc"), Color("2a2e26"))
	world.environment = e
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 150, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	add_child(HdDev.box(Vector3(60, 0.2, 16), HdTerrain.material("rock"), Vector3(0, -0.1, 0)))
	var defs := {}
	for d in Database.load_json("res://data/heroes.json").enemies:
		defs[str(d.id)] = d
	var x := 0.0
	var placed: Array = []
	for id in ids:
		var d: Dictionary = defs.get(id, {})
		if d.is_empty() or not d.has("model"):
			continue
		var w := maxf(float(d.size[0]), 1.0) * 1.3
		for pose in [0, 1]:
			var m: Node3D = load(str(d.model)).instantiate()
			m.scale = Vector3.ONE * float(d.get("model_scale", 1.0))
			m.position = Vector3(-(x + w * 0.5), 0, 0)
			m.rotation.y = 0.0
			add_child(m)
			Metall.modell(m)
			var player: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
			var name := "idle" if pose == 0 else clip
			if player.has_animation(name):
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				player.play(name)
				player.seek(player.get_animation(name).length * (0.2 if pose == 0 else at), true)
			x += w
		placed.append(id)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(x * 0.42, 4.0)
	camera.position = Vector3(-x * 0.5 - 4, 6.5, 9)
	add_child(camera)
	camera.look_at(Vector3(-x * 0.5, 1.0, 0))
	camera.current = true
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/gegner-%s.png" % (placed[0] if not placed.is_empty() else "leer")
	get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	get_tree().quit()