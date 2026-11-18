extends Node3D
## Helden-/Gegnermodelle nah in Spielbeleuchtung, mit HdStoffe (Leder, Stoff, Fell, Knochen, Chitin).
## Aufruf: stoffe_probe.tscn -- --ids=karawanenraeuber,torvik [--ohne]  ->  .godot/stoffe-<erster>[-ohne].png
## Ids werden unter assets/models/heroes und assets/models/heroes/gegner gesucht. --ohne = ohne Stoff-Texturen.


func _ready() -> void:
	var ids: PackedStringArray = []
	var ohne := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			ids = arg.trim_prefix("--ids=").split(",")
		ohne = ohne or arg == "--ohne"
	get_window().size = Vector2i(1600, 800)
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("10131a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a96b0")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Metall.spiegel_himmel(e, Color("5a6a86"), Color("a8b0bc"), Color("2a2e26"))
	world.environment = e
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 160, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	add_child(HdDev.box(Vector3(40, 0.2, 10), HdTerrain.material("rock"), Vector3(0, -0.1, 0)))
	var x := 0.0
	var top := 1.0
	for id in ids:
		var path := "res://assets/models/heroes/%s.glb" % id
		if not ResourceLoader.exists(path):
			path = "res://assets/models/heroes/gegner/%s.glb" % id
		if not ResourceLoader.exists(path):
			continue
		var m: Node3D = load(path).instantiate()
		if not path.contains("/gegner/"):
			Metall.modell(m)  # wie im Spiel: nur Helden laden Metall.modell
		if not ohne:
			HdStoffe.modell(m)
		add_child(m)
		var box := AABB()
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			box = box.merge(mi.get_aabb()) if box.size != Vector3.ZERO else mi.get_aabb()
		var w := maxf(box.size.x, 1.0) + 0.4
		m.position = Vector3(x + w * 0.5, 0, 0)
		x += w
		top = maxf(top, box.size.y)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(top * 1.15, x * 0.5 * 1.1)
	camera.position = Vector3(x * 0.5 + 1.0, top * 0.8, -6)
	add_child(camera)
	camera.look_at(Vector3(x * 0.5, top * 0.5, 0))
	camera.current = true
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/stoffe-%s%s.png" % [ids[0] if not ids.is_empty() else "leer", "-ohne" if ohne else ""]
	get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	get_tree().quit()
