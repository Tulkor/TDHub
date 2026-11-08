extends "res://scripts/game/game.gd"
## Randgruppen TD (Vorbild: Randgruppen TD2 UltraMods, Fan-Mod von vers.2b). Regeln in data/randgruppen.json,
## Tower und Gegner unter data/towers/rg_*.json und data/enemies/rg_*.json, Karte data/maps/randgruppen.json
## (alles erzeugt von tools/wc3/randgruppen/rg_daten.py, Designdokument docs/randgruppentd.md).
##
## Vor Level 1 wählt jeder eine Rasse (7 Tower) und der Host die Schwierigkeit (= Leben). Gebaut wird jederzeit:
## Tower der eigenen Rasse direkt aufs Feld der eigenen Zone, der Weg darf nicht zu sein. Der 7. Tower (Endtower)
## kostet 1 Holz und braucht die anderen 6. Zwischen den Leveln läuft eine Pause (Phase BUILD), danach das nächste
## Level (Phase WAVE), bis alle Gegner weg sind. Nach jedem Level gibt es 10 + 2 × Level Gold.
## Gegner kommen an allen Bahnen der Zonen mit Spieler, je Bahn so viele, wie das Level für ihre Art vorsieht
## (rules.lane_counts: oben "main", Mitte "two", unten "four", Boss "three").

const LANE_GAP := 0.45  ## Sekunden zwischen zwei Runden von Gegnern; eine Runde erscheint an allen Bahnen zugleich

var rules: Dictionary = {}
var difficulty := 2         ## Index in rules.difficulties
var _setup_cmd := {}        ## Setup-Befehl, der gerade ausgeführt wird (Aufstiegsstufe des Hosts)
var level_pause := 0.0      ## Sekunden bis zum nächsten Level (nur Phase BUILD)
var share_gold := false     ## Option „Geldteilen“ (Host): Kopfgeld jedes Kills gleich an alle
var placing := ""           ## Tower, der gerade gesetzt wird (Knopf in der Seitenleiste), "" = keiner
## Was jedem Spieler allein gehört, je Spielernummer (siehe rp()): Rasse, Holz, letzte Meldungen.
var rg_players: Array = []
var lumber: int:
	get:
		return rp().lumber
	set(v):
		rp().lumber = v
var rg_panel: RgPanel
var _outline_timer := 0.0
var _vandal_race := ""   ## Rasse, für die die Verschmierungen zuletzt gezeichnet wurden


func system_mode() -> String:
	return "randgruppen"


func _ready() -> void:
	# Stil „Plakatwand“ für die ganze Oberfläche, vor dem Bau des HUD in game.gd
	UiTheme.use_skin(UiTheme.POSTER)
	rules = Database.randgruppen
	var fresh: bool = Session.load_state.is_empty()
	difficulty = int(Session.rg_choice.get("difficulty", rules.get("difficulty_default", difficulty)))
	super._ready()
	if map == null:
		return
	if fresh:
		_apply_lives()
		for p in players:
			p.gold = start_gold()
		level_pause = float(rules.get("first_pause", 60))
	board.marker_labels = false
	board._rebuild_markers()
	RgScenery.add_to(self)
	_focus_own_zone()
	_style_hud()
	_refresh_hud()


func _exit_tree() -> void:
	super._exit_tree()
	UiTheme.use_skin(UiTheme.ARCADE)


func _style_hud() -> void:
	hud.title_label.text = "Randgruppen TD"
	hud.recipes_button.hide()
	hud.chance_value.get_parent().get_parent().hide()
	hud.pinned_panel.hide()
	rg_panel = RgPanel.new()
	rg_panel.game = self
	hud.left_col.add_child(rg_panel)
	hud.left_col.move_child(rg_panel, 0)
	_setup_debug()


## Kamera auf die eigene Zone statt auf die ganze (große) Karte.
func _focus_own_zone() -> void:
	for z in map.zones:
		if int(z.player) == local_player:
			var c: Vector2 = Vector2(z.rect.get_center()) * Board3D.CELL
			camera_rig.target = Vector3(c.x, 0, c.y + 4.0)
			camera_rig.distance = 38.0
			camera_rig._apply()
			return


func _setup_debug() -> void:
	hud.debug_gems_row.hide()
	hud.debug_extra.show()
	var row := hud.add_debug_row("Holz")
	for n in [1, 5]:
		hud.debug_button_in(row, "+%d" % n, func():
			lumber += n
			_refresh_hud())
	hud.debug_wave_label.text = tr("Level")
	hud.debug_wave_hint.text = tr("Läuft gerade ein Level, wird es abgebrochen und das gewählte startet sofort. In der Pause kommt es als nächstes.")
	hud.debug_pick_caption.hide()
	hud.debug_option.hide()


## Alle Panels des HUD im Look der eigenen Rasse verschmieren (Graffiti, Punk, Emo oder sauber).
func apply_vandal() -> void:
	_vandal_race = str(rp(local_player).race)
	var look: Dictionary = race(_vandal_race).get("look", {})
	var i := 0
	for n in hud.find_children("*", "PanelContainer", true, false):
		if n.has_meta("own_vandal") or _inside_panel(n):
			continue  # nur äußere Fenster, keine Kästchen darin
		i += 1
		RgVandal.apply(n, look, i)


func _inside_panel(n: Node) -> bool:
	var p := n.get_parent()
	while p != null and p != hud:
		if p is PanelContainer:
			return true
		p = p.get_parent()
	return false


func rp(p := -1) -> Dictionary:
	var i := maxi(0, acting if p < 0 else p)
	while rg_players.size() <= i:
		var races: Array = rules.get("races", [{}])
		rg_players.append({"race": str(Session.rg_choice.get("race", races[0].get("id", ""))), "lumber": 0, "log": [],
			"chosen": false, "ready": false})
	return rg_players[i]


## Die Karte gehört zum Modus (needs_map false): immer data/maps/randgruppen.json, auch wenn die Lobby keine schickt.
func _load_map() -> MapData:
	var m := super._load_map()
	if m == null or m.game != "randgruppen":
		m = MapData.load_file(str(Database.first_map("randgruppen").get("path", "res://data/maps/randgruppen.json")))
	return m


func start_gold() -> int:
	return int(rules.get("start_gold", 550)) - int(rules.get("builder_cost", 500))


func _apply_lives() -> void:
	lives = int(diff_rules().get("lives", 25))


func race(id: String) -> Dictionary:
	for r in rules.get("races", []):
		if str(r.id) == id:
			return r
	return {}


## Tower der Rasse von Spieler p in der Reihenfolge der Seitenleiste (der Endtower zuletzt).
func race_towers(p := -1) -> Array:
	return race(str(rp(p).race)).get("towers", [])


# --- Einstellungen und Level --------------------------------------------------------------

func _make_setup_panel() -> Control:
	var setup := RgSetupPanel.new()
	setup.game = self
	# Das Startfenster ist breit und deckt sonst die linke Spalte halb zu; sie zeigt dasselbe (Rasse, Wellen)
	var sync_left := func():
		if is_instance_valid(hud) and is_instance_valid(hud.left_col):
			hud.left_col.visible = not (setup.is_inside_tree() and setup.visible)
	setup.visibility_changed.connect(sync_left)
	setup.tree_entered.connect(sync_left)
	setup.tree_exited.connect(sync_left)
	return setup


func _apply_variance() -> void:
	pass


## Ein Level je Eintrag in rules.levels: je Art der Bahn (main, two, three, four) eine Gruppe mit der Anzahl je Bahn.
func _make_waves() -> Array:
	var list := []
	for lv in Database.randgruppen.get("levels", []):
		var groups := []
		var counts: Dictionary = lv.get("counts", {})
		var boss := int(lv.get("level", 0)) == int(Database.randgruppen.get("boss_level", 35))
		for kind in ["main", "two", "four", "three"]:
			var n := int(counts.get(kind, 0))
			if n > 0:
				groups.append({"enemy": str(lv.enemy), "count": n, "kind": kind, "interval": LANE_GAP})
		var def: Dictionary = Database.enemies.get(str(lv.enemy), {})
		var type := "Boss" if boss else ("Flieger" if def.get("flying", false) else "Boden")
		list.append({"type": type, "groups": groups})
	return list


## Vor den Einstellungen nimmt game.gd nur Befehle des Hosts an; hier wählt aber jeder seine Rasse selbst.
func execute(cmd: Dictionary) -> bool:
	var p := int(cmd.get("player", -1))
	if setup_done or str(cmd.get("type", "")) != "setup" or p < 0 or p >= players.size():
		return super.execute(cmd)
	acting = p
	var ok := _execute(cmd)
	acting = local_player
	return ok


func _execute(cmd: Dictionary) -> bool:
	match str(cmd.get("type", "")):
		"setup":
			if setup_done:
				return false
			take_foreign_build(cmd)
			if acting == 0 and cmd.has("share"):
				share_gold = bool(cmd.share)
			_setup_cmd = cmd
			return _apply_setup(str(cmd.get("race", "")), int(cmd.get("difficulty", difficulty)))
		"build":
			return build_tower(str(cmd.get("id", "")), cmd.get("cell", NO_CELL))
		"start_level":
			if phase != Phase.BUILD or not setup_done:
				return false
			# Im Koop startet das Level früher erst, wenn alle bereit sind (sonst nach Ablauf der Pause)
			rp().ready = true
			if _all_players(func(i): return rp(i).ready):
				level_pause = 0.0
			_refresh_hud()
			return true
		"option":
			var t := tower_from_ref(cmd.get("tower", {}))
			var opts := tower_options(t)
			var i := int(cmd.get("index", -1))
			if i < 0 or i >= opts.size():
				return false
			var o: Dictionary = opts[i]
			if o.action != cmd.get("action") or o.id != cmd.get("id"):
				return false
			return _apply_option(t, o)
		"place", "replace_rocks", "remove_rocks", "take_back", "move_trap", "rogue_pick":
			return false
	return super._execute(cmd)


## Jeder wählt seine Rasse, nur der Host (Spieler 0) die Schwierigkeit. Los geht es, wenn alle gewählt haben.
func _apply_setup(race_id: String, diff: int) -> bool:
	if race(race_id).is_empty() or rp().chosen:
		return false
	rp().race = race_id
	rp().chosen = true
	if acting == 0:
		difficulty = clampi(diff, 0, (rules.get("difficulties", []) as Array).size() - 1)
		take_ascension(_setup_cmd)
		_apply_lives()
	if acting == local_player:
		Session.rg_choice = {"race": race_id, "difficulty": difficulty, "share": share_gold}
	_check_setup()
	_refresh_hud()
	return true


## Alle Anwesenden haben ihre Rasse: Einstellungen fertig, die erste Pause läuft. Wer weg ist, hält nicht auf.
func _check_setup() -> void:
	if setup_done or not rp(0).chosen or not _all_players(func(i): return rp(i).chosen):
		return
	level_pause = float(rules.get("first_pause", 60))
	setup_done = true


## Gilt f für alle anwesenden Spieler?
func _all_players(f: Callable) -> bool:
	for i in players.size():
		if not players[i].away and not f.call(i):
			return false
	return true


func set_player_away(p: int, away: bool) -> void:
	super.set_player_away(p, away)
	if not mirror:
		_check_setup()


# --- Ablauf: Pause, Level, Pause … ------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	# bunte Schrift mit Kontur, Verschmierungen passend zur eigenen Rasse (beides nur Anzeige)
	_outline_timer -= delta / maxf(Engine.time_scale, 0.01)
	if _outline_timer <= 0.0 and hud != null:
		_outline_timer = 0.4
		PosterTheme.outline_colored(hud)
		if str(rp(local_player).race) != _vandal_race:
			apply_vandal()
	if phase == Phase.BUILD and setup_done and not mirror:
		level_pause -= delta
		if level_pause <= 0.0:
			_start_wave()
		elif ceili(level_pause) != ceili(level_pause + delta):
			_refresh_hud()


## Level geschafft: Gold für alle (10 + 2 × Level, die Mittelzone mehr), Holz vor Level 25, dann die Pause.
func _enter_build() -> void:
	phase = Phase.BUILD
	for p in players:
		p.stage = Phase.BUILD
	var done := wave_index  # gerade beendetes Level (1-basiert), 0 vor dem ersten
	for i in players.size():
		rp(i).ready = false
	if done > 0:
		var lg: Dictionary = rules.get("level_gold", {})
		var amount := int(lg.get("base", 10)) + int(lg.get("per_level", 2)) * done
		for p in players.size():
			var extra := roundi(amount * float(rules.get("center_bonus", 0.0))) if _zone_name(p) == "Hellblau" else 0
			players[p].gold += amount + extra
			_note(tr("Level %d geschafft: +%d Gold") % [done, amount + extra], p)
			var wood := int(rules.get("lumber", {}).get(str(done + 1), 0))
			if wood > 0:
				rp(p).lumber += wood
				_note(tr("+%d Holz für den Endtower!") % wood, p)
	level_pause = float(rules.get("pause", 30)) if done > 0 else float(rules.get("first_pause", 60))
	_refresh_hud()


func _zone_name(p: int) -> String:
	var names: Array = rules.get("zones", [])
	return str(names[p]) if p < names.size() else ""


## Gegner einer Runde erscheinen gleichzeitig an allen Bahnen ihrer Art, die Runden im Abstand LANE_GAP.
func _start_wave() -> void:
	super._start_wave()
	if phase != Phase.WAVE:
		return
	var groups: Array = waves[wave_index].get("groups", [])
	var rounds := 0
	for g in groups:
		rounds = maxi(rounds, int(g.count))
	spawn_queue.clear()
	for r in rounds:
		var batch := groups.filter(func(g): return int(g.count) > r)
		for i in batch.size():
			var e: Dictionary = batch[i].duplicate()
			e["interval"] = LANE_GAP if i == batch.size() - 1 else 0.0
			spawn_queue.append(e)


func _spawn_enemy(g: Dictionary, lane := -1) -> void:
	if lane >= 0:
		super._spawn_enemy(g, lane)
		return
	for l in lanes_for(str(g.get("kind", "main"))):
		super._spawn_enemy(g, l)


## Aktive Bahnen, an denen Gegner der Art kind erscheinen. Der Boss (three) kommt im Original an zwei Bahnen der
## Mitte; ist dort keiner, kommt er an der ersten Bahn jedes Spielers.
func lanes_for(kind: String) -> Array:
	var kinds: Array = rules.get("lane_counts", [])
	var out := active_lanes().filter(func(i): return i < kinds.size() and str(kinds[i]).split("+").has(kind))
	if out.is_empty() and kind == "three":
		var seen := {}
		for i in active_lanes():
			var p := map.lane_player(i)
			if not seen.has(p):
				seen[p] = true
				out.append(i)
	return out


func _apply_enemy_difficulty(_e: Enemy, _g: Dictionary) -> void:
	pass


func is_final_boss_wave() -> bool:
	return false


## Geldteilen: das Kopfgeld geht an alle zu gleichen Teilen (earn_gold ohne Spieler teilt mit Bruchteilen).
func on_enemy_killed(e: Enemy) -> void:
	if share_gold:
		e.last_hit_by = -1
	super.on_enemy_killed(e)


func _note(text: String, p := -1) -> void:
	var lines: Array = rp(p).log
	lines.append(text)
	if lines.size() > 4:
		lines.pop_front()


func _finish(p: Phase) -> void:
	phase = p
	drop_autosave()
	record_profile(p == Phase.VICTORY)
	Engine.time_scale = 1.0
	hud.show_game_over(p == Phase.VICTORY, mini(wave_index + 1, waves.size()), waves.size(), lives, enemies_killed, path_length,
		null, run_summary())
	_refresh_hud()


func profile_mode() -> String:
	return "randgruppen"


func profile_extra() -> Dictionary:
	return {"race": str(rp().race), "difficulty": difficulty}


# --- Bauen und Verkaufen -----------------------------------------------------------------

## Warum Tower id gerade nicht gebaut werden kann ("" = geht).
func build_reason(id: String) -> String:
	var r: Dictionary = Database.towers.get(id, {}).get("rg", {})
	if r.is_empty() or not race_towers().has(id):
		return tr("gehört nicht zur Rasse")
	if gold < int(r.get("cost", 0)):
		return tr("zu wenig Gold")
	if lumber < int(r.get("lumber", 0)):
		return tr("zu wenig Holz")
	var have := own_towers().map(func(t): return t.tower_id)
	for need in r.get("requires", []):
		if not have.has(need):
			return tr("braucht alle 6 anderen Tower")
	return ""


func can_build_tower(id: String, a: Vector2i) -> bool:
	return setup_done and phase < Phase.GAME_OVER and a != NO_CELL and build_reason(id) == "" and can_place(a)


func build_tower(id: String, a: Vector2i) -> bool:
	if not can_build_tower(id, a):
		return false
	var r: Dictionary = Database.towers[id].rg
	gold -= int(r.cost)
	lumber -= int(r.get("lumber", 0))
	var t := Tower.new()
	t.owner_player = acting
	board.add_child(t)
	t.setup(self, a, id, 0)
	t.set_meta("spent", int(r.cost))
	_register(t)
	run_stats.built(t, "build", wave_index + 1)
	_update_paths()
	_update_auras()
	if acting == local_player:
		board.hover_ok = can_build_tower(placing, a) if placing != "" else false
		board.refresh_hover()
		if placing != "" and build_reason(placing) != "":
			placing = ""
			board.hover_cell = NO_CELL
	_refresh_hud()
	return true


## Tower zum Setzen auswählen (Knopf oder Taste 1–7), nochmal drücken bricht ab.
func start_placement(id: String) -> void:
	_select(null)
	placing = "" if placing == id or build_reason(id) != "" else id
	board.hover_cell = NO_CELL
	_refresh_hud()


func sell_value(t: Tower) -> int:
	return floori(int(t.get_meta("spent", 0)) * float(rules.get("sell_factor", 0.75)))


func tower_options(t: Tower) -> Array:
	if t == null or not is_instance_valid(t) or phase >= Phase.GAME_OVER or t.owner_player != acting:
		return []
	return [{"label": tr("Verkaufen"), "action": "rg_sell", "id": t.tower_id, "tier": 0, "consume": [], "cost": 0,
			"refund": sell_value(t), "reason": ""}]


func _apply_option(t: Tower, o: Dictionary) -> bool:
	if t == null or o.action != "rg_sell":
		return false
	gold += sell_value(t)
	run_stats.flush(t)
	_unregister(t)
	if t == selected:
		_select(null)
	t.queue_free()
	_update_paths()
	_update_auras()
	_refresh_hud()
	return true


func _select_rocks(list: Array, t: Tower = null) -> void:
	placing = ""
	super._select_rocks(list, t)


# --- Eingabe -------------------------------------------------------------------------------


func _update_hover() -> void:
	_update_tower_hover(get_process_delta_time())
	var c := NO_CELL
	if placing != "" and setup_done and phase < Phase.GAME_OVER:
		c = board.mouse_anchor(camera_rig.camera, Board3D.TOWER_CELLS)
	var r := Tower.ring_radius(Database.tower_tier(placing, 0), false) if placing != "" else 0.0
	if c != board.hover_cell or board.hover_size != Board3D.TOWER_CELLS or r != board.hover_range:
		board.hover_cell = c
		board.hover_size = Board3D.TOWER_CELLS
		board.hover_range = r
		board.hover_ok = can_build_tower(placing, c)
		board.refresh_hover()


func _on_click(c: Vector2i, anchor: Vector2i, _add := false) -> void:
	if placing != "":
		if can_build_tower(placing, anchor):
			submit({"type": "build", "id": placing, "cell": anchor})
		elif anchor != NO_CELL and Board3D.footprint(anchor).any(func(f): return not may_build_for(f, local_player)):
			board.flash_zones()
		return
	var a: Vector2i = occupied.get(c, NO_CELL)
	if towers.has(a):
		_select(towers[a])
	else:
		_select(null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N and phase == Phase.BUILD:
			submit({"type": "start_level"})
			return
		if event.keycode == KEY_ESCAPE and placing != "":
			placing = ""
			board.hover_cell = NO_CELL
			_refresh_hud()
			return
		var k := int(event.keycode) - KEY_1
		var list := race_towers(local_player)
		if setup_done and k >= 0 and k < list.size():
			start_placement(str(list[k]))
			return
		if event.keycode == KEY_Z:
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and placing != "":
		placing = ""
		board.hover_cell = NO_CELL
		_refresh_hud()
	super._unhandled_input(event)


func _box_select(_r: Rect2, _add := false) -> void:
	pass


func _on_option_chosen(index: int) -> void:
	var opts := tower_options(selected)
	if index < 0 or index >= opts.size():
		return
	var o: Dictionary = opts[index]
	submit({"type": "option", "tower": tower_ref(selected), "index": index, "action": o.action, "id": o.id, "tier": o.tier})


# --- Anzeige -------------------------------------------------------------------------------

func _refresh_hud_local() -> void:
	hud.set_resources(mini(wave_index + 1, waves.size()), waves.size(), lives, gold, false)
	hud.set_path_length(path_length, 0)
	hud.set_waves(_upcoming_waves(4))
	hud.set_round_gems([], "")
	if placing != "" and phase < Phase.GAME_OVER:
		hud.set_phase(Database.tower_label(placing, 0), tr("Feld in deiner Zone anklicken · Esc oder Rechtsklick = fertig"))
	else:
		match phase:
			Phase.BUILD:
				var title := tr("Pause") if wave_index > 0 else tr("Aufbau")
				hud.set_phase(title, tr("Level %d in %d s · N = sofort starten · 1–7 = Tower bauen") % [wave_index + 1, ceili(maxf(level_pause, 0.0))])
			Phase.WAVE:
				hud.set_phase(tr("Level %d") % (wave_index + 1), tr("noch %d Gegner") % (enemies.size() + spawn_queue.size()))
			Phase.GAME_OVER:
				hud.set_phase(tr("Verloren"), "")
			Phase.VICTORY:
				hud.set_phase(tr("Gewonnen"), tr("Die Hochburg der Toleranz steht!"))
	_refresh_selection()
	if rg_panel != null:
		rg_panel.refresh()


func _refresh_selection() -> void:
	if selected == null or not is_instance_valid(selected):
		hud.set_selection({})
		hud.set_options([])
		return
	var view := TowerStats.view(selected)
	var r: Dictionary = selected.def.get("rg", {})
	view.subtitle = tr("%s · %s") % [tr(str(race(str(rp(selected.owner_player).race)).get("name", ""))),
			tr("Endtower") if r.get("ultimate", false) else tr("Tower %d von 7") % (int(r.get("place", 0)) + 1)]
	view.subtitle += " · " + TowerStats.targets_text(selected.target_mode())
	var body := tr("Ausgegeben: %d Gold") % int(selected.get_meta("spent", 0))
	hud.set_selection({"title": selected.label(), "color": selected.color, "body": body, "used_in": null, "stats": view})
	hud.set_options(tower_options(selected).map(func(o): return {"label": o.label, "sub": tr("+%d Gold") % int(o.refund),
			"style": "normal", "tooltip": tr("Tower abreißen, 75 % des Preises zurück")}))
	hud.set_options_enabled(true)


func _upcoming_waves(count: int) -> Array:
	var list := []
	if phase >= Phase.GAME_OVER:
		return list
	for i in range(wave_index, mini(wave_index + count, waves.size())):
		var w: Dictionary = waves[i]
		var groups: Array = w.get("groups", [])
		var d: Dictionary = Database.enemies.get(str(groups[0].enemy), {}) if not groups.is_empty() else {}
		var total := 0
		for g in groups:
			total += int(g.count) * lanes_for(str(g.kind)).size()
		var detail := tr("%d× %s · %d LP · Rüstung %d") % [total, tr(str(d.get("name", "?"))), int(d.get("hp", 0)), int(d.get("armor", 0))]
		var state := ""
		if i == wave_index:
			state = tr("läuft") if phase == Phase.WAVE else tr("in %d s") % ceili(maxf(level_pause, 0.0))
		list.append({"number": i + 1, "type": str(w.type), "detail": detail, "state": state})
	return list


# --- Spielstand (save_game.gd) ---------------------------------------------------------------

func save_extra() -> Dictionary:
	return {"difficulty": difficulty, "pause": level_pause, "players": rg_players.duplicate(true), "share": share_gold,
		"spent": all_towers().map(func(t): return int(t.get_meta("spent", 0)))}


func load_extra(d: Dictionary, made: Array) -> void:
	if d.is_empty():
		return
	difficulty = int(d.get("difficulty", difficulty))
	level_pause = float(d.get("pause", level_pause))
	share_gold = bool(d.get("share", false))
	rg_players = []
	for ps in d.get("players", []):
		rg_players.append({"race": str(ps.get("race", "")), "lumber": int(ps.get("lumber", 0)), "log": ps.get("log", []),
			"chosen": bool(ps.get("chosen", true)), "ready": false})
	var spent: Array = d.get("spent", [])
	for i in mini(spent.size(), made.size()):
		if made[i] != null:
			made[i].set_meta("spent", int(spent[i]))


# --- Koop (coop_sync.gd): alle auf der einen Karte, jeder in seiner Zone, der Host rechnet ----------------------

## Befehle, die Mitspieler zusätzlich zu denen von GemTD schicken dürfen.
func coop_commands() -> Array:
	return ["setup", "build", "start_level"]


## Was Randgruppen TD über den Stand von GemTD hinaus schickt. Die Pause in ganzen Sekunden, damit sich der Stand
## nicht jedes Bild ändert.
func coop_snapshot() -> Dictionary:
	var spent := {}
	for t in all_towers():
		spent["%d,%d" % [t.cell.x, t.cell.y]] = int(t.get_meta("spent", 0))
	return {"difficulty": difficulty, "pause": ceili(maxf(level_pause, 0.0)), "players": rg_players.duplicate(true),
		"spent": spent, "share": share_gold}


func apply_coop_snapshot(d: Dictionary) -> void:
	difficulty = int(d.get("difficulty", difficulty))
	share_gold = bool(d.get("share", share_gold))
	level_pause = float(d.get("pause", level_pause))
	var ps: Array = d.get("players", [])
	if not ps.is_empty():
		rg_players = ps
	var spent: Dictionary = d.get("spent", {})
	for t in all_towers():
		t.set_meta("spent", int(spent.get("%d,%d" % [t.cell.x, t.cell.y], 0)))
	if rg_panel != null:
		rg_panel.refresh()
