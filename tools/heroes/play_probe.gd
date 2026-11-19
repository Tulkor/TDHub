extends Node3D
## Reproduzierbare GPU-Ansichten: --event oder --imprint, sonst acht Lanes von oben.


func _ready() -> void:
	Sfx.audible = false
	if "--niedrig" in OS.get_cmdline_user_args():
		Display.quality=Display.LOW
		Display.apply_quality()
	Session.skip_setup = true
	var game: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	game.force_hero = "torvik"
	game.persist_settings = false
	game.bot = true
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.spawn_queue.clear()
	game.hero.add_xp(600)
	game.lane_ids = game.cfg.arena.roads.map(func(r): return str(r.id))
	game._build_roads()
	var args := OS.get_cmdline_user_args()
	var name := "bollwerk-lanes"
	if args.has("--gehwege"):
		var paths: Array=game.get_meta("settlement_street_paths",[])
		var focus := Vector3(-24,0,-24)
		var score := -INF
		for path in paths:
			var at: Vector3=path[path.size()/2]
			var nearby := 0
			for other in paths:
				if (other[other.size()/2] as Vector3).distance_to(at)<25:nearby+=1
			var weight := float(nearby)-at.length()*.012
			if weight>score:
				score=weight
				focus=at
		if args.has("--insel"):
			score=-INF
			for at: Vector3 in game.get_node("Atmosphere/CourtyardTrees").get_meta("tree_positions",[]):
				var nearby := 0
				for path in paths:
					if (path[path.size()/2] as Vector3).distance_to(at)<23:nearby+=1
				if nearby>score:
					score=nearby
					focus=at
		if args.has("--stadt"):focus=Vector3.ZERO
		for arg: String in args:
			if arg.begins_with("--punkt="):
				var xz := arg.trim_prefix("--punkt=").split(",")
				focus=Vector3(float(xz[0]),0,float(xz[1]))
		var fields: Node=game.get_node_or_null("Atmosphere/Fields")
		if fields:print("FELDER ",fields.get_meta("fields",[]).map(func(f):return Vector2i(int(f.pos.x),int(f.pos.z))))
		print("SECRETS ",HdExplorationLayout.sites().map(func(s):return [str(s.entrance_kind),Vector2i(int(s.pos.x),int(s.pos.z))]))
		focus.y=HdArenaMountains.ground_height(game.arena_layout,focus)
		game.hero.position=focus
		game.hero.hide()
		game.cam_pos=focus
		game.cam_dist=300 if args.has("--stadt") else (72 if args.has("--weit") else 43)
		game._place_camera()
		game.day_cycle.set_hour(21.5 if args.has("--nacht") else 16.5)
		if args.has("--stadt") and not args.has("--nacht"):game.day_cycle.set_hour(13.0)
		if args.has("--stadt"):
			for world: WorldEnvironment in game.find_children("*","WorldEnvironment",true,false):
				world.environment.fog_density*=.08 # Nur Kartenfoto: Stadtgrundriss aus großer Höhe lesbar.
		var atmosphere: HdAtmosphere=game.get_node("Atmosphere")
		atmosphere._wait=0
		atmosphere._process(0)
		game.get_node("Atmosphere/OverheadBirdLayer").hide()
		game.hud.hide()
		print("FEUER ",atmosphere.get_meta("fires")," hang=",atmosphere.get_meta("lane_lamp_skips"))
		print("GEHWEGE pfade=%d laternen=%d baeume_entfernt=%d fokus=%s" % [paths.size(),atmosphere.get_meta("street_lantern_positions").size(),game.get_node("Atmosphere/SettlementWalkways").get_meta("cleared_trees"),focus])
		print("STADT haeuser=%d zugaenge=%d plaetze=%d" % [game.get_node("SchwarzeKathedrale").get_meta("settlement_sites",[]).size(),game.get_meta("settlement_city_access",[]).size(),game.get_node("SchwarzeKathedrale").get_meta("settlement_plazas",[]).size()])
		print("STADT_GRUNDRISS ",hash(game.get_node("SchwarzeKathedrale").get_meta("settlement_sites",[]).map(func(site):return [site.pos.x,site.pos.z,site.yaw,site.ruin])))
		print("WEGGRUEN inseln=%d bepflanzt=%d baeume=%d baumdreiecke=%d" % [game.get_meta("settlement_islands",[]).size(),game.get_node("Atmosphere/UndergrowthPatches").get_meta("courtyard_islands",[]).size(),game.get_node("Atmosphere/CourtyardTrees").get_meta("tree_positions",[]).size(),game.get_node("Atmosphere/CourtyardTrees").get_meta("triangle_budget",0)])
		name=("bollwerk-stadt" if args.has("--stadt") else "bollwerk-gehwege")+("-insel" if args.has("--insel") else "")+("-nacht" if args.has("--nacht") else "-tag")+("-weit" if args.has("--weit") else "")+("-niedrig" if Display.quality==Display.LOW else "")
	elif args.has("--natur"):
		var plants=game.get_node("Atmosphere/UndergrowthPatches")
		var focus := Vector3(-110,0,-60)
		if args.has("--nah") or args.has("--weit"):
			var score := -INF
			for center: Vector3 in plants.get_meta("patch_centers"):
				if center.distance_to(focus)>45:continue
				var count := 0
				for at: Vector3 in plants.get_meta("plant_positions"):
					if Vector2(at.x-center.x,at.z-center.z).length()<5.5:count+=1
				var candidate := float(count)-center.distance_to(Vector3(-110,0,-60))*.12
				if candidate>score:
					score=candidate
					game.cam_pos=center
			game.cam_pos.y=HdArenaMountains.ground_height(game.arena_layout,game.cam_pos)
		else:game.cam_pos=focus
		game.cam_dist=23 if args.has("--nah") else (85 if args.has("--weit") else 50)
		game._place_camera()
		game.hud.hide()
		var birds=game.get_node("Atmosphere/OverheadBirdLayer/OverheadBirds")
		birds._rng.seed=719
		birds.begin_flock()
		birds._age=birds._duration*.5
		birds.queue_redraw()
		if args.has("--ohneunterholz"):plants.hide()
		print("NATUR patches=%d pflanzen=%d dreiecke=%d zellen=%d" % [plants.get_meta("patch_centers").size(),plants.get_meta("plant_count"),plants.get_meta("triangle_budget"),plants.get_meta("batch_count")])
		name="bollwerk-unterholz-voegel"+("-nah" if args.has("--nah") else ("-weit" if args.has("--weit") else ""))+("-niedrig" if Display.quality==Display.LOW else "")
	elif args.has("--hang"):
		var at := _hill_point(game)
		game.hero.position = at
		game._process(0)
		game.cam_pos = at
		game.cam_dist = 27
		game._place_camera()
		game.hud.hide()
		game.health_orbs._create_field(-1,at,game.play_time-.6,5)
		name = "bollwerk-hang-heilflaeche"
	elif args.has("--atmosphaere") or args.has("--schmiede"):
		game.day_cycle.set_hour(21.5)
		var at: Vector3 = game.zones.center("schmiede") if args.has("--schmiede") else game.roads[0].point(game.roads[0].length-28)
		game.hero.position = at
		game.cam_pos = at
		game.cam_dist = 26
		game._place_camera()
		game.hud.hide()
		name = "bollwerk-schmiede" if args.has("--schmiede") else "bollwerk-atmosphaere"
		if args.has("--vfx"):
			game.fx.play("boss:forge:0",at + Vector3(0,0,-3),Vector3.FORWARD,3.8,Color("ff8a35"))
			name += "-vfx"
	elif args.has("--event"):
		game.events.start("gefangener")
		game.cam_pos = game.event_arena.center
		game.cam_dist = 32
		game._place_camera()
		name = "bollwerk-event"
	else:
		game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		game.camera.size = 220
		game.camera.position = Vector3(0, 160, 0.1)
		game.camera.look_at(Vector3.ZERO)
	if args.has("--imprint"):
		game.bot = false
		game.wave = 10
		game.offer_imprint()
		name = "bollwerk-imprint"
	game.hud._banner_t = 0
	game.hud._banner.modulate.a = 0
	game.hud.refresh()
	for _i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/%s.png" % name
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(result)


func _hill_point(game: HdGame) -> Vector3:
	for road: HdRoad in game.arena_layout.paths:
		for p: Vector3 in road.points:
			for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
				var at: Vector3 = p+direction*18.0
				var height := HdArenaMountains.ground_height(game.arena_layout,at)
				if height>.2 and game.arena_layout.foothill(at,game.hero.radius):return at
	return game.hero_spawn()
