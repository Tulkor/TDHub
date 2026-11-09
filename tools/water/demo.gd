extends Node3D
## GPU-Vitrine und Animationstest; --live lässt die Demo offen (1/2/3: Grafikqualität).

var systems := {}
var water: WaterSystem
var _live := false
var _quality_label: Label
var _perspective := false


func water_regions() -> Array:
	return Database.load_json("res://tools/water/demo.json").get("water", [])


func _ready() -> void:
	_live = OS.get_cmdline_user_args().has("--live")
	_perspective = OS.get_cmdline_user_args().has("--perspective")
	get_tree().root.size = Vector2i(1400, 900)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263d4a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9d3df")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color("ffe6c5")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if _perspective else Camera3D.PROJECTION_ORTHOGONAL
	camera.fov = 50.0
	camera.size = 20.0
	add_child(camera)
	camera.position = Vector3(12, 11, 15)
	camera.look_at(Vector3(0, 1, 0.7))
	camera.current = true
	_box(Vector3(24, 0.5, 22), Vector3(0, -0.45, 0), Color("3d5147"))
	_box(Vector3(13, 2.9, 7), Vector3(-3, 1.25, -4.4), Color("66756a"))
	# Ufer aus ruhigen, unterschiedlich großen Felsen; keine externen Assets.
	for item in [
		[Vector3(-6.7, 3.2, -2.1), Vector3(1.5, 0.9, 2.0)],
		[Vector3(-3.1, 3.1, -4.4), Vector3(3.5, 0.9, 1.8)],
		[Vector3(-1.8, 3.1, -0.8), Vector3(1.0, 1.0, 1.1)],
		[Vector3(1.8, 3.0, -1.7), Vector3(1.2, 1.2, 2.3)],
		[Vector3(-2.0, 0.2, 0.9), Vector3(1.3, 1.0, 2.2)],
		[Vector3(2.2, 0.15, 1.0), Vector3(1.0, 0.8, 1.4)],
		[Vector3(0.2, 0.1, 3.8), Vector3(1.1, 0.7, 1.2)],
		[Vector3(6.7, 0.15, 4.1), Vector3(1.0, 0.8, 2.4)],
		[Vector3(3.2, 0.1, 7.6), Vector3(5.8, 0.7, 1.0)]
	]:
		_box(item[1], item[0], Color("79867b"))
	_quality_label = Label.new()
	_quality_label.position = Vector2(24, 20)
	_quality_label.add_theme_font_size_override("font_size", 25)
	add_child(_quality_label)
	water = SystemHost.attach(self, "", ["water"]).water
	await get_tree().process_frame
	await get_tree().process_frame
	if _live:
		_set_quality(Display.HIGH)
		return
	water.set_process(false)
	for quality in [Display.LOW, Display.MEDIUM, Display.HIGH]:
		_set_quality(quality)
		water.set_time(1.0)
		await _draw()
		_save("water-%d.png" % quality)
	var before := get_viewport().get_texture().get_image()
	# In freier Beckenmitte darf der Tiefenschaum nicht die ganze Fläche weiß färben.
	var clear_water := 0
	for x in [2.0, 3.2, 4.4]:
		for z in [4.8, 5.7, 6.3]:
			var pixel := camera.unproject_position(Vector3(x, 0.18, z))
			var color := before.get_pixel(clampi(int(pixel.x), 0, before.get_width() - 1), clampi(int(pixel.y), 0, before.get_height() - 1))
			if color.g > color.r * 1.4 and color.b > color.r * 1.4:
				clear_water += 1
	water.set_time(1.8)
	await _draw()
	var after := get_viewport().get_texture().get_image()
	var changed := 0
	for y in range(0, after.get_height(), 8):
		for x in range(0, after.get_width(), 8):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.025:
				changed += 1
	_save("water-motion.png")
	print("GPU Wasseranimation: ", changed, " Stichproben verändert")
	print("GPU Tiefenschaum: ", clear_water, "/9 freie Wasserpunkte ohne Weißschleier")
	if changed < 10:
		push_error("Wasseranimation ist im Bild nicht erkennbar")
	if clear_water < 6:
		push_error("Tiefenschaum verdeckt freie Wasserfläche")
	get_tree().quit(0 if changed >= 10 and clear_water >= 6 else 1)


func _set_quality(quality: int) -> void:
	Display.quality = quality
	Display.apply_quality()
	_quality_label.text = "Wasser / Wasserfall – %s%s" % [Display.QUALITY_NAMES[quality], "   [1 / 2 / 3]" if _live else ""]


func _draw() -> void:
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(name: String) -> void:
	var path := "res://.godot/" + name.replace("water-", "water-perspective-" if _perspective else "water-")
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Wasser-Vorschau konnte nicht gespeichert werden: " + str(error))
	print("BILD ", ProjectSettings.globalize_path(path))


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	node.material_override = Board3D.make_material(color)
	add_child(node)


func _unhandled_key_input(event: InputEvent) -> void:
	if _live and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			_set_quality(int(event.keycode - KEY_1))
