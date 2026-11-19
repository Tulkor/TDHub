extends Node3D
## Gegner-Animationen im Zeitverlauf: je Gegner eine Zeile, je Clip (run, attack, cast, death) drei Zeitpunkte.
## Aufruf: gegner_clips.tscn -- --ids=a,b,c  ->  .godot/gegnerclips-<erster>.png

const TILE := Vector2i(150, 170)


func _ready() -> void:
	var ids: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			ids = arg.trim_prefix("--ids=").split(",")
	get_window().size = TILE
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a202b")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("a0abc2")
	e.ambient_light_energy = 0.9
	world.environment = e
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	add_child(sun)
	add_child(HdDev.box(Vector3(14, 0.1, 14), HdDev.mat(Color("39404e")), Vector3(0, -0.05, 0)))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.current = true
	var defs := {}
	for d in Database.load_json("res://data/heroes.json").enemies:
		defs[str(d.id)] = d
	var rows: Array = []
	for id in ids:
		var d: Dictionary = defs.get(id, {})
		if d.is_empty() or not d.has("model"):
			continue
		var h := float(d.size[1])
		camera.size = maxf(h * 1.7, 2.0)
		camera.position = Vector3(h * 1.6, h * 1.3, h * 2.6)
		camera.look_at(Vector3(0, h * 0.5, 0))
		var m: Node3D = load(str(d.model)).instantiate()
		m.scale = Vector3.ONE * float(d.get("model_scale", 1.0))
		add_child(m)
		Metall.modell(m)
		var player: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var row: Array = []
		for clip in ["run", "attack", "cast", "death"]:
			if not player.has_animation(clip):
				continue
			var length := player.get_animation(clip).length
			for part in [0.2, 0.5, 0.85]:
				player.play(clip, 0.0)
				player.seek(length * part, true)
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				row.append(get_viewport().get_texture().get_image())
		rows.append(row)
		m.queue_free()
		await get_tree().process_frame
	var columns := 1
	for row in rows:
		columns = maxi(columns, row.size())
	var sheet := Image.create(TILE.x * columns, TILE.y * maxi(rows.size(), 1), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1a202b"))
	for r in rows.size():
		for c in rows[r].size():
			var img: Image = rows[r][c]
			img.convert(Image.FORMAT_RGBA8)
			if img.get_size() != TILE:
				img.resize(TILE.x, TILE.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(c * TILE.x, r * TILE.y))
	var path := "res://.godot/gegnerclips-%s.png" % (ids[0] if not ids.is_empty() else "leer")
	sheet.save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	get_tree().quit()