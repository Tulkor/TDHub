extends Node3D
## Echte GPU-Aufnahmen der Eisenliturgie-Oberfläche: Nahkampf mit Grolm und Torvik;
## --imprint zeigt zusätzlich die Prägungswahl, --shop den Shop, --tooltip den Fähigkeits-Tooltip, --flash das Aufleuchten nach einem Zurücksetzen.
## --map: Kartenfotografie mit weitem Sichtbereich und reduziertem Fernnebel, ohne HUD.
## --size=1024x768/1280x720/1400x900 überschreibt die Probe-Auflösung.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	TranslationServer.set_locale("de")
	for arg in args:
		if arg.begins_with("--size="):
			var sizes := arg.trim_prefix("--size=").split("x")
			if sizes.size() == 2:
				get_window().size = Vector2i(int(sizes[0]), int(sizes[1]))
	Session.skip_setup = true
	Session.difficulty = 1
	var game: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	game.force_hero = "torvik"
	game.persist_settings = false
	game.bot = true
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.spawn_queue.clear()
	game.wave = 10
	game.wave_time = 17.0
	game.preview_slot = 0
	game.lane_ids = game.cfg.arena.roads.map(func(r): return str(r.id))
	game._build_roads()
	game.hero.add_xp(2600)
	game.hero.hp = game.hero.max_hp * 0.78
	game.hero.mana = game.hero.max_mana * 0.66
	game.shop.gold = 1240
	game.shop.wood = 86
	for id in ["eisenklinge", "heiltrank", "manatrank", "heimkehr"]:
		game.shop._put(id, 2 if id.ends_with("trank") else 1)
	game.day_cycle.set_hour(20.65)
	var road: HdRoad = game.roads[0]
	var at := road.point(road.length - 26.0)
	game.hero.position = at
	game.hero._face(Vector3(0, 0, -1))
	for i in 7:
		var offset := Vector3((i % 3 - 1) * 2.6, 0, -4.5 - floorf(i / 3.0) * 2.5)
		var e := game.spawn("moorklauer" if i % 2 else "sumpfling", at + offset, road.length - 31, road)
		e._face((at - e.position).normalized())
	var boss := game.spawn("grolm", at + Vector3(4, 0, -8), road.length - 34, road)
	boss.hp = boss.max_hp * 0.72
	boss.target = game.hero
	boss.start_cast("grolm_kegel", game.play_time)
	boss.cast.t = 0.35
	# Zwei harte CC: gelber Aufbau unter dem Bossleben sichtbar.
	boss.cc.hard(0.05, game.play_time - 1.0)
	boss.cc.hard(0.05, game.play_time - 0.5)
	game.cam_follow = false
	game.cam_pos = at + Vector3(0, 0, -3)
	game.cam_dist = 35
	game._place_camera()
	var shot := "bollwerk-eisenliturgie-kampf"
	if args.has("--imprint"):
		game.bot = false
		game.offer_imprint()
		shot = "bollwerk-eisenliturgie-praegung"
	elif args.has("--tooltip"):
		# Fähigkeits-Tooltip (MOBA-Stil) wie beim Zeigen auf das Plus von Q, fest eingeblendet.
		game.hero.skills.points = 1
		game.hero.skills.ranks[0] = 2
		var tip := PanelContainer.new()
		tip.add_theme_stylebox_override("panel", HdUiStyle.panel(10.0))
		tip.add_child(HdSkillCard.tooltip(game.hero, 0, true))
		tip.name = "ProbeTooltip"
		game.hud.root.add_child(tip)
		shot = "bollwerk-eisenliturgie-tooltip"
		_place_tip.call_deferred(game, tip)
	elif args.has("--shop"):
		game.bot = false
		game.hud.econ.toggle()
		shot = "bollwerk-eisenliturgie-shop"
	game.hud._banner_t = 0
	game.hud._banner.modulate.a = 0
	game.hud.refresh()
	game.hud._fit_layout.call_deferred()
	if args.has("--map"):
		game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		game.camera.size = 215
		game.camera.far = 600
		game.camera.position = Vector3(0, 150, 90)
		game.camera.look_at(Vector3.ZERO)
		for child in game.get_children():
			if child is WorldEnvironment:
				child.environment.fog_density = 0.0015
		game.hud.hide()
		shot = "bollwerk-kathedrale-karte"
	for _i in 20:
		await get_tree().process_frame
	if args.has("--flash"):
		# Zurückgesetzte Abklingzeit von E: Aufleuchten kurz nach dem Zurücksetzen fotografieren.
		game.hero.cd[1] = 5.0
		game.hud.refresh()
		game.hero.cd[1] = 0.0
		game.hud.refresh()
		shot = "bollwerk-eisenliturgie-aufleuchten"
		for _i in 4:
			await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_audit(game)
	if args.has("--layout-check"):
		shot += "-%dx%d" % [get_window().size.x, get_window().size.y]
	var output := "res://.godot/%s.png" % shot
	var result := get_viewport().get_texture().get_image().save_png(output)
	print("BILD ", ProjectSettings.globalize_path(output))
	get_tree().quit(result)


func _place_tip(game: HdGame, tip: Control) -> void:
	await get_tree().process_frame
	var card: Control = game.hud._slots[0].panel
	tip.size = tip.get_combined_minimum_size()
	tip.global_position = Vector2(card.global_position.x, card.global_position.y - 36 - tip.size.y)


func _audit(game: HdGame) -> void:
	var hud: HdHud = game.hud
	var panels: Array = [hud._wave_panel, hud._actions_panel, hud._vitals_panel, hud._skills_panel,
		hud._boss_panel, hud.econ._resource_panel, hud.econ._inventory_panel, hud.econ._roads_panel, hud.side._panel_node]
	var window := get_viewport().get_visible_rect()
	for i in panels.size():
		var p: Control = panels[i]
		if not p.is_visible_in_tree():
			continue
		var rect := p.get_global_rect()
		if not window.encloses(rect):
			push_error("UI-AUDIT: außerhalb des Fensters: %s %s" % [p.name, rect])
		for j in range(i + 1, panels.size()):
			var other: Control = panels[j]
			if other.is_visible_in_tree() and rect.intersects(other.get_global_rect()):
				push_error("UI-AUDIT: Überlappung %s %s / %s %s" % [p.name, rect, other.name, other.get_global_rect()])
	print("UI-AUDIT ", get_window().size, " geprüft")
