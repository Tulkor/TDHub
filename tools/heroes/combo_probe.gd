extends Node3D
## Kontaktbogen der Angriffsanimationen: je Held eine Zeile, je Angriffsclip drei Posen (Ausholen 31 %, Treffer 46 %, Nachschwung 62 %).
## Aufruf: combo_probe.tscn -- --ab=0 --anzahl=4 [--clip=run] [--seite]  ->  .godot/combo-<ab>.png

const TILE := Vector2i(190, 250)


func _ready() -> void:
	var first := 0
	var count := 4
	var only_clip := ""
	var side := OS.get_cmdline_user_args().has("--seite")
	var ids: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ab="):
			first = int(arg.trim_prefix("--ab="))
		if arg.begins_with("--anzahl="):
			count = int(arg.trim_prefix("--anzahl="))
		if arg.begins_with("--ids="):
			ids = arg.trim_prefix("--ids=").split(",")
		if arg.begins_with("--clip="):
			only_clip = arg.trim_prefix("--clip=")
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
	sun.light_energy = 1.0
	add_child(sun)
	add_child(HdDev.box(Vector3(12, 0.1, 12), HdDev.mat(Color("39404e")), Vector3(0, -0.05, 0)))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	camera.position = Vector3(7, 3.4, -3.5) if side else Vector3(3.2, 3.6, -7)
	add_child(camera)
	camera.look_at(Vector3(0, 1.45, -0.4))
	camera.current = true
	var label := Label.new()
	label.position = Vector2(4, 2)
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	var heroes: Array = Database.load_json("res://data/heroes_helden.json").heroes
	var rows: Array = []
	var picked: Array = []
	for i in range(first, mini(first + count, heroes.size())):
		picked.append(heroes[i])
	if not ids.is_empty():
		picked = heroes.filter(func(x): return ids.has(str(x.id)))
	for h: Dictionary in picked:
		var model: Node3D = load(str(h.model)).instantiate()
		model.scale = Vector3.ONE * float(h.get("model_scale", 1.0))
		add_child(model)
		Metall.modell(model)
		var player: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clips: Array = [only_clip] if only_clip != "" else h.attack.get("animations", ["attack"])
		var row: Array = []
		for clip in clips:
			if not player.has_animation(str(clip)):
				continue
			var length := player.get_animation(str(clip)).length
			for part in ([0.31, 0.46, 0.62] if only_clip != "death" else [0.1, 0.3, 0.55, 0.8, 1.0]):
				player.play(str(clip), 0.0)
				player.seek(length * part, true)
				label.text = "%s %s %d%%" % [h.id, str(clip).trim_prefix("attack_"), int(part * 100)]
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				row.append(get_viewport().get_texture().get_image())
		rows.append(row)
		model.queue_free()
		await get_tree().process_frame
	var columns := 1
	for row in rows:
		columns = maxi(columns, row.size())
	var sheet := Image.create(TILE.x * columns, TILE.y * rows.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1a202b"))
	for r in rows.size():
		for c in rows[r].size():
			var img: Image = rows[r][c]
			img.convert(Image.FORMAT_RGBA8)
			if img.get_size() != TILE:
				img.resize(TILE.x, TILE.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(c * TILE.x, r * TILE.y))
	var path := "res://.godot/combo-%d%s.png" % [first, "-seite" if side else ""]
	sheet.save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	get_tree().quit()