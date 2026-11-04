class_name SvGame
extends Node3D
## Tower Survivors (Arbeitstitel, Modus "survivors"): ein Turm als Waffenplattform in der Mitte einer
## runden Arena, Gegner kommen in Wellen von allen Seiten und greifen den Turm an. Waffen im Laden
## kaufen und auf Montageplätze setzen (dieselbe Waffe nochmal kaufen = Stufe hoch, bis 5), Upgrades
## für Einkommen, Schaden, Überleben, Dornen; alle 5 Wellen ein Bonus aus drei. Sieg nach Welle 30.
## Alle Werte in data/survivors.json. Eigenes Design, angeregt von der WC3-Map „Tower Survivors“.
## Etappe 1: Einzelspieler, Dev-Texturen (SvDev). Mehrspieler (wer am längsten überlebt) folgt.
## Ablauf: setup → play ⇄ perk → over. Logik läuft in step(dt), damit Tests sie ohne Bild treiben können.

signal changed
signal message(text: String)
signal perk_offered(ids: Array)
signal ended(victory: bool)

const DATA := "res://data/survivors.json"

var cfg: Dictionary = {}
var weapon_defs: Dictionary = {}
var enemy_defs: Dictionary = {}
var upgrade_defs: Dictionary = {}
var perk_defs: Dictionary = {}

var state := "setup"
var paused := false
var difficulty := 1
var wave := 0
var wave_time := 0.0
var play_time := 0.0
var gold := 0.0
var hp := 1.0
var kills := 0
var leaks := 0
var damage_taken := 0.0
var slots_open := 3
var weapons: Array = []          ## je Montageplatz SvWeapon oder null
var paid: Array = []             ## je Platz bezahltes Gold (Verkaufswert)
var offers: Array = []           ## Waffen-IDs im Laden ("" = gekauft)
var rerolls := 0
var upgrades: Dictionary = {}    ## id → Stufe
var perks: Array = []            ## gewählte Boni (IDs)
var perk_choice: Array = []      ## gerade angebotene Boni
var enemies: Array = []
var spawn_queue: Array = []      ## {t, id, angle}
var wave_log: Array = []         ## {wave, kills, damage}
var debug := false
var result_news: Dictionary = {}
var _wave_kills := 0
var _wave_damage := 0.0
var _mods_cache: Dictionary = {}

var platform: SvPlatform
var fx: SvFx
var world: Node3D
var camera: Camera3D
var hud  ## SvHud
var cam_yaw := 0.0
var cam_dist := 27.0
var cam_pitch := 52.0  ## Grad über dem Boden
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Hologramm-Stil (Lukas 2026-11-04, Entwurf „Cyan-Kommando“)
	UiTheme.use_skin(UiTheme.HOLO)
	cfg = Database.load_json(DATA)
	for w in cfg.weapons:
		weapon_defs[str(w.id)] = w
	for e in cfg.enemies:
		enemy_defs[str(e.id)] = e
	for u in cfg.upgrades:
		upgrade_defs[str(u.id)] = u
	for p in cfg.perks:
		perk_defs[str(p.id)] = p
	rng.randomize()
	_build_world()
	hud = load("res://scripts/survivors/sv_hud.gd").new()
	hud.game = self
	add_child(hud)
	if Session.skip_setup:
		start(clampi(Session.difficulty, 0, cfg.difficulties.size() - 1))
	else:
		hud.show_setup()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	UiTheme.use_skin(UiTheme.ARCADE)


# ---------------------------------------------------------------- Welt

func _build_world() -> void:
	world = Node3D.new()
	add_child(world)
	# Nacht (Lukas 2026-11-04): dunkler Himmel, schwaches Mondlicht, Leuchten über Glow
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("04060c")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("4c5262")
	e.ambient_light_energy = 0.35
	# Himmel nur für Spiegelungen (Metall), sichtbar bleibt der dunkle Hintergrund
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("22262f")
	sm.sky_horizon_color = Color("5d626e")
	sm.ground_bottom_color = Color("0c0f18")
	sm.ground_horizon_color = Color("3a4560")
	sky.sky_material = sm
	e.sky = sky
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 0.85
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	e.fog_enabled = Display.quality > 0
	e.fog_light_color = Color("0b1020")
	e.fog_density = 0.008
	env.environment = e
	world.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -35, 0)
	moon.light_color = Color("c3cde6")
	moon.light_energy = 0.3
	moon.shadow_enabled = Display.quality > 0
	world.add_child(moon)

	var r := float(cfg.arena.radius)
	var outer := MeshInstance3D.new()
	var om := PlaneMesh.new()
	om.size = Vector2(r * 5, r * 5)
	outer.mesh = om
	outer.position.y = -0.02
	outer.material_override = SvDev.mat(Color("2a2e38"))
	world.add_child(outer)
	var floor_ := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = r
	fm.bottom_radius = r
	fm.height = 0.1
	fm.radial_segments = 64
	floor_.mesh = fm
	floor_.position.y = -0.05
	floor_.material_override = SvDev.mat(Color("6c7280"))
	world.add_child(floor_)
	# Rand der Arena in Akzentfarbe, Reichweiten-Hilfsringe alle 5 Einheiten
	for k in [r] + [5.0, 10.0, 15.0]:
		var rg := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = k - (0.12 if k == r else 0.04)
		tm.outer_radius = k
		tm.rings = 96
		tm.ring_segments = 3
		rg.mesh = tm
		rg.position.y = 0.02
		rg.material_override = SvDev.flat(UiTheme.GOLD if k == r else Color("8a90a0"), 1.0 if k == r else 0.5)
		world.add_child(rg)

	platform = SvPlatform.new()
	add_child(platform)
	fx = SvFx.new()
	fx.game = self
	add_child(fx)
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	_place_camera()


func _place_camera() -> void:
	var pitch := deg_to_rad(cam_pitch)
	var off := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * cam_dist
	camera.position = off + Vector3(0, 2.5, 0)
	camera.look_at(Vector3(0, 2.2, 0), Vector3.UP)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(10.0, cam_dist - 1.5)
			_place_camera()
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(46.0, cam_dist + 1.5)
			_place_camera()
		elif ev.button_index == MOUSE_BUTTON_LEFT and state != "setup":
			hud.pick(ev.position)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			hud.deselect()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_ESCAPE:
				# erst die Auswahl aufheben, dann das Menü
				if not hud.deselect():
					hud.toggle_menu()
			KEY_SPACE:
				if state == "play":
					paused = not paused
					changed.emit()
			KEY_R:
				reroll()


func _process(dt: float) -> void:
	var turn := 0.0
	if Input.is_key_pressed(KEY_Q):
		turn += 1.0
	if Input.is_key_pressed(KEY_E):
		turn -= 1.0
	if turn != 0.0:
		cam_yaw += turn * dt / maxf(Engine.time_scale, 0.01) * 1.6
		_place_camera()


func _physics_process(dt: float) -> void:
	if state == "play" and not paused:
		step(dt)


# ---------------------------------------------------------------- Ablauf

func start(diff: int) -> void:
	difficulty = diff
	Session.difficulty = diff
	var st: Dictionary = cfg.start
	gold = float(st.gold)
	slots_open = int(st.slots)
	weapons.resize(platform.SLOTS)
	paid.resize(platform.SLOTS)
	for i in platform.SLOTS:
		weapons[i] = null
		paid[i] = 0
		platform.set_state(i, "free" if i < slots_open else "locked")
	_mods_cache.clear()
	hp = max_hp()
	if str(st.get("weapon", "")) != "":
		_equip(str(st.weapon), 0)
	state = "play"
	start_wave(1)
	hud.on_started()


func start_wave(n: int) -> void:
	wave = n
	wave_time = 0.0
	rerolls = 0
	_wave_kills = 0
	_wave_damage = 0.0
	for w in weapons:
		if w:
			w.wave_damage = 0.0
	var wv: Dictionary = cfg.waves
	if n > 1:
		gold += float(wv.wave_bonus) + float(wv.wave_bonus_growth) * (n - 1)
	_roll_offers()
	_plan_spawns(n)
	var boss := n % int(wv.boss_every) == 0
	message.emit(tr("Welle %d – Boss!") % n if boss else tr("Welle %d") % n)
	changed.emit()


func _plan_spawns(n: int) -> void:
	var wv: Dictionary = cfg.waves
	var budget := float(wv.budget_base) * pow(float(wv.budget_growth), n - 1)
	var pool: Array = []
	var total_w := 0.0
	for e in cfg.enemies:
		if e.get("boss", false) or int(e.get("from_wave", 1)) > n:
			continue
		pool.append(e)
		total_w += float(e.weight)
	spawn_queue.clear()
	var guard := 0
	while budget > 0.0 and guard < 2000:
		guard += 1
		var pick := rng.randf() * total_w
		var e: Dictionary = pool[0]
		for c in pool:
			pick -= float(c.weight)
			if pick <= 0.0:
				e = c
				break
		var group := int(e.get("group", 1))
		var t := rng.randf() * float(wv.spawn_time)
		var ang := rng.randf() * TAU
		for g in group:
			spawn_queue.append({"t": t + g * 0.15, "id": str(e.id), "angle": ang + rng.randf_range(-0.12, 0.12)})
		budget -= float(e.cost) * group
	if n % int(wv.boss_every) == 0:
		for e in cfg.enemies:
			if e.get("boss", false):
				spawn_queue.append({"t": 1.0, "id": str(e.id), "angle": rng.randf() * TAU})
	spawn_queue.sort_custom(func(a, b): return a.t < b.t)


func step(dt: float) -> void:
	play_time += dt
	wave_time += dt
	while not spawn_queue.is_empty() and spawn_queue[0].t <= wave_time:
		var s: Dictionary = spawn_queue.pop_front()
		_spawn(s.id, s.angle)
	gold += income() * dt
	hp = minf(max_hp(), hp + regen() * dt)
	var arm := armor()
	var red := arm * 0.05 / (1.0 + arm * 0.05)
	for i in range(enemies.size() - 1, -1, -1):
		var e: SvEnemy = enemies[i]
		if e.dead:
			continue
		var hit := e.step(dt)
		if hit > 0.0:
			var dealt := hit * (1.0 - red)
			hp -= dealt
			damage_taken += dealt
			if thorns() > 0.0:
				damage(e, hit * thorns(), "phys", null)
		if e.dead:
			continue
		if e.burn.y > 0.0:
			e.burn.y -= dt
			damage(e, e.burn.x * dt, "fire", e.burn_src, true)
		if not e.dead and e.poison.y > 0.0:
			e.poison.y -= dt
			damage(e, e.poison.x * dt, "poison", e.poison_src, true)
	for w in weapons:
		if w:
			w.step(dt)
	fx.step(dt)
	platform.step(dt)
	platform.set_health(hp / max_hp())
	if hp <= 0.0:
		hp = 0.0
		_finish(false)
		return
	var wv: Dictionary = cfg.waves
	if wave_time >= float(wv.duration):
		if wave < int(wv.count):
			_log_wave()
			if wave % int(wv.perk_every) == 0:
				_offer_perks()
			else:
				start_wave(wave + 1)
		elif spawn_queue.is_empty() and enemies.is_empty():
			_log_wave()
			_finish(true)


func _log_wave() -> void:
	wave_log.append({"wave": wave, "kills": _wave_kills, "damage": roundi(_wave_damage)})
	for w in weapons:
		if w and w.wave_damage > w.best_wave_damage:
			w.best_wave_damage = w.wave_damage
			w.best_wave = wave


func _spawn(id: String, angle: float) -> void:
	var d: Dictionary = enemy_defs[id]
	var dd: Dictionary = cfg.difficulties[difficulty]
	var e := SvEnemy.new()
	var hpf := pow(float(cfg.waves.hp_growth), wave - 1) * float(dd.hp)
	e.setup(d, hpf, (1.0 + 0.04 * (wave - 1)) * float(dd.dps), float(cfg.arena.tower_radius))
	e.gold *= 1.0 + 0.04 * (wave - 1)
	var r := float(cfg.arena.spawn_radius)
	e.position = Vector3(cos(angle) * r, 0, sin(angle) * r)
	world.add_child(e)
	enemies.append(e)


# ---------------------------------------------------------------- Werte

## Summe eines Werts aus Upgrades und Boni (Schaden, Feuerrate, Rüstung …).
func mod(stat: String) -> float:
	if _mods_cache.has(stat):
		return _mods_cache[stat]
	var v := 0.0
	for id in upgrades:
		var u: Dictionary = upgrade_defs[id]
		if str(u.stat) == stat:
			v += float(u.add) * int(upgrades[id])
	for id in perks:
		var p: Dictionary = perk_defs[id]
		if str(p.stat) == stat:
			v += float(p.add)
	_mods_cache[stat] = v
	return v


func max_hp() -> float:
	return (float(cfg.start.hp) + mod("max_hp")) * (1.0 + mod("max_hp_pct"))


func armor() -> float:
	return float(cfg.start.armor) + mod("armor")


func regen() -> float:
	return float(cfg.start.regen) + mod("regen")


func income() -> float:
	return float(cfg.start.income) + mod("income")


func thorns() -> float:
	return mod("thorns")


func total_dps() -> float:
	var v := 0.0
	for w in weapons:
		if w:
			v += w.dps()
	return v


func type_color(t: String) -> Color:
	return Color(str(cfg.damage_types.get(t, {}).get("color", "ffffff")))


func rarity_color(r: String) -> Color:
	return Color(str(cfg.rarities.get(r, {}).get("color", "ffffff")))


func weapon_colors(w: Dictionary) -> Dictionary:
	var c := type_color(str(w.type))
	return {"type": c, "dark": Color("3a3f4d"), "light": Color("b8bdc9"), "glow": c.lightened(0.25)}


func score() -> int:
	return roundi((kills + (wave - 1) * 50 + roundi(hp)) * float(cfg.difficulties[difficulty].get("score", 1.0)))


# ---------------------------------------------------------------- Laden

func _roll_offers() -> void:
	offers.clear()
	for i in int(cfg.shop.offers):
		offers.append(_roll_weapon())


func _roll_weapon() -> String:
	var weights := {}
	var total := 0.0
	for r in cfg.rarities:
		var rd: Dictionary = cfg.rarities[r]
		if wave < int(rd.get("from_wave", 1)):
			continue
		var w := maxf(0.0, float(rd.weight) + float(rd.weight_per_wave) * (wave - 1))
		if r == "common":
			w = maxf(w, 15.0)
		weights[r] = w
		total += w
	var pick := rng.randf() * total
	var rar := "common"
	for r in weights:
		pick -= weights[r]
		if pick <= 0.0:
			rar = r
			break
	var pool: Array = cfg.weapons.filter(func(x): return str(x.rarity) == rar)
	return str(pool[rng.randi() % pool.size()].id)


func price(id: String) -> int:
	var w: Dictionary = weapon_defs[id]
	return roundi(float(cfg.rarities[str(w.rarity)].price) * (1.0 - mod("discount")))


func reroll_price() -> int:
	return int(cfg.shop.reroll_base) + int(cfg.shop.reroll_step) * rerolls


## Wohin ginge die Waffe? Platz der gleichen Waffe (Stufe hoch) oder ein freier Platz, sonst -1.
func target_slot(id: String) -> int:
	for i in weapons.size():
		var w: SvWeapon = weapons[i]
		if w and w.id == id and w.level < int(cfg.max_level):
			return i
	for i in slots_open:
		if weapons[i] == null:
			return i
	return -1


func buy_offer(i: int) -> bool:
	if state != "play" or i < 0 or i >= offers.size() or offers[i] == "":
		return false
	var id: String = offers[i]
	var cost := price(id)
	var slot := target_slot(id)
	if gold < cost or slot < 0:
		return false
	gold -= cost
	offers[i] = ""
	paid[slot] = int(paid[slot]) + cost
	_equip(id, slot)
	changed.emit()
	return true


func _equip(id: String, slot: int) -> void:
	var w: SvWeapon = weapons[slot]
	var d: Dictionary = weapon_defs[id]
	var col := rarity_color(str(d.rarity))
	if w and w.id == id:
		w.level += 1
		message.emit(tr("%s auf Stufe %d") % [tr(str(d.name)), w.level])
	else:
		w = SvWeapon.new(self, d, slot)
		weapons[slot] = w
		w.yaw = platform.mount(slot, d, weapon_colors(d))
		w.recoil = w.yaw.get_child(0)
	platform.set_state(slot, "armed", col)
	platform.set_level(slot, w.level, col)


func sell(slot: int) -> void:
	var w: SvWeapon = weapons[slot]
	if w == null or state == "over":
		return
	gold += float(paid[slot]) * float(cfg.sell_factor)
	paid[slot] = 0
	weapons[slot] = null
	platform.retract(slot)
	platform.set_state(slot, "free")
	changed.emit()


func reroll() -> bool:
	var cost := reroll_price()
	if state != "play" or gold < cost:
		return false
	gold -= cost
	rerolls += 1
	_roll_offers()
	changed.emit()
	return true


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


## Preis der nächsten Stufe, -1 = ausgebaut.
func upgrade_price(id: String) -> int:
	var u: Dictionary = upgrade_defs[id]
	var lv := upgrade_level(id)
	if lv >= int(u.max):
		return -1
	if u.has("costs"):
		return int(u.costs[lv])
	return roundi(float(u.cost) * pow(float(u.growth), lv))


func buy_upgrade(id: String) -> bool:
	var cost := upgrade_price(id)
	if state != "play" or cost < 0 or gold < cost:
		return false
	gold -= cost
	var before := max_hp()
	upgrades[id] = upgrade_level(id) + 1
	_mods_cache.clear()
	var u: Dictionary = upgrade_defs[id]
	if str(u.stat) == "slots":
		slots_open = mini(int(cfg.start.max_slots), slots_open + 1)
		platform.set_state(slots_open - 1, "free")
	hp += maxf(0.0, max_hp() - before)
	changed.emit()
	return true


# ---------------------------------------------------------------- Boni

func _offer_perks() -> void:
	var pool: Array = perk_defs.keys().filter(func(k): return not perks.has(k))
	pool.shuffle()
	perk_choice = pool.slice(0, 3)
	if perk_choice.is_empty():
		start_wave(wave + 1)
		return
	state = "perk"
	perk_offered.emit(perk_choice)
	changed.emit()


func choose_perk(i: int) -> void:
	if state != "perk" or i < 0 or i >= perk_choice.size():
		return
	var id: String = perk_choice[i]
	var before := max_hp()
	perks.append(id)
	_mods_cache.clear()
	if str(perk_defs[id].stat) == "max_hp_pct":
		hp = max_hp()
	else:
		hp += maxf(0.0, max_hp() - before)
	perk_choice = []
	state = "play"
	start_wave(wave + 1)


# ---------------------------------------------------------------- Kampf

func nearest(from: Vector3, rng_: float, skip: Array = []) -> SvEnemy:
	var best: SvEnemy = null
	var bd := INF
	for e in enemies:
		if e.dead or skip.has(e):
			continue
		var p: Vector3 = e.global_position
		var d: float = Vector2(p.x - from.x, p.z - from.z).length() - e.size * 0.5
		if d <= rng_ and d < bd:
			bd = d
			best = e
	return best


func in_radius(at: Vector3, r: float) -> Array:
	var out: Array = []
	for e in enemies:
		if e.dead:
			continue
		var p: Vector3 = e.global_position
		if Vector2(p.x - at.x, p.z - at.z).length() <= r + e.size * 0.5:
			out.append(e)
	return out


## Schaden mit Resistenz der Schadensart und Rüstung (Rüstung wirkt nicht auf Brennen und Gift).
func damage(e: SvEnemy, amount: float, type: String, w: SvWeapon, is_dot := false) -> void:
	if e.dead or amount <= 0.0:
		return
	var v := amount * (1.0 - float(e.resist.get(type, 0.0)))
	if not is_dot:
		v *= 1.0 - e.armor * 0.05 / (1.0 + e.armor * 0.05)
	v = minf(v, e.hp)
	e.hp -= v
	_wave_damage += v
	if w:
		w.add_damage(v)
	if mod("lifesteal") > 0.0:
		hp = minf(max_hp(), hp + v * mod("lifesteal"))
	if not is_dot:
		e.hit_flash()
	elif Engine.get_physics_frames() % 6 == 0:
		e.hit_flash()
	if e.hp <= 0.001:
		_kill(e, w)


func _kill(e: SvEnemy, w: SvWeapon) -> void:
	e.dead = true
	kills += 1
	_wave_kills += 1
	if w:
		w.kills += 1
	gold += e.gold * (1.0 + mod("kill_gold"))
	fx.pop(e.center(), Color(str(e.data.get("color", "ffffff"))), e.size)
	enemies.erase(e)
	e.queue_free()


func _effects(e: SvEnemy, w: SvWeapon) -> void:
	if e.dead:
		return
	var s := w.slow()
	if s.x > 0.0:
		e.apply_slow(s.x, s.y)
	var b := w.dot("burn")
	if b.x > 0.0 and b.x >= e.burn.x * 0.8:
		e.burn = b
		e.burn_src = w
	var p := w.dot("poison")
	if p.x > 0.0 and p.x >= e.poison.x * 0.8:
		e.poison = p
		e.poison_src = w


func fire(w: SvWeapon, target: SvEnemy) -> void:
	var col := type_color(w.type())
	if w.kind() != "nova":
		fx.flash(w.muzzle(), col)
	match w.kind():
		"bullet":
			var n := w.shots()
			var spread := float(w.data.get("spread", 0.0))
			if spread > 0.0:
				for k in n:
					var off := deg_to_rad(-spread * 0.5 + spread * (float(k) + 0.5) / n)
					fx.shoot(w, target, w.muzzle(), off)
			else:
				var used: Array = [target]
				fx.shoot(w, target, w.muzzle())
				for k in n - 1:
					var t2 := nearest(w.center(), w.reach(), used)
					if t2 == null:
						t2 = target
					used.append(t2)
					fx.shoot(w, t2, w.muzzle())
		"lob":
			fx.shoot(w, target, w.muzzle())
		"beam":
			if w.splash() > 0.0:
				fx.strike(target.center(), col)
				impact(w, null, target.global_position)
				return
			_chain(w, target, w.muzzle(), w.damage(), w.chain())
		"line":
			var from := w.origin()
			var dir := w.forward()
			var to := from + dir * (w.range_() + SvPlatform.PAD_RADIUS)
			fx.beam(w.muzzle(), Vector3(to.x, 0.6, to.z), col, 0.22, 0.2)
			for e in enemies.duplicate():
				var p: Vector3 = e.global_position
				var rel := Vector2(p.x - from.x, p.z - from.z)
				var along := rel.dot(Vector2(dir.x, dir.z))
				if along < 0.0 or along > w.range_() + SvPlatform.PAD_RADIUS:
					continue
				var side := absf(rel.cross(Vector2(dir.x, dir.z)))
				if side <= 0.6 + e.size * 0.5:
					damage(e, w.damage(), w.type(), w)
					_effects(e, w)
		"cone":
			var from := w.origin()
			var dir := w.forward()
			var half := deg_to_rad(float(w.data.get("angle", 40)) * 0.5)
			var cdir := (dir * (w.range_() + SvWeapon.AREA_BONUS) + Vector3(0, 0.6 - w.muzzle().y, 0)).normalized()
			fx.cone(w.muzzle(), cdir, w.range_() + SvWeapon.AREA_BONUS, float(w.data.get("angle", 40)), col)
			for e in in_radius(from, w.range_() + SvWeapon.AREA_BONUS):
				var p: Vector3 = e.global_position - from
				if absf(Vector2(dir.x, dir.z).angle_to(Vector2(p.x, p.z))) <= half:
					damage(e, w.damage(), w.type(), w)
					_effects(e, w)
		"nova":
			fx.ring(w.origin(), w.range_() + SvWeapon.AREA_BONUS, col)
			for e in in_radius(w.origin(), w.range_() + SvWeapon.AREA_BONUS):
				damage(e, w.damage(), w.type(), w)
				_effects(e, w)


## Blitz: Ziel treffen, dann auf den nächsten noch nicht getroffenen Gegner springen (je Sprung −15 %).
func _chain(w: SvWeapon, first: SvEnemy, from: Vector3, dmg: float, hops: int) -> void:
	var col := type_color(w.type())
	var hit: Array = []
	var cur := first
	var a := from
	for k in hops + 1:
		if cur == null:
			break
		var b := cur.center()
		fx.beam(a, b, col)
		hit.append(cur)
		damage(cur, dmg, w.type(), w)
		_effects(cur, w)
		dmg *= 0.85
		a = b
		cur = nearest(b, 3.5, hit)


## Einschlag eines Geschosses: Fläche oder Einzelziel, danach Zusatzwirkungen.
func impact(w: SvWeapon, target: SvEnemy, at: Vector3) -> void:
	var col := type_color(w.type())
	var r := w.splash()
	if r > 0.0:
		fx.ring(at, r, col, 0.3)
		for e in in_radius(at, r):
			damage(e, w.damage(), w.type(), w)
			_effects(e, w)
		return
	if target == null or target.dead:
		return
	if w.chain() > 0:
		_chain(w, target, target.center(), w.damage(), w.chain())
		return
	damage(target, w.damage(), w.type(), w)
	_effects(target, w)


# ---------------------------------------------------------------- Ende

func _finish(victory: bool) -> void:
	if state == "over":
		return
	state = "over"
	Engine.time_scale = 1.0
	result_news = _record(victory)
	ended.emit(victory)
	changed.emit()


func _record(victory: bool) -> Dictionary:
	var types := {}
	var towers: Array = []
	for w in weapons:
		if w == null:
			continue
		var label := "%s %d" % [tr(str(w.data.name)), w.level]
		towers.append({"id": w.id, "label": label, "kills": w.kills, "damage": roundi(w.damage_done),
			"best_wave_damage": roundi(w.best_wave_damage), "best_wave": w.best_wave})
		var t: Dictionary = types.get(w.id, {"built": 0, "tiers": {}, "kills": 0, "damage": 0.0, "best_wave_damage": 0.0, "best_wave": 0, "alive": 0})
		t.built += 1
		t.tiers[str(w.level)] = int(t.tiers.get(str(w.level), 0)) + 1
		t.kills += w.kills
		t.damage += w.damage_done
		t.alive += 1
		if w.best_wave_damage > t.best_wave_damage:
			t.best_wave_damage = w.best_wave_damage
			t.best_wave = w.best_wave
		types[w.id] = t
	towers.sort_custom(func(a, b): return a.damage > b.damage)
	var info := {"map": "Arena", "difficulty": difficulty, "victory": victory, "wave": wave,
		"waves": int(cfg.waves.count), "lives": roundi(hp), "max_lives": roundi(max_hp()), "score": score(),
		"kills": kills, "play_time": roundi(play_time), "debug": debug, "perks": perks.duplicate(),
		"upgrades": upgrades.duplicate()}
	return Profile.record_run("survivors", info, {"types": types, "towers": towers, "wave_log": wave_log})


func leave() -> void:
	if state == "play" or state == "perk":
		Profile.record_abort("survivors", {"map": "Arena", "difficulty": difficulty, "wave": wave,
			"waves": int(cfg.waves.count), "play_time": roundi(play_time), "debug": debug})
	Engine.time_scale = 1.0
	Session.goto(Session.return_scene)


func restart() -> void:
	Engine.time_scale = 1.0
	Session.skip_setup = true
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- Bot (Tests, Bilder)

## Einfacher Spieler für Tests, Screenshots und tools/survivors_sim.gd: kauft die teuerste Waffe, die auf
## einen Platz passt, öffnet Plätze, sonst das billigste Upgrade (Einkommen nur bis Welle 12).
func bot_turn() -> void:
	if state == "perk":
		choose_perk(0)
		return
	if state != "play":
		return
	for pass_ in 3:
		var best := -1
		var best_v := -1.0
		for i in offers.size():
			if offers[i] == "" or target_slot(offers[i]) < 0 or gold < price(offers[i]):
				continue
			var v := float(price(offers[i])) + (5.0 if target_slot(offers[i]) >= 0 and weapons[target_slot(offers[i])] != null else 0.0)
			if v > best_v:
				best_v = v
				best = i
		if best >= 0:
			buy_offer(best)
	# Alles belegt: schwächste Waffe gegen eine seltenere aus dem Laden tauschen
	if target_slot("__none__") < 0:
		var order: Array = cfg.rarities.keys()
		var low := -1
		for i in slots_open:
			var w: SvWeapon = weapons[i]
			if w and (low < 0 or order.find(str(w.data.rarity)) * 10 + w.level < order.find(str(weapons[low].data.rarity)) * 10 + weapons[low].level):
				low = i
		for i in offers.size():
			if low < 0 or offers[i] == "":
				continue
			var r := order.find(str(weapon_defs[offers[i]].rarity))
			if r > order.find(str(weapons[low].data.rarity)) and gold + float(paid[low]) * float(cfg.sell_factor) >= price(offers[i]):
				sell(low)
				buy_offer(i)
				break
	var full := true
	for i in slots_open:
		if weapons[i] == null:
			full = false
	if full and slots_open < int(cfg.start.max_slots):
		if not buy_upgrade("slot"):
			return  # sparen
	var ids: Array = ["damage", "rate", "hull", "armor", "repair", "thorns"]
	if wave <= 12:
		ids.append("income")
	var cheapest := ""
	var cp := 1 << 30
	for id in ids:
		var p := upgrade_price(id)
		if p > 0 and p < cp:
			cp = p
			cheapest = id
	if cheapest != "" and gold >= cp + 40:
		buy_upgrade(cheapest)
