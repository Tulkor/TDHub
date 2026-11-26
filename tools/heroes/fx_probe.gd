extends Node3D
## Zeigt die Effekte der Heldenfähigkeiten als Kontaktbogen: je Effekt ein Bild im besten Moment.
## Aufruf: fx_probe.tscn -- [--held=torvik|unrat|vesna|zix|basis] [--nur=<id>] [--zeit=S]
## Ergebnis: .godot/fx-<held>.png (mit --nur: .godot/fx-<id>.png, vier Zeitpunkte nebeneinander).

const TILE := Vector2i(520, 420)
const BLUE := Color(0.5, 0.88, 1.0)

var fx: HdFx
var stage: Node3D


## Einträge je Held: [Titel, Zeitpunkt des Bilds, Auslöser].
func _shots(hero: String) -> Array:
	var z := Vector3.ZERO
	var fwd := Vector3(0, 0, 1)
	if hero == "gegner":
		return [
			["Grabhieb · Warnung", .25, func(): _enemy_warning("grabhieb")],
			["Seelenkreuz · Warnung", .25, func(): _enemy_warning("seelenmoerser")],
			["Leerenriss · Warnung", .25, func(): _enemy_warning("riss")],
			["Heil-Orb · 3 × 5 %", .25, func():
				var orbs = load("res://scripts/heroes/hd_health_orbs.gd").new()
				orbs.game = {"play_time":0.0}
				stage.add_child(orbs)
				orbs.apply_state([{"id":1,"pos":Vector3.ZERO,"expires":30.0}])
				orbs.scale = Vector3.ONE * 3],
			["Grabhieb · Treffer", .3, func(): fx.play("boss:forge:5",z,Vector3.FORWARD,4.8,Color("c9d4bb"),Vector3(1.2,1.5,140))],
			["Seelenkreuz · Treffer", .3, func(): fx.play("boss:forge:4",z,Vector3.FORWARD,4.2,Color("c9d4bb"),Vector3(0,1.4,0))],
			["Leerenriss · Treffer", .3, func(): fx.play("boss:void:6",z,Vector3.FORWARD,9,Color("b08deb"),Vector3(0,2,0))],
			["Orb · Gruppen-Heilfläche", .25, func(): fx.play("health_orb",z,Vector3.UP,5,Color("73dfa2"))],
		]
	if hero == "alle":
		var all := []
		for hero_def in Database.load_json("res://data/heroes_helden.json").heroes:
			if str(hero_def.get("kit", "")) != "roster": continue
			for row in _shots(str(hero_def.id)):
				row[0] = str(hero_def.name) + " · " + str(row[0])
				row.append(str(hero_def.id))
				all.append(row)
		return all
	for definition in Database.load_json("res://data/heroes_helden.json").heroes:
		if str(definition.id) != hero or str(definition.get("kit", "")) != "roster": continue
		var rows := []
		var color := Color(str(definition.color))
		rows.append(["Grundangriff",.18,func(): _shot("roster_"+hero,color,.2,14),"attack_combo_1"])
		for slot in 4:
			var index: int = slot
			var a: Dictionary = definition.abilities[slot]
			var id := "roster:%s:%d:impact" % [hero,index]
			var held := str(a.op) in ["guard","form","zone","whirl","beacon","sun","wall"]
			rows.append(["%s %s" % ["QWER"[index],str(a.name)],.22,func():
				fx.play(id,z,fwd,float(a.radius),color,Vector3(0,0,4))
				if held: _hold(id,z,float(a.radius),color),"cast_%d" % index])
		return rows
	match hero:
		"torvik":
			return [
				["Grundangriff", 0.11, func(): fx.swing(z, fwd, 2.6, Color("c9d8ec"))],
				["Q Donnerhieb", 0.12, func():
					fx.play("thunder", z, fwd, 3.4, Color.WHITE, Vector3(90, 0, 0))
					fx.play("strike", Vector3(-1.0, 0, 2.4), fwd, 1.0, Color(0.62, 0.84, 1.0))
					fx.play("strike", Vector3(1.3, 0, 2.0), fwd, 1.0, Color(0.62, 0.84, 1.0))],
				["Q Windschlag (Aufstieg)", 0.16, func(): fx.play("gust_line", Vector3(0, 0, -3), fwd, 9.0, Color(0.6, 0.95, 1.0), Vector3(1.6, 0, 0))],
				["W Glutnova", 0.24, func(): fx.play("fire_nova", z, fwd, 3.6)],
				["E Erdschock", 0.22, func(): _shot("rock", Color("a07850"), 0.4, 13.0)],
				["R Windaufstieg", 0.42, func(): fx.play("ascend", z, fwd, 4.5)],
				["Windaufstieg (Aura)", 0.7, func(): _hold("wind_aura", z, 1.0, BLUE)],
				["Windklinge (Aufstieg)", 0.2, func(): _shot("wind", Color(0.6, 0.95, 1.0), 0.24, 14.0)],
			]
		"unrat":
			return [
				["Grundangriff", 0.11, func(): fx.swing(z, fwd, 2.6, Color("e4d2b4"))],
				["Q Schrottbombe (Wurf)", 0.3, func(): fx.play("lob", Vector3(-3.5, 1.9, 0), fwd, 0.6, Color.WHITE, Vector3(2.5, 0.3, 1.0))],
				["Q Schrottbombe (Explosion)", 0.13, func():
					_hold("scrap_pile", Vector3(1.0, 0, 1.0), 1.0, Color.WHITE)
					fx.play("scrap_blast", Vector3(1.0, 0, 1.0), fwd, 3.0)],
				["W Rattenschwarm", 0.2, func():
					fx.nova(z, 3.5, HdHeroUnrat.RAT)
					for p in [Vector3(3, 0.6, 1.5), Vector3(-2.5, 0.6, 2.5), Vector3(0.5, 0.6, 3.2)]:
						fx.play("rats", z, fwd, 4.0, HdHeroUnrat.RAT, p)],
				["E Königsgewand", 0.3, func():
					fx.play("robe", z, fwd, 1.0, UiTheme.GOLD)
					_hold("shield_dome", z, 1.0, UiTheme.GOLD)],
				["R Rattenbanner", 0.9, func(): _hold("banner_zone", Vector3(0, 0, 1.0), 4.0, HdHeroUnrat.RAT, Vector3(0.35, 0, 0))],
				["R Banner-Ausbruch", 0.22, func(): fx.play("plague_burst", Vector3(0, 0, 1.0), fwd, 4.0, HdHeroUnrat.RAT)],
			]
		"vesna":
			return [
				["Spritzengewehr", 0.16, func():
					_shot("dart", HdHeroVesna.SHOT, 0.18, 16.0)
					fx.play("muzzle", Vector3(0, 1.2, 0.9), fwd, 1.0, HdHeroVesna.SHOT)],
				["Q Aderlass", 0.6, func(): _hold("drain", Vector3(3.5, 1.0, 3.0), 1.0, Color("d0203f"), Vector3(0, 1.2, 0))],
				["W Betäubungspfeil (Treffer)", 0.1, func(): fx.play("stun_hit", Vector3(2.0, 1.2, 2.5), fwd, 1.0, Color("f2e27a"))],
				["E Notfallkapsel", 0.5, func():
					_hold("capsule", Vector3(0, 2.9, 0), 1.0, UiTheme.HAVE)
					fx.play("heal", z, fwd, 1.0, UiTheme.HAVE)],
				["E Kapsel platzt", 0.14, func(): fx.play("capsule_pop", Vector3(0, 2.4, 0), fwd, 1.0, UiTheme.HAVE)],
				["R Hochdosis", 0.3, func():
					fx.play("overdose", z, fwd, 1.0, UiTheme.GOLD)
					_hold("aura", z, 1.0, UiTheme.GOLD)],
			]
		"zix":
			return [
				["Funkenpistole", 0.06, func(): HdHeroZix.shock_fx(fx, z, fwd, Vector3(1.5, 1.0, 4.5))],
				["Gebäude bauen", 0.16, func(): fx.play("build", Vector3(1.5, 0, 2.0), fwd, 1.0, Color("ffb040"))],
				["Reparatur", 0.25, func():
					fx.tracer(Vector3(0, 1.2, 0), Vector3(1.5, 0.8, 2.0), Color("ffd070"))
					fx.play("heal", Vector3(1.5, 0, 2.0), fwd, 1.0, Color("ffd070"))],
				["R Überspannung", 0.1, func():
					fx.play("overcharge", z, fwd, 6.0, UiTheme.CYAN)
					_hold("aura", z, 1.2, UiTheme.CYAN)],
			]
	return [
		["Druckwelle", 0.2, func(): fx.nova(z, 4.0, UiTheme.PURPLE_LIGHT)],
		["Blitz", 0.05, func(): fx.bolt(Vector3(-3, 1.4, 0), Vector3(3, 1.0, 1.5))],
		["Leuchtspur", 0.07, func(): fx.tracer(Vector3(-3, 1.2, 0), Vector3(3, 1.0, 1.5), UiTheme.CYAN)],
		["Strahl", 0.03, func(): fx.beam(Vector3(-3, 1.4, 0), Vector3(3, 1.0, 1.5), UiTheme.HAVE, 0.1)],
		["Ausweichen", 0.12, func(): fx.dash_trail(Vector3(-2.5, 0, 0), Vector3(5, 0, 1))],
		["Treffer: Blut, Glut, Eis", 0.12, func():
			for i in 3:
				fx.impact(Vector3(-2.5 + i * 2.5, 1.2, 1), ["physical", "fire", "cold"][i], Vector3(0, 0, 1))],
		["Treffer: Blitz, Gift, Wind, Arkan", 0.12, func():
			for i in 4:
				fx.impact(Vector3(-3 + i * 2.0, 1.2, 1), ["lightning", "poison", "wind", "arcane"][i], Vector3(0, 0, 1))],
		["Heilfläche", 0.2, func(): fx.disc(z, 3.0, Color(0.3, 0.9, 0.5), 0.5)],
	]


var _moving: Array = []


func _shot(look: String, c: Color, size: float, speed: float) -> void:
	var n := HdFxParts.shot(look, c, size)
	n.position = Vector3(0, 1.0, -2.5)
	stage.add_child(n)
	_moving.append([n, speed])


func _hold(id: String, at: Vector3, size: float, c: Color, to := Vector3.ZERO) -> void:
	_holds.append([id, at, size, c, to])


var _holds: Array = []


func _process(dt: float) -> void:
	for m in _moving:
		if is_instance_valid(m[0]):
			m[0].position.z += float(m[1]) * dt
	for i in _holds.size():
		var h: Array = _holds[i]
		if is_instance_valid(fx): fx.hold("probe%d" % i, h[0], h[1], h[2], h[3], h[4])


func _enemy_warning(id: String) -> void:
	var ab: Dictionary = Database.load_json("res://data/heroes.json").abilities[id]
	var shapes := {"arc":HdTelegraph.ARC,"cross":HdTelegraph.CROSS,"box":HdTelegraph.BOX}
	var tele := HdTelegraph.make(int(shapes[str(ab.kind)]))
	tele.radius = float(ab.get("radius", 5))
	tele.inner = float(ab.get("inner", 0))
	tele.angle = float(ab.get("angle", 120))
	tele.length = float(ab.get("length", 8))
	tele.width = float(ab.get("width", 1.5))
	tele.position.y = .03
	tele.progress = .65
	stage.add_child(tele)


func _ready() -> void:
	Sfx.audible = false
	var hero := "basis"
	var output_name := ""
	var only := ""
	var at_time := -1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			output_name = arg.trim_prefix("--name=").validate_filename()
		if arg.begins_with("--held="):
			hero = arg.trim_prefix("--held=")
		if arg.begins_with("--nur="):
			only = arg.trim_prefix("--nur=")
		if arg.begins_with("--zeit="):
			at_time = float(arg.trim_prefix("--zeit="))
	get_window().size = TILE
	UiTheme.use_skin(UiTheme.BOLLWERK)
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
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	add_child(HdDev.cyl(9.0, 9.0, 0.2, HdCathedral.floor_material(), Vector3(0, -0.1, 0), 32))
	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.position = Vector3(0, 8.0, -8.6)
	add_child(camera)
	camera.look_at(Vector3(0, 0.9, 0.8))
	if hero == "gegner":
		camera.position = Vector3(0, 13, -14)
		camera.look_at(Vector3.ZERO)
	camera.current = true
	var label := Label.new()
	label.position = Vector2(14, 10)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	var shots := _shots(hero)
	if only != "":
		shots = shots.filter(func(s): return str(s[0]).to_lower().contains(only.to_lower()))
	var definition: Dictionary = {}
	for entry in Database.load_json("res://data/heroes_helden.json").heroes:
		if str(entry.id) == hero:
			definition = entry
	var images: Array = []
	# Erster Durchlauf ohne Bild: Shader und Materialien sind danach geladen, die Zeitpunkte stimmen.
	stage = Node3D.new()
	add_child(stage)
	fx = HdFx.new()
	stage.add_child(fx)
	for entry in shots:
		(entry[2] as Callable).call()
		await get_tree().create_timer(0.12).timeout
	_moving.clear()
	_holds.clear()
	stage.queue_free()
	await get_tree().create_timer(0.3).timeout
	for entry in shots:
		var times: Array = [float(entry[1])]
		if only != "":
			times = [at_time] if at_time >= 0.0 else [float(entry[1]) * 0.4, float(entry[1]), float(entry[1]) * 1.8, float(entry[1]) * 3.0]
		for moment in times:
			if entry.size()>4:
				for hero_def in Database.load_json("res://data/heroes_helden.json").heroes:
					if str(hero_def.id) == str(entry[4]): definition = hero_def
			stage = Node3D.new()
			add_child(stage)
			fx = HdFx.new()
			stage.add_child(fx)
			_moving.clear()
			_holds.clear()
			if not definition.is_empty():
				var model: Node3D = load(str(definition.model)).instantiate()
				model.scale = Vector3.ONE * float(definition.get("model_scale", 1.0))
				model.rotation.y = PI
				stage.add_child(model)
				Metall.modell(model)
				for player: AnimationPlayer in model.find_children("*", "AnimationPlayer", true, false):
					if player.has_animation("idle"):
						player.play(str(entry[3]) if entry.size()>3 and player.has_animation(str(entry[3])) else "idle")
			label.text = str(entry[0]) + ("  %.2f s" % moment if only != "" else "")
			for i in 3:
				await get_tree().process_frame
			(entry[2] as Callable).call()
			await get_tree().create_timer(float(moment)).timeout
			await RenderingServer.frame_post_draw
			images.append(get_viewport().get_texture().get_image())
			stage.queue_free()
			await get_tree().process_frame
	var columns := 4 if images.size() > 4 else maxi(images.size(), 1)
	var rows := ceili(float(images.size()) / columns)
	var sheet := Image.create(TILE.x * columns, TILE.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("10131a"))
	for i in images.size():
		var img: Image = images[i]
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != TILE:
			img.resize(TILE.x, TILE.y)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % columns) * TILE.x, (i / columns) * TILE.y))
	var path := "res://.godot/fx-%s.png" % (only.to_lower().replace(" ", "-") if only != "" else hero)
	if output_name != "": path = "res://.godot/" + output_name + ".png"
	sheet.save_png(path)
	if hero == "alle":
		var definitions: Array = Database.load_json("res://data/heroes_helden.json").heroes.filter(func(h): return str(h.get("kit", "")) == "roster")
		for hero_index in definitions.size():
			var strip := Image.create(TILE.x*5,TILE.y,false,Image.FORMAT_RGBA8)
			for k in 5:
				strip.blit_rect(images[hero_index*5+k],Rect2i(Vector2i.ZERO,TILE),Vector2i(k*TILE.x,0))
			strip.save_png("res://.godot/fx-kader-%s.png" % definitions[hero_index].id)
	print("BILD ", ProjectSettings.globalize_path(path), " ", images.size(), " Effekte")
	get_tree().quit()
