extends Node3D
## Bollwerk-Requisiten aus HdDev-Materialien in Spielbeleuchtung, nachgebaut mit den Farben aus dem Spielcode
## (Felsen, Mauer, Käfig, Kiste, Karawane, Gadget, Siegelstein, Ereignisboden, Notkörper eines Helden).
## Aufruf: oberflaechen_probe.tscn [-- --raster]  ->  .godot/oberflaechen[-raster].png
## --raster zeigt zum Vergleich das alte Dev-Raster.

var _raster := false


func _m(c: Color, scale := 0.25, glow := 0.0) -> Material:
	if not _raster:
		return HdDev.mat(c, scale, glow)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = HdDev.grid_texture()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.8
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _s(kind: String, c: Color, scale := 0.25) -> Material:
	return _m(c, scale) if _raster else HdDev.surface(kind, c, scale)


func _metal(c: Color, scale := 0.25) -> Material:
	if not _raster:
		return HdDev.metall(c, scale)
	var m: StandardMaterial3D = _m(c, scale)
	m.metallic = 0.8
	m.roughness = 0.4
	return m


func _ready() -> void:
	_raster = "--raster" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(1600, 800)
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
	sun.rotation_degrees = Vector3(-50, 140, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	# Ereignisboden (hd_event_arena) und Arenarand
	add_child(HdDev.box(Vector3(30, 0.5, 14), _m(Color("293b45"), 0.8), Vector3(0, -0.25, 0)))
	add_child(HdDev.box(Vector3(30, 3, 1), _m(Color("766343"), 0.8), Vector3(0, 1.5, -6.5)))
	# Felsen und Festungsmauer (hd_game)
	add_child(HdDev.cyl(0.9, 1.3, 1.6, _m(Color("6f6a64"), 0.5), Vector3(-12, 0.8, -3), 7))
	add_child(HdDev.box(Vector3(3, 3.5, 1.6), _m(Color("9a9aa4"), 0.5), Vector3(-8.5, 1.75, -4)))
	# Käfig (hd_events)
	var cage := Node3D.new()
	cage.position = Vector3(-4.5, 0, -2)
	add_child(cage)
	for i in 8:
		var a := TAU * i / 8.0
		cage.add_child(HdDev.box(Vector3(0.15, 2.4, 0.15), _m(Color("6a6a72"), 0.5), Vector3(cos(a), 1.2, sin(a))))
	cage.add_child(HdDev.cyl(1.1, 1.1, 0.15, _m(Color("4a4a52"), 0.5), Vector3(0, 2.45, 0), 10))
	cage.add_child(HdDev.cyl(0.4, 0.5, 1.4, _m(Color("5aa0e0"), 0.5), Vector3(0, 0.7, 0)))
	# Kiste (hd_zones) und Karawane (hd_ally)
	add_child(HdDev.box(Vector3(0.9, 1.1, 0.9), _m(Color("c98a3a"), 0.5), Vector3(-1.5, 0.55, -1)))
	var wood := _s("holz", Color("8a5a2a"), 0.5)
	add_child(HdDev.box(Vector3(1.6, 1.0, 2.4), wood, Vector3(1.5, 0.9, -1.5)))
	add_child(HdDev.box(Vector3(1.2, 0.7, 1.4), _m(UiTheme.COIN, 0.5, 0.9), Vector3(1.5, 1.75, -1.7)))
	for sx in [-0.85, 0.85]:
		for sz in [-0.8, 0.8]:
			var wheel := HdDev.cyl(0.35, 0.35, 0.15, _s("holz", Color("3a2a1a"), 0.5), Vector3(1.5 + sx, 0.35, -1.5 + sz), 10)
			wheel.rotation.z = PI * 0.5
			add_child(wheel)
	# Gadget Bolzenturm (hd_gadget)
	add_child(HdDev.cyl(0.8, 0.88, 0.3, _s("bruchstein", Color("5a5048"), 0.5), Vector3(5, 0.15, -1), 8))
	add_child(HdDev.cyl(0.3, 0.4, 1.2, _metal(Color("8a7a5a"), 0.5), Vector3(5, 0.9, -1), 6))
	add_child(HdDev.box(Vector3(0.18, 0.18, 1.0), _m(Color("ffb040"), 0.5, 0.8), Vector3(5, 1.5, -0.6)))
	# Siegelstein (hd_final) und Notkörper eines Helden (hd_hero)
	add_child(HdDev.box(Vector3(1.0, 1.8, 1.0), _m(Color("4a4a5a"), 0.5), Vector3(8, 0.9, -2)))
	add_child(HdDev.box(Vector3(0.6, 0.6, 1.05), _m(Color("b05de0"), 0.5, 0.2), Vector3(8, 1.2, -2)))
	add_child(HdDev.cyl(0.55, 0.65, 1.5, _m(Color("3d8fd6"), 0.5), Vector3(11, 0.75, -1)))
	var camera := Camera3D.new()
	camera.fov = 40
	camera.position = Vector3(0, 9, 16)
	add_child(camera)
	camera.look_at(Vector3(0, 0.8, -1.5))
	camera.current = true
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/oberflaechen%s.png" % ("-raster" if _raster else "")
	get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	get_tree().quit()
