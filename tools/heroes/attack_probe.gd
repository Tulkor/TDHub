extends Node3D
## Records the real GLB attack animation; --held=torvik|unrat|vesna|zix.

func _ready() -> void:
	get_window().size = Vector2i(640, 640)
	var id := "torvik"
	var clip := "attack"
	var repeats := 0
	var combo := OS.get_cmdline_user_args().has("--combo")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--held="):
			id = arg.trim_prefix("--held=")
		if arg.begins_with("--clip="):
			clip = arg.trim_prefix("--clip=")
		if arg.begins_with("--schlaege="):
			repeats = clampi(int(arg.trim_prefix("--schlaege=")),1,12)
	var definition: Dictionary = {}
	for entry in Database.load_json("res://data/heroes_helden.json").heroes:
		if str(entry.id) == id:
			definition = entry
	if definition.is_empty():
		push_error("Unknown hero: " + id)
		get_tree().quit(1)
		return
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("101824")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("c6d5ed")
	world.environment.ambient_light_energy = 0.55
	add_child(world)
	Metall.spiegel_himmel(world.environment, Color("101824"), Color("28374b"), Color("0d131c"))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = 1.4
	sun.light_color = Color("ffe6c3")
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.1
	sun.directional_shadow_max_distance = 20.0
	add_child(sun)
	add_child(HdDev.cyl(2.5,2.6,0.15,HdCathedral.floor_material(),Vector3(0,-0.075,0)))
	var model: Node3D = load(str(definition.model)).instantiate()
	model.scale = Vector3.ONE * float(definition.get("model_scale",1.0))
	model.rotation.y = -0.4
	add_child(model)
	Metall.modell(model)
	var players := model.find_children("*","AnimationPlayer",true,false)
	if players.is_empty() or not players[0].has_animation(clip):
		push_error("Missing attack animation: " + id)
		get_tree().quit(1)
		return
	var animation: AnimationPlayer = players[0]
	if definition.attack.has("animations"):
		var actor := HdHero.new()
		actor.def = definition
		actor._anim = animation
		for index in 6:
			assert(actor._attack_clip() == str(definition.attack.animations[index % definition.attack.animations.size()]), "Hero attack rotation")
		actor.free()
		print("GPU ",id,": all 3 imported clips and 6-step runtime rotation OK")
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.play(clip)
	animation.advance(0)
	var sequence: Array = definition.attack.get("animations",[]) if combo else []
	if combo and sequence.is_empty():
		push_error("This hero has no authored combo")
		get_tree().quit(1)
		return
	for attack in sequence:
		assert(animation.has_animation(str(attack)),"Missing combo clip")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.4 if combo and id == "unrat" else 4.9
	camera.position = Vector3(4,3.1,-6)
	if OS.get_cmdline_user_args().has("--seite"):
		camera.position = Vector3(-5,2.8,-5)
	if OS.get_cmdline_user_args().has("--profil"):
		model.rotation.y = 0.0
		camera.position = Vector3(-7,2.5,0)
	add_child(camera)
	camera.look_at(Vector3(0,1.25 if combo and id == "unrat" else 1.05,0))
	camera.current = true
	var label := Label.new()
	var title: String = {"idle":"Ruhe", "run":"Laufen", "cast":"Zaubern", "attack_cleave":"Breiter Seitenschwung", "attack_dual_strike":"Doppelschlag von oben", "attack_overhead":"Diagonaler Überkopfhieb"}.get(clip,"Angriff")
	label.text = str(definition.name) + " · " + title
	label.position = Vector2(20,18)
	label.add_theme_font_size_override("font_size",24)
	add_child(label)
	var directory := "res://.godot/hero-attacks/" + id
	if clip != "attack":
		directory += "-" + clip
	if repeats > 0:
		directory += "-%d-schlaege" % repeats
	if combo:
		directory += "-combo"
	DirAccess.make_dir_recursive_absolute(directory)
	for i in 5:
		await get_tree().process_frame
	var duration := animation.get_animation(clip).length * repeats if repeats > 0 else 4.0
	if combo:
		duration = 0.0
		for attack in sequence:
			duration += animation.get_animation(str(attack)).length
	var count := ceili(duration * 20.0)
	var sequence_index := -1
	var shock: HdFx
	var shock_cycle := -1
	if id == "zix" and clip == "attack":
		shock = HdFx.new()
		add_child(shock)
		shock.set_process(false)
	for frame in count:
		if combo:
			var sample := minf((frame+1)/20.0,duration-0.0001)
			var index := 0
			while index < sequence.size()-1 and sample >= animation.get_animation(str(sequence[index])).length:
				sample -= animation.get_animation(str(sequence[index])).length
				index += 1
			if index != sequence_index:
				animation.play(str(sequence[index]),0.0)
				sequence_index = index
			animation.seek(sample,true)
			label.text = str(definition.name) + " · Schlag %d/%d" % [index+1,sequence.size()] + (" · Wuchthieb" if index == 2 else "")
		else:
			animation.advance(minf(1.0/20.0, maxf(0.0,duration-frame/20.0-0.0001)))
		if repeats > 0:
			label.text = str(definition.name) + " · Schlag %d/%d" % [mini(repeats,1+int(frame/20.0/animation.get_animation(clip).length)),repeats]
		if shock:
			shock._process(1.0 / 20.0)
			var cycle := int(frame / 20.0 / animation.get_animation(clip).length)
			var phase := fmod(frame / 20.0, animation.get_animation(clip).length)
			if cycle != shock_cycle and phase >= 4.0 / 24.0:
				HdHeroZix.shock_fx(shock, Vector3.ZERO, -model.global_basis.z)
				shock.network_events.clear()
				shock_cycle = cycle
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png(directory+"/frame-%03d.png"%frame)
		if result != OK:
			get_tree().quit(result)
			return
	print("GPU attack frames: ",id," ",count," @20fps")
	get_tree().quit()
