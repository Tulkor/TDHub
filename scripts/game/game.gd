extends Node3D
## Hauptspiel.
## Ablauf pro Runde wie in GemTD:
##   1. Bauphase: der Spieler setzt gems_per_round zufällige Gems ins Labyrinth.
##      Steine kann er jederzeit (gegen Gold laut balance.json) entfernen.
##   2. Auswahl: einen davon behalten (oder kombinieren), der Rest wird zu Steinen.
##   3. Welle: Gegner laufen Spawn -> Checkpoints -> Ziel durch das Labyrinth.

enum Phase { BUILD, CHOOSE, WAVE, GAME_OVER, VICTORY }

## Gemeinsame Spielsysteme des Modus (scripts/systems/, data/modes.json → systems), angelegt in _init.
var systems := {}

const NO_CELL := Vector2i(-1, -1)

var map: MapData
var pathfinder: Pathfinder
var waves: Array = []
var ground_path := PackedVector2Array()   ## Bahn 0 (siehe lane_paths)
var air_path := PackedVector2Array()
## Wege aller Bahnen (Maul-Maps haben mehrere): [{ground, air, length}]
var lane_paths: Array = []
var show_all_paths := false  ## Mehrspieler: auch die Bahnen der Mitspieler als Punkte zeigen

var board: Board3D
var path_lights: PathLights  ## Lichtpfad entlang der Gegnerwege (Knopf „Lichtpfad“)
var path_depth := 0.0  ## Laufweg ("_"-Felder) so tief als Schlucht unter den Bauflächen (Board3D.path_depth)
var camera_rig: CameraRig
var effects: Effects
var hud: Hud

## Tower und Steine belegen 2×2 Felder und sind über ihr Feld oben links (Anker) gespeichert.
## Fallen liegen auf einer eigenen Ebene darunter (3×3 Felder): Gegner laufen darüber,
## und man kann Tower darauf bauen.
var towers: Dictionary = {}      ## Anker -> Tower (ohne Fallen)
var rocks: Dictionary = {}       ## Anker -> true
var occupied: Dictionary = {}    ## jedes von Tower/Stein belegte Feld -> Anker
var traps: Dictionary = {}       ## Anker -> Falle
var trap_cells: Dictionary = {}  ## jedes Feld unter einer Falle -> Anker
var moving: Tower = null         ## Falle, für die gerade ein neuer Platz gewählt wird, oder Tower mit „Tauschen“
var enemies: Array = []
## Spieler (solo nur einer). Was jedem allein gehört, steht in PlayerState; Leben, Punkte und Wellen sind gemeinsam.
var players: Array = [PlayerState.new()]
## Spieler, dessen Befehl gerade ausgeführt wird (sonst der lokale). round_towers, undo_gems und gold
## meinen immer diesen Spieler.
var acting := 0
var round_towers: Array:
	get:
		return pl().round_towers
	set(v):
		pl().round_towers = v
## Zurückgenommene Gems dieser Runde als [id, tier]: die nächsten Setzungen bekommen genau diese wieder,
## damit Zurücknehmen nur Fehlklicks korrigiert und nicht neu würfelt.
var undo_gems: Array:
	get:
		return pl().undo_gems
	set(v):
		pl().undo_gems = v
var selected: Tower = null
## Ausgewählte Steine (Anker), per Klick einer oder per Rahmen bis zu MAX_ROCK_SELECTION.
var selected_rocks: Array = []
var selected_rock: Vector2i:
	get:
		return selected_rocks[0] if not selected_rocks.is_empty() else NO_CELL
const MAX_ROCK_SELECTION := 5
const DRAG_THRESHOLD := 8.0
var _left_down := false
var _press_pos := Vector2.ZERO
var _dragging := false

## Gemeinsame Phase. Solo folgt die Stufe des Spielers ihr direkt (siehe stage()).
var phase := Phase.BUILD:
	set(v):
		phase = v
		if players.size() == 1 and v <= Phase.CHOOSE:
			players[0].stage = v
var wave_index := 0
var lives := 50
## Punkte-Modus (Session.score_mode): statt Leben zählen Punkte, das Spiel endet erst nach der letzten Welle.
var score_mode := false
## Aufstiegsstufe (+1, +2, …) auf der höchsten Schwierigkeit, siehe ascension.gd; wählt der Host vor Runde 1.
var ascension := 0
## Nach dem Run neu freigeschaltete Stufe (0 = keine), fürs Ende-Fenster.
var ascension_unlocked := 0
## Option „Überall bauen“ (Host, Startfenster): in Karten mit Gebieten auch in fremden Gebieten bauen
var foreign_build := false
var score := 0.0
## Wertung nach Wellentyp (wave_type): {kills, points, leaks, lost}, für den Endbildschirm
var score_stats := {}
## Endboss (letzte Welle, falls Boss): Schaden, seine Leben gesamt, besiegt, Punkte dafür
var final_boss := {"damage": 0.0, "hp": 0.0, "kills": 0, "points": 0.0}
var gold: int:
	get:
		return pl().gold
	set(v):
		pl().gold = v
var chance_level := 0
var _gold_frac: float:
	get:
		return pl().gold_frac
	set(v):
		pl().gold_frac = v
var spawn_queue: Array = []
## Laufende Welle fürs Gegner-Fenster: Leben und Schaden der schon entfernten Gegner, Kills, Durchgelassene
var wave_live := {"gone_hp": 0.0, "gone_dealt": 0.0, "killed": 0, "leaked": 0}
## Länge des Bodenwegs in Feldern, und wie lang er zu Beginn der Bauphase war.
var path_length := 0
var round_path_start := 0
var enemies_killed := 0
var leaks_per_wave := {}  ## Welle (Index) -> verlorene Leben (Punkte-Modus: durchgelassene Gegner), für die Run-History
var play_time := 0.0      ## gespielte Sekunden in Echtzeit, ohne Pause
var run_stats := RunStats.new()  ## Statistik fürs Profil (profile.gd)
var debug_used := false   ## Debug-Menü geöffnet: der Run zählt nicht für Summen und Rekorde im Profil, keine EP
var profile_time := 0      ## Sekunden dieses Runs, die schon im Profil stehen (Verlassen und später Laden)
var _saves_at_start := 0
var _speed_applied := false   ## Session.speed einmal nach den Einstellungen vor Runde 1 gesetzt
var auto_wave := false        ## Schalter „Auto“: nächste Welle ohne Pause (Session.auto_wave je Modus)
var _hover_tower: Tower = null
var _pause_input: PauseInput = null
var _hover_time := 0.0
var spawn_timer := 0.0
var debug_tower := ""
var rng := RandomNumberGenerator.new()
## Mehrspieler (nur wenn verbunden): Stand senden und Mitspielern zuschauen.
var net_sync: NetSync = null
## Spieler, für den dieser Rechner Befehle abschickt (solo immer 0)
var local_player := 0
## Koop (coop_sync.gd): gemeinsames Feld. mirror: dieser Rechner ist Mitspieler, rechnet nichts selbst,
## schickt Befehle an den Host und zeigt dessen Stand.
var coop: CoopSync = null
var mirror := false
## Einstellungen vor Runde 1 (setup_panel.gd) bestätigt; bis dahin ist das Feld gesperrt.
var setup_done := true
## Variante Roguelike (rogue.gd): Boni alle zehn Wellen, null = klassisch.
var rogue: Rogue = null
var net_panel: NetPanel = null
var _next_enemy_id := 1
var _cover: Array = []     ## is_covered: [Tower, größte Reichweite] dieses Bilds
var _cover_frame := -1
var _cover_sig := 0        ## ändert sich, wenn Tower dazukommen, wegfallen oder ihre Reichweite ändern
var _free_cache := {}      ## free_stretch: Bahn/Flieger → {path, sig, list}
var _probe: Enemy = null   ## Messpunkt für free_stretch


func _init() -> void:
	SystemHost.attach(self, system_mode())


## Modus-ID in data/modes.json, deren Systeme dieses Spiel bekommt (eeveTD, Randgruppen, YouTD überschreiben).
func system_mode() -> String:
	return "gemtd"


func _ready() -> void:
	_saves_at_start = SaveGame.writes
	rng.randomize()
	# Spielstand fortsetzen (save_game.gd) oder neues Spiel
	var saved: Dictionary = Session.load_state
	Session.load_state = {}
	var coop_info: Dictionary = Session.coop
	Session.coop = {}
	if not coop_info.is_empty():
		local_player = int(coop_info.get("player", 0))
		acting = local_player
		mirror = coop_info.get("role", "") == "client"
	map = MapData.from_dict(saved.map) if saved.has("map") else _load_map()
	if map == null:
		push_error("Keine Map gefunden")
		Session.goto(Session.MAIN_MENU)
		return
	waves = _make_waves()
	lives = map.lives
	score_mode = Session.score_mode
	if coop_info.is_empty():
		players[0].gold = map.start_gold
	else:
		setup_players(coop_info.get("names", []))
	pathfinder = Pathfinder.new(map)

	CameraRig.add_environment(self)
	board = Board3D.new()
	board.map = map
	board.rocks = rocks
	board.path_depth = path_depth
	add_child(board)
	effects = Effects.new()
	board.add_child(effects)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.frame_map(map.width * Board3D.CELL, map.height * Board3D.CELL)

	hud = Hud.new()
	add_child(hud)
	if systems.has("inventory"):
		inv_drop = systems.inventory.setup_drop()
	hud.option_chosen.connect(_on_option_chosen)
	hud.preview_range_requested.connect(func(r): if selected != null and is_instance_valid(selected): selected.show_preview_range(r))
	hud.round_gem_selected.connect(func(i): if i < round_towers.size(): _select(round_towers[i]))
	hud.next_gem_requested.connect(select_next_gem)
	hud.pause_toggled.connect(_on_pause_toggled)
	hud.extra_chance_requested.connect(func(): hud.extra_chance_panel.open(extra_chance_cfg(), gold, pl(local_player).extra_chance))
	hud.extra_chance_panel.chosen.connect(func(id): submit({"type": "extra_chance", "id": id}))
	hud.speed_selected.connect(func(f): submit({"type": "speed", "factor": f}))
	hud.menu_requested.connect(func(): Session.goto(Session.return_scene))
	hud.main_menu_requested.connect(func(): Session.goto(Session.MAIN_MENU))
	hud.restart_requested.connect(func():
		Session.save_id = ""
		# Gleiche Szene wie jetzt (eeveTD bleibt eeveTD); Koop neu starten geht nur gemeinsam über die Lobby
		if coop != null:
			Session.goto(Session.MAIN_MENU)
		else:
			Session.goto(scene_file_path if scene_file_path != "" else Session.game_scene()))
	hud.save_mode = save_mode
	hud.save_and_leave_requested.connect(func(quit): leave(true, quit))
	hud.leave_requested.connect(func(quit): leave(false, quit))
	hud.debug_tower_changed.connect(func(k): debug_tower = k)
	hud.debug_immortal_changed.connect(func(on): Session.debug_immortal = on)
	hud.debug_button.toggled.connect(func(on): debug_used = debug_used or on)
	hud.immortal_button.set_pressed_no_signal(Session.debug_immortal)
	debug_tower = Session.test_tower
	hud.setup_debug_towers(debug_tower)
	hud.setup_debug(gems_per_round(), waves.size())
	hud.debug_gems_changed.connect(_debug_set_gems)
	hud.debug_gold_requested.connect(func(n):
		gold += n
		_refresh_hud())
	hud.debug_lives_requested.connect(func(n):
		lives += n
		_refresh_hud())
	hud.debug_wave_requested.connect(debug_jump_to_wave)
	if has_path_lights():
		path_lights = PathLights.new(board, map.game if map.game != "" else Session.game_kind, map.path_lights)
		path_lights.visible = Display.path_lights
		board.add_child(path_lights)
		hud.add_lights_toggle(Display.path_lights, set_path_lights)
		board.set_path_dots(not Display.path_lights)
	if has_other_paths():
		hud.add_paths_toggle(set_show_all_paths)
		board.set_marker_lanes(_own_lanes())

	setup_done = not saved.is_empty() or Session.skip_setup
	if Session.skip_setup and saved.is_empty() and Session.rogue:
		enable_rogue()
	if not setup_done:
		hud.add_child(_make_setup_panel())
	if saved.is_empty():
		# Mitspieler bekommen die zufälligen Steine mit dem ersten Stand vom Host
		if not mirror:
			_apply_variance()
		_update_paths()
		board.refresh_rocks()
		_enter_build()
	else:
		SaveGame.apply(self, saved)
	get_tree().auto_accept_quit = false
	Net.game = self
	if not coop_info.is_empty():
		coop = CoopSync.new()
		coop.game = self
		coop.host = not mirror
		add_child(coop)
	if Net.is_active():
		net_sync = NetSync.new()
		net_sync.game = self
		add_child(net_sync)
		net_panel = NetPanel.new()
		net_panel.game = self
		net_panel.avoid = hud.bottom
		add_child(net_panel)
		hud.tower_list.limits.append(net_panel.panel)
	# Einzelspiel: Pause (Taste P) und, wo es Pausen zwischen den Wellen gibt, der Schalter „Auto“
	hud.pause_button.visible = solo()
	auto_wave = Session.auto_wave_on() and solo()
	if has_auto_wave() and solo():
		hud.add_auto_toggle(auto_wave, set_auto_wave)
	_pause_input = PauseInput.new()
	_pause_input.on_event = func(e): if hud.user_paused: paused_input(e)
	add_child(_pause_input)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	record_profile_abort()
	if _probe != null:
		_probe.free()
		_probe = null
	get_tree().auto_accept_quit = true
	if Net.game == self:
		Net.game = null
	if coop != null and not mirror:
		Net.end_coop()


## Fenster schließen: mitten in der Partie erst fragen, ob gespeichert werden soll.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if phase < Phase.GAME_OVER and hud != null:
			hud.open_leave_confirm(true)
		else:
			get_tree().quit()


# --- Speichern -----------------------------------------------------------------

## Was die Rückfrage beim Verlassen anbietet: "single" (selbst speichern), "host" (speichert alle Felder),
## "client" (nur der Host speichert) oder "none" (Partie vorbei).
func save_mode() -> String:
	if phase >= Phase.GAME_OVER:
		return "none"
	if mirror:
		return "client"
	if coop != null and Net.is_active():
		# Gemischte Sitzung: den Stand einer Koop-Gruppe, die ein Mitspieler rechnet, speichert der Host mit
		return "host" if Net.is_host() else "client"
	if coop != null:
		return "single"
	if Net.is_active():
		return "host" if Net.is_host() else "client"
	return "single"


## Nach jeder Welle still speichern (Einzelspiel, Lukas 2026-11-03): „Weiterspielen“ im Hub setzt hier fort,
## auch nach einem Absturz. Überschreibt nur den Spielstand dieser Partie. Nicht im Mehrspieler, nicht beim
## Testen aus dem Map-Editor und nicht in Tests/Screenshots (Session.skip_setup).
func autosave() -> bool:
	if not setup_done or not solo() or phase >= Phase.GAME_OVER or Session.return_scene != Session.MAIN_MENU or Session.skip_setup:
		return false
	return save_game()


## Partie vorbei: den Spielstand dieser Partie löschen, damit „Weiterspielen“ keine beendete Partie anbietet
## (wie Shopping Maul).
func drop_autosave() -> void:
	if solo() and Session.save_id != "" and Session.return_scene == Session.MAIN_MENU:
		SaveGame.remove(Session.save_id)
		Session.save_id = ""


## Einzelspiel speichern; dieselbe Partie überschreibt ihren Spielstand.
func save_game() -> bool:
	var st := SaveGame.capture(self)
	if st.is_empty():
		return false
	if Session.save_id == "":
		Session.save_id = SaveGame.new_id()
	return SaveGame.write({"id": Session.save_id, "kind": "single", "mode": Session.game_kind, "meta": SaveGame.meta_for(self), "state": st})


## Koop (Host): das gemeinsame Feld mit allen Spielern speichern, Spielernummern bleiben an den Spieler-IDs.
func save_coop() -> bool:
	var st := SaveGame.capture(self)
	if st.is_empty():
		return false
	var names: Array = players.map(func(p): return p.name)
	return SaveGame.write({"id": str(Net.session.get("id", SaveGame.new_id())), "kind": "coop", "mode": Session.game_kind,
		"meta": SaveGame.meta_for(self, {"players": names}), "map": map.to_dict(), "host_uid": Net.uid,
		"coop": Net.session.get("coop", []), "state": st})


## Partie verlassen (quit: Fenster schließen), vorher auf Wunsch speichern.
## Im Mehrspieler geht der Stand an die Sitzung des Hosts, damit man später wieder einsteigen kann.
func leave(save: bool, quit := false) -> void:
	if save:
		hud.set_leave_busy(tr("Speichere …"))
		var ok := false
		if save_mode() == "host" and coop != null and Net.is_coop():
			ok = save_coop()
		elif save_mode() == "host":
			ok = await Net.save_session(self)
		elif save_mode() == "single":
			ok = save_game()
		if not ok:
			hud.set_leave_busy(tr("Speichern fehlgeschlagen"), true)
			return
	elif Net.is_active() and not mirror and not Net.is_coop():
		Net.report_state(SaveGame.capture(self))
	if quit:
		get_tree().quit()
	else:
		Session.goto(Session.return_scene)


## Wellen des Spiels (eeve_game.gd würfelt sie selbst aus).
func _make_waves() -> Array:
	return Database.wave_sets.get(map.wave_set, {}).get("waves", [])


## Fenster für die Einstellungen vor Runde 1.
func _make_setup_panel() -> Control:
	var setup := SetupPanel.new()
	setup.game = self
	return setup


func _load_map() -> MapData:
	if Session.map_override != null:
		return Session.map_override.duplicate_map()
	var path := Session.map_path
	if path == "":
		var maps := Database.list_maps()
		if maps.is_empty():
			return null
		path = str(Database.first_map().get("path", maps[0].path))
	return MapData.load_file(path)


## Zufällige Steine laut map.variance.
func _apply_variance() -> void:
	var count := int(map.variance.get("random_rocks", 0))
	if count <= 0:
		return
	var vr := RandomNumberGenerator.new()
	var seed_value := int(map.variance.get("seed", -1))
	if seed_value >= 0:
		vr.seed = seed_value
	else:
		vr.randomize()
	var placed := 0
	for attempt in count * 30:
		if placed >= count:
			break
		var c := Vector2i(vr.randi_range(0, map.width - 2), vr.randi_range(0, map.height - 2))
		if can_place(c, true):
			rocks[c] = true
			_occupy(c, true, true)
			placed += 1


func _update_paths() -> void:
	lane_paths = []
	path_length = 0
	var dots := PackedVector2Array()
	var others := PackedVector2Array()
	for i in map.lane_count():
		var ground := PackedVector2Array()
		var cells := pathfinder.compute_path(i)
		for c in cells:
			ground.append(Board3D.cell_center(c))
		var air := PackedVector2Array()
		for c in map.waypoints(i):
			air.append(Board3D.cell_center(c))
		lane_paths.append({"ground": ground, "air": air, "length": cells.size()})
		path_length += cells.size()
		(dots if _own_lane(i) else others).append_array(ground)
	ground_path = lane_paths[0].ground
	air_path = lane_paths[0].air
	board.path_points = dots + others if show_all_paths else dots
	board.refresh_path()
	if path_lights != null:
		path_lights.set_paths(range(lane_paths.size()).filter(func(i): return show_all_paths or _own_lane(i)).map(func(i): return lane_paths[i].ground))


## Im Mehrspieler gehören Bahnen mit Spielernummer einem Spieler; anfangs zeigt das Feld nur die
## eigenen, die übrigen über den Knopf „Alle Wege zeigen“. Allein (oder ohne Nummer) alle.
func _own_lane(i: int) -> bool:
	return players.size() <= 1 or map.lane_player(i) == local_player


func _own_lanes() -> Array:
	return range(map.lane_count()).filter(_own_lane)


func has_other_paths() -> bool:
	return range(map.lane_count()).any(func(i): return not _own_lane(i))


## Lichtpfad (Knopf „Lichtpfad“) in diesem Modus? YouTD hat einen festen Weg und braucht ihn nicht.
func has_path_lights() -> bool:
	return true


## Lichtpfad ein/aus (Knopf im HUD, Taste L); bleibt gespeichert. Solange er läuft, ohne Wegpunkte am Boden.
func set_path_lights(on: bool) -> void:
	Display.set_path_lights(on)
	path_lights.visible = on
	board.set_path_dots(not on)


func set_show_all_paths(on: bool) -> void:
	show_all_paths = on
	if hud.paths_button != null:
		hud.paths_button.set_pressed_no_signal(on)
	board.set_marker_lanes([] if on else _own_lanes())
	_update_paths()


## Bahnen, die gerade spawnen: ohne Spieler oder deren Spieler mitspielt.
func active_lanes() -> Array:
	return range(map.lane_count()).filter(func(i): return map.lane_player(i) < players.size())


# --- Inventar: Items auf Tower in der Welt ziehen (System inventory, Modi mit Items) ---

var inv_drop: InvWorldDrop


# --- Eingabe -----------------------------------------------------------------

func _process(delta: float) -> void:
	_ux_tick()
	if phase < Phase.GAME_OVER:
		play_time += delta / maxf(Engine.time_scale, 0.001)
	_update_hover()
	# Zonenrahmen (Maul-Maps, Randgruppen) ab der ersten Welle nur noch schwach, auch im Koop beim Gast
	if phase == Phase.WAVE or wave_index > 0:
		board.set_zone_glow(Board3D.ZONE_FAINT)
	# hell nur, solange die Gebietsgrenze gilt (Option „Überall bauen“ hebt sie auf)
	board.set_zone_rule(not foreign_build)
	if phase == Phase.WAVE and not mirror:
		_process_wave(delta)


## Einmal pro Bild (auch aus youtd_game.gd): gemerktes Tempo nach den Einstellungen vor Runde 1 setzen,
## Auto-Start der nächsten Welle.
func _ux_tick() -> void:
	if setup_done and not _speed_applied:
		_speed_applied = true
		if solo() and phase < Phase.GAME_OVER:
			Engine.time_scale = Session.speed
	if auto_wave and setup_done and solo() and phase < Phase.GAME_OVER and auto_wave_due():
		next_wave_now()


## Einzelspiel ohne Netz und ohne Koop: nur dort gibt es Pause, Auto-Start und gemerktes Tempo.
func solo() -> bool:
	return not Net.is_active() and coop == null and not mirror and players.size() <= 1


# --- Auto-Start der nächsten Welle (Schalter „Auto“ neben dem Tempo) -------------------------

## Hat der Modus Pausen zwischen den Wellen, die man mit N abkürzen kann? (System waves, modes.json)
func has_auto_wave() -> bool:
	return systems.waves.has_auto()


## Soll die nächste Welle jetzt automatisch starten (Auto an)?
func auto_wave_due() -> bool:
	return systems.waves.auto_due()


## Nächste Welle sofort (wie Taste N).
func next_wave_now() -> void:
	systems.waves.next_now()


func set_auto_wave(on: bool) -> void:
	auto_wave = on
	Session.auto_wave[Session.game_kind] = on
	Session.save_last()


# --- Hover: Reichweite und Kurzinfo ohne Klick ----------------------------------------------

const HOVER_DELAY := 0.3


## Tower unter der Maus nach kurzer Zeit: Reichweitenring und kleine Karte an der Maus.
func _update_tower_hover(delta: float) -> void:
	var t: Tower = null
	if inv_drop == null or not inv_drop.active():
		var c := board.mouse_cell(camera_rig.camera)
		var a: Vector2i = occupied.get(c, NO_CELL)
		t = towers.get(a, null)
		if t == null:
			t = traps.get(trap_cells.get(c, NO_CELL), null)
	if t != null and (t == selected or not is_instance_valid(t)):
		t = null
	var vp := get_viewport()
	if t != null and vp != null and vp.gui_get_hovered_control() != null:
		t = null  # Maus über einem Fenster
	if t != _hover_tower:
		if _hover_tower != null and is_instance_valid(_hover_tower):
			_hover_tower.set_hovered(false)
		_hover_tower = t
		_hover_time = 0.0
		hud.show_hover_card("", Vector2.ZERO)
	if t == null:
		return
	_hover_time += delta / maxf(Engine.time_scale, 0.001)
	if _hover_time >= HOVER_DELAY and not t.hovered:
		t.set_hovered(true)
		hud.show_hover_card(hover_text(t), vp.get_mouse_position())


## Kurzinfo für die Karte an der Maus: Name, Untertitel (Art · Ziele), Reichweite und Schaden, Kills.
func hover_text(t: Tower) -> String:
	var st: Dictionary = t.view() if t.has_method("view") else TowerStats.view(t)
	var lines := [t.label(), str(st.get("subtitle", ""))]
	var parts := []
	for tile in st.get("tiles", []):
		if str(tile.get("key", "")) in ["range", "damage"]:
			parts.append("%s %s" % [tile.caption, tile.value])
	if not parts.is_empty():
		lines.append(" · ".join(parts))
	lines.append(tr("Kills %d") % t.kills)
	return "\n".join(lines.filter(func(l): return l != ""))


func _update_hover() -> void:
	_update_tower_hover(get_process_delta_time())
	if inv_drop != null and inv_drop.active():
		return  # beim Ziehen eines Items markiert inv_drop den Tower unter der Maus
	var c := NO_CELL
	var size := Board3D.TOWER_CELLS
	if moving != null and not moving.is_trap():
		c = occupied.get(board.mouse_cell(camera_rig.camera), NO_CELL)
	elif moving != null:
		size = Board3D.TRAP_CELLS
		c = board.mouse_anchor(camera_rig.camera, size)
	elif stage() == Phase.BUILD and not occupied.has(board.mouse_cell(camera_rig.camera)):
		c = board.mouse_anchor(camera_rig.camera)
	if c != board.hover_cell or size != board.hover_size:
		board.hover_cell = c
		board.hover_size = size
		board.hover_ok = (can_swap(moving, c) if not moving.is_trap() else can_move_trap(moving, c)) if moving != null else can_place(c)
		board.refresh_hover()


func _unhandled_input(event: InputEvent) -> void:
	if not setup_done:
		return
	# Linke Maustaste: Klick beim Loslassen, Ziehen spannt einen Auswahlrahmen für Steine auf (wie in RTS-Spielen)
	if event is InputEventMouseMotion and _left_down and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if not _dragging and event.position.distance_to(_press_pos) >= DRAG_THRESHOLD and moving == null:
			_dragging = true
		if _dragging:
			hud.show_drag_box(Rect2(_press_pos, Vector2.ZERO).expand(event.position))
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_left_down = true
			_dragging = false
			_press_pos = event.position
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and _left_down:
			_left_down = false
			if _dragging:
				_dragging = false
				hud.show_drag_box(Rect2())
				_box_select(Rect2(_press_pos, Vector2.ZERO).expand(event.position), event.ctrl_pressed or event.meta_pressed)
			else:
				_on_click(board.mouse_cell(camera_rig.camera), board.mouse_anchor(camera_rig.camera), event.ctrl_pressed or event.meta_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed and not camera_rig.right_dragged:
			# Rechtsklick hebt die Auswahl auf, rechts ziehen verschiebt nur die Kamera
			_select(null)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed) and not round_towers.is_empty():
			submit({"type": "take_back", "tower": tower_ref(round_towers[-1])})
			return
		match event.keycode:
			KEY_ESCAPE:
				# Erst abbrechen, was gerade läuft (Auswahl, Falle versetzen), sonst Menü öffnen
				if selected != null or not selected_rocks.is_empty() or moving != null:
					_select(null)
				elif phase < Phase.GAME_OVER:
					hud.open_leave_confirm()
			KEY_1:
				submit({"type": "speed", "factor": 1.0})
			KEY_2:
				submit({"type": "speed", "factor": 2.0})
			KEY_3:
				submit({"type": "speed", "factor": 4.0})


## c: Feld unter der Maus, anchor: wo ein neuer Tower hinkäme. add (Strg): Stein zur Auswahl hinzufügen/abwählen.
func _on_click(c: Vector2i, anchor: Vector2i, add := false) -> void:
	if moving != null and not moving.is_trap():
		var other: Vector2i = occupied.get(c, NO_CELL)
		if can_swap(moving, other):
			submit({"type": "swap", "tower": tower_ref(moving), "with": other})
		else:
			Sfx.play("error")
		return
	if moving != null:
		var target := board.mouse_anchor(camera_rig.camera, Board3D.TRAP_CELLS)
		if can_move_trap(moving, target):
			submit({"type": "move_trap", "tower": tower_ref(moving), "to": target})
		else:
			Sfx.play("error")
		return
	var a: Vector2i = occupied.get(c, NO_CELL)
	if add and rocks.has(a):
		toggle_rock(a)
		return
	var trap: Tower = traps.get(trap_cells.get(c, NO_CELL), null)
	# Liegt eine Falle unter einem Tower/Stein, wählt ein zweiter Klick die Falle
	var on_top_selected: bool = (towers.has(a) and selected == towers[a]) or (rocks.has(a) and selected_rock == a)
	if trap != null and on_top_selected:
		_select(trap)
	elif towers.has(a):
		_select(towers[a])
	elif rocks.has(a):
		_select(null, a)
	elif stage() == Phase.BUILD and can_place(anchor):
		submit({"type": "place", "cell": anchor})
	elif trap != null:
		_select(trap)
	else:
		# Freies Feld in der Bauphase, aber hier geht kein Gem hin (Weg versperrt, belegt, Rand)
		if stage() == Phase.BUILD and gems_left() > 0 and map.in_bounds(anchor):
			Sfx.play("error")
		_select(null)


## Alle Tower und Fallen.
func all_towers() -> Array:
	return towers.values() + traps.values()


## Tower/Falle eintragen: Tower belegen ihre Felder und blockieren Gegner, Fallen liegen darunter.
func _register(t: Tower) -> void:
	if t.is_trap():
		traps[t.cell] = t
		for c in Board3D.footprint(t.cell, Board3D.TRAP_CELLS):
			trap_cells[c] = t.cell
	else:
		towers[t.cell] = t
		_occupy(t.cell, true, true)


func _unregister(t: Tower) -> void:
	if traps.get(t.cell) == t:
		traps.erase(t.cell)
		for c in Board3D.footprint(t.cell, Board3D.TRAP_CELLS):
			if trap_cells.get(c) == t.cell:
				trap_cells.erase(c)
	if towers.get(t.cell) == t:
		towers.erase(t.cell)
		_occupy(t.cell, false, false)


## Würde t als Falle auf seinem Platz eine andere Falle überdecken (außer den verbrauchten)?
func _trap_overlaps(t: Tower, at: Vector2i, ignore: Array = []) -> bool:
	for c in Board3D.footprint(at, Board3D.TRAP_CELLS):
		var other: Tower = traps.get(trap_cells.get(c, NO_CELL), null)
		if other != null and other != t and not ignore.has(other):
			return true
	return false


func trap_moves() -> int:
	return int(Database.balance.get("trap_moves", 2))


## Falle verschieben: auf jedes begehbare Feld (auch Checkpoints und unter Tower), nicht auf andere Fallen.
func can_move_trap(t: Tower, a: Vector2i) -> bool:
	if t == null or not is_instance_valid(t) or not t.is_trap() or t.moves_left <= 0 or a == t.cell:
		return false
	for c in Board3D.footprint(a, Board3D.TRAP_CELLS):
		if not map.is_walkable(c) or not may_build_for(c):
			return false
	return not _trap_overlaps(t, a)


func move_trap(t: Tower, a: Vector2i) -> bool:
	if not can_move_trap(t, a):
		return false
	_unregister(t)
	t.place_at(a)
	_register(t)
	t.moves_left -= 1
	moving = null
	board.hover_cell = NO_CELL
	_update_auras()
	_refresh_hud()
	return true


## „Tauschen“ (Schwarzer Opal, Feld swap_cost in der Tower-Datei): Platz mit einem eigenen fertigen Gem oder einem
## Stein tauschen. Beide belegen 2×2 Felder und blockieren, der Weg bleibt also gleich.
func swap_cost(t: Tower) -> int:
	return int(t.def.get("swap_cost", 0)) if t != null and is_instance_valid(t) else 0


func can_swap(t: Tower, other: Vector2i) -> bool:
	if swap_cost(t) <= 0 or t.is_new or t.owner_player != acting or other == t.cell or gold < swap_cost(t):
		return false
	if rocks.has(other):
		return may_build_for(other)
	var o: Tower = towers.get(other, null)
	return o != null and not o.is_new and o.owner_player == acting


func swap_tower(t: Tower, other: Vector2i) -> bool:
	if t == null or not is_instance_valid(t) or t.is_trap() or not can_swap(t, other):
		return false
	gold -= swap_cost(t)
	var from := t.cell
	var o: Tower = towers.get(other, null)
	_unregister(t)
	if o != null:
		_unregister(o)
		o.place_at(from)
		_register(o)
	else:
		rocks.erase(other)
		_occupy(other, false, true)
		rocks[from] = true
		_occupy(from, true, true)
	t.place_at(other)
	_register(t)
	moving = null
	board.hover_cell = NO_CELL
	board.refresh_rocks()
	_update_paths()
	_update_auras()
	_refresh_hud()
	return true


## Passt ein Tower mit Anker a hin, ohne den Weg zu versperren? Fallen darunter stören nicht.
## Darf Spieler p auf Feld c bauen? Eigenes oder freies Gebiet, mit „Überall bauen“ jedes Gebiet.
func may_build_for(c: Vector2i, p := acting) -> bool:
	return map.can_build_for(c, p) or (foreign_build and map.zone_index(c) >= 0)


## Hat die Karte Gebiete für mehrere Spieler? Dann zeigen die Startfenster die Option „Überall bauen“.
func has_foreign_zones() -> bool:
	var owners := {}
	for z in map.zones:
		if int(z.player) >= 0:
			owners[int(z.player)] = true
	return owners.size() >= 2


## Aus dem Befehl setup des Hosts: „Überall bauen“ übernehmen.
func take_foreign_build(cmd: Dictionary) -> void:
	if acting == 0 and cmd.has("foreign"):
		foreign_build = bool(cmd.foreign)
		Session.foreign_build = foreign_build


## any_zone: Zonen der Maul-Maps nicht beachten (zufällige Steine beim Start)
func can_place(a: Vector2i, any_zone := false) -> bool:
	var cells := Board3D.footprint(a)
	for c in cells:
		if not map.is_buildable(c) or occupied.has(c) or not (any_zone or may_build_for(c)):
			return false
	return not pathfinder.would_block_cells(cells)


## Belegt oder räumt die Felder eines Towers/Steins. solid: blockiert er Gegner?
func _occupy(a: Vector2i, on: bool, solid: bool) -> void:
	var cells := Board3D.footprint(a)
	for c in cells:
		if on:
			occupied[c] = a
		else:
			occupied.erase(c)
	pathfinder.set_solid_cells(cells, on and solid)


func _select(t: Tower, rock := NO_CELL) -> void:
	_select_rocks([rock] if rock != NO_CELL else [], t)


## Mehrere Steine auswählen (oder einen Tower t, dann ist rocks leer).
func _select_rocks(list: Array, t: Tower = null) -> void:
	moving = null
	if selected != null and is_instance_valid(selected):
		selected.set_selected(false)
	selected = t
	selected_rocks = list.slice(0, MAX_ROCK_SELECTION)
	board.selected_rocks = selected_rocks
	board.refresh_selection()
	if t != null:
		t.set_selected(true)
	_refresh_hud()


# --- Bauphase ----------------------------------------------------------------

func gems_per_round() -> int:
	if Session.debug_gems_per_round > 0:
		return Session.debug_gems_per_round
	return int(Database.balance.get("gems_per_round", 5))


func _debug_set_gems(n: int) -> void:
	Session.debug_gems_per_round = n
	# Schon genug gesetzt: gleich in die Wahlphase
	if stage() == Phase.BUILD and not round_towers.is_empty() and round_towers.size() >= n:
		_set_stage(Phase.CHOOSE)
		_select(round_towers[-1])
	_refresh_hud()


## Debug: Welle number (ab 1). Läuft eine Welle, wird sie abgebrochen und die gewählte startet sofort,
## sonst kommt die gewählte nach der laufenden Runde.
func debug_jump_to_wave(number: int) -> void:
	if phase >= Phase.GAME_OVER or waves.is_empty():
		return
	wave_index = clampi(number - 1, 0, waves.size() - 1)
	if phase == Phase.WAVE:
		for e in enemies.duplicate():
			_remove_enemy(e)
		_start_wave()
	_refresh_hud()


## Extra Chance (data/balance.json → extra_chance): nur GemTD, leer = aus.
func extra_chance_cfg() -> Dictionary:
	return Database.balance.get("extra_chance", {}) if Session.game_kind == "gemtd" else {}


## In der eigenen Bauphase einmal pro Runde eine Gem-Sorte kaufen (Befehl "extra_chance").
func can_buy_extra_chance() -> bool:
	var ec := extra_chance_cfg()
	return not ec.is_empty() and stage() == Phase.BUILD and gems_left() > 0 and pl().extra_chance == "" \
		and gold >= int(ec.get("cost", 175)) and phase < Phase.GAME_OVER


func buy_extra_chance(id: String) -> bool:
	if not can_buy_extra_chance() or not Database.gem_ids().has(id):
		return false
	gold -= int(extra_chance_cfg().get("cost", 175))
	pl().extra_chance = id
	_refresh_hud()
	return true


func rock_remove_cost() -> int:
	return int(Database.balance.get("rock_remove_cost", 0))


func _enter_build() -> void:
	phase = Phase.BUILD
	chance_level = chance_level_for(current_wave())
	for p in players:
		p.stage = Phase.BUILD
		p.round_towers.clear()
		p.undo_gems.clear()
		p.extra_chance = ""
	round_path_start = path_length
	if rogue != null:
		rogue.on_build()
	_refresh_hud()


## Gegnerwerte: im Roguelike mit den eigenen Werten aus data/roguelike_enemies.json.
func enemy_def(id: String) -> Dictionary:
	return Rogue.enemy_def(id) if rogue != null else Database.enemies.get(id, {})


## Variante Roguelike einschalten (Einstellungen vor Runde 1, Spielstand oder Stand vom Host).
func enable_rogue() -> Rogue:
	if rogue == null:
		rogue = Rogue.new(self)
		add_child(rogue)
	return rogue


func place_gem(c: Vector2i) -> Tower:
	var id := ""
	var tier := 0
	if not undo_gems.is_empty():
		var back: Array = undo_gems.pop_back()
		id = back[0]
		tier = back[1]
	elif debug_tower != "":
		var parts := debug_tower.split(":")
		id = parts[0]
		tier = int(parts[1]) if parts.size() > 1 else 0
	else:
		var roll := Database.roll_gem(chance_level + (rogue.luck(acting) if rogue != null else 0), rng)
		id = roll[0]
		tier = roll[1]
		var ec := extra_chance_cfg()
		if pl().extra_chance != "" and rng.randf() < float(ec.get("chance", 0.0)):
			id = pl().extra_chance
			tier = mini(int(ec.get("tier", 4)), Database.tier_count(id) - 1)
	if not Database.towers.has(id):
		push_error("Unbekannter Tower: " + id)
		return null
	var t := Tower.new()
	t.is_new = true
	t.owner_player = acting
	board.add_child(t)
	t.setup(self, c, id, tier)
	_register(t)
	round_towers.append(t)
	_update_paths()
	_update_auras()
	board.hover_ok = false
	board.refresh_hover()
	if round_towers.size() >= gems_per_round():
		_set_stage(Phase.CHOOSE)
		if _mine():
			_select(t)
	_refresh_hud()
	return t


## Strg+Klick wie bei Dateien: Stein zur Auswahl hinzufügen oder wieder abwählen (höchstens 5).
func toggle_rock(a: Vector2i) -> void:
	var list: Array = selected_rocks.duplicate() if selected == null else []
	if list.has(a):
		list.erase(a)
	elif list.size() < MAX_ROCK_SELECTION:
		list.append(a)
	_select_rocks(list)


## Steine im Auswahlrahmen (Bildschirmkoordinaten), die nächsten zum Startpunkt zuerst, höchstens 5.
## add (Strg): zur bisherigen Auswahl hinzufügen.
func _box_select(r: Rect2, add := false) -> void:
	var cam: Camera3D = camera_rig.camera
	var found := []
	for c in rocks:
		var p3 := Board3D.to_3d(Board3D.footprint_center(c))
		if cam.is_position_behind(p3):
			continue
		var p := cam.unproject_position(p3)
		if r.has_point(p):
			found.append([p.distance_squared_to(_press_pos), c])
	found.sort_custom(func(a, b): return a[0] < b[0])
	var list: Array = selected_rocks.duplicate() if add and selected == null else []
	for f in found:
		if not list.has(f[1]):
			list.append(f[1])
	_select_rocks(list)


## Wie viele Gems in dieser Bauphase noch gesetzt werden dürfen.
func gems_left() -> int:
	return maxi(gems_per_round() - round_towers.size(), 0) if stage() == Phase.BUILD else 0


## Steine direkt durch neue Gems ersetzen (so viele, wie in der Runde noch übrig sind). Gibt die Anzahl zurück.
func replace_rocks(list: Array) -> int:
	var done := 0
	for c in list.duplicate():
		if gems_left() <= 0 or not can_remove_rock(c):
			break
		remove_rock(c)
		if can_place(c):
			var t := place_gem(c)
			if t != null:
				t.set_meta("on_rock", true)
			done += 1
		else:
			# sollte nicht vorkommen (gleiche Felder wie der Stein), sonst Stein zurücklegen
			rocks[c] = true
			_occupy(c, true, true)
			_update_paths()
			board.refresh_rocks()
	if stage() == Phase.BUILD and _mine():
		_select(null)
	return done


## Stein entfernen (in jeder Phase, kostet rock_remove_cost Gold).
func can_remove_rock(c: Vector2i) -> bool:
	return phase < Phase.GAME_OVER and rocks.has(c) and gold >= rock_remove_cost() and may_build_for(c)


func remove_rock(c: Vector2i) -> bool:
	if not can_remove_rock(c):
		return false
	gold -= rock_remove_cost()
	rocks.erase(c)
	_occupy(c, false, false)
	_update_paths()
	board.refresh_rocks()
	if _mine() or selected_rocks.has(c):
		_select(null)
	return true


## Gesetzten Gem dieser Runde zurücknehmen (Fehlklick), in Bau- und Auswahlphase. Aus der Auswahlphase geht es
## zurück in die Bauphase. Der Gem wird nicht neu gewürfelt (siehe undo_gems), ein ersetzter Stein kommt zurück.
func can_take_back(t: Tower) -> bool:
	return stage() <= Phase.CHOOSE and t != null and is_instance_valid(t) and t.is_new and round_towers.has(t)


func take_back(t: Tower) -> bool:
	if not can_take_back(t):
		return false
	undo_gems.append([t.tower_id, t.tier])
	round_towers.erase(t)
	_unregister(t)
	if t.get_meta("on_rock", false) and not pathfinder.would_block_cells(Board3D.footprint(t.cell)):
		rocks[t.cell] = true
		_occupy(t.cell, true, true)
		gold += rock_remove_cost()
	t.queue_free()
	_set_stage(Phase.BUILD)
	_update_paths()
	_update_auras()
	board.refresh_rocks()
	if _mine() or t == selected:
		_select(null)
	return true


## Was man mit dem ausgewählten Tower machen kann.
## Rückgabe: [{label, action, id, tier, consume: [Tower], cost}]
##   action "keep":    Runde abschließen, ausgewählter Gem wird zu id/tier, Rest der Runde wird zu Steinen
##   action "combine": Kombination aus fertigen Towern auf dem Feld, ohne die Runde zu beenden
##   action "upgrade": Spezial-Tower gegen Gold aufwerten
##   action "take_back": gesetzten Gem dieser Runde zurücknehmen
func tower_options(t: Tower) -> Array:
	if t == null or not is_instance_valid(t) or phase >= Phase.GAME_OVER or t.owner_player != acting:
		return []
	if t.is_new:
		var choice := choice_options(t)
		if can_take_back(t):
			choice.append({"label": tr("Zurücknehmen"), "action": "take_back", "id": t.tower_id, "tier": t.tier, "consume": [], "cost": 0})
		return choice
	var opts := []
	var field := own_towers().filter(func(o): return o != t and not o.is_new)
	# Fertige Tower auf dem Feld kombinieren geht nur während der Welle, nicht beim Setzen und Auswählen
	# der neuen Gems (deren Rezepte siehe choice_options)
	if phase == Phase.WAVE:
		for sid in Database.special_ids():
			var def: Dictionary = Database.towers[sid]
			if def.get("recipe_same_round", false):
				continue
			var consume = _match_recipe(def.get("recipe", []), t, field)
			if consume != null:
				opts.append({"label": tr("Kombinieren → ") + Database.tower_label(sid, 0), "action": "combine",
						"id": sid, "tier": 0, "consume": consume, "cost": 0})
	opts.append_array(upgrade_options(t))
	if t.is_trap() and t.moves_left > 0:
		opts.append({"label": tr("Verschieben (noch %d×)") % t.moves_left, "action": "move", "id": t.tower_id,
				"tier": t.tier, "consume": [], "cost": 0})
	if swap_cost(t) > 0 and not t.is_trap():
		opts.append({"label": tr("Tauschen"), "action": "swap", "id": t.tower_id, "tier": t.tier, "consume": [],
				"cost": swap_cost(t)})
	return opts.filter(func(o): return not _makes_blocked_trap(t, o))


## Option, die aus t eine Falle macht, obwohl dort schon eine andere Falle liegt?
func _makes_blocked_trap(t: Tower, o: Dictionary) -> bool:
	if o.action == "move" or str(Database.towers.get(o.id, {}).get("kind", "tower")) != "trap":
		return false
	return _trap_overlaps(t, t.cell, o.consume)


## In der Auswahlphase: behalten, 2/4 gleiche, Rezepte.
## Schon in der Bauphase (One-Shot): nur Rezepte, wer das nimmt, beendet die Runde sofort.
## Rezepte gelten in beiden Fällen nur mit den in dieser Runde gesetzten Gems, fertige Tower auf dem
## Feld zählen nicht (die lassen sich während der Welle kombinieren, siehe tower_options).
func choice_options(t: Tower) -> Array:
	var one_shot := stage() == Phase.BUILD
	if (stage() != Phase.CHOOSE and not one_shot) or t == null or not round_towers.has(t):
		return []
	var opts := [] if one_shot else [_keep_option(tr("Behalten: ") + t.label(), t.tower_id, t.tier)]
	if t.def.get("category", "gem") == "gem" and not one_shot:
		# Abstufen wie in WC3: den Gem eine Qualität niedriger behalten, z. B. für ein Rezept
		if t.tier > 0:
			opts.append(_keep_option(tr("Abstufen → ") + Database.tower_label(t.tower_id, t.tier - 1), t.tower_id, t.tier - 1))
		var same := round_towers.filter(func(o): return o.tower_id == t.tower_id and o.tier == t.tier).size()
		var max_tier := Database.tier_count(t.tower_id) - 1
		for n in [2, 4]:
			if same < n:
				continue
			var steps := 1 if n == 2 else 2
			var o: Dictionary
			if t.tier + steps <= max_tier:
				o = _keep_option(tr("%d gleiche → %s") % [n, Database.tower_label(t.tower_id, t.tier + steps)], t.tower_id, t.tier + steps)
			else:
				var overflow := str(Database.balance.get("overflow_tower", ""))
				if not Database.towers.has(overflow):
					break
				o = _keep_option(tr("%d gleiche → %s") % [n, Database.tower_label(overflow, 0)], overflow, 0)
			o.same = n
			opts.append(o)
			if t.tier + steps > max_tier:
				break
	var others := round_towers.filter(func(o): return o != t)
	for sid in Database.special_ids():
		var def: Dictionary = Database.towers[sid]
		# Zutaten sind alle aus dieser Runde und werden ohnehin mit dem Rest zu Steinen
		if _match_recipe(def.get("recipe", []), t, others) != null:
			opts.append(_keep_option(tr("One-Shot → " if one_shot else "Kombinieren → ") + Database.tower_label(sid, 0), sid, 0))
	return opts.filter(func(o): return not _makes_blocked_trap(t, o))


## Spezial-Tower, die man in der Bauphase schon jetzt bauen könnte, z. B. "Silber (aus Splitter Topas)".
func one_shot_hints() -> Array:
	var hints := []
	for t in round_towers:
		for o in choice_options(t):
			hints.append(tr("%s (aus %s)") % [Database.tower_label(o.id, o.tier), t.label()])
	return hints


func _keep_option(label: String, id: String, tier: int) -> Dictionary:
	return {"label": label, "action": "keep", "id": id, "tier": tier, "consume": [], "cost": 0}


func _ingredient_matches(ing: Dictionary, o: Tower) -> bool:
	if ing.has("any_of"):
		for alt in ing.any_of:
			if _ingredient_matches(alt, o):
				return true
		return false
	return o.tower_id == str(ing.get("tower", "")) and o.tier == int(ing.get("tier", 0))


## Prüft ein Rezept. Der ausgewählte Tower t muss eine Zutat sein, die übrigen kommen aus pool.
## Rückgabe: die verbrauchten Tower aus pool, oder null wenn das Rezept nicht erfüllt ist.
func _match_recipe(recipe: Array, t: Tower, pool: Array):
	if recipe.is_empty():
		return null
	for i in recipe.size():
		if not _ingredient_matches(recipe[i], t):
			continue
		var rest := pool.duplicate()
		var used := []
		var ok := true
		for j in recipe.size():
			if j == i:
				continue
			var found = null
			for o in rest:
				if _ingredient_matches(recipe[j], o):
					found = o
					break
			if found == null:
				ok = false
				break
			rest.erase(found)
			used.append(found)
		if ok:
			return used
	return null


## Upgrades fertiger Spezial-Tower (Feld "upgrades" in der Tower-Datei): Gold, optional weitere Zutaten.
## Nur während der Welle möglich.
func upgrade_options(t: Tower) -> Array:
	if t == null or t.is_new or phase != Phase.WAVE:
		return []
	var ups: Array = t.def.get("upgrades", [])
	if t.tier >= ups.size() or t.tier + 1 >= Database.tier_count(t.tower_id):
		return []
	var up: Dictionary = ups[t.tier]
	var consume := []
	var pool := own_towers().filter(func(o): return o != t and not o.is_new)
	for ing in up.get("recipe", []):
		var found = null
		for o in pool:
			if _ingredient_matches(ing, o):
				found = o
				break
		if found == null:
			return []
		pool.erase(found)
		consume.append(found)
	var cost := int(up.get("cost", 0))
	return [{"label": tr("Aufwerten → %s%s") % [Database.tower_label(t.tower_id, t.tier + 1), tr(" (%d Gold)") % cost if cost > 0 else ""],
			"action": "upgrade", "id": t.tower_id, "tier": t.tier + 1, "consume": consume, "cost": cost}]


func _on_option_chosen(index: int) -> void:
	if not selected_rocks.is_empty():
		var list := selected_rocks.duplicate()
		if index == 0 and gems_left() > 0:
			submit({"type": "replace_rocks", "cells": list})
		else:
			submit({"type": "remove_rocks", "cells": list})
		return
	if moving != null:
		# einzige Option im Verschiebe-Modus: abbrechen
		moving = null
		board.hover_cell = NO_CELL
		_refresh_hud()
		return
	var opts := tower_options(selected)
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	if o.action == "move" or o.action == "swap":
		# Platz wählen ist nur Ansicht, der Befehl kommt beim Klick (move_trap)
		moving = selected
		board.hover_cell = NO_CELL
		_refresh_hud()
		return
	if o.action == "take_back":
		submit({"type": "take_back", "tower": tower_ref(selected)})
		return
	submit({"type": "option", "tower": tower_ref(selected), "index": index, "action": o.action, "id": o.id, "tier": o.tier})


# --- Befehle -------------------------------------------------------------------
# Jede Spieleraktion, die den Spielstand ändert, läuft als Befehl durch submit(). Solo wird er
# sofort ausgeführt; im Koop schickt ein Mitspieler ihn an den Host, der ihn mit execute() prüft
# und ausführt. Tower werden über ihren Platz benannt (tower_ref), nie als Objekt, damit ein
# Befehl auch über das Netz verständlich ist. Ein Befehl, der nicht (mehr) passt, wird verworfen.
#   place          {cell}                 Gem setzen
#   remove_rocks   {cells}                Steine entfernen
#   replace_rocks  {cells}                Steine durch Gems ersetzen
#   take_back      {tower}                gesetzten Gem der Runde zurücknehmen
#   option         {tower, index, action, id, tier}  Behalten, Kombinieren, Aufwerten …
#   move_trap      {tower, to}            Falle verschieben
#   speed          {factor}               Spieltempo 1×, 2× oder 4× (im Koop für alle)
#   setup          {difficulty, score_mode}  Einstellungen vor Runde 1 (nur Spieler 0, d. h. solo oder Host)

# --- Spieler ------------------------------------------------------------------

## Spieler p (-1 = der gerade handelnde).
func pl(p := -1) -> PlayerState:
	return players[clampi(acting if p < 0 else p, 0, players.size() - 1)]


## Spieler für ein neues Spiel festlegen (Reihenfolge = Spielernummer), jeder mit dem Startgold der Map.
func setup_players(names: Array) -> void:
	if names.is_empty():
		names = [""]
	players = []
	for i in names.size():
		var ps := PlayerState.new(i, str(names[i]))
		ps.gold = map.start_gold if map != null else 0
		ps.stage = phase if phase <= Phase.CHOOSE else Phase.BUILD
		players.append(ps)
	acting = local_player


func _mine() -> bool:
	return acting == local_player


## Eigene Tower und Fallen des handelnden Spielers (für Rezepte und Upgrades).
func own_towers() -> Array:
	return all_towers().filter(func(t): return t.owner_player == acting)


## Wo der Spieler gerade steht: in Bau- und Wahlphase jeder für sich (BUILD, CHOOSE oder WAVE = fertig
## und wartet auf die anderen), sonst die gemeinsame Phase.
func stage(p := -1) -> int:
	return pl(p).stage if phase <= Phase.CHOOSE else phase


## Stufe des handelnden Spielers setzen. Die gemeinsame Phase ist CHOOSE, sobald niemand mehr setzt.
func _set_stage(s: int) -> void:
	var me := pl()
	if phase <= Phase.CHOOSE:
		var all_chosen := players.all(func(ps): return (s if ps == me else ps.stage) >= Phase.CHOOSE or ps.away)
		phase = Phase.CHOOSE if all_chosen else Phase.BUILD
	# erst danach: solo setzt die Phase die Stufe mit (siehe phase)
	me.stage = s


## Runde des handelnden Spielers ist fertig (Gem behalten). Die Welle startet, wenn alle fertig sind.
func _finish_round() -> void:
	_set_stage(Phase.WAVE)
	if players.all(func(ps): return ps.stage == Phase.WAVE or ps.away):
		_start_wave()
	else:
		_refresh_hud()


## Weiterleitung → System  coop
func set_player_away(p: int, away: bool) -> void:
	systems.coop.set_away(p, away)


## Haken des Systems coop (Host): Spieler p ist weg (away) oder wieder da. Wer geht, hält die Runde nicht auf: seine
## gesetzten Gems bleiben, behalten wird der erste, der Rest wird zu Steinen. Wer ohne gesetzte Gems geht und noch in
## der Bauphase zurückkommt, setzt gleich mit, sonst ab der nächsten Runde.
func on_player_away(p: int, away: bool) -> void:
	var ps: PlayerState = players[p]
	if phase > Phase.CHOOSE:
		return
	acting = p
	if away and not ps.round_towers.is_empty() and ps.stage != Phase.WAVE:
		var t: Tower = ps.round_towers[0]
		_apply_option(t, _keep_option("", t.tower_id, t.tier))
	elif away and players.all(func(o): return o.stage == Phase.WAVE or o.away):
		_start_wave()
	else:
		_set_stage(ps.stage)
		_refresh_hud()
	acting = local_player


## Befehl des lokalen Spielers abschicken. Als Mitspieler im Koop geht er an den Host (true heißt dann nur:
## abgeschickt), das Ergebnis kommt mit dem nächsten Stand.
func submit(cmd: Dictionary) -> bool:
	if not cmd.has("player"):
		cmd.player = local_player
	var ok := true
	if mirror:
		coop.send(cmd)
	else:
		ok = execute(cmd)
	Sfx.command_sound(cmd, ok)
	return ok


## Befehl ausführen (nur die Simulation, d. h. solo oder auf dem Host). false = verworfen.
## Während der Ausführung gilt acting = cmd.player: Gold, Runde und Besitz sind die dieses Spielers.
func execute(cmd: Dictionary) -> bool:
	var p := int(cmd.get("player", -1))
	if p < 0 or p >= players.size():
		return false
	# Vor den Einstellungen darf nur der Host bzw. Solo-Spieler etwas tun
	if not setup_done and p != local_player:
		return false
	acting = p
	var ok := _execute(cmd)
	acting = local_player
	return ok


func _execute(cmd: Dictionary) -> bool:
	match str(cmd.get("type", "")):
		"place":
			var c: Vector2i = cmd.get("cell", NO_CELL)
			if stage() != Phase.BUILD or gems_left() <= 0 or not can_place(c) or (rogue != null and rogue.pending(acting)):
				return false
			return place_gem(c) != null
		"remove_rocks":
			var done := false
			for c in cmd.get("cells", []):
				done = remove_rock(c) or done
			return done
		"replace_rocks":
			return replace_rocks(cmd.get("cells", [])) > 0
		"take_back":
			return take_back(tower_from_ref(cmd.get("tower", {})))
		"move_trap":
			return move_trap(tower_from_ref(cmd.get("tower", {})), cmd.get("to", NO_CELL))
		"extra_chance":
			return buy_extra_chance(str(cmd.get("id", "")))
		"swap":
			return swap_tower(tower_from_ref(cmd.get("tower", {})), cmd.get("with", NO_CELL))
		"setup":
			if setup_done or acting != 0:
				return false
			Session.difficulty = clampi(int(cmd.get("difficulty", 1)), 0, Session.DIFFICULTIES.size() - 1)
			Session.score_mode = bool(cmd.get("score_mode", false))
			score_mode = Session.score_mode
			Session.rogue = bool(cmd.get("rogue", false)) and Session.game_kind == "gemtd"
			take_foreign_build(cmd)
			if Session.rogue:
				enable_rogue()
			take_ascension(cmd)
			setup_done = true
			_refresh_hud()
			return true
		"rogue_pick":
			if rogue == null or not rogue.pending(acting):
				return false
			var i := int(cmd.get("index", -1))
			var offer: Array = rogue.offers[acting]
			# nur dasselbe Angebot nehmen, das der Spieler gesehen hat
			if i < 0 or i >= offer.size() or offer[i].id != cmd.get("id") or offer[i].boon != cmd.get("boon"):
				return false
			if not rogue.pick(acting, i):
				return false
			_refresh_hud()
			return true
		"speed":
			var f := float(cmd.get("factor", 1.0))
			if not f in [1.0, 2.0, 4.0]:
				return false
			Engine.time_scale = f
			if solo():
				Session.speed = f
			return true
		"option":
			var t := tower_from_ref(cmd.get("tower", {}))
			var opts := tower_options(t)
			var i := int(cmd.get("index", -1))
			if i < 0 or i >= opts.size():
				return false
			var o: Dictionary = opts[i]
			# Optionen können sich inzwischen verschoben haben: nur ausführen, wenn es dieselbe ist
			if o.action != cmd.get("action") or o.id != cmd.get("id") or o.tier != int(cmd.get("tier", -1)):
				return false
			return _apply_option(t, o)
	return false


## Tower oder Falle als Platz (+ ob Falle), damit Befehle ohne Objektverweise auskommen.
static func tower_ref(t: Tower) -> Dictionary:
	if t == null or not is_instance_valid(t):
		return {}
	return {"cell": t.cell, "trap": t.is_trap()}


func tower_from_ref(ref: Dictionary) -> Tower:
	if ref.is_empty():
		return null
	var c: Vector2i = ref.get("cell", NO_CELL)
	return traps.get(c) if ref.get("trap", false) else towers.get(c)


## Option o (aus tower_options(t)) ausführen: Behalten, Kombinieren, Aufwerten.
func _apply_option(t: Tower, o: Dictionary) -> bool:
	if t == null or o.action in ["move", "swap", "take_back"] or gold < int(o.cost):
		return false
	gold -= int(o.cost)
	run_stats.flush(t)
	for c in o.consume:
		run_stats.flush(c)
		_consume(c)
	# Roguelike „Doppelfund“: diesen Gem behalten, die anderen bleiben zur Wahl
	var extra: bool = o.action == "keep" and rogue != null and round_towers.size() > 1 and rogue.take_extra_keep(acting)
	if extra:
		round_towers.erase(t)
		t.is_new = false
	elif o.action == "keep":
		for r in round_towers:
			if r != t and is_instance_valid(r):
				_turn_into_rock(r)
		round_towers.clear()
		t.is_new = false
	t.kills += o.consume.reduce(func(acc, c): return acc + c.kills, 0)
	var ep_sum: float = t.ep + o.consume.reduce(func(acc, c): return acc + c.ep, 0.0)
	var old_id := t.tower_id
	_unregister(t)
	t.set_tower(o.id, o.tier)
	t.set_ep(ep_sum)
	_register(t)
	run_stats.built(t, o.action, wave_index + 1)
	if t.is_trap() and (o.id != old_id or o.action == "keep"):
		t.moves_left = trap_moves()
	if t == selected:
		t.set_selected(true)
	_update_paths()
	board.refresh_rocks()
	_update_auras()
	if o.action == "keep" and not extra:
		_finish_round()
	else:
		_refresh_hud()
	return true


## Verbrauchte Zutat: Tower werden zu Steinen, Fallen verschwinden.
func _consume(t: Tower) -> void:
	if t.is_trap():
		_unregister(t)
		t.queue_free()
	else:
		_turn_into_rock(t)


func _turn_into_rock(t: Tower) -> void:
	_unregister(t)
	rocks[t.cell] = true
	_occupy(t.cell, true, true)
	t.queue_free()


## Chance-Stufe steigt automatisch: höchste Stufe, deren „wave“ erreicht ist.
func chance_level_for(wave: int) -> int:
	var levels: Array = Database.balance.get("chance_levels", [])
	var lvl := 0
	for i in levels.size():
		if wave >= int(levels[i].get("wave", 1)):
			lvl = i
	return lvl


## Welle, ab der die nächste Chance-Stufe gilt (-1 = schon maximal).
func next_chance_wave() -> int:
	var levels: Array = Database.balance.get("chance_levels", [])
	if chance_level + 1 >= levels.size():
		return -1
	return int(levels[chance_level + 1].get("wave", 1))


## Anteil des Golds aus Kills und Fähigkeiten in dieser Welle (System economy; GemTD: data/balance.json
## gold_income_factor, ab gold_income_ramp steigend; eeveTD/Randgruppen 1.0 über modes.json).
func gold_income_factor(wave: int) -> float:
	return systems.economy.income_factor(wave)


## Gold aus Kills und Fähigkeiten, gekürzt um gold_income_factor (Reste werden gesammelt), System economy.
func earn_gold(amount: float, p := -1) -> void:
	systems.economy.earn(amount, p)


func current_wave() -> int:
	return wave_index + 1


func add_gold(amount: int, p := -1) -> void:
	systems.economy.earn(amount, p)
	_refresh_hud()


## Auren, die andere Tower verstärken.
func _update_auras() -> void:
	for t in all_towers():
		t.speed_bonus = 0.0
		t.damage_bonus = 0.0
		t.speed_source = ""
		t.damage_source = ""
		t.bounty_bonus = 0.0
		t.xp_bonus = 0.0
	for src in all_towers():
		for ab in src.abilities():
			var type := str(ab.get("type", ""))
			if not type in ["speed_aura", "damage_aura", "bounty_aura", "xp_aura"]:
				continue
			for t in all_towers():
				if t.pos.distance_to(src.pos) > float(ab.radius):
					continue
				# Kopfgeld und Erfahrung wirken wie in Warcraft 3 auch auf den Tower selbst, gleiche Auren zählen nicht doppelt
				if type == "bounty_aura":
					t.bounty_bonus = maxf(t.bounty_bonus, float(ab.bonus))
					continue
				if type == "xp_aura":
					t.xp_bonus = maxf(t.xp_bonus, float(ab.bonus))
					continue
				if t == src:
					continue
				if type == "speed_aura" and float(ab.bonus) > t.speed_bonus:
					t.speed_bonus = float(ab.bonus)
					t.speed_source = src.label()
				elif type == "damage_aura" and float(ab.bonus) > t.damage_bonus:
					t.damage_bonus = float(ab.bonus)
					t.damage_source = src.label()
	for t in all_towers():
		t.set_rogue(rogue.bonus_for(t) if rogue != null else {})


# --- Welle -------------------------------------------------------------------

func is_wave_running() -> bool:
	return phase == Phase.WAVE


func _start_wave() -> void:
	if wave_index >= waves.size():
		_finish(Phase.VICTORY)
		return
	phase = Phase.WAVE
	spawn_queue.clear()
	wave_live = {"gone_hp": 0.0, "gone_dealt": 0.0, "killed": 0, "leaked": 0}
	var w: Dictionary = waves[wave_index]
	for g in w.get("groups", []):
		spawn_queue.append_array(group_queue(g))
	spawn_timer = 0.5
	Sfx.play("wave_start")
	_refresh_hud()


## Gegner einer Gruppe in Spawn-Reihenfolge. Massenwellen (Feld "pack", bei Pyramiden-Gegnern Standard 5)
## kommen in Trupps: innerhalb eines Trupps im Abstand "pack_gap", ein neuer Trupp startet alle pack × interval
## Sekunden, so bleibt die Dauer der Welle gleich wie einzeln. pack 1 = alle einzeln.
static func group_queue(g: Dictionary) -> Array:
	var count := int(g.get("count", 1))
	var pack := int(g.get("pack", 5 if str(g.get("shape", "")) == "pyramid" else 1))
	var out := []
	if pack <= 1 or count <= 1:
		for i in count:
			out.append(g)
		return out
	var interval := float(g.get("interval", 1.0))
	var gap := minf(float(g.get("pack_gap", 0.2)), interval)
	var inside := g.duplicate()
	inside["interval"] = gap
	var last := g.duplicate()
	last["interval"] = maxf(pack * interval - (pack - 1) * gap, gap)
	for i in count:
		out.append(last if i % pack == pack - 1 else inside)
	return out


func _process_wave(delta: float) -> void:
	# Spawn-Warteschlange im System waves (holt verspätete Gegner nach, damit die Abstände nicht vom Bildraster abhängen)
	spawn_timer = systems.waves.drain(spawn_queue, spawn_timer, delta, _spawn_new, func(g): return float(g.get("interval", 1.0)))
	if spawn_queue.is_empty() and enemies.is_empty() and phase == Phase.WAVE:
		run_stats.wave_done(all_towers(), wave_index + 1, int(leaks_per_wave.get(wave_index, 0)), int(wave_live.killed))
		wave_index += 1
		effects.clear()
		if wave_index >= waves.size():
			_finish(Phase.VICTORY)
		else:
			_enter_build()
			autosave.call_deferred()


## Gegner der Gruppe g erscheinen an jeder aktiven Bahn (lane < 0) oder nur an Bahn lane.
## Gruppe g spawnen und die neuen Gegner zurückgeben (für waves.drain).
func _spawn_new(g: Dictionary) -> Array:
	var before := enemies.size()
	_spawn_enemy(g)
	return enemies.slice(before)


func _spawn_enemy(g: Dictionary, lane := -1) -> void:
	var def: Dictionary = enemy_def(str(g.get("enemy", "")))
	if def.is_empty():
		push_warning("Unbekannter Gegner: %s" % g.get("enemy", ""))
		return
	var lanes := active_lanes() if lane < 0 else [lane]
	for i in lanes:
		var e := Enemy.new()
		e.net_id = _next_enemy_id
		e.lane = i
		_next_enemy_id += 1
		board.add_child(e)
		var lp: Dictionary = lane_paths[i]
		e.setup(self, def, g, lp.air if def.get("flying", false) else lp.ground)
		_apply_enemy_difficulty(e, g)
		_apply_ascension(e)
		setup_score(e, g)
		# Eine Welle ist gleich viele Punkte wert, egal an wie vielen Bahnen sie läuft
		e.score_value /= lanes.size()
		enemies.append(e)
	if def.get("boss", false):
		Sfx.play("boss")


## Schwierigkeit auf einen neuen Gegner der Gruppe g anwenden.
func _apply_enemy_difficulty(e: Enemy, _g: Dictionary) -> void:
	e.apply_difficulty(Session.difficulty_factor())


## Aufstiegsstufe auf einen neuen Gegner anwenden (nach der Schwierigkeit), System difficulty.
func _apply_ascension(e: Enemy) -> void:
	systems.difficulty.apply_ascension(e)


## Was die gewählte Aufstiegsstufe ändert (ascension.gd), einmal je Run ausgerechnet.
func ascension_mods() -> Dictionary:
	return systems.difficulty.ascension_mods()


## Index der gewählten Schwierigkeit in der Liste des Modus (System difficulty, Quelle je Modus in modes.json).
func difficulty_index() -> int:
	return systems.difficulty.index()


## Name der gewählten Schwierigkeit mit Aufstiegsstufe, z. B. „Schwer +3“.
func difficulty_label() -> String:
	return systems.difficulty.label()


## Anzahl der Schwierigkeiten des Modus.
func difficulty_count() -> int:
	return systems.difficulty.count()


## Aufstiegsstufe aus dem Setup-Befehl übernehmen: nur auf der höchsten Schwierigkeit, höchstens max_level.
func take_ascension(cmd: Dictionary) -> void:
	systems.difficulty.take_ascension(int(cmd.get("ascension", 0)))


## Die gewählte Schwierigkeit als Daten (eeveTD, Randgruppen, YouTD: Eintrag aus rules.difficulties).
func diff_rules() -> Dictionary:
	return systems.difficulty.current()


## Ist der Gegner in Reichweite eines Towers, der ihn angreifen oder mit einer Aura treffen kann?
## Wirkt noch Gift, zählt das auch: sonst liefe er mit dem Gift schneller ins Ziel als ohne Schnelllauf.
func is_covered(e: Enemy) -> bool:
	if e.poison_time > 0.0:
		return true
	_refresh_cover()
	for c in _cover:
		var t: Tower = c[0]
		if not is_instance_valid(t) or e.pos.distance_squared_to(t.pos) > c[1] * c[1]:
			continue
		if t.can_attack() and t.can_target(e) and t.in_range(e):
			return true
		var aura := t.enemy_aura_radius(e)
		if aura > 0.0 and e.pos.distance_to(t.pos) <= aura:
			return true
	return false


## Einmal pro Bild: Tower, die überhaupt etwas erreichen, mit ihrer größten Reichweite.
func _refresh_cover() -> void:
	var frame := Engine.get_process_frames()
	if frame == _cover_frame:
		return
	_cover_frame = frame
	_cover = []
	var sig := []
	for t in all_towers():
		var reach := maxf(t.range_cells() if t.can_attack() else 0.0, t._aura_radius())
		if t.can_attack() and t.stats.has("range_air"):
			reach = maxf(reach, float(t.stats.range_air) * (1.0 + t.rogue_range))
		if reach > 0.0:
			_cover.append([t, reach + 1.5])
			sig.append([t.pos, reach, t.target_mode(), t.can_attack()])
	_cover_sig = hash(sig)


## Für Mitspieler: das Stück, auf dem der Gegner schnell läuft oder als Nächstes laufen wird, als [von, bis] in
## zurückgelegter Strecke, oder [-1, -1]. Damit sagen sie voraus, wo er abbremst, statt bis zur
## nächsten Meldung mit 8× weiterzulaufen. Solange Gift wirkt, beginnt das Stück erst danach.
func free_stretch(e: Enemy) -> Array:
	if idle_speed_factor() <= 1.0:
		return [-1.0, -1.0]
	_refresh_cover()
	var key := "%d/%d" % [e.lane, int(e.flying)]
	var cached: Dictionary = _free_cache.get(key, {})
	if cached.is_empty() or cached.sig != _cover_sig or not is_same(cached.path, e.path):
		cached = {"path": e.path, "sig": _cover_sig, "list": _free_stretches(e.path, e.flying)}
		_free_cache[key] = cached
	# Das Stück, auf dem er gerade ist, ab seinem echten Anfang: der Mitspieler liegt oft knapp
	# dahinter und soll dort nicht normal schnell laufen.
	var from := e.traveled
	var poisoned := e.poison_time > 0.0
	if poisoned:
		from += e.base_speed() * e.poison_time
	for st in cached.list:
		if st[1] > from:
			return [maxf(st[0], from) if poisoned else st[0], st[1]]
	return [-1.0, -1.0]


const COVER_SAMPLE := 0.25


## Stücke des Wegs ohne Tower in Reichweite, als [von, bis] in Strecke ab dem Start.
func _free_stretches(path: Array, flying: bool) -> Array:
	if _probe == null:
		_probe = Enemy.new()
	_probe.flying = flying
	_probe.poison_time = 0.0
	var out := []
	var start := -1.0
	var done := 0.0
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var seg := a.distance_to(b)
		var n := maxi(ceili(seg / COVER_SAMPLE), 1)
		for k in range(0 if i == 1 else 1, n + 1):
			var s := seg * k / n
			var free := not _probe_covered(a, b, seg, s)
			if free and start < 0.0:
				start = done + _cover_edge(a, b, seg, maxf(s - seg / n, 0.0), s, false)
			elif not free and start >= 0.0:
				out.append([start, done + _cover_edge(a, b, seg, maxf(s - seg / n, 0.0), s, true)])
				start = -1.0
		done += seg
	if start >= 0.0:
		out.append([start, done])
	return out


func _probe_covered(a: Vector2, b: Vector2, seg: float, s: float) -> bool:
	_probe.pos = a.lerp(b, s / seg) if seg > 0.0 else b
	return is_covered(_probe)


## Rand zwischen lo und hi auf dem Abschnitt a–b genauer suchen: dort wechselt is_covered auf covered_at_hi.
func _cover_edge(a: Vector2, b: Vector2, seg: float, lo: float, hi: float, covered_at_hi: bool) -> float:
	for i in 5:
		var mid := (lo + hi) / 2.0
		if _probe_covered(a, b, seg, mid) == covered_at_hi:
			hi = mid
		else:
			lo = mid
	return hi


## Tempo-Faktor für Gegner, die gerade kein Tower erreicht.
func idle_speed_factor() -> float:
	return maxf(float(Database.balance.get("idle_speed_factor", 1.0)), 1.0)


## Weiterleitung → System  targeting
func find_targets(t: Tower, count: int) -> Array:
	return systems.targeting.find_targets(t, count)


## Weiterleitung → System  targeting
func enemies_in_radius(p: Vector2, radius: float) -> Array:
	return systems.targeting.enemies_in_radius(p, radius)


## fx: Schuss-/Treffer-Effekt, siehe effects.gd
func add_beam(from: Vector3, to: Vector3, col: Color, fx: String = "") -> void:
	effects.add_beam(from, to, col, fx)
	if coop != null and not mirror:
		coop.add_beam(from, to, col, fx)
	if net_sync:
		net_sync.add_beam(from, to, col, fx)


func on_enemy_killed(e: Enemy) -> void:
	enemies_killed += 1
	# Kopfgeld bekommt der Spieler, dessen Tower zuletzt getroffen hat, mit dessen Kopfgeld-Aura
	var aura := float(e.last_tower.bounty_bonus) if is_instance_valid(e.last_tower) else 0.0
	earn_gold(e.bounty * (1.0 + aura) * (rogue.gold_factor(e.last_hit_by) if rogue != null else 1.0), e.last_hit_by)
	if rogue != null:
		rogue.on_kill(e)
	if e.final_boss:
		_final_boss_done(e, true)
	else:
		var st := _stats_for_wave()
		st.kills += 1
		if score_mode:
			score += e.score_value
			st.points += e.score_value
	_remove_enemy(e)
	if e.stack_time > 0.0 and not e.stack_boom.is_empty():
		_stack_boom(e)
	_refresh_hud()


## Geisterplatte: Gegner, die mit ihren Stapeln sterben, explodieren und treffen alle Gegner im Umkreis.
## Wer dabei selbst mit Stapeln stirbt, explodiert ebenfalls (Kettenreaktion).
func _stack_boom(e: Enemy) -> void:
	var boom: Dictionary = e.stack_boom
	e.stack_boom = {}
	var t = e.stack_source if is_instance_valid(e.stack_source) else null
	var radius := float(boom.radius)
	if t != null:
		add_beam(Board3D.to_3d(e.pos, 0.1), Board3D.to_3d(e.pos, 1.5), Color.WHITE, "n:%s:%d:%s" % [t.tower_id, t.tier, radius])
	for other in enemies_in_radius(e.pos, radius):
		if t == null:
			other.take_damage(float(boom.damage), "spells")
			continue
		other.last_hit_by = t.owner_player
		other.last_tower = t
		t.total_damage += other.take_damage(float(boom.damage), "spells")
		if other.dead:
			t.kills += 1


func on_enemy_leaked(e: Enemy) -> void:
	if e.final_boss:
		# Schadenscheck: der Endboss kostet weder Leben noch Punkte, zählt nur der Schaden
		_final_boss_done(e, false)
		_remove_enemy(e)
		_refresh_hud()
		return
	var st := _stats_for_wave()
	st.leaks += 1
	leaks_per_wave[wave_index] = int(leaks_per_wave.get(wave_index, 0)) + (1 if score_mode else e.damage)
	if score_mode:
		score -= leak_penalty(e.score_value)
		st.lost += leak_penalty(e.score_value)
		_remove_enemy(e)
		_refresh_hud()
		return
	lives -= e.damage
	Sfx.play("leak")
	_remove_enemy(e)
	# Debug „Unsterblich“: Leben gehen ins Minus, das Spiel läuft weiter
	if lives <= 0 and not Session.debug_immortal:
		lives = 0
		_finish(Phase.GAME_OVER)
	_refresh_hud()


# --- Punkte-Modus ----------------------------------------------------------------
# Jede Welle ist wave_base + wave_step × (Welle − 1) Punkte wert (Welle 1: 100, Welle 40: 490),
# verteilt nach Lebenspunkten auf ihre Gegner: ein Boss allein bekommt alles, bei einer Massenwelle
# zählt jeder der 25 Gegner wenig. Ein Durchbruch kostet leak_factor (50 %) des Werts.
# Die Schwierigkeit multipliziert alles (Session.score_factor).

## Punkte, die eine ganze Welle wert ist (wave: 1-basiert).
func wave_points(wave: int) -> float:
	var cfg: Dictionary = Database.balance.get("score", {})
	return (float(cfg.get("wave_base", 100)) + float(cfg.get("wave_step", 10)) * (wave - 1)) * Session.score_factor()


## Punkte für einen Gegner der Gruppe g in der aktuellen Welle.
func score_for(g: Dictionary) -> float:
	if wave_index >= waves.size():
		return 0.0
	var total := 0.0
	for grp in waves[wave_index].get("groups", []):
		total += _group_hp(grp) * int(grp.get("count", 1))
	if total <= 0.0:
		return 0.0
	return wave_points(wave_index + 1) * _group_hp(g) / total


## Punktewert und Endboss-Markierung für einen neuen (oder geladenen) Gegner der Gruppe g.
func setup_score(e: Enemy, g: Dictionary) -> void:
	e.final_boss = is_final_boss_wave()
	e.score_value = score_for(g) * (float(Database.balance.get("score", {}).get("final_boss_factor", 3.0)) if e.final_boss else 1.0)


## Letzte Welle ist eine Boss-Welle: ihr Boss ist der Endboss (Schadenscheck).
func is_final_boss_wave() -> bool:
	return not waves.is_empty() and wave_index == waves.size() - 1 and wave_type(waves[wave_index]) == "Boss"


## Endboss verschwindet (besiegt oder durchgelaufen): Schaden zählen, im Punkte-Modus Punkte nach Schaden.
func _final_boss_done(e: Enemy, killed: bool) -> void:
	var dmg := e.max_hp if killed else clampf(e.max_hp - e.hp, 0.0, e.max_hp)
	final_boss.damage += dmg
	final_boss.hp += e.max_hp
	if killed:
		final_boss.kills += 1
	if score_mode and e.max_hp > 0.0:
		var pts := e.score_value * dmg / e.max_hp
		score += pts
		final_boss.points += pts


func _stats_for_wave() -> Dictionary:
	var type := wave_type(waves[wave_index]) if wave_index < waves.size() else "?"
	if not score_stats.has(type):
		score_stats[type] = {"kills": 0, "points": 0.0, "leaks": 0, "lost": 0.0}
	return score_stats[type]


## Zusammenfassung für den Endbildschirm.
func run_summary() -> Dictionary:
	return {"score_mode": score_mode, "types": score_stats.duplicate(true),
		"final_boss": final_boss.duplicate() if final_boss.hp > 0.0 else {}}


func leak_penalty(value: float) -> float:
	return value * float(Database.balance.get("score", {}).get("leak_factor", 0.5))


## Leben der Gegner, die in dieser Welle noch nicht erschienen sind (mit Schwierigkeit).
func queued_hp() -> float:
	var total := 0.0
	for g in spawn_queue:
		total += _group_hp(g)
	return total * Session.difficulty_factor() * active_lanes().size()


func _group_hp(g: Dictionary) -> float:
	return float(g.get("hp", enemy_def(str(g.get("enemy", ""))).get("hp", 10)))


func _remove_enemy(e: Enemy) -> void:
	wave_live.gone_hp += e.max_hp
	wave_live.gone_dealt += clampf(e.max_hp - e.hp, 0.0, e.max_hp)
	if e.hp <= 0.0:
		wave_live.killed += 1
	else:
		wave_live.leaked += 1
	enemies.erase(e)
	e.queue_free()


func _finish(p: Phase) -> void:
	phase = p
	drop_autosave()
	RunHistory.record(RunHistory.entry_from(self, p == Phase.VICTORY))
	record_profile(p == Phase.VICTORY)
	Engine.time_scale = 1.0
	hud.show_game_over(p == Phase.VICTORY, mini(wave_index + 1, waves.size()), waves.size(), lives, enemies_killed, path_length,
		roundi(score) if score_mode else null, run_summary())
	_refresh_hud()


## Run ins Profil (profile.gd): Kurzinfo wie in der Run-History plus alle Tower- und Wellenwerte.
func record_profile(victory: bool) -> Dictionary:
	var info := RunHistory.entry_from(self, victory)
	info.erase("top")
	info.coop = coop != null
	info.players = players.size()
	return systems.run_record.finish(info, run_stats.result(all_towers().filter(func(t): return not t.is_new)),
		{"difficulty": difficulty_index(), "ascension": ascension})


## Hilft hier eine Debug-Hilfe? Dann gibt der Run keine EP und zählt nicht für Siege und Rekorde (nur die
## Zeit). Gilt für den ganzen Run, auch nach Speichern und Laden (debug_used steht im Spielstand).
func debug_run() -> bool:
	return debug_used or Session.debug_immortal or Session.debug_gems_per_round > 0 or Session.return_scene != Session.MAIN_MENU


## Spiel verlassen, bevor der Run zu Ende ist: Zeit ins Profil, ohne Speichern auch als abgebrochen.
func record_profile_abort() -> void:
	if phase >= Phase.GAME_OVER:
		return
	var info := RunHistory.entry_from(self, false)
	info.erase("top")
	systems.run_record.abort(info, {"difficulty": difficulty_index(), "ascension": ascension})


## Modus im Profil (eeve_game.gd überschreibt das, die Variante Roguelike zählt eigen).
func profile_mode() -> String:
	return "roguelike" if rogue != null else "gemtd"


## Zusätzliche Werte für den Run im Profil (eeve_game.gd überschreibt das), im Roguelike die gewählten Boni.
func profile_extra() -> Dictionary:
	if rogue != null and local_player < rogue.boons.size():
		return {"boons": rogue.boons[local_player]}
	return {}


# --- HUD ---------------------------------------------------------------------

func _gold_text(cost: int) -> String:
	return tr(" (%d Gold)") % cost if cost > 0 else ""


## Die Anzeige zeigt immer den lokalen Spieler, auch wenn gerade der Befehl eines Mitspielers läuft.
func _refresh_hud() -> void:
	if hud == null:
		return
	var was := acting
	acting = local_player
	_refresh_hud_local()
	acting = was


func _refresh_hud_local() -> void:
	hud.set_resources(mini(wave_index + 1, waves.size()), waves.size(), roundi(score) if score_mode else lives, gold, score_mode)
	hud.set_path_length(path_length, path_length - round_path_start if phase <= Phase.CHOOSE else 0)
	var my_stage := stage()
	hud.set_waves(_upcoming_waves(4))
	# Baubar: in der Welle aus fertigen Towern, beim Setzen und Auswählen nur aus den Gems der Runde
	var now_pool: Array = own_towers().filter(func(t): return not t.is_new) if phase == Phase.WAVE else round_towers
	# Zutaten: fixierte Tower plus nur der ausgewählte neue Gem (pro Runde behält man genau einen)
	var have: Array = own_towers().filter(func(t): return not t.is_new or t == selected)
	hud.set_owned(have.map(func(t): return [t.tower_id, t.tier, t.is_new]),
			{"pool": now_pool.map(func(t): return [t.tower_id, t.tier, t.is_new]), "wave": phase == Phase.WAVE})

	# Neue Gems, die eine Zutat für einen Spezial-Tower aus dieser Runde sind (lila markiert)
	var specials := []
	var gems := []
	for t in round_towers:
		var shot := false
		for o in choice_options(t):
			if _is_special_option(t, o):
				shot = true
				if not specials.has(Database.tower_label(o.id, o.tier)):
					specials.append(Database.tower_label(o.id, o.tier))
		gems.append({"label": t.label(), "color": t.color, "selected": t == selected, "oneshot": shot,
				"tier": t.tier, "tiers": Database.tier_count(t.tower_id), "id": t.tower_id})
	var shot_text := ""
	if not specials.is_empty():
		shot_text = tr("One-Shot möglich: " if my_stage == Phase.BUILD else "Spezial möglich: ") + ", ".join(specials)
	hud.set_round_gems(gems if my_stage <= Phase.CHOOSE else [], tr("Hellblauer Rand: Zutat für ") + ", ".join(specials) if not specials.is_empty() else "")
	hud.set_gem_tags(gem_tags() if my_stage == Phase.CHOOSE else [])

	if phase <= Phase.CHOOSE and my_stage == Phase.WAVE:
		hud.set_phase(tr("Warten"), tr("Dein Gem ist gewählt. Die Welle startet, sobald alle Mitspieler fertig sind."), "")
	else:
		_set_phase_banner(my_stage, shot_text)
	hud.set_chance(chance_level, next_chance_wave())
	hud.set_extra_chance(not extra_chance_cfg().is_empty(), can_buy_extra_chance(), pl(local_player).extra_chance)
	if rogue != null:
		var every := int(Rogue.rules().get("every", 10))
		var next := (floori(wave_index / float(every)) + 1) * every if every > 0 else -1
		hud.set_boons(rogue.boons[local_player].map(func(b): return Rogue.describe(b)) if local_player < rogue.boons.size() else [],
				next if next < waves.size() else -1)
	_refresh_selection()


func _set_phase_banner(my_stage: int, shot_text: String) -> void:
	match my_stage:
		Phase.BUILD:
			hud.set_phase(tr("Bauphase"), tr("Gems gesetzt: %d / %d · Steine anklicken: ersetzen oder entfernen") % [round_towers.size(), gems_per_round()], shot_text)
		Phase.CHOOSE:
			var extra: int = rogue.extra_keeps_left(local_player) if rogue != null else 0
			if extra > 0:
				hud.set_phase(tr("Wahlphase"), tr("Doppelfund: du darfst %d Gems mehr behalten, danach werden die anderen zu Steinen.") % extra, shot_text)
			else:
				hud.set_phase(tr("Wahlphase"), tr("Wähle einen der neuen Gems und behalte ihn. Die anderen werden zu Steinen."), shot_text)
		Phase.WAVE:
			if is_final_boss_wave():
				hud.set_phase(tr("Endboss"), tr("Schadenscheck: kostet keine Leben, zählt nur dein Schaden") if not score_mode
					else tr("Schadenscheck: jeder Schaden bringt Punkte, Durchlaufen kostet nichts"))
			else:
				hud.set_phase(tr("Welle %d") % (wave_index + 1), tr("noch %d Gegner") % (enemies.size() + spawn_queue.size()))
		Phase.GAME_OVER:
			hud.set_phase(tr("Verloren"), "")
		Phase.VICTORY:
			hud.set_phase(tr("Gewonnen"), tr("Alle Wellen geschafft!"))


func _refresh_selection() -> void:
	if not selected_rocks.is_empty():
		var n := selected_rocks.size()
		var each := rock_remove_cost()
		var free := gems_left()
		var k := mini(n, free)
		var body := tr("Ziehen oder Strg+Klick wählt bis zu %d Steine auf einmal aus.") % MAX_ROCK_SELECTION
		if free > 0 and n > free:
			body = tr("Diese Runde sind noch %d Gems übrig, ersetzt werden die ersten %d Steine.") % [free, free]
		hud.set_selection({"title": tr("Stein") if n == 1 else tr("%d Steine") % n, "color": Color("6d6a63"), "used_in": null, "body": body})
		var opts := []
		if free > 0:
			opts.append({"label": (tr("Gem hierher setzen") if n == 1 else tr("%d Gems setzen") % k) + _gold_text(each * k), "style": "primary"})
		opts.append({"label": (tr("Stein entfernen") if n == 1 else tr("%d Steine entfernen") % n) + _gold_text(each * n), "style": "normal"})
		hud.set_options(opts)
		hud.set_options_enabled(phase < Phase.GAME_OVER and gold >= each * (k if free > 0 else n))
		return
	if moving != null and is_instance_valid(moving) and not moving.is_trap():
		hud.set_selection({"title": tr("%s tauschen") % moving.label(), "color": moving.color, "used_in": null,
				"body": tr("Eigenen Gem oder Stein anklicken, der Opal tauscht mit ihm den Platz (%d Gold).\nRechtsklick oder Esc bricht ab.") % swap_cost(moving)})
		hud.set_options([{"label": tr("Abbrechen"), "style": "normal"}])
		hud.set_options_enabled(true)
		return
	if moving != null and is_instance_valid(moving):
		hud.set_selection({"title": tr("%s verschieben") % moving.label(), "color": moving.color, "used_in": null,
				"body": tr("Neuen Platz anklicken (grün = möglich). Fallen dürfen auf Checkpoints und unter Tower.\nRechtsklick oder Esc bricht ab.")})
		hud.set_options([{"label": tr("Abbrechen"), "style": "normal"}])
		hud.set_options_enabled(true)
		return
	if selected == null or not is_instance_valid(selected):
		hud.set_selection({})
		hud.set_options([])
		return
	var used := Recipes.used_in(selected.tower_id, selected.tier)
	var body := ""
	if not selected.is_new and phase <= Phase.CHOOSE and _field_recipe_complete(used):
		body = tr("Kombinieren geht erst wieder während der Welle.")
	var info := {"title": selected.label(), "color": selected.color, "body": body, "used_in": used,
			"stats": TowerStats.view(selected)}
	if Database.towers.get(selected.tower_id, {}).get("category", "gem") == "gem":
		info["tier"] = selected.tier
	hud.set_selection(info)
	hud.set_options(_promote_combine(tower_options(selected).map(func(o): return _option_view(selected, o))))
	hud.set_options_enabled(true)


## Lässt sich der Gem mit einem zweiten gleichen um eine Qualität verbessern, wird das die große Aktion
## (Leertaste) und „Behalten“ ein kleiner Knopf. Die Reihenfolge bleibt, sie ist der Index für option_chosen.
func _promote_combine(views: Array) -> Array:
	var i := -1
	for k in views.size():
		if views[k].get("combine_up", false):
			i = k
			break
	if i < 0:
		return views
	for v in views:
		if v.style == "primary":
			v.style = "normal"
	views[i].style = "primary"
	views[i].hint = tr("2 gleiche Gems kombinieren")
	return views


## Ob eines der Rezepte mit den fertigen Towern auf dem Feld komplett wäre (für den Hinweis außerhalb der Welle).
func _field_recipe_complete(ids: Array) -> bool:
	var field: Array = all_towers().filter(func(t): return not t.is_new).map(func(t): return [t.tower_id, t.tier])
	return ids.any(func(id): return Recipes.ready_now(id, field, {"pool": field, "wave": true}))


## Vorschau der nächsten Wellen für die linke Spalte.
func _upcoming_waves(count: int) -> Array:
	var list := []
	if phase >= Phase.GAME_OVER:
		return list
	for i in range(wave_index, mini(wave_index + count, waves.size())):
		var groups: Array = waves[i].get("groups", [])
		var defs := groups.map(func(g): return enemy_def(str(g.get("enemy", ""))))
		var total := 0
		for g in groups:
			total += int(g.get("count", 1))
		var detail := ""
		if groups.size() == 1 and not defs[0].is_empty():
			var d: Dictionary = defs[0]
			# Werte der Welle (Massenwellen überschreiben sie) mit der Schwierigkeitsstufe
			var f := Session.difficulty_factor()
			var hp := float(groups[0].get("hp", d.get("hp", 0))) * f
			var armor := float(groups[0].get("armor", d.get("armor", 0)))
			if armor > 0.0:
				armor *= f
			detail = tr("%d× %s · %d LP · Rüstung %d") % [total, tr(str(d.get("name", "?"))), roundi(hp), roundi(armor)]
		else:
			detail = tr("%d Gegner: %s") % [total, ", ".join(defs.map(func(d): return tr(str(d.get("name", "?")))))]
		var state := ""
		if i == wave_index:
			state = tr("läuft") if phase == Phase.WAVE else tr("als Nächstes")
		list.append({"number": i + 1, "type": wave_type(waves[i]), "detail": detail, "state": state})
	return list


## Wellentyp wie die Gegnerformen: Boss, Flieger, Masse (Pyramiden oder sehr viele Gegner), Boden oder Gemischt.
static func wave_type(w: Dictionary) -> String:
	if w.has("type"):
		return str(w.type)
	var groups: Array = w.get("groups", [])
	var flying := 0
	var ground := 0
	var total := 0
	for g in groups:
		var d: Dictionary = Database.enemies.get(str(g.get("enemy", "")), {})
		if d.get("boss", false):
			return "Boss"
		if d.get("flying", false):
			flying += 1
		else:
			ground += 1
		total += int(g.get("count", 1))
		if str(d.get("shape", "")) == "pyramid":
			return "Masse"
	if flying > 0 and ground > 0:
		return "Gemischt"
	if flying > 0:
		return "Flieger"
	return "Masse" if total >= 20 else "Boden"


## Wird aus dem Gem ein Spezial-Tower (One-Shot in der Bau-, Kombination in der Wahlphase)?
func _is_special_option(t: Tower, o: Dictionary) -> bool:
	return t.is_new and o.action == "keep" and o.id != t.tower_id \
			and Database.towers.get(o.id, {}).get("category", "gem") == "special"


func _option_view(t: Tower, o: Dictionary) -> Dictionary:
	var v := {"label": o.label, "style": "normal"}
	if _is_special_option(t, o):
		v.style = "oneshot"
		var hint := tr("Baut %s sofort und beendet die Runde.") % Database.tower_label(o.id, o.tier) if stage() == Phase.BUILD else ""
		hint += " " + tr("Die übrigen neuen Gems werden zu Steinen.")
		if not o.consume.is_empty():
			hint += " " + tr("Verbraucht vom Feld: ") + ", ".join(o.consume.map(func(c): return c.label()))
		v.hint = hint.strip_edges()
	elif o.action == "upgrade":
		# Name des Upgrades, darunter die Goldkosten
		v.label = Database.tower_label(o.id, o.tier)
		if int(o.cost) > 0:
			v.sub = tr("%d Gold") % int(o.cost)
	elif o.action == "keep" and o.id == t.tower_id and o.tier == t.tier:
		v.style = "primary"
		v.label = tr("Behalten")
	elif int(o.get("same", 0)) == 2:
		v.combine_up = true
	# Symbol + Zielname statt "Abstufen → …", "2 gleiche → …", "Kombinieren → …"
	var overflow := str(Database.balance.get("overflow_tower", ""))
	if o.action == "upgrade" or (o.action == "keep" and ((o.id == t.tower_id and o.tier > t.tier) or (o.id == overflow and o.id != t.tower_id))):
		v.icon = "up"
	elif o.action == "keep" and o.id == t.tower_id and o.tier < t.tier:
		v.icon = "down"
	elif o.action == "combine" or (o.action == "keep" and o.id != t.tower_id):
		v.icon = "combine"
	if v.has("icon"):
		v.tooltip = o.label
		v.label = Database.tower_label(o.id, o.tier)
	# Vorschau beim Hover: neue Reichweite als Ring und was sich an den Werten ändert
	if o.action in ["upgrade", "keep", "combine"] and (o.id != t.tower_id or o.tier != t.tier):
		var trap := str(Database.towers.get(o.id, {}).get("kind", "tower")) == "trap"
		v.preview_range = Tower.ring_radius(Database.tower_tier(o.id, o.tier), trap)
		v.diff = TowerStats.diff(t, o.id, o.tier)
	return v


# --- GemTD-Auswahlphase: Schilder über den neuen Gems (Lukas 2026-11-03) ---------------------

## Für jeden neuen Gem der Runde die beste Option als kurzes Schild: Spezial-Tower (pink), Kombinieren (grün),
## Zutat eines angepinnten Rezepts (gold), sonst nur der Name (grau).
func gem_tags() -> Array:
	var out := []
	if round_towers.size() < 2:
		return out
	for i in round_towers.size():
		var t: Tower = round_towers[i]
		if not is_instance_valid(t):
			continue
		var tag := {"tower": t, "index": i, "text": t.label(), "style": "keep"}
		var best_same := 0
		for o in choice_options(t):
			if _is_special_option(t, o):
				tag.text = "★ " + Database.tower_label(o.id, o.tier)
				tag.style = "special"
				break
			if int(o.get("same", 0)) > best_same:
				best_same = int(o.same)
				tag.text = "▲ " + Database.tower_label(o.id, o.tier)
				tag.style = "combine"
		if tag.style == "keep":
			for sid in Session.pinned_recipes:
				var def: Dictionary = Database.towers.get(sid, {})
				if def.get("recipe", []).any(func(ing): return _ingredient_matches(ing, t)):
					tag.text = "◆ " + Database.tower_label(sid, 0)
					tag.style = "pinned"
					break
		out.append(tag)
	return out


## Tab: nächster neuer Gem der Runde auswählen.
func select_next_gem() -> void:
	var list := round_towers.filter(func(t): return is_instance_valid(t))
	if list.is_empty():
		return
	var i := list.find(selected)
	_select(list[(i + 1) % list.size()])


# --- Pause (Taste P, nur Einzelspiel) ------------------------------------------------------

## Pausiert (SceneTree.paused) laufen nur Oberfläche, Kamera und PauseInput: Tower lassen sich auswählen und
## ansehen, die Welt steht.
func _on_pause_toggled(on: bool) -> void:
	camera_rig.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
	hud.show_hover_card("", Vector2.ZERO)


## Klick während der Pause: nur auswählen (Tower, Stein), nichts bauen.
func paused_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and not event.pressed):
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		var c := board.mouse_cell(camera_rig.camera)
		var a: Vector2i = occupied.get(c, NO_CELL)
		var trap: Tower = traps.get(trap_cells.get(c, NO_CELL), null)
		if towers.has(a):
			_select(towers[a])
		elif trap != null:
			_select(trap)
		elif rocks.has(a):
			_select(null, a)
		else:
			_select(null)
	elif event.button_index == MOUSE_BUTTON_RIGHT and not camera_rig.right_dragged:
		_select(null)


# --- Warnung vor Luftwellen (Lukas 2026-11-03) ---------------------------------------------

const AIR_WARN_SHARE := 0.35  ## weniger als dieser Anteil des Flugwegs in Reichweite eines Luft-Towers: Warnung


## Anteil des Flugwegs (erste Bahn), den mindestens ein Tower erreicht, der Luft trifft (0..1).
func air_cover_share() -> float:
	if air_path.size() < 2:
		return 1.0
	_refresh_cover()
	var key := [_cover_sig, air_path.size()]
	if _air_share_key == key:
		return _air_share
	var total := 0.0
	for i in range(1, air_path.size()):
		total += air_path[i - 1].distance_to(air_path[i])
	var free := 0.0
	for st in _free_stretches(Array(air_path), true):
		free += float(st[1]) - float(st[0])
	_air_share_key = key
	_air_share = clampf(1.0 - free / maxf(total, 0.001), 0.0, 1.0)
	return _air_share


var _air_share := 1.0
var _air_share_key := []


## Warnung unter einer Zeile der Wellenliste (hud.set_waves): nur für die nächste, noch nicht laufende Welle.
func wave_warning(number: int, type: String) -> String:
	if phase >= Phase.GAME_OVER or is_wave_running() or number != wave_index + 1:
		return ""
	return air_warning(type)


## Text, wenn die Welle Flieger hat und man kaum vorbereitet ist ("" = keine Warnung).
func air_warning(type: String) -> String:
	if not type in ["Flieger", "Gemischt"]:
		return ""
	var air_towers := own_towers().filter(func(t): return is_instance_valid(t) and not t.is_new and t.can_attack() and t.target_mode() != "ground")
	if air_towers.is_empty():
		return tr("⚠ Kein Tower trifft Luft")
	var share := air_cover_share()
	if share < AIR_WARN_SHARE:
		return tr("⚠ Nur %d %% des Flugwegs abgedeckt") % roundi(share * 100.0)
	return ""
