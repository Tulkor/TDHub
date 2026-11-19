extends Node3D
## Endboss-Bewegungen als Kontaktbogen: je Boss eine Zeile mit Gehen, Hieb (Ausholen, Treffer,
## Nachfedern) und Zusammenbruch. Ergebnis: .godot/boss-anim.png


const TILE := Vector2i(220, 240)


func _ready() -> void:
	get_window().size = TILE
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("141922")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9aa6bf")
	e.ambient_light_energy = 0.9
	world.environment = e
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 150, 0)
	add_child(sun)
	add_child(HdDev.box(Vector3(20, 0.1, 20), HdDev.mat(Color("39404e")), Vector3(0, -0.05, 0)))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	camera.position = Vector3(7, 4.5, -8)
	add_child(camera)
	camera.look_at(Vector3(0, 2.3, 0))
	camera.current = true
	var data: Dictionary = Database.load_json("res://data/heroes_bosse.json")
	var rows: Array = []
	for b in data.bosses:
		var def: Dictionary = SystemHost.cascade(data.defaults, b)
		var visual := HdBossVisual.new()
		add_child(visual)
		visual.build(def)
		visual.rotation.y = PI
		var row: Array = []
		var now := 1.0
		var shots := [[0.35, 2.5, false], [0.0, 0.0, true], [0.24, 0.0, false], [0.16, 0.0, false], [0.3, 0.0, false]]
		for shot in shots:
			if shot[2]:
				visual.strike()
			var wait: float = shot[0]
			var steps := maxi(1, int(wait / 0.02))
			for k in steps:
				now += wait / steps
				visual.animate(now, 1, false, shot[1])
			if wait == 0.0:
				continue
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			row.append(get_viewport().get_texture().get_image())
		visual.die()
		await get_tree().create_timer(1.4).timeout
		await RenderingServer.frame_post_draw
		row.append(get_viewport().get_texture().get_image())
		rows.append(row)
		visual.queue_free()
		await get_tree().process_frame
	var sheet := Image.create(TILE.x * 5, TILE.y * rows.size(), false, Image.FORMAT_RGBA8)
	for r in rows.size():
		for c in rows[r].size():
			var img: Image = rows[r][c]
			img.convert(Image.FORMAT_RGBA8)
			if img.get_size() != TILE:
				img.resize(TILE.x, TILE.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(c * TILE.x, r * TILE.y))
	sheet.save_png("res://.godot/boss-anim.png")
	print("BILD ", ProjectSettings.globalize_path("res://.godot/boss-anim.png"))
	get_tree().quit()