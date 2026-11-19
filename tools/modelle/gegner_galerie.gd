extends Node3D
## Bollwerk-Gegner von vorn-oben (wie die Spielkamera) in Reihen, mit HdStoffe wie im Spiel.
## Aufruf: gegner_galerie.tscn -- --ids=a,b,c [--name=x] [--spalten=6] [--bilder=N]  ->  .godot/galerie-<name>.png
## Ohne --ids alle .glb unter assets/models/heroes/gegner.


func _ready() -> void:
	var ids: PackedStringArray = []
	var name_ := "gegner"
	var spalten := 6
	var bilder := 0  # >0: Bildfolge für eine Animation (Wabbeln), alle 0,1 s
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			ids = arg.trim_prefix("--ids=").split(",")
		elif arg.begins_with("--name="):
			name_ = arg.trim_prefix("--name=")
		elif arg.begins_with("--bilder="):
			bilder = int(arg.trim_prefix("--bilder="))
		elif arg.begins_with("--spalten="):
			spalten = int(arg.trim_prefix("--spalten="))
	if ids.is_empty():
		for f in DirAccess.get_files_at("res://assets/models/heroes/gegner"):
			if f.ends_with(".glb"):
				ids.append(f.get_basename())
	var world := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("10131a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a96b0")
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	Metall.spiegel_himmel(e, Color("5a6a86"), Color("a8b0bc"), Color("2a2e26"))
	world.environment = e
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	# Zelle je Figur so breit wie die größte Figur der Reihe; Reihen nach hinten versetzt
	var modelle: Array = []
	for id in ids:
		var path := "res://assets/models/heroes/gegner/%s.glb" % id
		if not ResourceLoader.exists(path):
			continue
		var m: Node3D = load(path).instantiate()
		HdStoffe.modell(m)
		add_child(m)
		var b0 := AABB()
		for mi0 in m.find_children("*", "MeshInstance3D", true, false):
			b0 = b0.merge(mi0.get_aabb()) if b0.size != Vector3.ZERO else mi0.get_aabb()
		HdWobbel.modell(m, b0.size.y)
		var box := AABB()
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = box.merge(b) if box.size != Vector3.ZERO else b
		modelle.append([m, box])
	var zeilen := (modelle.size() + spalten - 1) / spalten
	var zelle := 2.4
	var breite := spalten * zelle
	var tiefe := zeilen * zelle * 1.5
	for i in modelle.size():
		var m: Node3D = modelle[i][0]
		var box: AABB = modelle[i][1]
		var s := 1.0
		if maxf(box.size.x, box.size.y * 0.8) > zelle * 0.92:
			s = zelle * 0.92 / maxf(box.size.x, box.size.y * 0.8)  # Bosse verkleinert, damit sie in die Zelle passen
		m.scale = Vector3.ONE * s
		m.position = Vector3((i % spalten + 0.5) * zelle - breite * 0.5, 0, -(i / spalten) * zelle * 1.5)
		var anim: Array = m.find_children("*", "AnimationPlayer", true, false)
		if not anim.is_empty() and anim[0].has_animation("idle"):
			anim[0].play("idle")
			anim[0].seek(0.0, true)
			anim[0].pause()
		var schild := Label3D.new()
		schild.text = str(ids[i])
		schild.font_size = 64
		schild.outline_size = 12
		schild.pixel_size = 0.004
		schild.position = m.position + Vector3(0, -0.05, zelle * 0.45)
		schild.rotation_degrees = Vector3(-60, 0, 0)
		add_child(schild)
	add_child(HdDev.box(Vector3(breite + 4, 0.2, tiefe + 6), HdDev.mat(Color("3a3d36"), 0.9), Vector3(0, -0.1, -tiefe * 0.5 + 1.5)))
	get_window().size = Vector2i(1800, int(1800.0 * (tiefe * 0.62 + 2.0) / breite))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = breite * 0.98
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.rotation_degrees = Vector3(-38, 0, 0)
	camera.position = Vector3(0, 30 * sin(deg_to_rad(38)), -tiefe * 0.5 + 1.0 + 30 * cos(deg_to_rad(38)))
	add_child(camera)
	camera.current = true
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	for k in bilder:
		await get_tree().create_timer(0.1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/galerie-%s-%02d.png" % [name_, k])
	var path := "res://.godot/galerie-%s.png" % name_
	get_viewport().get_texture().get_image().save_png(path)
	print("BILD ", ProjectSettings.globalize_path(path))
	get_tree().quit()
