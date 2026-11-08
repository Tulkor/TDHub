class_name MaulGame
extends Node3D
## Shopping Maul: Spielablauf. Jeder Spieler eröffnet eine Filiale und kauft deren Tower in sein
## Gebiet, die Gewerbeaufsicht läuft von 12 Spawns über Teleports zur Mall in P1. Das Team teilt
## sich die Leben. Regeln aus data/maul/rules.json, Level aus waves.json (siehe Designdokument).
##
## Wie in game.gd laufen alle Spieleraktionen als Befehle über submit(cmd) → execute(cmd) mit
## Spielernummer. Im Koop (maul_sync.gd) rechnet nur der Host, die Mitspieler schicken ihre Befehle
## und zeigen den gemeldeten Stand. Spieler i baut in Gebiet P(i+1), der Host im Zentrum.
## Tower und Gegner sind die GemTD-Klassen (MaulTower, MaulEnemy) und rufen dieselben
## Funktionen auf wie in game.gd (find_targets, enemies_in_radius, on_enemy_killed …).
##
## Etappe 2 (pro.json): Hauptgebäude mit Bonus (+5 % Schaden je Stufe) oder Rabatt (5 % des
## Kaufpreises zurück), XP über Spiele hinweg (maul_xp.gd) mit XPert-Towern, die Profi-Filialen
## mit Items (Post, IKEO, Fitness, Waffenladen), Wasser (Gärtnerei), Zombies und Drohnen (maul_unit.gd).

enum Phase { SETUP, COUNTDOWN, WAVE, GAME_OVER, VICTORY }

const NO_CELL := Vector2i(-1, -1)
## Bau-Tasten wie im WC3-Raster (physische Tasten, auf QWERTZ unten links „Y“)
const BUILD_KEYS := [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_A, KEY_S, KEY_D, KEY_F, KEY_Z, KEY_X, KEY_C]

class Player:
	var name := ""
	var shop := ""
	var gold := 0
	var zone := 0
	var kills := 0
	var level_kills := 0
	var reveal_until := -1.0
	var reveal_ready := 0.0
	var bonus := 0            ## Stufe Bonus-Upgrade bzw. Rabatt im Hauptgebäude (0–5)
	var xp := 10              ## Erfahrung in Zehnteln (10 = 1,0 XP)
	var xp_pot := 0.0
	var research := {}        ## TOI: Forschung → Stufe
	var aok_lives := 0        ## AOX/Life: in diesem Level durch Kills zurückgeholte Leben
	var account := 0          ## Konto (maul_bank.gd)
	var auto_deposit := false ## am Levelende alles Gold aufs Konto
	var bank_level := 0       ## Bank-Upgrade im Hauptgebäude (0–3)
	var withdraw_in := 0.0    ## laufende Überweisung: Sekunden bis zur Auszahlung (0 = keine)
	var team_points := 0      ## Teampunkte: einlösen für Leben, Durchblick oder Winter (rules.json → team_points)
	var emma_mined := 0       ## Tante Emma: von der Stammkundin geholtes Gold
	var emma_timer := 0.0
	var away := false

## Gemeinsame Spielsysteme des Modus (scripts/systems/, data/modes.json → systems), angelegt in _init.
var systems := {}
var rules: Dictionary
var levels: Array
var map: MaulMap
var board: MaulBoard
var path_lights: PathLights  ## Lichtpfad entlang der Gegnerwege (Knopf „Lichtpfad“)
var _own_routes: Array = []  ## Wege (PackedVector2Array) durchs eigene Gebiet, für den Lichtpfad
var _other_routes: Array = []
var effects: Effects
var camera_rig: MaulCamera
var hud: MaulHud
var pathfinder: Pathfinder   ## mit Towern
var ghost_finder: Pathfinder ## nur Gelände (Geist-Level)

## Koop (maul_sync.gd): im Koop rechnet nur der Host, mirror = Mitspieler
var sync: MaulSync = null
## Für Net._coop_end (verlässt der Host die Partie, gehen die Mitspieler zurück ins Menü)
var coop: MaulSync:
	get:
		return sync
var mirror := false
var local_player := 0
var acting := 0
var players: Array = []
var sandbox := false        ## Option „Sandbox“: feste 800 XP (alles offen), Durchbrüche kosten keine Leben, keine XP
var foreign_build := false  ## Option „Überall bauen“: Tower und Einheiten auch in den Gebieten der anderen
## Option „Geldteilen“: Kopfgeld in einen Topf, gleich an alle verteilt; dafür kein Konzernbonus aufs Einkommen
var share_gold := false
var gold_pot := 0           ## Geldteilen: Rest, der noch nicht durch die Spielerzahl teilbar war
var sight_until := -1.0     ## Teampunkt „Durchblick“: alle Unsichtbaren angreifbar bis zu dieser Spielzeit
var winter_until := -1.0    ## Teampunkt „Winter“: alle Gegner langsamer bis zu dieser Spielzeit
var levels_done := 0
## Debug-Menü (maul_debug.gd): freies Bauen = Tower aller Filialen ohne Voraussetzungen und Towerlimit,
## alle Items ohne Laden. debug_xp: XP verändert, dann wird am Levelende nichts gespeichert.
var debug_free := false
var debug_xp := false
var xp_start := 0           ## XP beim Start (Endbildschirm zeigt den Zuwachs)
var debug_used := false     ## Debug-Menü geöffnet: die Partie zählt nicht fürs Profil (maul_profile.gd), keine XP
var profile_time := 0       ## Sekunden dieser Partie, die schon im Profil stehen (Verlassen und später Laden)
var _saves_at_start := 0
var profile_news := {}      ## Neue Rekorde dieser Partie für den Endbildschirm
var run_stats := RunStats.new()  ## Statistik der eigenen Tower fürs Profil (profile.gd)
var level_save := {}        ## Einzelspiel: Stand vom Beginn des laufenden Levels (maul_save.gd)

var phase := Phase.SETUP
var difficulty := 1
## Aufstiegsstufe (+1, +2, …) auf der höchsten Schwierigkeit (ascension.gd), wählt der Host im Startfenster.
var ascension := 0
## Nach der Partie neu freigeschaltete Stufe (0 = keine), fürs Ende-Fenster.
var ascension_unlocked := 0
var mode := "group"
var level := 0               ## zuletzt gestartetes Level (1-basiert)
var countdown := 0.0
var lives := 150
var max_lives := 150
var game_time := 0.0
var play_time := 0.0

var towers := {}             ## Anker → MaulTower
var occupied := {}           ## Feld → Anker
var enemies: Array = []
var units: Array = []        ## Zombies und Drohnen (MaulUnit)
var selected: MaulTower = null
var selected_unit: MaulUnit = null
var pending := {}            ## wartende Klick-Aktion: {type: "move_items", from: Anker}
var _next_unit_id := 1
var notes := {}              ## Koop: Spieler → [Zähler, Meldung] für Mitspieler
var build_id := ""           ## gewählter Tower zum Bauen (nur lokal)
var message := ""
var message_time := 0.0

# Level
var income_pot := 185
var prev_budget := 0.0
var adapt_raw: Array = [1.0]
var streak := 0
var je := 1.0
var je_min := 1.0
var je_max := 1.0
var level_lost := 0          ## in diesem Level verlorene Leben
var level_kind := ""
var level_specials: Array = []
var level_hp := 0.0          ## Leben pro Gegner
var level_count := 0         ## Gegner gesamt
var spawn_queue: Array = []  ## je Spawn: [Spawn-Index, noch zu erzeugen]
var spawn_timer := 0.0
var enemies_killed := 0
var enemies_leaked := 0
var _next_enemy_id := 1
var _alternate := {}         ## Route → Zähler für abwechselnde Abzweigungen

var _path_cache := {}        ## Schlüssel → {path, wp}
var show_all_paths := false  ## Mehrspieler: auch die Wege durch fremde Gebiete zeigen
var _own_path_pts := PackedVector2Array()
var _other_path_pts := PackedVector2Array()
var _zone_towers: Array = [] ## Tower je Zone
var _frost_level := false
var _detect_towers: Array = []
var _range_preview: MeshInstance3D
var _range_preview_r := -1.0
var _hud_timer := 0.0


func _init() -> void:
	SystemHost.attach(self, "shoppingmaul")


func _ready() -> void:
	_saves_at_start = SaveGame.writes
	# Art déco für Oberfläche und Spielfeld (Petrol, Messing), vor dem Bau von HUD und Board
	UiTheme.use_skin(UiTheme.DECO)
	rules = MaulData.rules()
	levels = MaulData.levels()
	map = MaulMap.create()
	pathfinder = Pathfinder.new(map)
	ghost_finder = Pathfinder.new(map)
	_zone_towers.resize(map.zones.size())
	_zone_towers.fill(0)
	difficulty = int(rules.get("default_difficulty", 1))
	var coop_info: Dictionary = Session.coop
	Session.coop = {}
	var names: Array = coop_info.get("names", [])
	if coop_info.is_empty():
		names = [tr("Du")]
	local_player = int(coop_info.get("player", 0))
	acting = local_player
	mirror = coop_info.get("role", "") == "client"
	for i in mini(names.size(), map.zones.size()):
		var p := Player.new()
		p.name = str(names[i])
		p.zone = i
		players.append(p)
	players[local_player].xp = MaulXp.load_xp()
	xp_start = players[local_player].xp

	CameraRig.add_environment(self)
	board = MaulBoard.new()
	board.own_zone = players[local_player].zone
	board.players = players.size()
	board.map = map
	add_child(board)
	path_lights = PathLights.new(board, "shoppingmaul")
	path_lights.visible = Display.path_lights
	path_lights.color_at = _path_light_color
	board.add_child(path_lights)
	board.set_path_dots(not Display.path_lights)
	effects = Effects.new()
	board.add_child(effects)
	camera_rig = MaulCamera.new()
	add_child(camera_rig)
	camera_rig.frame_map(map.width * Board3D.CELL, map.height * Board3D.CELL)
	camera_rig.look_at_point(map.zone_center(0), 42.0)
	_range_preview = MeshInstance3D.new()
	_range_preview.visible = false
	_range_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_range_preview)

	hud = MaulHud.new()
	hud.game = self
	add_child(hud)
	_setup_inv_drop()
	_refresh_paths()
	camera_rig.look_at_point(map.zone_center(players[local_player].zone), 42.0)
	hud.show_setup()
	var saved: Dictionary = Session.load_state
	Session.load_state = {}
	if not mirror and not saved.is_empty():
		# Einzelspiel oder gespeicherter Koop (der Host lädt, die Mitspieler bekommen den Stand über maul_sync.gd)
		MaulSave.apply(self, saved)
	elif coop_info.is_empty():
		Session.save_id = ""
	if not coop_info.is_empty():
		sync = MaulSync.new()
		sync.game = self
		sync.host = not mirror
		add_child(sync)
		Net.game = self


# --- Start ---------------------------------------------------------------------

## Nach der Filialwahl: Gold, Leben und Countdown bis Level 1. Im Koop startet der Host (Schwierigkeit,
## Modus, Sandbox, Überall bauen, Geldteilen gelten für alle), die Mitspieler wählen ihre Filiale mit dem Befehl "shop".
func start_game(shop_id: String, diff: int, play_mode: String, sandbox_on := false, foreign_on := false, share_on := false) -> void:
	if mirror:
		submit({"type": "shop", "shop": shop_id, "xp": players[local_player].xp})
		return
	if phase != Phase.SETUP:
		return
	difficulty = clampi(diff, 0, rules.get("difficulties", []).size() - 1)
	if difficulty != systems.difficulty.top():
		ascension = 0
	mode = play_mode
	sandbox = sandbox_on
	foreign_build = foreign_on
	share_gold = share_on
	gold_pot = 0
	var d := MaulData.difficulty(difficulty)
	max_lives = int(d.get("lives", 150))
	lives = max_lives
	adapt_raw = [1.0]
	je = 1.0
	je_min = 1.0
	je_max = 1.0
	income_pot = int(rules.income.start)
	var m := players.size()
	for i in m:
		var pl: Player = players[i]
		pl.gold = int(rules.start_gold) / m + (int(rules.start_gold_red) if i == 0 else 0)
		pl.team_points = int(rules.team_points.start) + (int(rules.team_points.host) if i == 0 else 0)
		if sandbox:
			pl.xp = int(MaulXp.cfg().get("sandbox", 8000))
	countdown = float(rules.first_delay_many if m >= 4 else rules.first_delay)
	phase = Phase.COUNTDOWN
	_pick_shop(local_player, shop_id)
	if solo():
		Engine.time_scale = Session.speed
		auto_wave = Session.auto_wave_on()
	_refresh_hud()


## Filiale für Spieler p eröffnen (Zufall: "random" = Standard, "random_pro" = Profi).
func _pick_shop(p: int, shop_id: String) -> bool:
	var pl: Player = players[p]
	if pl.shop != "" or phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return false
	var pro_ok := MaulXp.pro_unlocked(pl.xp) and specials_on()
	if shop_id == "random" or shop_id == "random_pro":
		var kind := "pro" if shop_id == "random_pro" else "standard"
		var pool := MaulData.shops().filter(func(s): return str(s.kind) == kind)
		if pool.is_empty():
			return false
		shop_id = str(pool[randi() % pool.size()].id)
	var s := MaulData.shop(shop_id)
	if s.is_empty() or str(s.kind) == "xpert" or (str(s.kind) == "pro" and not pro_ok):
		return false
	pl.shop = shop_id
	if p == local_player:
		hud.hide_setup()
		hud.build_shop()
	return true


func shop_of(p := -1) -> String:
	return players[local_player if p < 0 else p].shop


func pl(p := -1) -> Player:
	return players[acting if p < 0 else p]


# --- Ablauf ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if phase == Phase.SETUP:
		return
	# Gebietsrahmen ab dem ersten Level nur noch schwach (auch beim Gast, level kommt vom Host);
	# hell nur, solange die Gebietsgrenze gilt (Option „Überall bauen“ hebt sie auf)
	if level > 0:
		board.set_zone_glow(Board3D.ZONE_FAINT)
	board.set_zone_rule(not foreign_build)
	if phase < Phase.GAME_OVER:
		game_time += delta
		play_time += delta / maxf(Engine.time_scale, 0.001)
	if message_time > 0.0:
		message_time -= delta / maxf(Engine.time_scale, 0.001)
		if message_time <= 0.0:
			message = ""
			hud.refresh_message()
	_update_hover()
	if not mirror:
		match phase:
			Phase.COUNTDOWN:
				if auto_wave and level > 0 and solo():
					countdown = 0.0
				countdown -= delta
				if countdown <= 0.0:
					_start_level(level + 1)
			Phase.WAVE:
				_process_wave(delta)
		_water(delta)
		if phase < Phase.GAME_OVER and MaulBank.process(self, delta):
			_refresh_hud()
	elif phase == Phase.COUNTDOWN:
		countdown = maxf(countdown - delta, 0.0)
	_hud_timer -= delta / maxf(Engine.time_scale, 0.001)
	if _hud_timer <= 0.0:
		_hud_timer = 0.2
		hud.refresh_live()


func is_wave_running() -> bool:
	return phase == Phase.WAVE


func current_wave() -> int:
	return level


func level_def(n: int) -> Dictionary:
	return levels[n - 1] if n >= 1 and n <= levels.size() else {}


## Gegner pro Spawnpunkt für ein Level dieser Art.
func per_spawn(kind: String) -> int:
	var e: Array = rules.enemies_per_spawn.get(kind, [2, 1])
	return int(e[0]) + int(e[1]) * players.size()


func spawn_count() -> int:
	return rules_spawns().size()


func rules_spawns() -> Array:
	return map.maul.get("spawns", [])


## Spielerfaktor Yx: 0,5·(1 + (11 − m)·0,02), +0,2 ab Level 36, 40, 41 und 49.
func player_factor(n: int) -> float:
	var pf: Dictionary = rules.player_factor
	var y := float(pf.base) * (1.0 + (int(pf.max_players) - players.size()) * float(pf.per_missing))
	for s in pf.steps_before:
		if n >= int(s):
			y += float(pf.step)
	return y


## HP-Budget der ganzen Welle (Jv'), mindestens +5 % zum Vorlevel.
func level_budget(n: int) -> float:
	var lv := level_def(n)
	var d := MaulData.difficulty(difficulty)
	var b := float(lv.get("jv", 1)) * float(d.get("hp", 180))
	if n > 1:
		b *= je * player_factor(n) * float(d.get("factor", 1.0))
		b = maxf(b, prev_budget * float(rules.min_growth))
	return b


func specials_on() -> bool:
	return bool(MaulData.difficulty(difficulty).get("specials", true))


func _start_level(n: int) -> void:
	if n > levels.size():
		_finish(Phase.VICTORY)
		return
	if not mirror:
		level_save = MaulSave.state(self)
	# Einzelspiel: vor jedem Level still speichern („Weiterspielen“ im Hub, Lukas 2026-11-03)
	if n > 1 and solo() and not Session.skip_setup and not sandbox:
		MaulSave.save(self)
	level = n
	var lv := level_def(n)
	level_kind = str(lv.get("kind", "ground"))
	level_specials = lv.get("specials", []) if specials_on() else []
	_frost_level = level_specials.has("frost")
	var per := per_spawn(level_kind)
	level_count = per * spawn_count()
	var budget := level_budget(n)
	prev_budget = budget
	level_hp = budget / level_count
	if level_kind == "boss":
		level_hp /= float(rules.boss_hp_divisor)
	level_lost = 0
	for p in players:
		p.level_kills = 0
		p.aok_lives = 0
	spawn_queue.clear()
	for i in spawn_count():
		spawn_queue.append([i, per])
	spawn_timer = 0.0
	phase = Phase.WAVE
	Sfx.play("boss" if level_kind == "boss" else "wave_start")
	_alternate.clear()
	show_message(level_title(n), 4.0)
	_refresh_hud()


## „Welle 7: Boden, Schnell“
func level_title(n: int) -> String:
	var lv := level_def(n)
	var parts := [kind_name(str(lv.get("kind", "")))]
	if specials_on():
		for s in lv.get("specials", []):
			parts.append(special_name(s))
	return tr("Welle %d: %s") % [n, ", ".join(parts)]


static func kind_name(kind: String) -> String:
	match kind:
		"air":
			return TranslationServer.translate("Luft")
		"boss":
			return TranslationServer.translate("Boss")
	return TranslationServer.translate("Boden")


static func special_name(s: String) -> String:
	match s:
		"invisible":
			return TranslationServer.translate("Unsichtbar")
		"fast":
			return TranslationServer.translate("Schnell")
		"spell_resist":
			return TranslationServer.translate("Zauberresistent")
		"frost":
			return TranslationServer.translate("Frost")
		"ghost":
			return TranslationServer.translate("Geist")
	return s


func _process_wave(delta: float) -> void:
	if not spawn_queue.is_empty():
		spawn_timer -= delta
		var line := mode == "line"
		var interval := float(rules.modes[1].get("interval", 0.8)) if line else float(rules.get("spawn_interval_group", 0.25))
		var max_alive := int(rules.modes[1].get("max_alive", 120)) if line else 1000000
		while spawn_timer <= 0.0 and not spawn_queue.is_empty():
			if enemies.size() >= max_alive:
				spawn_timer = interval
				break
			for q in spawn_queue:
				_spawn(int(q[0]))
				q[1] -= 1
			spawn_queue = spawn_queue.filter(func(q): return q[1] > 0)
			spawn_timer += interval
	if spawn_queue.is_empty() and enemies.is_empty():
		_end_level()


func _spawn(index: int) -> void:
	var s: Dictionary = rules_spawns()[index]
	var route: Dictionary = map.maul.routes[s.route]
	var lv := level_def(level)
	var e := MaulEnemy.new()
	var asc: Dictionary = systems.difficulty.ascension_mods()
	e.net_id = _next_enemy_id
	_next_enemy_id += 1
	e.route = str(s.route)
	var start := MaulMap.cell(s.cell)
	var legs: Array = route.legs
	e.legs = [{"start": start, "points": legs[0]}]
	for i in range(1, legs.size()):
		e.legs.append({"start": MaulMap.cell(legs[i][0]), "points": legs[i].slice(1)})
	e.chose = not route.has("choices")
	var specials := level_specials
	var sp: Dictionary = rules.specials
	var speed := float(lv.get("speed", 300)) + randi_range(-int(rules.speed_random), int(rules.speed_random))
	var armor := float(lv.get("armor", 0))
	var spell := 1.0
	if specials.has("fast"):
		speed *= 1.0 + float(sp.fast.speed)
	if specials.has("invisible"):
		armor += float(sp.invisible.armor)
		e.invisible = true
	if specials.has("ghost"):
		armor += float(sp.ghost.armor)
		spell *= float(sp.ghost.spell_factor)
		e.ghost = true
	if specials.has("spell_resist"):
		spell *= float(sp.spell_resist.spell_factor)
	e.frost = specials.has("frost")
	e.spell_factor = spell
	var boss := level_kind == "boss"
	var lk: Dictionary = rules.leak
	if boss:
		e.leak_cost = int(lk.boss_40) if level == int(rules.regular_levels) else int(lk.boss)
	else:
		e.leak_cost = clampi(int(lk.budget) / maxi(level_count, 1), 1, int(lk.max))
	var def := {
		"id": str(lv.get("unit", "")),
		"flying": level_kind == "air",
		"boss": boss,
		"color": _enemy_color(),
	}
	var o := {
		"hp": level_hp * float(asc.hp) + float(asc.hp_add),
		"speed": (speed / 128.0) * float(asc.speed) + float(asc.speed_add),
		"armor": armor * float(asc.armor) + float(asc.armor_add),
		"bounty": float(lv.get("bounty", 1)),
		"armor_type": str(lv.get("armor_type", "medium")),
		"size": 1.6 if boss else 1.0,
	}
	board.add_child(e)
	var leg := _leg_path(e, 0)
	e.setup(self, def, o, leg.path)
	e.waypoint_at = leg.wp
	enemies.append(e)


func _enemy_color() -> String:
	if level_kind == "boss":
		return "#ff4f4f"
	if level_kind == "air":
		return "#7fd4ff"
	if level_specials.has("ghost"):
		return "#b38cff"
	if level_specials.has("frost"):
		return "#bfefff"
	if level_specials.has("fast"):
		return "#ffd166"
	return "#d7cdea"


func _end_level() -> void:
	effects.clear()
	var n := level
	var air := level_kind == "air"
	# Selbstanpassung (JE) nach der Leckquote
	var quota := float(level_lost) / float(maxi(max_lives, 1))
	var a: Dictionary = rules.adapt
	var raw: float = adapt_raw.back()
	if quota <= float(a.quota) and not air:
		streak = mini(streak + 1, int(a.streak_max))
		if streak > 1:
			raw += streak * float(a.streak_step)
	else:
		raw -= quota / 2.0
		streak = maxi(streak - floori(30.0 * quota), 0)
		if quota >= float(a.reset_quota):
			streak = 0
	var d := MaulData.difficulty(difficulty)
	raw = clampf(raw, float(d.get("adapt_min", 0.75)), float(d.get("adapt_max", 7.5)))
	adapt_raw.append(raw)
	var last := adapt_raw.slice(maxi(adapt_raw.size() - int(a.average), 0))
	var sum := 0.0
	for v in last:
		sum += float(v)
	je = sum / last.size()
	je_min = minf(je_min, je)
	je_max = maxf(je_max, je)
	# Fehlerfrei: +5 Leben
	if level_lost == 0:
		lives = mini(lives + int(rules.leak.no_leak_bonus), max_lives)
	levels_done = n
	_end_level_pro(n)
	# Einkommen
	var inc: Dictionary = rules.income
	income_pot = floori((income_pot + int(inc.add)) * float(inc.growth))
	if n == 10 or n == 20 or n == 30:
		income_pot += int(inc.boss_bonus)
	var m := players.size()
	var my_income := 0
	for i in m:
		var share := floori(income_pot / m * income_factor(i))
		if i == 0:
			share += floori(income_pot * float(inc.red_share) / m)
		players[i].gold += share
		if i == local_player:
			my_income = share
	# Teampunkte nach Level 10, 20 und 30
	var team_bonus := (rules.team_points.after_levels as Array).has(float(n))  # JSON-Zahlen sind float
	if team_bonus:
		for pl in players:
			pl.team_points += 1
	# Obo: jede Runde −1 % Towerwert
	for t in towers.values():
		if shop_of(t.owner_player) == "obi":
			t.value = floori(t.value * 0.99)
	_fitness_upkeep()
	var bank_text := MaulBank.end_level(self)
	run_stats.wave_done(_my_towers(), n, level_lost)
	if n >= levels.size():
		_finish(Phase.VICTORY)
		return
	phase = Phase.COUNTDOWN
	if n == int(rules.regular_levels):
		countdown = float(rules.level_delay_after_40)
		show_message(tr(str(rules.get("level_40_text", ""))), 8.0)
	else:
		countdown = float(rules.level_delay)
		var done_text: String = tr("Welle %d geschafft: +%d Gold") % [n, my_income]
		if not is_equal_approx(income_factor(local_player), 1.0):
			done_text += " " + tr("(Konzernbonus %d %%)") % roundi(income_factor(local_player) * 100.0)
		if team_bonus:
			done_text += "\n" + tr("+1 Teampunkt für alle")
		show_message(done_text + ("\n" + bank_text if bank_text != "" else ""), 4.0)
	_refresh_hud()


## Konzernbonus (ohne Geldteilen, ab 2 Spielern): Platz p nach Kills im Level verändert das Einkommen,
## (100 − 5·m + Platz·10·m/(m − 1)) %, wer am wenigsten trifft, bekommt am meisten (bei 4 Spielern 93–133 %).
func income_factor(p: int) -> float:
	var m := players.size()
	if share_gold or m < 2:
		return 1.0
	var rank := 1
	for o in players:
		if o.level_kills > players[p].level_kills:
			rank += 1
	var inc: Dictionary = rules.income
	return (100.0 - float(inc.rank_base) * m + rank * float(inc.rank_step) * m / (m - 1)) / 100.0


func _finish(p: Phase) -> void:
	phase = p
	if sync == null and Session.save_id != "":
		SaveGame.remove(Session.save_id)
		Session.save_id = ""
	Engine.time_scale = 1.0
	build_id = ""
	_record_profile(p == Phase.VICTORY)
	_record_run(p == Phase.VICTORY)
	hud.show_game_over(p == Phase.VICTORY)


## Partie ins eigene Profil schreiben (auch Koop-Mitspieler, jeder auf seinem Rechner).
func _record_profile(won: bool) -> void:
	profile_news = {}
	if debug_run():
		return
	profile_news = MaulProfile.record(shop_of(local_player), difficulty, levels_done, won, enemies_killed, play_time)


## Run ins allgemeine Profil (profile.gd), auch mit Sandbox und Debug (dann nur in der Liste).
func _record_run(won: bool) -> void:
	var me = players[local_player]
	var info := {"map": shop_of(local_player), "shop": shop_of(local_player), "difficulty": difficulty, "ascension": ascension, "victory": won,
		"wave": levels_done, "waves": levels.size(), "lives": lives, "max_lives": max_lives, "kills": enemies_killed,
		"play_time": roundi(play_time), "coop": players.size() > 1, "players": players.size(),
		"xp": me.xp, "xp_gain": me.xp - xp_start, "gold": me.gold, "sandbox": sandbox}
	systems.run_record.finish(info, run_stats.result(_my_towers()))


## Debug-Menü, Sandbox oder Unsterblich in diesem Run: keine XP, zählt nicht für Siege und Rekorde (nur die Zeit).
func debug_run() -> bool:
	return sandbox or debug_used or Session.debug_immortal


## Spiel verlassen, bevor die Partie zu Ende ist: Zeit ins Profil, ohne Speichern auch als abgebrochen.
func _record_abort() -> void:
	if phase >= Phase.GAME_OVER or phase == Phase.SETUP and levels_done == 0:
		return
	systems.run_record.abort({"map": shop_of(local_player), "shop": shop_of(local_player), "difficulty": difficulty, "ascension": ascension,
		"wave": levels_done, "waves": levels.size(), "lives": lives, "kills": enemies_killed, "play_time": roundi(play_time)})


func _my_towers() -> Array:
	return towers.values().filter(func(t): return is_instance_valid(t) and t.owner_player == local_player)


## Tower t wird zu to (Ausbau oder Kopie): Werte bis jetzt der alten Art gutschreiben.
func _stats_change(t: MaulTower, to: String, action: String) -> void:
	var mine := t.owner_player == local_player
	if mine:
		run_stats.flush(t)
	t.set_tower(to, 0)
	if mine:
		run_stats.built(t, action, level)


# --- Wege --------------------------------------------------------------------------

## Weg eines Abschnitts: {path: PackedVector2Array (Feldmitten), wp: Index im Pfad je Wegpunkt}.
## Boden mit Towern, Geister nur übers Gelände, Flieger gerade von Punkt zu Punkt.
func _route(start: Vector2i, points: Array, how: String) -> Dictionary:
	var key := "%s|%s|%s" % [how, start, points]
	if _path_cache.has(key):
		return _path_cache[key]
	var res := _compute_route(start, points, how, pathfinder)
	_path_cache[key] = res
	return res


func _compute_route(start: Vector2i, points: Array, how: String, finder: Pathfinder) -> Dictionary:
	var path := PackedVector2Array([Board3D.cell_center(start)])
	var wp: Array = []
	var from := start
	var f := ghost_finder if how == "ghost" else finder
	for p in points:
		var to := MaulMap.cell(p)
		if how == "air":
			path.append(Board3D.cell_center(to))
		else:
			if f.astar.is_point_solid(from) or f.astar.is_point_solid(to):
				return {"path": PackedVector2Array(), "wp": []}
			var seg := f.astar.get_id_path(from, to)
			if seg.is_empty():
				return {"path": PackedVector2Array(), "wp": []}
			for j in range(1, seg.size()):
				path.append(Board3D.cell_center(seg[j]))
		wp.append(path.size() - 1)
		from = to
	return {"path": path, "wp": wp}


func _how(e: MaulEnemy) -> String:
	return "air" if e.flying else ("ghost" if e.ghost else "ground")


func _leg_path(e: MaulEnemy, i: int) -> Dictionary:
	var leg: Dictionary = e.legs[i]
	var how := "air" if level_kind == "air" else ("ghost" if e.ghost else "ground")
	return _route(leg.start, leg.points, how)


## Alle Abschnitte aller Routen (mit beiden Abzweigungen) als [Start, Punkte].
func all_legs() -> Array:
	var list := []
	for s in rules_spawns():
		var r: Dictionary = map.maul.routes[s.route]
		list.append([MaulMap.cell(s.cell), r.legs[0]])
		for i in range(1, r.legs.size()):
			list.append([MaulMap.cell(r.legs[i][0]), r.legs[i].slice(1)])
		for ch in r.get("choices", []):
			for leg in ch.legs:
				list.append([MaulMap.cell(leg[0]), leg.slice(1)])
	return list


## Neu berechnen nach Bauen/Verkaufen; zeigt die Wege als Punkte. Im Mehrspieler erst nur die
## Abschnitte durchs eigene Gebiet, die übrigen über show_all_paths (Knopf an der Übersichtskarte).
func _refresh_paths() -> void:
	_path_cache.clear()
	var zone: int = players[local_player].zone
	var own := {}
	var other := {}
	_own_routes = []
	_other_routes = []
	for leg in all_legs():
		var r := _route(leg[0], leg[1], "ground")
		var mine := players.size() <= 1
		for p in r.path:
			if mine:
				break
			mine = map.zone_at(Vector2i(floori(p.x / Board3D.CELL), floori(p.y / Board3D.CELL))) == zone
		for i in range(0, r.path.size(), 2):
			(own if mine else other)[r.path[i]] = true
		if not _own_routes.has(r.path) and not _other_routes.has(r.path):  # gleiche Abschnitte nur einmal beleuchten
			(_own_routes if mine else _other_routes).append(r.path)
	_own_path_pts = PackedVector2Array(own.keys())
	_other_path_pts = PackedVector2Array(other.keys().filter(func(p): return not own.has(p)))
	_show_paths()


func has_other_paths() -> bool:
	return not _other_path_pts.is_empty()


func set_show_all_paths(on: bool) -> void:
	show_all_paths = on
	if hud.paths_button != null:
		hud.paths_button.set_pressed_no_signal(on)
	_show_paths()


func _show_paths() -> void:
	board.path_points = _own_path_pts + _other_path_pts if show_all_paths else _own_path_pts
	board.refresh_path()
	if path_lights != null:
		path_lights.set_paths(_own_routes + _other_routes if show_all_paths else _own_routes)


## Lichter in der Farbe des Spielers, durch dessen Gebiet sie gerade fliegen (Spieler i besitzt Gebiet i,
## Board3D.PLAYER_COLORS); außerhalb der Spielergebiete in Messing (PathLights.COLORS).
func _path_light_color(p: Vector2) -> Color:
	var z := map.zone_at(Vector2i(floori(p.x / Board3D.CELL), floori(p.y / Board3D.CELL)))
	if z < 0 or z >= players.size():
		return Color(0, 0, 0, 0)
	return Board3D.PLAYER_COLORS[z % Board3D.PLAYER_COLORS.size()]


## Lichtpfad ein/aus (Knopf im HUD, Taste L); bleibt gespeichert. Solange er läuft, ohne Wegpunkte am Boden.
func set_path_lights(on: bool) -> void:
	Display.set_path_lights(on)
	path_lights.visible = on
	board.set_path_dots(not on)
	if hud.lights_button != null:
		hud.lights_button.set_pressed_no_signal(on)


## Würde ein Tower auf diesen Feldern einen der Wege versperren?
func would_block(cells: Array[Vector2i]) -> bool:
	var changed: Array[Vector2i] = []
	for c in cells:
		if not pathfinder.astar.is_point_solid(c):
			pathfinder.astar.set_point_solid(c, true)
			changed.append(c)
	var blocked := false
	var tried := {}
	for leg in all_legs():
		var key := "%s|%s" % [leg[0], leg[1]]
		if tried.has(key):
			continue
		tried[key] = true
		if _compute_route(leg[0], leg[1], "ground", pathfinder).path.is_empty():
			blocked = true
			break
	for c in changed:
		pathfinder.astar.set_point_solid(c, false)
	return blocked


## Gegner, deren restlicher Weg über neue Tower führt, laufen von ihrer Stelle aus neu.
func _repath_enemies(cells: Array[Vector2i]) -> void:
	var blocked := {}
	for c in cells:
		blocked[Board3D.cell_center(c)] = true
	for e in enemies:
		if e.dead or e.flying or e.ghost:
			continue
		var hit := false
		for i in range(e.path_index, e.path.size()):
			if blocked.has(e.path[i]):
				hit = true
				break
		if not hit:
			continue
		var rest: Array = []
		var pts: Array = e.legs[e.leg].points
		for k in e.waypoint_at.size():
			if int(e.waypoint_at[k]) >= e.path_index:
				rest.append(pts[k])
		var here := Vector2i(floori(e.pos.x / Board3D.CELL), floori(e.pos.y / Board3D.CELL))
		var r := _compute_route(here, rest, "ground", pathfinder)
		if r.path.is_empty():
			continue
		var path: PackedVector2Array = r.path
		path[0] = e.pos
		e.path = path
		e.path_index = 1
		var wp: Array = []
		var skipped := pts.size() - rest.size()
		for k in skipped:
			wp.append(-1)
		wp.append_array(r.wp)
		e.waypoint_at = wp


# --- Gegner: Schnittstelle für Enemy/Tower -----------------------------------------

func on_enemy_killed(e) -> void:
	enemies_killed += 1
	var p: int = e.last_hit_by if e.last_hit_by >= 0 and e.last_hit_by < players.size() else 0
	if share_gold:
		_share_bounty(int(e.bounty))
	else:
		players[p].gold += int(e.bounty)
	players[p].kills += 1
	players[p].level_kills += 1
	# AOX: 10 % Chance, Leben zurückzuholen (Tower mit "Life" würfeln selbst, MaulTower._killed)
	if players[p].shop == "aok" and randf() < float(MaulData.pro().aok.life_chance):
		kill_life(p, e)
	# Contained Darkness frisst Leichen in der Nähe, nach 5 wird sie für 30 s zur Unleashed Darkness
	var dk: Dictionary = MaulData.pro().undertaker.darkness
	for t in towers.values():
		if t.tower_id == str(dk.tower) and not t.is_unleashed() and t.pos.distance_to(e.pos) <= float(dk.radius):
			t.corpses += 1
			if t.corpses >= int(dk.corpses):
				t.corpses = 0
				t.unleashed_until = game_time + float(dk.duration)
				if t == selected:
					hud.refresh_selection()
	_remove_enemy(e)
	_refresh_hud()


## Geldteilen: Kopfgeld in den Topf, ausgezahlt wird, sobald jeder gleich viel bekommt.
func _share_bounty(amount: int) -> void:
	gold_pot += amount
	var m := players.size()
	var each := gold_pot / m
	if each <= 0:
		return
	for pl in players:
		pl.gold += each
	gold_pot -= each * m


## Leben durch einen Kill zurückholen (AOX, Life): die Hälfte der Leckkosten, höchstens 30 pro Level und Spieler.
func kill_life(p: int, e) -> void:
	if lives >= max_lives or p < 0 or p >= players.size():
		return
	var room: int = int(MaulData.pro().aok.life_max_per_level) - players[p].aok_lives
	var gain := mini(maxi(e.leak_cost / 2, 1), room)
	if gain > 0:
		players[p].aok_lives += gain
		gain_lives(gain)


func gain_lives(n: int) -> void:
	lives = mini(lives + n, max_lives)
	_refresh_hud()


## Ende eines Abschnitts: Teleport zum nächsten Abschnitt, sonst Leak.
func on_enemy_leaked(e) -> void:
	var me: MaulEnemy = e
	if me.leg + 1 < me.legs.size():
		_teleport(me, me.leg + 1)
		return
	if not me.chose:
		var route: Dictionary = map.maul.routes[me.route]
		var ch: Dictionary = _choose(me.route, route.choices)
		me.chose = true
		var base := me.legs.size()
		for leg in ch.legs:
			me.legs.append({"start": MaulMap.cell(leg[0]), "points": leg.slice(1)})
		_teleport(me, base)
		return
	enemies_leaked += 1
	var cost := 0 if sandbox else mini(me.leak_cost, lives)
	lives -= cost
	level_lost += cost
	if cost > 0:
		Sfx.play("leak")
	_remove_enemy(me)
	if lives <= 0 and not Session.debug_immortal:
		lives = 0
		_finish(Phase.GAME_OVER)
	_refresh_hud()


## Abzweigung links/rechts: ist eines der Gebiete leer, gehen alle ins bebaute, sonst abwechselnd.
func _choose(route: String, choices: Array) -> Dictionary:
	var built := choices.filter(func(c): return _zone_towers[int(c.zone)] > 1)
	if built.size() == 1:
		return built[0]
	var n: int = _alternate.get(route, 0)
	_alternate[route] = n + 1
	return choices[n % choices.size()]


func _teleport(e: MaulEnemy, leg: int) -> void:
	var from := e.position
	e.leg = leg
	e.leg_from = e.traveled
	e.path_len = -1.0
	var r := _leg_path(e, leg)
	if r.path.is_empty():
		r = _route(e.legs[leg].start, e.legs[leg].points, "ghost")
	e.path = r.path
	e.waypoint_at = r.wp
	e.path_index = 1
	e.pos = e.path[0]
	e.dead = false
	e._sync_position()
	add_beam(from + Vector3(0, 0.3, 0), e.position + Vector3(0, 0.3, 0), Color("b38cff"))


func _remove_enemy(e) -> void:
	enemies.erase(e)
	if selected_enemy == e:
		selected_enemy = null
	e.queue_free()


var selected_enemy = null


## Leere Gebiete (ohne Tower) laufen die Gegner dreimal so schnell durch.
func is_covered(e) -> bool:
	var c := Vector2i(floori(e.pos.x / Board3D.CELL), floori(e.pos.y / Board3D.CELL))
	var z := map.zone_at(c)
	return z < 0 or _zone_towers[z] > 0


func idle_speed_factor() -> float:
	return float(rules.get("empty_zone_speed", 3.0))


func free_stretch(_e) -> Array:
	return [-1.0, -1.0]


func is_detected(e) -> bool:
	if not e.invisible:
		return true
	if e.detected_until > game_time or sight_until > game_time:
		return true
	for p in players:
		if MaulData.rules().detect_shops.has(p.shop) or p.reveal_until > game_time:
			return true
	for t in _detect_towers:
		if is_instance_valid(t) and e.pos.distance_to(t.pos) <= float(t.ability("detect").radius):
			e.detected_until = game_time + 0.5
			return true
	for u in units:
		var r: float = u.detect_radius()
		if r > 0.0 and e.pos.distance_to(u.pos) <= r:
			e.detected_until = game_time + 0.5
			return true
	return false


## Frost-Level: Tower im Umkreis eines Frostgegners greifen 33 % langsamer an.
func frost_factor(t) -> float:
	if not _frost_level:
		return 1.0
	var f: Dictionary = rules.specials.frost
	var r := float(f.radius) / 128.0
	for e in enemies:
		if e.frost and not e.dead and e.pos.distance_to(t.pos) <= r:
			return 1.0 / (1.0 - float(f.attack_slow))
	return 1.0


## Weiterleitung → System  targeting
func find_targets(t, count: int) -> Array:
	return systems.targeting.find_targets(t, count)


## Weiterleitung → System  targeting
func find_targets_in(t, r: float, count: int) -> Array:
	return systems.targeting.find_targets_in(t, r, count)


## Weiterleitung → System  targeting
func enemies_in_radius(p: Vector2, radius: float) -> Array:
	return systems.targeting.enemies_in_radius(p, radius)


## fx wie bei game.gd ("t:<tower>:<stufe>"); FxData wählt den Effekt nach Filialfarbe und Fähigkeit.
func add_beam(from: Vector3, to: Vector3, col: Color, fx: String = "") -> void:
	effects.add_beam(from, to, col, fx)
	if sync != null and not mirror:
		sync.add_beam(from, to, col, fx)


## Ring aus kurzen Strahlen (Donnerschlag).
func add_ring(p: Vector2, r: float, col: Color) -> void:
	var n := 16
	for i in n:
		var a := TAU * i / n
		var b := TAU * (i + 1) / n
		add_beam(Board3D.to_3d(p + Vector2(cos(a), sin(a)) * r, 0.15), Board3D.to_3d(p + Vector2(cos(b), sin(b)) * r, 0.15), col)


func add_gold(amount: int, p := -1) -> void:
	players[acting if p < 0 else p].gold += amount
	_refresh_hud()


# --- Bauen -------------------------------------------------------------------------

func boss_alive() -> bool:
	for e in enemies:
		if e.boss and not e.dead:
			return true
	return false


func tower_count(p: int) -> int:
	var n := 0
	for t in towers.values():
		if t.owner_player == p:
			n += 1
	return n


func tower_value(p := -1) -> int:
	var n := 0
	var who := local_player if p < 0 else p
	for t in towers.values():
		if t.owner_player == who:
			n += t.value
	return n


func food_limit(p: int) -> int:
	var small := ["tui", "waffenladen"]
	return int(MaulData.pro().get("food_small", 6)) if small.has(shop_of(p)) else int(rules.food)


## Ist ein Tower ein XP-Tower (Token n00B) oder ein Ultimate-Tower (n00H, auch deren Upgrades)?
static func tower_slot(def: Dictionary) -> String:
	var t := def
	while not t.is_empty():
		var req: Array = t.get("requires", [])
		if req.has("n00B"):
			return "xp"
		if req.has("n00H"):
			return "ultimate"
		if t.get("upgrade_from") == null:
			break
		t = MaulData.tower(str(t.upgrade_from))
	return ""


## Fehlende Voraussetzung eines Towers für Spieler p ("" = erfüllt): XP, Level 20 geschafft, kein AOX,
## höchstens ein XP- und ein Ultimate-Tower. ignore: Tower, der gerade aufgewertet wird.
func requirement_problem(def: Dictionary, p: int, ignore: MaulTower = null) -> String:
	if debug_free:
		return ""
	for req in def.get("requires", []):
		var need := MaulXp.needed(str(req))
		if need > 0 and players[p].xp < need:
			return tr("Braucht %d XP") % (need / 10)
		match str(req):
			"R00S":
				if levels_done < int(MaulData.pro().get("ultimate_level", 20)):
					return tr("Erst ab Level %d") % (int(MaulData.pro().get("ultimate_level", 20)) + 1)
			"R00U":
				if shop_of(p) == "aok":
					return tr("Nicht mit der AOX")
	var slot := tower_slot(def)
	if slot != "" and ignore == null:
		for t in towers.values():
			if t.owner_player == p and tower_slot(t.def) == slot:
				return tr("Nur ein XP-Tower erlaubt") if slot == "xp" else tr("Nur ein Ultimate-Tower erlaubt")
	if str(def.get("id", "")) == str(MaulData.pro().drones.charger):
		for t in towers.values():
			if t.owner_player == p and t.tower_id == def.id:
				return tr("Nur ein Drone Charger erlaubt")
	return ""


## Darf Spieler p in Gebiet z bauen und Einheiten aufstellen? Ohne „Überall bauen“ nur im eigenen.
func may_use_zone(z: int, p: int) -> bool:
	return z == players[p].zone or (foreign_build and z >= 0)


## Grund, warum Spieler p hier nicht bauen kann ("" = geht). check_path: Wege prüfen (teuer).
func build_problem(id: String, a: Vector2i, p: int, check_path := false) -> String:
	var def := MaulData.tower(id)
	var own := str(def.get("shop", ""))
	if def.is_empty() or (own != shop_of(p) and own != "xpert" and not debug_free) or shop_of(p) == "":
		return tr("Kein Tower deiner Filiale")
	if phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return tr("Gerade kann nicht gebaut werden")
	var cells := Board3D.footprint(a)
	for c in cells:
		if not map.in_bounds(c) or map.get_tile(c) != MapData.FLOOR or not may_use_zone(map.zone_at(c), p):
			return tr("Nur im eigenen Gebiet") if not foreign_build else tr("Nur in einem Gebiet")
		if map.is_marker_zone(c):
			return tr("Zu nah am Wegpunkt")
		if occupied.has(c):
			return tr("Hier steht schon ein Tower")
	var why := requirement_problem(def, p)
	if why != "":
		return why
	if int(def.get("cost", 0)) > players[p].gold:
		return tr("Zu wenig Gold")
	if tower_count(p) >= food_limit(p) and not debug_free:
		return tr("Kein Platz mehr (höchstens %d Tower)") % food_limit(p)
	if boss_alive() and not debug_free:
		return tr("Solange ein Boss lebt, wird nicht gebaut")
	var here := {}
	for c in cells:
		here[c] = true
	for e in enemies:
		if not e.flying and here.has(Vector2i(floori(e.pos.x / Board3D.CELL), floori(e.pos.y / Board3D.CELL))):
			return tr("Ein Gegner steht im Weg")
	if check_path and would_block(cells):
		return tr("Würde den Weg versperren")
	return ""


func submit(cmd: Dictionary) -> bool:
	if not cmd.has("player"):
		cmd.player = local_player
	var ok := true
	if mirror:
		sync.send(cmd)
	else:
		ok = execute(cmd)
	Sfx.command_sound(cmd, ok)
	return ok


func execute(cmd: Dictionary) -> bool:
	var p := int(cmd.get("player", -1))
	if p < 0 or p >= players.size():
		return false
	acting = p
	var ok := _execute(cmd)
	acting = local_player
	if ok:
		_refresh_hud()
		if selected != null and is_instance_valid(selected):
			hud.refresh_selection()
	return ok


## Gold ausgeben; Filialen mit Rabatt bekommen 5 % je Stufe zurück.
func _pay(p: int, cost: int) -> void:
	var pl: Player = players[p]
	pl.gold -= cost
	if str(MaulData.shop(pl.shop).get("bonus", "")) == "rebate" and pl.bonus > 0:
		pl.gold += floori(cost * float(MaulData.pro().bonus.rebate_step) * pl.bonus)


func _tower(p: int, cell) -> MaulTower:
	var t: MaulTower = towers.get(cell, null) if cell is Vector2i else null
	return t if t != null and t.owner_player == p else null


func _execute(cmd: Dictionary) -> bool:
	var p := acting
	match str(cmd.get("type", "")):
		"shop":
			if mirror:
				return false
			players[p].xp = clampi(int(cmd.get("xp", players[p].xp)), 0, int(MaulXp.cfg().get("max", 9999))) if not sandbox else players[p].xp
			if _pick_shop(p, str(cmd.get("shop", ""))):
				return true
			_tell(p, tr("Diese Filiale ist gesperrt"))
			return false
		"build":
			var a: Vector2i = cmd.cell
			var id := str(cmd.tower)
			var why := build_problem(id, a, p, true)
			if why != "":
				_tell(p, why)
				return false
			var def := MaulData.tower(id)
			_pay(p, int(def.cost))
			var t := MaulTower.new()
			t.owner_player = p
			board.add_child(t)
			t.setup(self, a, id, 0)
			t.value = int(def.get("value", def.cost))
			_register(t)
			if p == local_player:
				run_stats.built(t, "build", level)
			return true
		"sell":
			var t: MaulTower = towers.get(cmd.cell, null)
			if t == null or (t.owner_player != p and map.zone_at(t.cell) != players[p].zone):
				return false
			players[t.owner_player].gold += sell_value(t)
			if t.owner_player == local_player:
				run_stats.flush(t)
			_unregister(t)
			t.queue_free()
			return true
		"upgrade":
			var t := _tower(p, cmd.get("cell"))
			var to := str(cmd.get("to", ""))
			if t == null or not t.def.get("upgrades_to", []).has(to):
				return false
			var def := MaulData.tower(to)
			var why := requirement_problem(def, p, t)
			if why == "" and int(def.cost) > players[p].gold:
				why = tr("Zu wenig Gold")
			if why != "":
				_tell(p, why)
				return false
			_pay(p, int(def.cost))
			_stats_change(t, to, "upgrade")
			t.value = int(def.value) if def.get("swap", false) else t.value + int(def.cost)
			t.set_selected(t == selected)
			_update_detect()
			return true
		"start_now":
			if phase == Phase.COUNTDOWN and p == 0:
				countdown = 0.0
				return true
			return false
		"speed":
			Engine.time_scale = clampf(float(cmd.get("f", 1.0)), 1.0, 4.0)
			return true
		"reveal":
			var me: Player = players[p]
			if me.reveal_ready > game_time or MaulData.rules().detect_shops.has(me.shop):
				return false
			me.reveal_until = game_time + float(rules.reveal.duration)
			me.reveal_ready = game_time + float(rules.reveal.cooldown)
			return true
		"deposit", "withdraw", "auto_deposit", "bank_upgrade":
			return MaulBank.execute(self, p, str(cmd.type))
		"team":
			return _use_team_point(p, str(cmd.get("use", "")))
		"xp":
			# Koop-Mitspieler steigt in einen gespeicherten Koop ein: seine XP gehören seinem Rechner
			if not sandbox:
				players[p].xp = clampi(int(cmd.get("xp", players[p].xp)), 0, int(MaulXp.cfg().get("max", 9999)))
			return true
		"bonus":
			var me: Player = players[p]
			var kind := str(MaulData.shop(me.shop).get("bonus", ""))
			if not has_bonus(p) or me.bonus >= int(MaulData.pro().bonus.levels):
				return false
			var cost := MaulData.bonus_cost(me.bonus + 1, kind == "rebate", players.size())
			if cost > me.gold:
				_tell(p, tr("Zu wenig Gold"))
				return false
			me.gold -= cost
			me.bonus += 1
			return true
		"research":
			var me: Player = players[p]
			var r: Dictionary = MaulData.pro().tui.research.get(str(cmd.get("id", "")), {})
			var lv: int = me.research.get(str(cmd.id), 0)
			if me.shop != "tui" or r.is_empty() or lv >= int(r.max):
				return false
			if int(r.cost) > me.gold:
				_tell(p, tr("Zu wenig Gold"))
				return false
			me.gold -= int(r.cost)
			me.research[str(cmd.id)] = lv + 1
			return true
		"item":
			return _buy_item(p, _tower(p, cmd.get("cell")), str(cmd.get("item", "")))
		"item_sell":
			var t := _tower(p, cmd.get("cell"))
			var i := int(cmd.get("slot", -1))
			if t == null or i < 0 or i >= t.items.size():
				return false
			players[p].gold += floori(int(MaulData.item(str(t.items[i])).get("cost", 0)) * float(rules.sell_refund))
			t.items.remove_at(i)
			return true
		"item_move":
			return move_item(p, cmd.get("from", {}), cmd.get("to", {}))
		"move_items":
			var from := _tower(p, cmd.get("from"))
			var to := _tower(p, cmd.get("to"))
			if from == null or to == null or from == to or from.slots() == 0 or to.slots() == 0:
				return false
			while not from.items.is_empty() and to.items.size() < to.slots():
				to.items.append(from.items.pop_front())
				_combine(to)
			return true
		"copy":
			var t := _tower(p, cmd.get("cell"))
			var to := str(cmd.get("to", ""))
			var cs: Dictionary = MaulData.pro().copyshop
			var def := MaulData.tower(to)
			if t == null or t.tower_id != str(cs.copier) or def.is_empty() or not cs.shops.has(str(def.shop)):
				return false
			var cost := copy_cost(to)
			if cost > players[p].gold:
				_tell(p, tr("Zu wenig Gold"))
				return false
			players[p].gold -= cost
			_stats_change(t, to, "copy")
			t.value = int(def.get("value", def.cost))
			_update_detect()
			return true
		"summon":
			var t := _tower(p, cmd.get("cell"))
			var id := str(cmd.get("unit", ""))
			if t == null or not MaulData.pro().undertaker.summons.get(t.tower_id, []).has(id):
				return false
			if float(t.summon_ready.get(id, 0.0)) > game_time:
				return false
			t.summon_ready[id] = game_time + float(MaulData.unit(id).get("summon_cd", 10))
			spawn_unit(id, p, t)
			return true
		"drone":
			var t := _tower(p, cmd.get("cell"))
			var kind := str(cmd.get("kind", ""))
			var dr: Dictionary = MaulData.pro().drones
			if t == null or t.tower_id != str(dr.charger) or not ["battle", "support"].has(kind):
				return false
			if units.filter(func(u): return u.owner_player == p and u.drone).size() >= int(dr.max):
				_tell(p, tr("Höchstens %d Drohnen") % int(dr.max))
				return false
			var cost := int(MaulData.unit(kind).get("cost", 20))
			if cost > players[p].gold:
				_tell(p, tr("Zu wenig Gold"))
				return false
			_pay(p, cost)
			spawn_unit(kind, p, t)
			return true
		"module":
			return _buy_module(p, unit_by_id(int(cmd.get("unit", -1))), str(cmd.get("item", "")))
		"module_sell":
			var u := unit_by_id(int(cmd.get("unit", -1)))
			var slot := str(cmd.get("slot", ""))
			if u == null or u.owner_player != p or not u.modules.has(slot):
				return false
			players[p].gold += floori(int(MaulData.item(str(u.modules[slot])).get("cost", 0)) * float(rules.sell_refund))
			u.modules.erase(slot)
			u.energy = minf(u.energy, u.max_energy())
			return true
		"post":
			var u := unit_by_id(int(cmd.get("unit", -1)))
			if u == null or u.owner_player != p:
				return false
			var at := Vector2(float(cmd.get("x", 0)), float(cmd.get("y", 0)))
			if not may_use_zone(map.zone_at(Vector2i(floori(at.x / Board3D.CELL), floori(at.y / Board3D.CELL))), p):
				_tell(p, tr("Nur im eigenen Gebiet") if not foreign_build else tr("Nur in einem Gebiet"))
				return false
			u.post = at
			return true
	return false


## Teampunkt einlösen: "lives" +10 Leben (nur wenn welche fehlen), "sight" Durchblick 30 s,
## "winter" Winter 10 s (alle Gegner −90 % Tempo). Wirkt fürs ganze Team.
func _use_team_point(p: int, use: String) -> bool:
	var me: Player = players[p]
	if me.team_points <= 0 or phase >= Phase.GAME_OVER:
		return false
	var tp: Dictionary = rules.team_points
	var text := ""
	match use:
		"lives":
			if lives >= max_lives:
				_tell(p, tr("Die Leben sind schon voll"))
				return false
			gain_lives(int(tp.lives))
			text = tr("%s löst einen Teampunkt ein: +%d Leben") % [me.name, int(tp.lives)]
		"sight":
			sight_until = maxf(sight_until, game_time) + float(tp.sight)
			text = tr("%s löst einen Teampunkt ein: Durchblick für %d s") % [me.name, int(tp.sight)]
		"winter":
			winter_until = maxf(winter_until, game_time) + float(tp.winter)
			text = tr("%s löst einen Teampunkt ein: Winter für %d s") % [me.name, int(tp.winter)]
		_:
			return false
	me.team_points -= 1
	for i in players.size():
		_tell(i, text)
	return true


## Winter (Teampunkt): Faktor aufs Tempo aller Gegner.
func winter_factor() -> float:
	return 1.0 - float(rules.team_points.winter_slow) if winter_until > game_time else 1.0


## Meldung an Spieler p: lokal sofort, an Mitspieler über den nächsten Stand (maul_sync.gd → notes).
func _tell(p: int, text: String) -> void:
	if p == local_player:
		show_message(text)
	elif sync != null:
		notes[p] = [int(notes.get(p, [0, ""])[0]) + 1, text]


func has_bonus(p: int) -> bool:
	var s := shop_of(p)
	return s != "" and str(MaulData.shop(s).get("bonus", "")) != "" and not ["gaertnerei", "waffenladen"].has(s)


## Copyshop: Punktwert × 1,05 − 9 Gold (Tower unter 9 Gold sind gratis).
func copy_cost(id: String) -> int:
	var cs: Dictionary = MaulData.pro().copyshop
	var v := int(MaulData.tower(id).get("value", 0))
	return 0 if v < int(cs.minus) else floori(v * float(cs.factor) - float(cs.minus))


## Läden, die Spieler p für dieses Item gebaut hat (Item gibt es nur, wenn so ein Laden steht).
func store_has(p: int, item_id: String) -> bool:
	if debug_free:
		return not MaulData.item(item_id).is_empty()
	var st: Dictionary = MaulData.pro().stores
	for t in towers.values():
		if t.owner_player == p and st.get(t.tower_id, []).has(item_id):
			return true
	return false


## Items, die Spieler p gerade kaufen kann (aus seinen Läden), nach Preis.
func items_for(p: int, kind: String) -> Array:
	var st: Dictionary = MaulData.pro().stores
	var seen := {}
	if debug_free:
		for id in MaulData.pro().get("items", {}):
			if str(MaulData.item(id).get("kind", "weapon")) == kind:
				seen[str(id)] = true
	for t in towers.values():
		if t.owner_player == p:
			for id in st.get(t.tower_id, []):
				var it := MaulData.item(str(id))
				if str(it.get("kind", "weapon")) == kind:
					seen[str(id)] = true
	var list := seen.keys()
	list.sort_custom(func(x, y): return int(MaulData.item(x).cost) < int(MaulData.item(y).cost))
	return list


func _buy_item(p: int, t: MaulTower, id: String) -> bool:
	var it := MaulData.item(id)
	if t == null or it.is_empty() or not store_has(p, id):
		return false
	var cost := int(it.get("cost", 0))
	if cost > players[p].gold:
		_tell(p, tr("Zu wenig Gold"))
		return false
	if str(it.get("kind", "weapon")) == "drug":
		if not MaulData.pro().fitness.upkeep.has(t.tower_id):
			return false
		_pay(p, cost)
		_take_drug(t, it)
		return true
	if t.items.size() >= t.slots():
		_tell(p, tr("Alle Slots belegt"))
		return false
	_pay(p, cost)
	t.items.append(id)
	_combine(t)
	return true


## Item wie in WC3 ziehen: von {"tower": Anker, "slot": k} nach {"tower": Anker, "slot": j} (j über den belegten
## Plätzen oder -1 = freier Platz). Auf ein Item = tauschen, sonst verschieben; danach greifen die IKEO-Kombis.
func move_item(p: int, from: Dictionary, to: Dictionary) -> bool:
	if move_reason(p, from, to) != "":
		return false
	var a := _tower(p, from.get("tower"))
	var b := _tower(p, to.get("tower"))
	var k := int(from.get("slot", -1))
	var j := int(to.get("slot", -1))
	var id: String = a.items[k]
	if j >= 0 and j < b.items.size():
		a.items[k] = b.items[j]
		b.items[j] = id
	else:
		a.items.remove_at(k)
		b.items.append(id)
	a._item_cd.clear()
	b._item_cd.clear()
	_combine(a)
	if b != a:
		_combine(b)
	return true


## Warum das Item nicht dorthin geht ("" = geht).
func move_reason(p: int, from: Dictionary, to: Dictionary) -> String:
	var a := _tower(p, from.get("tower"))
	var b := _tower(p, to.get("tower"))
	var k := int(from.get("slot", -1))
	var j := int(to.get("slot", -1))
	if a == null or k < 0 or k >= a.items.size():
		return tr("Item nicht mehr da")
	if b == null:
		return tr("Nicht dein Tower")
	if b.slots() <= 0:
		return tr("Dieser Tower hat keine Item-Slots")
	if j >= b.slots():
		return tr("Diesen Slot hat der Tower nicht")
	if a == b and (j == k or j < 0 or j >= b.items.size()):
		return tr("Liegt schon in diesem Tower") if j != k else tr("Liegt schon dort")
	if (j < 0 or j >= b.items.size()) and b.items.size() >= b.slots():
		return tr("Inventar voll")
	return ""


## IKEO: zwei passende Teile im selben Show House werden zu einem besseren (auch mehrstufig).
func _combine(t: MaulTower) -> void:
	var again := true
	while again:
		again = false
		for c in MaulData.pro().get("combos", []):
			var i := t.items.find(c[0])
			if i < 0:
				continue
			var j := -1
			for k in t.items.size():
				if k != i and t.items[k] == c[1]:
					j = k
					break
			if j < 0:
				continue
			t.items.remove_at(maxi(i, j))
			t.items.remove_at(mini(i, j))
			t.items.append(str(c[2]))
			_tell(t.owner_player, tr("Combo: %s") % MaulData.item_name(str(c[2])))
			again = true
			break


## Fitness: Doping wirkt sofort und dauerhaft; starke Mittel bringen Nebenwirkungen (Dosis/300 Stufen).
func _take_drug(t: MaulTower, it: Dictionary) -> void:
	var fit: Dictionary = MaulData.pro().fitness
	var dmg := 0.0
	if it.has("damage"):
		var d = it.damage
		dmg = randf_range(float(d[0]), float(d[1])) if d is Array else float(d)
	t.flat += roundf(dmg)
	var s = it.get("side", 0)
	var add := 0.0
	if str(s) == "dose":
		add = dmg / float(fit.side_dose)
	else:
		add = float(s)
	if add > 0.0:
		add *= float(fit.resist.get(t.tower_id, 1.0))
	t.side = maxi(t.side + roundi(add), 0)
	if it.has("stun"):
		t.drugs["stun"] = [float(it.stun_chance), float(it.stun)]
	if it.has("frost"):
		t.drugs["frost"] = float(it.frost)
	if it.has("slow_aura"):
		t.drugs["slow_aura"] = float(it.slow_aura)
	t._update_extra()


func _buy_module(p: int, u: MaulUnit, id: String) -> bool:
	var it := MaulData.item(id)
	if u == null or u.owner_player != p or not u.drone or str(it.get("kind", "")) != "module" or not store_has(p, id):
		return false
	var slot := str(it.slot)
	if it.get("battle_only", false) and u.unit_id != "battle":
		_tell(p, tr("Hilfsdrohnen tragen keine Kanonen"))
		return false
	if u.modules.has(slot):
		_tell(p, tr("Dieser Modultyp ist schon eingebaut"))
		return false
	if u.modules.size() >= int(MaulData.pro().drones.slots):
		_tell(p, tr("Alle Slots belegt"))
		return false
	if int(it.cost) > players[p].gold:
		_tell(p, tr("Zu wenig Gold"))
		return false
	_pay(p, int(it.cost))
	u.modules[slot] = id
	return true


func sell_value(t: MaulTower) -> int:
	return floori((t.value + t.items_value()) * float(rules.sell_refund))


# --- Profi-Filialen: Schaden, Wasser, Einheiten, Levelende -------------------------------

## Faktor auf den Schaden aller Tower von Spieler p: Bonus-Upgrade +5 % je Stufe, AOX mit vollen
## Leben +33 %, First/Second Aid +40/+50 % (nicht stapelbar).
func damage_factor_for(p: int) -> float:
	if p < 0 or p >= players.size():
		return 1.0
	var pl: Player = players[p]
	var f := 1.0
	if has_bonus(p) and str(MaulData.shop(pl.shop).get("bonus", "")) == "damage":
		f += pl.bonus * float(MaulData.pro().bonus.damage_step)
	if pl.shop == "aok":
		var aok: Dictionary = MaulData.pro().aok
		if lives >= max_lives:
			f += float(aok.full_lives_bonus)
		var aura := 0.0
		for t in towers.values():
			if t.owner_player == p:
				aura = maxf(aura, float(aok.auras.get(t.tower_id, 0.0)))
		f += aura
	return f


func damage_factor(t) -> float:
	return damage_factor_for(t.owner_player)


## Zusätzlicher Schaden pro Treffer: TOI-Forschung (Grundschaden, Profischaden für die Endstufen).
func flat_bonus_for(t) -> float:
	var pl: Player = players[t.owner_player] if t.owner_player < players.size() else null
	if pl == null or pl.shop != "tui" or str(t.def.get("shop", "")) != "tui":
		return 0.0
	var r: Dictionary = MaulData.pro().tui.research
	var v := float(pl.research.get("damage", 0)) * float(r.damage.step)
	if r.advanced.towers.has(t.tower_id):
		v += float(pl.research.get("advanced", 0)) * float(r.advanced.step)
	return v


func range_bonus_for(t) -> float:
	var pl: Player = players[t.owner_player] if t.owner_player < players.size() else null
	if pl == null or pl.shop != "tui" or str(t.def.get("shop", "")) != "tui":
		return 0.0
	return float(pl.research.get("range", 0)) * float(MaulData.pro().tui.research.range.step)


## Gärtnerei: Bewässerungsanlagen füllen alle eigenen Pflanzen in Reichweite auf.
func _water(delta: float) -> void:
	if phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return
	var g: Dictionary = MaulData.pro().garden
	var irr: Dictionary = g.irrigation
	var r := float(g.radius)
	for src in towers.values():
		if not irr.has(src.tower_id):
			continue
		var rate := float(irr[src.tower_id]) * delta
		for t in towers.values():
			if t.owner_player != src.owner_player:
				continue
			var pl: Dictionary = t.plant()
			if pl.is_empty() or t.pos.distance_to(src.pos) > r:
				continue
			t.water = minf(t.water + rate, float(pl.water))


## Kultstätten heilen die Zombies ihres Besitzers in der Nähe (HP pro Sekunde).
func cult_heal_at(at: Vector2, p: int) -> float:
	var u: Dictionary = MaulData.pro().undertaker
	var best := 0.0
	for t in towers.values():
		if t.owner_player == p and u.cults.has(t.tower_id) and t.pos.distance_to(at) <= float(u.cult_radius):
			best = maxf(best, float(u.cults[t.tower_id]))
	return best


func charger_of(p: int) -> MaulTower:
	var id := str(MaulData.pro().drones.charger)
	for t in towers.values():
		if t.owner_player == p and t.tower_id == id:
			return t
	return null


func spawn_unit(id: String, p: int, from: MaulTower) -> MaulUnit:
	var u := MaulUnit.new()
	u.net_id = _next_unit_id
	_next_unit_id += 1
	u.home = from.cell if from != null else NO_CELL
	board.add_child(u)
	u.setup(self, id, p, from.pos + Vector2(0.8, 0.0) if from != null else map.zone_center(players[p].zone))
	units.append(u)
	return u


func remove_unit(u: MaulUnit) -> void:
	units.erase(u)
	if selected_unit == u:
		select_unit(null)
	u.queue_free()


func unit_by_id(id: int) -> MaulUnit:
	for u in units:
		if u.net_id == id:
			return u
	return null


## Fitness: nach jedem Level Anabolika zahlen (3/25/75/200 Gold), dafür gibt es gleich viel Stärke.
## Fehlt das Geld, setzt der Tower ein Level aus. Nebenwirkungen sinken um eine Stufe.
func _fitness_upkeep() -> void:
	var up: Dictionary = MaulData.pro().fitness.upkeep
	for t in towers.values():
		if not up.has(t.tower_id):
			continue
		var cost := int(up[t.tower_id])
		var pl: Player = players[t.owner_player]
		t.side = maxi(t.side - 1, 0)
		if pl.gold >= cost:
			pl.gold -= cost
			t.flat += cost
			t.paused = false
		else:
			t.paused = true
			_tell(t.owner_player, tr("Kalter Entzug: %s setzt ein Level aus") % t.label())


## AOX-Bonus und XP am Levelende.
func _end_level_pro(n: int) -> void:
	var aok: Dictionary = MaulData.pro().aok
	for p in players:
		if p.shop == "aok" and level_lost > 0:
			p.gold += mini(n * floori(float(aok.gold_factor) * level_lost), n * int(aok.gold_cap))
	var x := MaulXp.cfg()
	if sandbox or debug_xp or debug_run() or players.size() < int(x.get("min_players", 1)):
		return
	var ke := float(MaulData.difficulty(difficulty).get("xp", 1.0))
	for i in players.size():
		var pl: Player = players[i]
		var before := pl.xp
		var res := MaulXp.gain(pl.xp, pl.xp_pot, n, players.size(), ke)
		pl.xp = int(res[0])
		pl.xp_pot = float(res[1])
		if i == local_player and pl.xp != before:
			MaulXp.save_xp(pl.xp)
			_announce_unlocks(before, pl.xp)


func _announce_unlocks(before: int, now: int) -> void:
	if not MaulXp.pro_unlocked(before) and MaulXp.pro_unlocked(now):
		show_message(tr("%s XP: Profi-Filialen freigeschaltet!") % MaulXp.text(now), 6.0)
		return
	for t in MaulData.xpert().get("towers", []):
		for req in t.get("requires", []):
			var need := MaulXp.needed(str(req))
			if need > before and need <= now:
				show_message(tr("%s XP: %s freigeschaltet!") % [MaulXp.text(now), str(t.name)], 6.0)


func _register(t: MaulTower) -> void:
	towers[t.cell] = t
	var cells := Board3D.footprint(t.cell)
	for c in cells:
		occupied[c] = t.cell
		pathfinder.set_solid(c, true)
	var z := map.zone_at(t.cell)
	if z >= 0:
		_zone_towers[z] += 1
	_update_detect()
	_refresh_paths()
	_repath_enemies(cells)


func _unregister(t: MaulTower) -> void:
	towers.erase(t.cell)
	for c in Board3D.footprint(t.cell):
		occupied.erase(c)
		pathfinder.set_solid(c, false)
	var z := map.zone_at(t.cell)
	if z >= 0:
		_zone_towers[z] -= 1
	if selected == t:
		select(null)
	_update_detect()
	_refresh_paths()


func _update_detect() -> void:
	_detect_towers = towers.values().filter(func(t): return not t.ability("detect").is_empty())


# --- Eingabe -----------------------------------------------------------------------

func select(t: MaulTower) -> void:
	if selected != null and is_instance_valid(selected):
		selected.set_selected(false)
	selected = t
	pending = {}
	if t != null:
		t.set_selected(true)
		build_id = ""
		if selected_unit != null and is_instance_valid(selected_unit):
			selected_unit.set_selected(false)
		selected_unit = null
	hud.refresh_selection()
	hud.refresh_shop()


func choose_build(id: String) -> void:
	build_id = id if build_id != id else ""
	if build_id != "":
		select(null)
		build_id = id
	_range_preview_r = -1.0
	hud.refresh_shop()


# --- Inventar: Items auf einen anderen Tower in der Welt ziehen (InvWorldDrop) ---

var inv_drop: InvWorldDrop


func _setup_inv_drop() -> void:
	inv_drop = InvWorldDrop.new()
	inv_drop.tower_at = func():
		return towers.get(occupied.get(board.mouse_cell(camera_rig.camera), NO_CELL))
	inv_drop.reason = func(t: MaulTower, data: Dictionary) -> String:
		return move_reason(local_player, data.get("from", {}), {"tower": t.cell, "slot": -1})
	inv_drop.hint = func(t: MaulTower, _data: Dictionary) -> String:
		return "+ " + tr("Einlegen · %d frei") % (t.slots() - t.items.size())
	inv_drop.drop = func(t: MaulTower, data: Dictionary) -> void:
		submit({"type": "item_move", "from": data.get("from", {}), "to": {"tower": t.cell, "slot": -1}})
	inv_drop.mark = func(t, ok: bool) -> void:
		board.hover_cell = t.cell if t != null else NO_CELL
		board.hover_ok = ok
		board.refresh_hover()
	inv_drop.tell = func(text: String) -> void: show_message(text)
	add_child(inv_drop)


func _update_hover() -> void:
	if inv_drop != null and inv_drop.active():
		return  # beim Ziehen eines Items markiert inv_drop den Tower unter der Maus
	var c := NO_CELL
	if build_id != "" and camera_rig.camera != null:
		c = board.mouse_anchor(camera_rig.camera)
	if c != board.hover_cell:
		board.hover_cell = c
		board.hover_ok = c != NO_CELL and build_problem(build_id, c, local_player) == ""
		board.refresh_hover()
	_range_preview.visible = c != NO_CELL
	if c != NO_CELL:
		var r := float(MaulData.tower(build_id).get("range", 0))
		if r != _range_preview_r:
			_range_preview_r = r
			var torus := TorusMesh.new()
			torus.inner_radius = maxf(r - 0.06, 0.01)
			torus.outer_radius = maxf(r, 0.07)
			torus.rings = 64
			torus.ring_segments = 4
			_range_preview.mesh = torus
			_range_preview.material_override = Board3D.make_material(Color(0.13, 0.77, 0.93, 0.7), true)
		_range_preview.position = Board3D.to_3d(Board3D.footprint_center(c), 0.05)


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.SETUP:
		return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_click(event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not camera_rig.right_dragged:
			build_id = ""
			select(null)
			select_unit(null)
	elif event is InputEventKey and event.pressed and not event.echo:
		var i := BUILD_KEYS.find(event.physical_keycode)
		if i >= 0 and not event.ctrl_pressed:
			var list := MaulData.buyable(shop_of())
			if i < list.size():
				choose_build(str(list[i].id))
			return
		match event.keycode:
			KEY_ESCAPE:
				# Erst Bauwahl und Auswahl aufheben, sonst Menü öffnen oder schließen
				if build_id != "" or selected != null or selected_unit != null or not pending.is_empty():
					build_id = ""
					select(null)
					select_unit(null)
				else:
					hud.toggle_menu()
			KEY_1:
				set_speed(1.0)
			KEY_2:
				set_speed(2.0)
			KEY_3:
				set_speed(4.0)
			KEY_L:
				set_path_lights(not path_lights.visible)
			KEY_N:
				if phase == Phase.COUNTDOWN:
					submit({"type": "start_now"})
			KEY_P, KEY_PAUSE:
				set_user_paused(true)
			KEY_DELETE:
				if selected != null:
					submit({"type": "sell", "cell": selected.cell})


func _on_click(keep := false) -> void:
	var c := board.mouse_cell(camera_rig.camera)
	if build_id != "":
		var a := board.mouse_anchor(camera_rig.camera)
		# außerhalb des eigenen Gebiets: Rahmen leuchten auf
		if not foreign_build and Board3D.footprint(a).any(func(f): return map.zone_at(f) != players[local_player].zone):
			board.flash_zones()
		if submit({"type": "build", "tower": build_id, "cell": a}) and not keep:
			build_id = ""
			hud.refresh_shop()
		return
	if pending.get("type", "") == "move_items":
		var from: Vector2i = pending.from
		pending = {}
		if occupied.has(c):
			submit({"type": "move_items", "from": from, "to": occupied[c]})
		hud.refresh_selection()
		return
	var hit = board._mouse_ground(camera_rig.camera)
	var u := unit_at(hit) if hit != null else null
	if u != null:
		select_unit(u)
		return
	# Gewählte eigene Einheit: Klick ins Gelände setzt ihren Posten
	if selected_unit != null and selected_unit.owner_player == local_player and hit != null and not occupied.has(c):
		submit({"type": "post", "unit": selected_unit.net_id, "x": hit.x, "y": hit.y})
		return
	if occupied.has(c):
		select(towers[occupied[c]])
	else:
		select(null)


## Einheit unter dem Mauszeiger (Weltkoordinaten), sonst null.
func unit_at(at: Vector2) -> MaulUnit:
	var best := 0.45
	var out: MaulUnit = null
	for u in units:
		var d: float = u.pos.distance_to(at)
		if d < best:
			best = d
			out = u
	return out


func select_unit(u: MaulUnit) -> void:
	if selected_unit != null and is_instance_valid(selected_unit):
		selected_unit.set_selected(false)
	selected_unit = u
	pending = {}
	if u != null:
		u.set_selected(true)
		if selected != null and is_instance_valid(selected):
			selected.set_selected(false)
		selected = null
		build_id = ""
	hud.refresh_selection()


## Spieltempo: im Koop bestimmt es der Host, Mitspieler schicken ihren Wunsch als Befehl.
## Einzelspiel ohne Mitspieler: Pause, Auto-Start und gemerktes Tempo gibt es nur dort.
func solo() -> bool:
	return sync == null and not mirror and not Net.is_active() and players.size() <= 1


var auto_wave := false  ## Schalter „Auto“: Countdown zwischen den Leveln überspringen
var user_paused := false
var _pause_input: PauseInput = null


func set_auto_wave(on: bool) -> void:
	auto_wave = on
	Session.auto_wave[Session.game_kind] = on
	Session.save_last()


## Pause (Taste P, nur Einzelspiel): Welt steht, Kamera und Oberfläche laufen weiter.
func set_user_paused(on: bool) -> void:
	if not solo() or phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		on = false
	user_paused = on
	get_tree().paused = on
	camera_rig.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
	hud.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
	hud.show_pause(on)
	if _pause_input == null:
		_pause_input = PauseInput.new()
		_pause_input.on_event = func(e):
			if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_P, KEY_PAUSE, KEY_ESCAPE]:
				set_user_paused(false)
				get_viewport().set_input_as_handled()
		add_child(_pause_input)


func set_speed(f: float) -> void:
	if mirror:
		submit({"type": "speed", "f": f})
		return
	if solo():
		Session.speed = f
	Engine.time_scale = f
	hud.refresh_live()


# --- Debug-Menü ------------------------------------------------------------------

## Debug: XP des eigenen Spielers erhöhen (Zehntel, -1 = alles frei wie in der Sandbox). Wird nicht gespeichert.
func debug_add_xp(tenths: int) -> void:
	var me: Player = players[local_player]
	var before := me.xp
	var top := int(MaulXp.cfg().get("sandbox", 8000))
	me.xp = top if tenths < 0 else mini(me.xp + tenths, int(MaulXp.cfg().get("max", 9999)))
	debug_xp = true
	_announce_unlocks(before, me.xp)
	_refresh_hud()


## Debug: eigene Filiale wechseln (alle Standard- und Profi-Filialen); gebaute Tower bleiben stehen.
func debug_set_shop(shop_id: String) -> void:
	if MaulData.shop(shop_id).is_empty() or phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return
	players[local_player].shop = shop_id
	build_id = ""
	select(null)
	hud.build_shop()
	_refresh_hud()


## Debug: Level n (ab 1). Läuft ein Level, verschwinden seine Gegner und n startet sofort, im Countdown kommt n als nächstes.
func debug_jump_to_level(n: int) -> void:
	if mirror or phase == Phase.SETUP or phase >= Phase.GAME_OVER:
		return
	n = clampi(n, 1, levels.size())
	for e in enemies.duplicate():
		_remove_enemy(e)
	spawn_queue.clear()
	effects.clear()
	levels_done = maxi(levels_done, n - 1)
	if phase == Phase.WAVE:
		_start_level(n)
	else:
		level = n - 1
	_refresh_hud()


func show_message(text: String, seconds := 2.5) -> void:
	message = text
	message_time = seconds
	if hud != null:
		hud.refresh_message()


func _refresh_hud() -> void:
	if hud != null:
		hud.refresh()


func _exit_tree() -> void:
	_record_abort()
	UiTheme.use_skin(UiTheme.ARCADE)
	Engine.time_scale = 1.0
	if Net.game == self:
		Net.game = null
	if sync != null and not mirror:
		Net.end_coop()
