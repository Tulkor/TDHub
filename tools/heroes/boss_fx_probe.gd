extends Node3D
## Boss-Fähigkeitseffekte (HdBossFx) als Bogen: je Boss eine Zeile, Spalten Kreis, Kegel, Linie, Ring.
## Aufruf: boss_fx_probe.tscn [-- --zeit=0.3]  ->  .godot/boss-fx.png

const TILE := Vector2i(360, 260)


func _ready() -> void:
	var at_time := 0.3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--zeit="):
			at_time = float(arg.trim_prefix("--zeit="))
	get_window().size = TILE
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0e1118")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("6c7894")
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	world.environment = e
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 150, 0)
	sun.light_energy = 0.6
	add_child(sun)
	add_child(HdDev.box(Vector3(40, 0.2, 40), HdTerrain.material("basalt") if false else HdTerrain.material("rock"), Vector3(0, -0.1, 0)))
	var camera := Camera3D.new()
	camera.fov = 50.0
	camera.position = Vector3(0, 11, 10)
	add_child(camera)
	camera.look_at(Vector3(0, 0.6, -1.5))
	camera.current = true
	var label := Label.new()
	label.position = Vector2(6, 4)
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)
	var data: Dictionary = Database.load_json("res://data/heroes_bosse.json")
	var shapes := [[HdTelegraph.CIRCLE, 4.0, Vector3.ZERO, "Kreis"], [HdTelegraph.CONE, 7.0, Vector3(0, 0, 70), "Kegel"],
		[HdTelegraph.LINE, 9.0, Vector3(0, 2.2, 0), "Linie"], [HdTelegraph.RING, 6.0, Vector3(3.5, 0, 0), "Ring"]]
	var rows: Array = []
	for b in data.bosses:
		var def: Dictionary = SystemHost.cascade(data.defaults, b)
		var theme := str(def.visual.theme)
		var accent := Color(str(def.visual.get("accent", "c8ac77")))
		var row: Array = []
		for sh in shapes:
			var fx := HdFx.new()
			add_child(fx)
			var at := Vector3(0, 0, 2.5) if sh[0] in [HdTelegraph.CONE, HdTelegraph.LINE] else Vector3(0, 0, -1)
			fx.play("boss:%s:%d" % [theme, sh[0]], at, Vector3(0, 0, -1), sh[1], accent, sh[2])
			label.text = "%s · %s" % [str(def.name).get_slice(",", 0), sh[3]]
			await get_tree().create_timer(at_time).timeout
			await RenderingServer.frame_post_draw
			row.append(get_viewport().get_texture().get_image())
			fx.queue_free()
			await get_tree().process_frame
		rows.append(row)
	var sheet := Image.create(TILE.x * 4, TILE.y * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for c in rows[r].size():
			var img: Image = rows[r][c]
			img.convert(Image.FORMAT_RGBA8)
			if img.get_size() != TILE:
				img.resize(TILE.x, TILE.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(c * TILE.x, r * TILE.y))
	sheet.save_png("res://.godot/boss-fx.png")
	print("BILD ", ProjectSettings.globalize_path("res://.godot/boss-fx.png"))
	get_tree().quit()