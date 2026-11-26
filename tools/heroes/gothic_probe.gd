extends Node3D
## Vitrine der gotischen Spielgebäude von Bollwerk (HdGothic): Vorwerk, Innentor, Ruine,
## Teleport-Schrein und Spawn-Portal nebeneinander. Ergebnis: .godot/gothic-bauten.png
## Aufruf: gothic_probe.tscn [-- --nacht] [--wirbel=0..1] [--nah]
## --wirbel: Spawn-Stärke des Portals (0 Plasmakugel, 1 voller Wirbel), --nah: Kamera aufs Portal.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var night := args.has("--nacht")
	var near := args.has("--nah")
	var surge := 0.0
	for a in args:
		if a.begins_with("--wirbel="):
			surge = float(a.get_slice("=", 1))
	get_window().size = Vector2i(1600, 900)
	UiTheme.use_skin(UiTheme.BOLLWERK)
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0b0e15") if night else Color("171b25")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("5a6890") if night else Color("8a96b0")
	e.ambient_light_energy = 0.45 if night else 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	Metall.spiegel_himmel(e, Color("5a6a86"), Color("a8b0bc"), Color("2a2e26"))
	world.environment = e
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.35 if night else 1.1
	sun.light_color = Color("9db4ff") if night else Color("ffe9cc")
	sun.shadow_enabled = true
	add_child(sun)
	add_child(HdDev.box(Vector3(60, 0.2, 40), HdCathedral.floor_material(), Vector3(0, -0.1, 0)))
	var road := HdDev.box(Vector3(7, 0.02, 40), HdCathedral.path_material(), Vector3(12.5, 0.01, 0))
	add_child(road)
	var x := -13.0
	for inner in [false, true]:
		var h := 4.2 if inner else 3.2
		for part: MeshInstance3D in HdGothic.gate_tower(1.5, h, inner, UiTheme.COIN if inner else UiTheme.CYAN):
			part.position = Vector3(x, 0, 0)
			part.rotation.y = PI
			add_child(part)
		x += 5.5
	var ruin := HdGothic.gate_ruin(1.5)
	ruin.position = Vector3(x, 0, 0)
	add_child(ruin)
	x += 5.0
	for color in [UiTheme.PURPLE_LIGHT, Color("3ad8e8")]:
		var shrine := HdGothic.waystone(color)
		shrine.position = Vector3(x, 0, -1.0)
		shrine.rotation.y = 0.5
		add_child(shrine)
		x += 3.6
	var portal := HdGothic.portal(7.0, true)
	portal.position = Vector3(12.5, 0, 3.0)
	add_child(portal)
	HdGothic.set_portal_surge(portal, surge)
	var hero: Node3D = load("res://assets/models/heroes/torvik.glb").instantiate()
	hero.position = Vector3(-10.2, 0, -2.5)
	hero.rotation.y = PI
	add_child(hero)
	Metall.modell(hero)
	var camera := Camera3D.new()
	camera.fov = 38.0
	camera.position = Vector3(0.5, 13.0, -27.0) if not near else Vector3(8.0, 5.5, -9.0)
	add_child(camera)
	camera.look_at(Vector3(0.5, 3.2, 0) if not near else Vector3(11.5, 2.4, 2.0))
	camera.current = true
	for i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/gothic-bauten%s%s%s.png" % ["-nacht" if night else "", "-nah" if near else "", "-wirbel" if surge > 0.0 else ""]
	get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	get_tree().quit()