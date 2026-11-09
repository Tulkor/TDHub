extends Node3D
## Reproduzierbare GPU-Vitrine der fünf Boss-Silhouetten; echte Kampfmechanik: tests/heroes_boss_test.gd.


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kampf="):
			await _fight(arg.trim_prefix("--kampf="))
			return
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("101823")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("afc4de")
	world.environment.ambient_light_energy = 0.65
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.4
	add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	add_child(camera)
	camera.position = Vector3(0, 17, -25)
	camera.look_at(Vector3(0, 1.8, 0))
	camera.current = true
	add_child(HdDev.box(Vector3(37, 0.15, 14), HdDev.mat(Color("202d3c")), Vector3(0, -0.15, 0)))
	var data: Dictionary = Database.load_json(HdBossCatalog.DATA)
	for i in data.bosses.size():
		var def: Dictionary = SystemHost.cascade(data.defaults, data.bosses[i])
		var x: float = (2 - i) * 6.8
		add_child(HdDev.cyl(2.5, 2.65, 0.3, HdDev.mat(Color("334454")), Vector3(x, 0.02, 0)))
		var visual := HdBossVisual.new()
		add_child(visual)
		visual.position = Vector3(x, 0.2, 0)
		visual.build(def)
		visual.animate(1.2, 2, true)
		var label := Label3D.new()
		label.text = str(def.name).replace(", ", "\n") + "\n" + str(def.theme)
		label.font_size = 42
		label.pixel_size = 0.011
		label.position = Vector3(x, 0.4, -4)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)
	await _save("boss-gallery")


func _fight(id: String) -> void:
	Session.skip_setup = true
	Session.difficulty = 0
	var game: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	game.force_hero = "torvik"
	game.force_final_boss = id
	add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.spawn_queue.clear()
	for enemy in game.enemies.duplicate():
		game._remove(enemy)
	game.enemies.clear()
	game.start_wave(40)
	game.spawn_queue.clear()
	game.final.enter()
	game.systems.challenges.start_boss("gate")
	var boss: HdEnemy = game.final.boss
	game.hero.position = boss.position + Vector3(4, 0, 7)
	boss.target = game.hero
	game.play_time = 30
	boss.start_cast(str(boss.abilities()[0]), game.play_time)
	boss._step_cast(float(boss.cast.windup) * 0.65, game.play_time)
	game.cam_pos = boss.position + Vector3(0, 0, 2)
	game.cam_dist = 25
	game._place_camera()
	game.hud._banner_t = 0
	game.hud._banner.modulate.a = 0
	game.hud.refresh()
	await _save("boss-fight-" + id)


func _save(name: String) -> void:
	for _i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/%s.png" % name
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path), " exit=", error)
	get_tree().quit(error)
