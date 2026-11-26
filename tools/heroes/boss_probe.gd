extends Node3D
## Reproduzierbare GPU-Vitrine der fünf Boss-Silhouetten; echte Kampfmechanik: tests/heroes_boss_test.gd.
## --weg=<boss> --detail: Nahaufnahme von Felsmaterial, Gehweg und Feuerstellen.


func _ready() -> void:
	var model_id := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modell="):
			model_id = arg.trim_prefix("--modell=")
		if arg.begins_with("--weg="):
			await _fight(arg.trim_prefix("--weg="), "path")
			return
		if arg.begins_with("--arena="):
			await _fight(arg.trim_prefix("--arena="), "arena")
			return
		if arg.begins_with("--schlund="):
			await _fight(arg.trim_prefix("--schlund="), "lobby")
			return
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
	camera.size = 7.2 if model_id != "" else 24.0
	add_child(camera)
	camera.position = Vector3(7,6,-13) if model_id != "" else Vector3(0,17,-25)
	camera.look_at(Vector3(0,2.1 if model_id != "" else 1.8,0))
	camera.current = true
	add_child(HdDev.box(Vector3(37, 0.15, 14), HdCathedral.floor_material(), Vector3(0, -0.15, 0)))
	var data: Dictionary = Database.load_json(HdBossCatalog.DATA)
	if model_id != "":
		data.bosses = data.bosses.filter(func(b): return str(b.id) == model_id)
		if data.bosses.is_empty():
			push_error("Unbekanntes Bossmodell: " + model_id)
			get_tree().quit(1)
			return
	for i in data.bosses.size():
		var def: Dictionary = SystemHost.cascade(data.defaults, data.bosses[i])
		var x: float = 0.0 if model_id != "" else (2-i)*6.8
		add_child(HdDev.cyl(2.5, 2.65, 0.3, HdCathedral.wall_material(), Vector3(x, 0.02, 0)))
		var visual := HdBossVisual.new()
		add_child(visual)
		visual.position = Vector3(x, 0.2, 0)
		visual.build(def)
		visual.animate(1.2, 2, true)
		var label := Label3D.new()
		label.text = str(def.name).replace(", ", "\n") + "\n" + str(def.theme)
		label.font_size = 28 if model_id != "" else 42
		label.pixel_size = 0.008 if model_id != "" else 0.011
		label.position = Vector3(x, 0.4, -4)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)
	if OS.get_cmdline_user_args().has("--effekte"):
		for _frame in 12: await get_tree().process_frame
		var fx := HdFx.new()
		add_child(fx)
		for i in data.bosses.size():
			var definition: Dictionary = SystemHost.cascade(data.defaults,data.bosses[i])
			var x: float = 0.0 if model_id != "" else (2-i)*6.8
			fx.play("boss:%s:0" % definition.visual.theme,Vector3(x,.2,-1.7),Vector3.FORWARD,2.3,Color(str(definition.visual.accent)))
		await _save("boss-effekte")
		return
	await _save("boss-model-"+model_id if model_id != "" else "boss-gallery")


func _fight(id: String, view := "fight") -> void:
	Session.skip_setup = true
	Session.difficulty = 0
	var game: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	game.force_hero = "torvik"
	game.force_final_boss = id
	game.persist_settings = false
	add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.spawn_queue.clear()
	for enemy in game.enemies.duplicate():
		game._remove(enemy)
	game.enemies.clear()
	game.start_wave(40)
	game.spawn_queue.clear()
	game.final.enter()
	if view in ["lobby", "path"]:
		# Die weite Fotokamera zeigt nur das Endgebiet, keine Nachbarkarte am Bildrand.
		for child in game.get_children():
			if child is Node3D and not child is Light3D and not child is Camera3D and not child is HdHero and child != game.final._root:
				child.hide()
		game.camera.far = 500
		game.cam_pos = game.final.center + (Vector3(0, 0, -8) if view == "path" else Vector3.ZERO)
		game.cam_dist = 105 if view == "path" else 295
		var detail := view == "path" and OS.get_cmdline_user_args().has("--detail")
		if detail:
			game.cam_pos = game.final.center + Vector3(14, 0, -8)
			game.cam_dist = 32
		game._place_camera()
		_photo_light(game)
		if view == "lobby":
			for child in game.get_children():
				if child is WorldEnvironment:
					child.environment.fog_density = minf(child.environment.fog_density, 0.0007)
		game.hud.hide()
		await _save(("schlund-detail-" if detail else ("schlund-weg-" if view == "path" else "schlund-")) + id)
		return
	game.systems.challenges.start_boss("gate")
	var boss: HdEnemy = game.final.boss
	game.hero.position = boss.position + Vector3(4, 0, 7)
	boss.target = game.hero
	game.play_time = 30
	boss.start_cast(str(boss.abilities()[0]), game.play_time)
	boss._step_cast(float(boss.cast.windup) * 0.65, game.play_time)
	# Nur für das eingefrorene Foto: die kurzlebige Ankunftsnova verdeckt sonst den Kampfplatz.
	game.fx.hide()
	game.cam_pos = boss.position + Vector3(0, 0, 2)
	game.cam_dist = 25
	game._place_camera()
	game.hud._banner_t = 0
	game.hud._banner.modulate.a = 0
	game.hud.refresh()
	if view == "arena":
		boss.cancel_cast(true)
		game.fx.hide()
		game.cam_dist = 43
		game.camera.far = 500
		game._place_camera()
		_photo_light(game)
		game.hud.hide()
		await _save("arena-" + id)
		return
	await _save("boss-fight-" + id)


func _photo_light(game: HdGame) -> void:
	if OS.get_cmdline_user_args().has("--nacht"):
		game.day_cycle.set_hour(20.5)
	for child in game.get_children():
		if child is WorldEnvironment:
			child.environment.fog_density = minf(child.environment.fog_density, 0.002)


func _save(name: String) -> void:
	for _i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/%s.png" % name
	var error := get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path), " exit=", error)
	get_tree().quit(error)
