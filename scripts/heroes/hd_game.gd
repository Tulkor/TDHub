class_name HdGame
extends Node3D
## Bollwerk (Arbeitstitel), Hero-Defense-Modus "heroes" (Design: /mnt/project-files/docs/hero-defense/,
## Abschnitte 2, 5a, 6, 13, 15): Feste in der Mitte, 4 Straßen (bei 1–3 Spielern 2) mit je Vorwerk und
## Innentor, 10 Wellen Sumpfvolk mit ausweichbaren Fähigkeiten (Warnflächen), Boss in Welle 10.
## Wirtschaft (Gold, Holz, Shop, Rezepte, Inventar) in HdShop, Straßen in HdRoad.
## Steuerung WASD (Laufen, Maus zielt, Linksklick Angriff) oder Maus (Rechtsklick laufen/angreifen,
## Q W E R mit Zielvorschau), Leertaste Ausweichen. Alle Werte in data/heroes.json.
## Ablauf: setup → play → over. Logik läuft in step(dt), damit Tests und Bilder sie ohne Eingabe treiben.

signal changed
signal message(text: String)
signal floated(pos: Vector3, text: String, color: Color)
signal ended(victory: bool)

const DATA := "res://data/heroes.json"
const SETTINGS := "user://heroes.cfg"
## Tasten der Fähigkeiten 1–4 je Steuerung (WASD belegt W, deshalb dort Q E F R).
const KEYS := {"wasd": [KEY_Q, KEY_E, KEY_F, KEY_R], "maus": [KEY_Q, KEY_W, KEY_E, KEY_R]}

var cfg: Dictionary = {}
var ability_defs: Dictionary = {}
var enemy_defs: Dictionary = {}

var state := "setup"
var paused := false
var difficulty := 1
var wave := 0
var wave_time := 0.0
var play_time := 0.0
var lives := 20
var max_lives := 20
var kills := 0
var leaks := 0
var enemies: Array = []
var buildings: Array = []
var spawn_queue: Array = []     ## {t, id}
var projectiles: Array = []     ## {pos, dir, speed, left, width, dmg, node, from_hero, slow, slow_time}
var pools: Array = []           ## {pos, r, dps, until, tele}
var obstacles: Array = []       ## [Vector3, Radius]
var wave_log: Array = []
var debug := false
var bot := false                ## Tests/Bilder: keine Eingabe lesen
var control := "wasd"           ## wasd | maus
var quickcast := false          ## Maus-Modus: Q W E R sofort statt Zielvorschau
var result_news: Dictionary = {}

var roads: Array = []           ## HdRoad, alle aktiven Straßen (Spielerzahl, Einstellung)
var players := 1                ## Etappe 2a: Einzelspieler; bestimmt Straßen und Gegnerleben (players)
var road_choice := 0            ## 0 = nach Spielerzahl, 4 = immer alle vier Straßen (Einstellung)
var fortress_pos := Vector3.ZERO
var stones: Array = []          ## Teleport-Steine {pos, to, road}
var shop: HdShop
var _road_root: Node3D
var _tp_cd := 0.0
var tp_hold := 0.0              ## so lange steht der Held schon auf tp_stone
var tp_stone: Dictionary = {}
## Erste aktive Straße (Tests und Etappe-1-Aufrufe ohne Straßenangabe).
var road_len: float:
	get:
		return roads[0].length

var hero: HdHero
var fx: HdFx
var camera: Camera3D
var hud  ## HdHud
var cam_dist := 24.0
var cam_follow := true
var cam_pos := Vector3.ZERO
var preview_slot := -1
var _preview: HdTelegraph
var _wave_kills := 0
var _wave_leaks := 0
var _wave_damage0 := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	UiTheme.use_skin(UiTheme.ARCADE)
	cfg = Database.load_json(DATA)
	for k in cfg.abilities:
		ability_defs[k] = cfg.abilities[k]
	for e in cfg.enemies:
		enemy_defs[str(e.id)] = e
	rng.randomize()
	_load_settings()
	var f: Array = cfg.arena.fortress
	fortress_pos = Vector3(float(f[0]), 0, float(f[1]))
	_build_world()
	_build_roads()
	shop = HdShop.new(self)
	hero.set_bonus(shop.bonus())
	hud = load("res://scripts/heroes/hd_hud.gd").new()
	hud.game = self
	add_child(hud)
	if Session.skip_setup:
		start(clampi(Session.difficulty, 0, cfg.difficulties.size() - 1))
	else:
		hud.show_setup()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS) == OK:
		control = str(c.get_value("steuerung", "modus", "wasd"))
		quickcast = bool(c.get_value("steuerung", "schnellzauber", false))
		road_choice = int(c.get_value("spiel", "strassen", 0))
		HdTelegraph.palette = int(c.get_value("warnflaechen", "farbe", 0))
		HdTelegraph.outline = int(c.get_value("warnflaechen", "umriss", 0))
	if not KEYS.has(control):
		control = "wasd"


func save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("steuerung", "modus", control)
	c.set_value("steuerung", "schnellzauber", quickcast)
	c.set_value("spiel", "strassen", road_choice)
	c.set_value("warnflaechen", "farbe", HdTelegraph.palette)
	c.set_value("warnflaechen", "umriss", HdTelegraph.outline)
	c.save(SETTINGS)


func diff() -> Dictionary:
	return cfg.difficulties[clampi(difficulty, 0, cfg.difficulties.size() - 1)]


## Zeile der Spielerzahl-Tabelle (Design Abschnitt 12): Straßen, Gegnerleben, Gold je Kill.
func scaling() -> Dictionary:
	for row in cfg.players:
		if players <= int(row.max):
			return row
	return cfg.players[-1]


func active_road_ids() -> Array:
	if road_choice == 4:
		var all: Array = []
		for rd in cfg.arena.roads:
			all.append(str(rd.id))
		return all
	return scaling().roads


func key_name(slot: int) -> String:
	return OS.get_keycode_string(KEYS[control][slot])


# ---------------------------------------------------------------- Straßen

## Aktive Straßen mit Torwerken und Teleport-Steinen bauen (neu bei geänderter Einstellung).
func _build_roads() -> void:
	if _road_root:
		for bl in buildings:
			if bl.road != null:
				bl.queue_free()
		buildings = buildings.filter(func(x): return x.road == null)
		_road_root.queue_free()
	_road_root = Node3D.new()
	add_child(_road_root)
	roads.clear()
	stones.clear()
	var fast := {}
	for gd in cfg.arena.gates:
		fast[str(gd.kind)] = float(gd.get("fast", 1.0))
	var ids := active_road_ids()
	var rw := float(cfg.arena.road_width)
	for rd in cfg.arena.roads:
		var r := HdRoad.new(rd, fast)
		var on := ids.has(r.id)
		_draw_road(r, on)
		if not on:
			continue
		roads.append(r)
		for gd in cfg.arena.gates:
			var bl := HdBuilding.new()
			bl.setup(self, gd, r)
			add_child(bl)
			buildings.append(bl)
			r.gates.append(bl)
		# Teleport-Steine: an der Feste zur Straße hinaus (vor das Vorwerk), beim Vorwerk zurück
		var tp: Dictionary = cfg.arena.teleport
		var vs: float = r.length * float(r.gate("vorwerk").def.at)
		var off := rw * 0.5 + float(tp.offset)
		var home := r.point(r.length - 5.0) + r.side(r.length - 5.0) * off
		var out := r.point(vs + 4.0)
		var back := r.point(vs + 2.0) - r.side(vs + 2.0) * off
		stones.append({"pos": home, "to": out, "road": r, "out": true})
		stones.append({"pos": back, "to": hero_spawn(), "road": r, "out": false})
		for st in [home, back]:
			_road_root.add_child(HdDev.cyl(1.0, 1.2, 0.3, HdDev.mat(Color("3a3f55"), 0.5), st + Vector3(0, 0.15, 0), 12))
			_road_root.add_child(HdDev.cyl(0.7, 0.7, 0.06, HdDev.mat(UiTheme.PURPLE_LIGHT, 0.5, 1.6), st + Vector3(0, 0.34, 0), 12))


func _draw_road(r: HdRoad, on: bool) -> void:
	var rw := float(cfg.arena.road_width)
	var road_mat := HdDev.mat(Color("8a7356") if on else Color("5d5546"))
	for i in r.points.size() - 1:
		var a: Vector3 = r.points[i]
		var c: Vector3 = r.points[i + 1]
		var seg := MeshInstance3D.new()
		var sm := PlaneMesh.new()
		sm.size = Vector2(rw, a.distance_to(c))
		seg.mesh = sm
		seg.material_override = road_mat
		seg.position = (a + c) * 0.5 + Vector3(0, 0.005, 0)
		seg.rotation.y = atan2(c.x - a.x, c.z - a.z)
		_road_root.add_child(seg)
		_road_root.add_child(HdDev.cyl(rw * 0.5, rw * 0.5, 0.01, road_mat, a + Vector3(0, 0.006, 0), 20))
	# Spawn-Tor, quer zur Straße; gesperrte Straßen haben einen Balken davor
	var sp: Vector3 = r.points[0]
	var sd := r.side(0.0)
	var gate_mat := HdDev.mat(Color("5d4a6a") if on else Color("4a4a4a"), 0.5)
	for side in [-1.0, 1.0]:
		_road_root.add_child(HdDev.box(Vector3(0.8, 4.0, 0.8), gate_mat, sp + sd * side * (rw * 0.5 + 0.6) + Vector3(0, 2.0, 0)))
	var top := HdDev.box(Vector3(rw + 2.0, 0.6, 0.8), gate_mat, sp + Vector3(0, 4.2, 0))
	top.rotation.y = atan2(sd.x, sd.z) + PI * 0.5
	_road_root.add_child(top)
	if not on:
		var bar := HdDev.box(Vector3(rw + 1.0, 1.0, 0.6), HdDev.mat(Color("6b4a2a"), 0.5), r.point(3.0) + Vector3(0, 0.8, 0))
		bar.rotation.y = top.rotation.y
		_road_root.add_child(bar)


func road_point(s: float, lane := 0.0) -> Vector3:
	return roads[0].point(s, lane)


func road_project(pos: Vector3, s0: float, s1: float) -> float:
	return roads[0].project(pos, s0, s1)


func road_by_id(id: String) -> HdRoad:
	for r in roads:
		if r.id == id:
			return r
	return null


## Straße, der der Punkt am nächsten liegt.
func nearest_road(pos: Vector3) -> HdRoad:
	var best: HdRoad = roads[0]
	var bd := INF
	for r in roads:
		var d: float = r.distance(pos)
		if d < bd:
			bd = d
			best = r
	return best


func gate_by_name(label: String):
	for b in buildings:
		if b.label() == label:
			return b
	return null


## Neben der Feste, zwischen den Straßen (diagonal).
func hero_spawn() -> Vector3:
	return fortress_pos + Vector3(6.5, 0, 6.5)


# ---------------------------------------------------------------- Welt

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("10131a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8a96b0")
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = Display.quality > 0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = Display.quality > 0
	add_child(sun)

	var b: Array = cfg.arena.bounds
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(float(b[2]) - float(b[0]) + 30.0, float(b[3]) - float(b[1]) + 30.0)
	ground.mesh = gm
	ground.position = Vector3((float(b[0]) + float(b[2])) * 0.5, -0.02, (float(b[1]) + float(b[3])) * 0.5)
	ground.material_override = HdDev.mat(Color("4b5a44"))
	add_child(ground)
	# Felsen (Hindernisse)
	for o in cfg.arena.obstacles:
		var p := Vector3(float(o[0]), 0, float(o[1]))
		var r := float(o[2])
		obstacles.append([p, r])
		var rock := HdDev.cyl(r * 0.7, r, r * 1.2, HdDev.mat(Color("6f6a64"), 0.5), p + Vector3(0, r * 0.6, 0), 7)
		rock.rotation.y = fmod(p.x * 1.7 + p.z, TAU)
		add_child(rock)
	# Feste
	var fr := float(cfg.arena.fortress_radius)
	var wall := HdDev.mat(Color("9a9aa4"), 0.5)
	add_child(HdDev.cyl(fr, fr * 1.05, 3.0, wall, fortress_pos + Vector3(0, 1.5, 0), 8))
	add_child(HdDev.cyl(fr * 0.45, fr * 0.5, 7.0, wall, fortress_pos + Vector3(0, 3.5, 0), 8))
	add_child(HdDev.box(Vector3(1.6, 1.6, 1.6), HdDev.mat(UiTheme.CYAN, 0.5, 1.4), fortress_pos + Vector3(0, 7.8, 0)))
	for k in 6:
		var a := k * TAU / 6.0
		add_child(HdDev.box(Vector3(1.2, 1.4, 1.2), wall, fortress_pos + Vector3(cos(a) * fr * 0.92, 3.5, sin(a) * fr * 0.92)))
	fx = HdFx.new()
	add_child(fx)
	hero = HdHero.new()
	hero.setup(self, cfg.hero)
	hero.position = hero_spawn()
	add_child(hero)
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	cam_pos = hero.position
	_place_camera()


func _place_camera() -> void:
	var pitch := deg_to_rad(56.0)
	camera.position = cam_pos + Vector3(0, sin(pitch), cos(pitch)) * cam_dist
	camera.look_at(cam_pos + Vector3(0, 0.5, 0), Vector3.UP)


# ---------------------------------------------------------------- Eingabe

func mouse_ground() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var o := camera.project_ray_origin(mp)
	var d := camera.project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return hero.position
	var t := -o.y / d.y
	return o + d * t


func _unhandled_input(ev: InputEvent) -> void:
	if bot:
		return
	if ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				cam_dist = maxf(12.0, cam_dist - 1.5)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam_dist = minf(44.0, cam_dist + 1.5)
			MOUSE_BUTTON_LEFT:
				if preview_slot >= 0:
					_cast_preview()
			MOUSE_BUTTON_RIGHT:
				if preview_slot >= 0:
					_end_preview()
				elif control == "maus" and state == "play":
					var at := mouse_ground()
					var e = enemy_at(at)
					hero.order = {"kind": "attack", "target": e} if e else {"kind": "move", "point": at}
		return
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	var key: int = ev.keycode
	if key == KEY_ESCAPE:
		if preview_slot >= 0:
			_end_preview()
		else:
			hud.toggle_menu()
		return
	if state != "play":
		return
	if key == KEY_P:
		paused = not paused
		changed.emit()
		return
	if key == KEY_Y:
		cam_follow = not cam_follow
		return
	if key == KEY_B:
		hud.econ.toggle()
		return
	if key == KEY_N:
		call_early()
		return
	if paused:
		return
	if key == KEY_SPACE:
		var dir := hero.move_dir if control == "wasd" else mouse_ground() - hero.position
		hero.dodge(dir)
		return
	var slot: int = KEYS[control].find(key)
	if slot < 0 and key >= KEY_1 and key <= KEY_4:
		slot = key - KEY_1
	if slot >= 0:
		if control == "wasd" or quickcast:
			hero.cast(slot, mouse_ground())
		else:
			preview_slot = slot
			changed.emit()


func _cast_preview() -> void:
	hero.cast(preview_slot, mouse_ground())
	_end_preview()


func _end_preview() -> void:
	preview_slot = -1
	if _preview:
		_preview.queue_free()
		_preview = null
	changed.emit()


## Zielvorschau im Maus-Modus: Form der Fähigkeit in Blau am Helden bzw. Mauspunkt.
func _update_preview() -> void:
	if preview_slot < 0:
		return
	var a := hero.ability(preview_slot)
	var want := ""
	match str(a.kind):
		"cone":
			want = "cone"
		"line", "skillshot":
			want = "line"
		_:
			want = "circle"
	if _preview == null or _preview.get_meta("kind", "") != want:
		if _preview:
			_preview.queue_free()
		match want:
			"cone":
				_preview = HdTelegraph.cone(float(a.range), float(a.angle), HdTelegraph.BLUE)
			"line":
				_preview = HdTelegraph.line(float(a.range), float(a.get("width", 1.0)), HdTelegraph.BLUE)
			_:
				_preview = HdTelegraph.circle(float(a.get("radius", 3.0)), HdTelegraph.BLUE)
		_preview.set_meta("kind", want)
		add_child(_preview)
	_preview.position = Vector3(hero.position.x, 0.04, hero.position.z)
	_preview.aim(mouse_ground() - hero.position)


func _process(dt: float) -> void:
	if state == "play" and not bot and not paused:
		var aim := mouse_ground()
		hero.aim = aim
		if control == "wasd":
			var v := Vector3.ZERO
			if Input.is_key_pressed(KEY_W):
				v.z -= 1
			if Input.is_key_pressed(KEY_S):
				v.z += 1
			if Input.is_key_pressed(KEY_A):
				v.x -= 1
			if Input.is_key_pressed(KEY_D):
				v.x += 1
			hero.move_dir = v.normalized()
			hero.attack_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not UiUtil.mouse_over_ui(get_viewport())
			hero.auto_attack = false
		else:
			hero.move_dir = Vector3.ZERO
			hero.attack_held = false
			hero.auto_attack = true
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and hero.order.get("kind", "") == "move" and preview_slot < 0:
				hero.order.point = aim
		_update_preview()
	if cam_follow or bot:
		cam_pos = cam_pos.lerp(hero.position, clampf(dt * 6.0, 0.0, 1.0))
	elif not bot:
		var pan := Vector3.ZERO
		if Input.is_key_pressed(KEY_UP):
			pan.z -= 1
		if Input.is_key_pressed(KEY_DOWN):
			pan.z += 1
		if Input.is_key_pressed(KEY_LEFT):
			pan.x -= 1
		if Input.is_key_pressed(KEY_RIGHT):
			pan.x += 1
		cam_pos += pan * dt * 25.0
	_place_camera()


func _physics_process(dt: float) -> void:
	if state == "play" and not paused:
		step(dt)


# ---------------------------------------------------------------- Ablauf

func start(diff_index: int) -> void:
	difficulty = diff_index
	Session.difficulty = diff_index
	lives = int(diff().get("lives", 20))
	max_lives = lives
	if active_road_ids().size() != roads.size():
		_build_roads()
	state = "play"
	start_wave(1)
	hud.on_started()


func start_wave(n: int) -> void:
	if wave > 0:
		_wave_reward(wave)
		wave_log.append({"wave": wave, "kills": _wave_kills, "leaks": _wave_leaks, "damage": roundi(hero.damage_done - _wave_damage0)})
	wave = n
	wave_time = 0.0
	_wave_kills = 0
	_wave_leaks = 0
	_wave_damage0 = hero.damage_done
	var w: Dictionary = cfg.waves.list[n - 1]
	# Gruppen reihum mischen und gleichmäßig über das Spawn-Fenster verteilen
	var left: Array = []
	for g in w.groups:
		left.append([str(g[0]), int(g[1])])
	var order: Array = []
	var any := true
	while any:
		any = false
		for g in left:
			if g[1] > 0:
				order.append(g[0])
				g[1] -= 1
				any = true
	# reihum auf die aktiven Straßen, gleichzeitig an allen Toren; der Boss nimmt eine zufällige
	var window := float(cfg.waves.spawn_window)
	var per := ceili(order.size() / float(roads.size()))
	var boss_road: HdRoad = roads[rng.randi() % roads.size()]
	for i in order.size():
		var id: String = order[i]
		var rd: HdRoad = roads[i % roads.size()]
		var t := window * (i / roads.size()) / maxf(per, 1.0)
		if str(enemy_defs[id].get("rank", "")) == "boss":
			t = minf(6.0, window)
			rd = boss_road
		spawn_queue.append({"t": play_time + t, "id": id, "road": rd})
	spawn_queue.sort_custom(func(a, b): return a.t < b.t)
	if bool(w.get("boss", false)):
		message.emit(tr("Welle %d: Der Moorkönig kommt über die %s!") % [n, tr(boss_road.name)])
	else:
		message.emit(tr("Welle %d") % n)
	changed.emit()


func can_call_early() -> bool:
	return state == "play" and spawn_queue.is_empty() and wave < int(cfg.waves.count)


func call_early() -> void:
	if can_call_early():
		var bonus := roundi(maxf(0.0, float(cfg.waves.time) - wave_time) * float(cfg.economy.early_gold))
		if bonus > 0:
			shop.add_gold(bonus)
			message.emit(tr("Früher gerufen: +%d Gold") % bonus)
		start_wave(wave + 1)


## Belohnung für eine überstandene Welle (beim Start der nächsten bzw. beim Sieg).
func _wave_reward(n: int) -> void:
	shop.add_gold(shop.wave_gold(n))
	var w: Dictionary = cfg.waves.list[n - 1]
	var wd := int(cfg.economy.boss_wood) if bool(w.get("boss", false)) else int(cfg.economy.wave_wood)
	shop.add_wood(maxi(1, roundi(wd * float(diff().get("wood", 1.0)))))


func step(dt: float) -> void:
	if state != "play":
		return
	play_time += dt
	wave_time += dt
	var now := play_time
	while not spawn_queue.is_empty() and spawn_queue[0].t <= now:
		var s: Dictionary = spawn_queue.pop_front()
		spawn(s.id, null, 0.0, s.get("road"))
	if wave < int(cfg.waves.count) and wave_time >= float(cfg.waves.time):
		start_wave(wave + 1)
	hero.step(dt, now)
	_step_stones(dt)
	for e in enemies:
		if e.dead:
			continue
		e.step(dt, now)
		if not e.dead and now < e.burn_until:
			hero_hit(e, e.burn_dps * dt, "burn", true)
	for b in buildings:
		b.step(dt)
	_step_projectiles(dt)
	_step_pools(dt, now)
	enemies = enemies.filter(func(e): return not e.dead)
	if state == "play" and wave >= int(cfg.waves.count) and spawn_queue.is_empty() and enemies.is_empty():
		_finish(true)


## Teleport-Steine: Held steht kurz drauf (teleport.hold) → zur anderen Seite (Feste ↔ vor das Vorwerk).
func _step_stones(dt: float) -> void:
	_tp_cd = maxf(0.0, _tp_cd - dt)
	if _tp_cd > 0.0 or not hero.alive() or hero.dodging():
		return
	var tp: Dictionary = cfg.arena.teleport
	for st in stones:
		var d: Vector3 = hero.position - st.pos
		d.y = 0.0
		if d.length() <= float(tp.radius):
			tp_stone = st
			tp_hold += dt
			if tp_hold >= float(tp.get("hold", 0.8)):
				teleport_hero(st.to)
			return
	tp_hold = 0.0
	tp_stone = {}


func teleport_hero(to: Vector3) -> void:
	fx.nova(hero.position, 2.0, UiTheme.PURPLE_LIGHT)
	hero.position = to
	hero.order = {}
	_resolve(hero)
	fx.nova(hero.position, 2.0, UiTheme.PURPLE_LIGHT)
	_tp_cd = float(cfg.arena.teleport.cooldown)
	tp_hold = 0.0
	tp_stone = {}
	if not bot:
		cam_pos = hero.position


func spawn(id: String, at = null, road_s := 0.0, rd = null) -> HdEnemy:
	var e := HdEnemy.new()
	e.road = rd if rd != null else (nearest_road(at) if at != null else roads[0])
	e.setup(self, enemy_defs[id], wave)
	e.road_s = road_s
	e.position = at if at != null else e.road.point(road_s, e.lane)
	add_child(e)
	enemies.append(e)
	return e


## Beschwörerkreis: neue Gegner um den Beschwörer, sie laufen ab seiner Stelle die Straße weiter.
func summon(src: HdEnemy, id: String, count: int, r: float) -> void:
	for k in count:
		var a := TAU * k / maxf(count, 1)
		var p := src.position + Vector3(cos(a), 0, sin(a)) * r * 0.7
		var e := spawn(id, p, src.road_s, src.road)
		_resolve(e)


func leak(e: HdEnemy) -> void:
	if e.dead:
		return
	_remove(e)
	leaks += 1
	_wave_leaks += 1
	lives -= int(e.def.get("lives", 1))
	message.emit(tr("%s hat die Feste erreicht!") % tr(str(e.def.name)))
	if lives <= 0:
		lives = 0
		_finish(false)
	changed.emit()


func _remove(e: HdEnemy) -> void:
	e.dead = true
	for t in e.cast.get("tele", []):
		if is_instance_valid(t):
			t.queue_free()
	e.cast = {}
	e.queue_free()


func _kill(e: HdEnemy) -> void:
	if e.dead:
		return
	_remove(e)
	kills += 1
	_wave_kills += 1
	hero.kills += 1
	hero.add_xp(float(e.def.get("xp", 10)))
	var g := shop.kill_gold(e)
	if g > 0:
		shop.add_gold(g)
		floater(e.position + Vector3(0, e.height() + 1.0, 0), "+%d" % g, UiTheme.COIN)
	changed.emit()


func on_level_up() -> void:
	message.emit(tr("Stufe %d!") % hero.level)
	floater(hero.position + Vector3(0, 2.6, 0), tr("Stufe %d") % hero.level, UiTheme.COIN)
	changed.emit()


# ---------------------------------------------------------------- Bewegung

## Bewegt eine Einheit (Held oder Gegner) mit Ausweichen: Gegner halten Abstand zueinander und zum
## Helden und lenken vor Felsen/Gebäuden seitlich weg. Danach werden Überlappungen aufgelöst, damit
## niemand in einem Hindernis landet. direct = ohne Lenken (Ansturm, Rückstoß, Ausweichen).
func move_unit(u: Node3D, dir: Vector3, spd: float, dt: float, direct := false) -> void:
	dir.y = 0.0
	var v := dir * spd
	if u is HdEnemy and not direct:
		var push := Vector3.ZERO
		for o in enemies:
			if o == u or o.dead:
				continue
			push += _sep(u, o.position, o.radius)
		if hero.alive():
			push += _sep(u, hero.position, hero.radius)
		v += push * spd * 1.5
		var lat := Vector3(-dir.z, 0, dir.x)
		for ob in _all_obstacles():
			var to: Vector3 = ob[0] - u.position
			to.y = 0.0
			var dist := to.length()
			var clear: float = ob[1] + u.radius
			if dist < clear + 2.5 and to.dot(dir) > 0.0:
				var side := -signf(to.dot(lat))
				if side == 0.0:
					side = 1.0
				v += lat * side * spd * (clear + 2.5 - dist) / 2.5 * 1.3
		if v.length() > spd * 1.3:
			v = v.normalized() * spd * 1.3
	u.position += v * dt
	_resolve(u)


func _sep(u: Node3D, p: Vector3, r: float) -> Vector3:
	var d: Vector3 = u.position - p
	d.y = 0.0
	var min_d: float = u.radius + r + 0.15
	var l := d.length()
	if l >= min_d:
		return Vector3.ZERO
	if l < 0.001:
		return Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
	return d / l * (min_d - l) / min_d


func _all_obstacles() -> Array:
	var all := obstacles.duplicate()
	for b in buildings:
		if b.alive():
			all.append([b.position, b.radius])
	all.append([fortress_pos, float(cfg.arena.fortress_radius)])
	return all


## Aus Hindernissen herausschieben und im Spielfeld halten.
func _resolve(u: Node3D) -> void:
	for ob in _all_obstacles():
		var d: Vector3 = u.position - ob[0]
		d.y = 0.0
		var min_d: float = ob[1] + u.radius
		var l := d.length()
		if l < min_d:
			if l < 0.001:
				d = Vector3(1, 0, 0)
				l = 1.0
			u.position += d / l * (min_d - l)
	var b: Array = cfg.arena.bounds
	u.position.x = clampf(u.position.x, float(b[0]), float(b[2]))
	u.position.z = clampf(u.position.z, float(b[1]), float(b[3]))
	u.position.y = 0.0


# ---------------------------------------------------------------- Abfragen

func nearest_enemy(at: Vector3, r: float, skip: Array = []) -> HdEnemy:
	var best: HdEnemy = null
	var best_d := r
	for e in enemies:
		if e.dead or skip.has(e):
			continue
		var d: float = Vector2(e.position.x - at.x, e.position.z - at.z).length() - e.radius
		if d <= best_d:
			best_d = d
			best = e
	return best


func enemy_at(at: Vector3) -> HdEnemy:
	return nearest_enemy(at, 0.8)


## Nächster Gegner im Bogen (Grad) vor dem Helden.
func enemy_in_arc(at: Vector3, dir: Vector3, r: float, arc: float) -> HdEnemy:
	var best: HdEnemy = null
	var best_d := INF
	for e in enemies:
		if e.dead:
			continue
		if HdTelegraph.in_shape(HdTelegraph.CONE, at, dir, r, 0, arc, 0, 0, e.position, e.radius):
			var d := at.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	return best


func enemies_in(kind: int, origin: Vector3, dir: Vector3, r: float, r_in: float, deg: float, l: float, w: float) -> Array:
	var out: Array = []
	for e in enemies:
		if not e.dead and HdTelegraph.in_shape(kind, origin, dir, r, r_in, deg, l, w, e.position, e.radius):
			out.append(e)
	return out


func building_near(at: Vector3, r: float) -> HdBuilding:
	for b in buildings:
		if b.alive() and at.distance_to(b.position) - b.radius <= r:
			return b
	return null


# ---------------------------------------------------------------- Schaden

static func armor_factor(a: float) -> float:
	if a >= 0.0:
		return 1.0 - 0.06 * a / (1.0 + 0.06 * a)
	return 2.0 - pow(0.94, -a)


## Schaden des Helden an einem Gegner (zieht dessen Aufmerksamkeit auf den Helden).
func hero_hit(e: HdEnemy, amount: float, _kind: String, quiet := false) -> void:
	if e.dead:
		return
	var dmg := amount * armor_factor(e.armor - e.cc.armor_reduction(play_time))
	e.hp -= dmg
	e.hit_flash = 0.12
	hero.damage_done += dmg
	if hero.b("lifesteal") > 0.0 and hero.alive():
		hero.hp = minf(hero.max_hp, hero.hp + dmg * hero.b("lifesteal"))
	e.provoke(hero)
	if not quiet:
		floater(e.position + Vector3(0, e.height() + 0.4, 0), str(roundi(dmg)), UiTheme.TEXT)
	if e.hp <= 0.0:
		_kill(e)


func building_hit(e: HdEnemy, amount: float, b: HdBuilding) -> void:
	if e.dead:
		return
	e.hp -= amount * armor_factor(e.armor - e.cc.armor_reduction(play_time))
	e.provoke(b)
	if e.hp <= 0.0:
		_kill(e)


## Harte CC mit abnehmender Wirkung. Gibt die tatsächliche Dauer zurück (0 = immun).
func stun(e: HdEnemy, duration: float) -> float:
	var eff := e.cc.hard(duration, play_time)
	var at := e.position + Vector3(0, e.height() + 0.9, 0)
	if eff <= 0.0:
		floater(at, tr("Immun"), UiTheme.COIN)
	else:
		floater(at, tr("Betäubt %.1f s") % eff, UiTheme.CYAN)
	return eff


func damage_hero(amount: float, _src, quiet := false) -> void:
	if not hero.alive():
		return
	if hero.dodging():
		return
	var dmg := amount * armor_factor(hero.armor - hero.cc.armor_reduction(play_time))
	if play_time < hero.shield_until:
		dmg *= 1.0 - hero.shield
	hero.hp -= dmg
	hero.damage_taken += dmg
	if not quiet:
		floater(hero.position + Vector3(0, 2.4, 0), str(roundi(dmg)), UiTheme.MISSING)
	if hero.hp <= 0.0:
		hero.hp = 0.0
		hero.die()
		changed.emit()


func damage_building(b: HdBuilding, amount: float) -> void:
	if not b.alive():
		return
	b.hp -= amount * armor_factor(b.armor)
	if b.hp <= 0.0:
		b.hp = 0.0
		b.destroy()
		message.emit(tr("%s zerstört!") % b.label())
		if b.kind == "vorwerk" and b.road != null:
			message.emit(tr("Gegner der %s laufen schneller!") % tr(b.road.name))
		changed.emit()


## Ausgelöste Warnfläche: trifft den Helden (wenn er nicht ausweicht) und Gebäude darin.
func tele_hit(src: HdEnemy, t: HdTelegraph, dmg: float, knockdown: float) -> void:
	area_hit(src, t.contains(hero.position, hero.radius), dmg, knockdown)
	for b in buildings:
		if b.alive() and t.contains(b.position, b.radius):
			damage_building(b, dmg * 0.5)


func ability_hit_area(src: HdEnemy, kind: int, origin: Vector3, dir: Vector3, r: float, r_in: float, deg: float, l: float, w: float, dmg: float, knockdown: float) -> void:
	area_hit(src, HdTelegraph.in_shape(kind, origin, dir, r, r_in, deg, l, w, hero.position, hero.radius), dmg, knockdown)


func area_hit(src: HdEnemy, inside: bool, dmg: float, knockdown: float) -> void:
	if not inside or not hero.alive():
		return
	if hero.dodging():
		floater(hero.position + Vector3(0, 2.4, 0), tr("Ausgewichen"), UiTheme.CYAN)
		return
	damage_hero(dmg, src)
	if knockdown > 0.0 and hero.alive():
		hero.cc.hard(knockdown, play_time)


func add_tele(t: HdTelegraph) -> void:
	t.position.y = 0.03 + rng.randf() * 0.01
	add_child(t)


func add_pool(at: Vector3, r: float, dps: float, time: float, _src) -> void:
	var t := HdTelegraph.circle(r, HdTelegraph.POISON)
	t.progress = 1.0
	t.position = Vector3(at.x, 0.025, at.z)
	add_child(t)
	pools.append({"pos": at, "r": r, "dps": dps, "until": play_time + time, "tele": t})


func _step_pools(dt: float, now: float) -> void:
	for i in range(pools.size() - 1, -1, -1):
		var p: Dictionary = pools[i]
		if now >= float(p.until):
			if is_instance_valid(p.tele):
				p.tele.trigger(0.3)
			pools.remove_at(i)
			continue
		if hero.alive() and Vector2(hero.position.x - p.pos.x, hero.position.z - p.pos.z).length() <= float(p.r) + hero.radius:
			damage_hero(float(p.dps) * dt, null, true)


func enemy_projectile(src: HdEnemy, from: Vector3, dir: Vector3, spd: float, length: float, width: float, dmg: float) -> void:
	var n := HdDev.box(Vector3(0.12, 0.12, 1.4), HdDev.flat(Color("e0b060")))
	add_child(n)
	projectiles.append({"pos": Vector3(from.x, 1.0, from.z), "dir": dir.normalized(), "speed": spd, "left": length,
		"width": width, "dmg": dmg, "node": n, "from_hero": false, "src": src})


func hero_projectile(from: Vector3, dir: Vector3, a: Dictionary, pw: float) -> void:
	var n := HdDev.sphere(0.4, HdDev.mat(Color("a07850"), 0.5, 0.3))
	add_child(n)
	projectiles.append({"pos": Vector3(from.x, 1.0, from.z), "dir": dir.normalized(), "speed": float(a.speed),
		"left": float(a.range), "width": float(a.width), "dmg": float(a.damage) * pw, "node": n, "from_hero": true,
		"slow": float(a.slow), "slow_time": float(a.slow_time)})


func _step_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		var mv := minf(float(p.speed) * dt, float(p.left))
		p.pos += p.dir * mv
		p.left -= mv
		var n: Node3D = p.node
		n.position = p.pos
		if absf(p.dir.x) + absf(p.dir.z) > 0.0:
			n.rotation.y = atan2(p.dir.x, p.dir.z)
		var done := float(p.left) <= 0.0
		if p.from_hero:
			for e in enemies:
				if e.dead:
					continue
				if Vector2(e.position.x - p.pos.x, e.position.z - p.pos.z).length() <= e.radius + float(p.width) * 0.5:
					hero_hit(e, float(p.dmg), "e")
					if not e.dead:
						e.cc.slow("erdschock", float(p.slow), float(p.slow_time), play_time)
						floater(e.position + Vector3(0, e.height() + 0.9, 0), tr("Verlangsamt"), UiTheme.CYAN)
					done = true
					break
		elif hero.alive() and Vector2(hero.position.x - p.pos.x, hero.position.z - p.pos.z).length() <= hero.radius + float(p.width) * 0.5:
			if hero.dodging():
				floater(hero.position + Vector3(0, 2.4, 0), tr("Ausgewichen"), UiTheme.CYAN)
			else:
				damage_hero(float(p.dmg), p.get("src"))
				done = true
		if done:
			n.queue_free()
			projectiles.remove_at(i)


func floater(at: Vector3, text: String, c: Color) -> void:
	floated.emit(at, text, c)


# ---------------------------------------------------------------- Ende

func _finish(victory: bool) -> void:
	if state == "over":
		return
	state = "over"
	Engine.time_scale = 1.0
	if victory:
		_wave_reward(wave)
	wave_log.append({"wave": wave, "kills": _wave_kills, "leaks": _wave_leaks, "damage": roundi(hero.damage_done - _wave_damage0)})
	result_news = _record(victory)
	ended.emit(victory)
	changed.emit()


func score() -> int:
	return kills * 10 + (wave - 1) * 100 + lives * 50 + (2000 if state == "over" and lives > 0 and wave >= int(cfg.waves.count) else 0)


func _record(victory: bool) -> Dictionary:
	var hid := str(cfg.hero.id)
	var label := "%s %d" % [tr(str(cfg.hero.name)), hero.level]
	var types := {hid: {"built": 1, "tiers": {str(hero.level): 1}, "kills": hero.kills, "damage": hero.damage_done,
		"best_wave_damage": 0.0, "best_wave": 0, "alive": 1}}
	var towers: Array = [{"id": hid, "label": label, "kills": hero.kills, "damage": roundi(hero.damage_done),
		"best_wave_damage": 0, "best_wave": 0}]
	var info := {"map": "Morgenwacht", "difficulty": difficulty, "victory": victory, "wave": wave,
		"waves": int(cfg.waves.count), "lives": lives, "max_lives": max_lives, "score": score(),
		"kills": kills, "play_time": roundi(play_time), "debug": debug, "hero": hid, "hero_level": hero.level}
	return Profile.record_run("heroes", info, {"types": types, "towers": towers, "wave_log": wave_log})


func leave() -> void:
	if state == "play":
		Profile.record_abort("heroes", {"map": "Morgenwacht", "difficulty": difficulty, "wave": wave,
			"waves": int(cfg.waves.count), "play_time": roundi(play_time), "debug": debug})
	Engine.time_scale = 1.0
	Session.goto(Session.return_scene)


func restart() -> void:
	Engine.time_scale = 1.0
	Session.skip_setup = true
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- Bot (Tests, Bilder)

## Einfacher Spieler: weicht Warnflächen aus (Ausweichen, wenn es knapp wird), greift den nächsten
## Gegner an, nutzt Fähigkeiten, Tränke und den Shop (BOT_PLAN), repariert Torwerke und hält die
## Straße mit dem größten Druck. Steuert über dieselben Felder wie WASD.
const BOT_PLAN := ["brecherklinge", "turmschild", "windlaeufer", "schmiedesonne", "bollwerkplatte", "sturmschwinge",
	"blutdorn", "vampirklinge", "festungsherz", "morgenwacht"]
var _bot_road: HdRoad


func bot_turn() -> void:
	var h := hero
	if h.dead:
		return
	_bot_shop()
	h.attack_held = false
	h.order = {}
	var danger := _danger(h.position, h.radius + 0.4)
	if danger.dir != Vector3.ZERO:
		h.move_dir = danger.dir
		if danger.urgent:
			h.dodge(danger.dir)
		return
	var e := nearest_enemy(h.position, 14.0)
	if e == null:
		_bot_walk(_bot_goal())
		return
	var to := e.position - h.position
	to.y = 0.0
	var d := to.length()
	h.aim = e.position
	var near := enemies_in(HdTelegraph.CIRCLE, h.position, to, 5.0, 0, 0, 0, 0).size()
	if near >= 3 and h.unlocked(3):
		h.cast(3, e.position)
	if near >= 2:
		h.cast(1, e.position)
	if d < 3.4 + e.radius:
		h.cast(0, e.position)
	if d < 14.0 and e.hp > 90.0:
		h.cast(2, e.position)
	if d > float(h.def.attack.range) + e.radius + h.radius - 0.3:
		h.move_dir = to.normalized()
	else:
		h.move_dir = Vector3.ZERO
	h.attack_held = true


## Ziel ohne Gegner in der Nähe: Ausrüstung aus dem Lager holen, sonst zur Straße mit dem meisten
## Druck (Gegner weiter vorn zählen mehr), dort zum vordersten Gegner oder vor das Vorwerk.
func _bot_goal() -> Vector3:
	var threat := {}
	var lead := {}
	for r in roads:
		threat[r] = 0.0
	for e in enemies:
		if e.dead or e.road == null:
			continue
		var w: float = e.hp / 200.0 * (1.0 + 2.0 * e.road_s / e.road.length)
		threat[e.road] = float(threat.get(e.road, 0.0)) + w
		if not lead.has(e.road) or e.road_s > lead[e.road].road_s:
			lead[e.road] = e
	var best: HdRoad = _bot_road if _bot_road != null else roads[0]
	for r in roads:
		if threat[r] > float(threat.get(best, 0.0)) * 1.5 + 0.5:
			best = r
	_bot_road = best
	var total := 0.0
	for r in roads:
		total += float(threat[r])
	if total < 3.0 and _stash_gear():
		return hero_spawn()
	if lead.has(best):
		return lead[best].position
	return best.point(best.length * float(best.gate("vorwerk").def.at) + 3.0)


## Laufen mit Umweg um die Feste (sonst bleibt er an ihrer Mauer hängen).
func _bot_walk(goal: Vector3) -> void:
	var h := hero
	var to := goal - h.position
	to.y = 0.0
	if to.length() < 1.5:
		h.move_dir = Vector3.ZERO
		return
	var dir := to.normalized()
	var f := fortress_pos - h.position
	f.y = 0.0
	var along := f.dot(dir)
	var keep := float(cfg.arena.fortress_radius) + 2.5
	if along > 0.0 and along < to.length() and (f - dir * along).length() < keep:
		var lat := Vector3(-dir.z, 0, dir.x)
		if (f - dir * along).dot(lat) > 0.0:
			lat = -lat
		dir = (fortress_pos + lat * (keep + 2.0) - h.position).normalized()
	h.move_dir = dir


func _stash_gear() -> bool:
	for x in shop.stash:
		if x != null:
			return true
	return false


func _bot_owns(id: String) -> bool:
	if shop.owned_count(id) > 0:
		return true
	for up in shop.used_in.get(id, []):
		if _bot_owns(up):
			return true
	return false


func _bot_shop() -> void:
	var h := hero
	if shop.in_fortress():
		for i in shop.stash.size():
			if shop.stash[i] != null:
				var free := shop.inv.find(null)
				if free >= 0:
					shop.move("stash", i, "hero", free)
	if h.hp < h.max_hp * 0.35:
		for i in shop.inv.size():
			if shop.inv[i] != null and shop.inv[i].id == "heiltrank":
				shop.use(i)
				break
	for g in buildings:
		if g.road != null and shop.can_repair(g) == "" and shop.repair_cost(g) < shop.gold * 0.6:
			shop.repair(g)
	for id in BOT_PLAN:
		if _bot_owns(id):
			continue
		if shop.can_craft(id, true) == "":
			shop.craft(id, true)
		break
	if shop.owned_count("heiltrank") == 0 and shop.gold >= 150:
		shop.buy("heiltrank")
	var order := ["schaerfe", "kraft", "haerte"]
	var pick: String = order[(shop.wood_bought.values().reduce(func(a, b): return a + b, 0)) % order.size()]
	if shop.wood >= shop.wood_price(pick):
		shop.buy_wood(pick)


## Fluchtrichtung aus allen gegnerischen Warnflächen und Pfützen, in denen der Punkt liegt.
func _danger(at: Vector3, r: float) -> Dictionary:
	var out := Vector3.ZERO
	var urgent := false
	for e in enemies:
		if e.dead or not e.casting():
			continue
		for t in e.cast.get("tele", []):
			if not is_instance_valid(t) or t.fade >= 0.0 or not t.contains(at, r):
				continue
			var away: Vector3 = at - t.position
			away.y = 0.0
			match t.shape:
				HdTelegraph.LINE, HdTelegraph.CONE:
					var f: Vector3 = t.forward()
					var lat := Vector3(-f.z, 0, f.x)
					away = lat * (1.0 if away.dot(lat) >= 0.0 else -1.0)
				HdTelegraph.RING:
					if t.inner > 1.5 and away.length() < t.inner + 1.0:
						away = -away
			if away.length_squared() < 0.01:
				away = Vector3(1, 0, 0)
			out += away.normalized()
			if t.progress > 0.6 or str(e.cast.get("phase", "")) == "whirl":
				urgent = true
	for p in pools:
		var away: Vector3 = at - p.pos
		away.y = 0.0
		if away.length() <= float(p.r) + r:
			out += away.normalized() if away.length() > 0.01 else Vector3.RIGHT
	return {"dir": out.normalized() if out.length() > 0.01 else Vector3.ZERO, "urgent": urgent}
