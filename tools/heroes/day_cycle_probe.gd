extends Node3D
## Echte GPU-Zeitrafferaufnahme: vier Orte, derselbe vollständige native Tag-Nacht-Zyklus.
const FRAMES := 240
const SITES := [
 {"title":"Feste und Vorplatz","pos":Vector3(0,0,0),"distance":48.0},
 {"title":"Kathedralbezirk","pos":Vector3(-33,0,-33),"distance":62.0},
 {"title":"Wald und Pflanzengruppen","pos":Vector3(-110,0,-60),"distance":50.0},
 {"title":"Schmiede und Feuerschalen","pos":Vector3(0,0,0),"distance":37.0}
]

func _ready() -> void:
	Sfx.audible=false
	DayCycle.fixed_hour=-1
	Display.resolution=Vector2i(960,600)
	Display._apply()
	Session.coop={}
	Session.skip_setup=true
	var game: HdGame=load("res://scenes/heroes_game.tscn").instantiate()
	game.force_hero="torvik"
	game.persist_settings=false
	game.bot=true
	add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hero.set_process(false)
	game.hero.hide()
	game.hud.hide()
	game.spawn_queue.clear()
	game.day_cycle.set_process(false)
	game.day_cycle.set_hour(6.0)
	game.get_node("Atmosphere/OverheadBirdLayer").hide()
	var atmosphere: HdAtmosphere=game.get_node("Atmosphere")
	atmosphere.set_process(false)
	var sites: Array=SITES.duplicate(true)
	sites[3].pos=game.zones.center("schmiede")
	for site in sites:site.pos.y=HdArenaMountains.ground_height(game.arena_layout,site.pos)
	var folder := "res://.godot/bollwerk-day-cycle"
	DirAccess.make_dir_recursive_absolute(folder)
	for frame in 12:await get_tree().process_frame
	var hours: Array = []
	var real_cycle := 0.0
	for segment in DayCycle.PACE:real_cycle+=float(segment[2])
	for index in FRAMES:
		hours.append(game.day_cycle.hour)
		var composite := Image.create(1280,800,false,Image.FORMAT_RGBA8)
		for view in sites.size():
			var site: Dictionary=sites[view]
			game.hero.position=site.pos
			game.cam_pos=site.pos
			game.cam_dist=float(site.distance)
			game._place_camera()
			atmosphere._clock=float(index)*.1
			atmosphere._wait=0
			atmosphere._process(0)
			for frame in 2:await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			image.resize(640,400,Image.INTERPOLATE_LANCZOS)
			composite.blit_rect(image,Rect2i(0,0,640,400),Vector2i((view%2)*640,(view/2)*400))
		var error := composite.save_png(folder+"/frame-%04d.png" % index)
		if error!=OK:
			push_error("Tageszyklus-Aufnahme konnte Frame nicht speichern")
			get_tree().quit(1)
			return
		game.day_cycle.advance(real_cycle/FRAMES)
		if index%40==0:print("MESSUNG Tageszyklus Frame=%d/%d Uhrzeit=%.2f" % [index,FRAMES,game.day_cycle.hour])
	var file := FileAccess.open(folder+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"frames":FRAMES,"duration_ms":100,"hours":hours,"sites":sites.map(func(site):return str(site.title)),"native_cycle_seconds":real_cycle},"  "))
	file.close()
	print("BILD ",ProjectSettings.globalize_path(folder+"/frame-0000.png"))
	print("MESSUNG Tageszyklus fertig: ",FRAMES," Frames, vier Orte, ",real_cycle," Spielsekunden")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()
