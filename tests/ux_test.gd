extends Node
## Lauf: einzeln (Name ux)
## Modi: kern
## Komfort im Spiel (Lukas 2026-11-03): letzte Wahl merken, Autosave und „Weiterspielen“, Pause mit P,
## Schilder über den neuen Gems, Warnung vor Luftwellen, Hover-Reichweite, Reiter rechts, Liste nach Sorte,
## Reichweitenring beim Setzen, Auto-Start der nächsten Welle.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _new_game(scene := Session.GAME, map := "") -> Node:
	Session.map_path = map if map != "" else Database.first_map().path
	Session.map_override = null
	Session.load_state = {}
	Session.save_id = ""
	var g: Node = load(scene).instantiate()
	add_child(g)
	return g


func _free_cell(g: Node, from := Vector2i(4, 4)) -> Vector2i:
	for y in range(from.y, g.map.height - 4, 2):
		for x in range(4, g.map.width - 4, 2):
			if g.can_place(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Session.game_kind = "gemtd"
	Session.return_scene = Session.MAIN_MENU

	# --- Letzte Wahl über Neustarts -------------------------------------------------------
	var keep := {"kind": Session.game_kind, "diff": Session.difficulty, "speed": Session.speed}
	Session.game_kind = "randgruppen"
	Session.difficulty = 2
	Session.speed = 4.0
	Session.auto_wave = {"randgruppen": true}
	Session.save_last()
	Session.game_kind = "gemtd"
	Session.difficulty = 0
	Session.speed = 1.0
	Session.auto_wave = {}
	Session._last_loaded = false
	Session.load_last()
	check(Session.game_kind == "randgruppen" and Session.difficulty == 2 and Session.speed == 4.0, "Letzte Wahl geladen: Modus, Schwierigkeit, Tempo")
	check(Session.auto_wave_on(), "Auto-Schalter je Modus gemerkt")
	Session.game_kind = keep.kind
	Session.difficulty = keep.diff
	Session.speed = 4.0
	Session.auto_wave = {}

	# --- GemTD: gemerktes Tempo, Pause, Schilder, Tab ----------------------------------------
	Session.skip_setup = true
	var g: Node = _new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(Engine.time_scale, 4.0), "Einzelspiel startet mit dem gemerkten Tempo")
	g.submit({"type": "speed", "factor": 2.0})
	check(Session.speed == 2.0, "Tempo-Wahl wird gemerkt")
	check(g.hud.pause_button.visible, "Pausenknopf im Einzelspiel sichtbar")
	check(g.hud.pause_button.get_meta("key_badge", null) != null, "Pausenknopf zeigt seine Taste")
	g.hud.set_user_paused(true)
	check(get_tree().paused and g.hud.pause_banner.visible, "P pausiert und zeigt das Schild")
	check(g.camera_rig.process_mode == Node.PROCESS_MODE_ALWAYS, "Kamera läuft in der Pause weiter")
	g.hud.open_leave_confirm()
	g.hud.close_leave_confirm()
	check(get_tree().paused, "Menü schließen hebt die P-Pause nicht auf")
	g.hud.set_user_paused(false)
	check(not get_tree().paused and not g.hud.pause_banner.visible, "P nochmal: weiter")

	# Zwei gleiche Gems → Schild „Kombinieren“, Rest grau
	var keys := ["ruby:0", "ruby:0", "sapphire:0", "topaz:0", "emerald:0"]
	var from := Vector2i(4, 4)
	for k in keys:
		g.debug_tower = k
		var c: Vector2i = _free_cell(g, from)
		g.submit({"type": "place", "cell": c})
		from = Vector2i(4, c.y + 4)
	g.debug_tower = ""
	check(g.stage() == g.Phase.CHOOSE, "Nach fünf Gems Wahlphase")
	var tags: Array = g.gem_tags()
	check(tags.size() == 5, "Ein Schild je neuem Gem")
	check(tags.filter(func(t): return t.style == "combine").size() == 2, "Beide gleichen Gems zeigen Kombinieren")
	check(tags.filter(func(t): return t.style == "keep").size() >= 2, "Übrige Gems grau")
	g._refresh_hud()
	await get_tree().process_frame
	check(g.hud._gem_tags.size() == 5, "Schilder im HUD")
	g.select_next_gem()
	var first = g.selected
	g.select_next_gem()
	check(first != null and g.selected != null and g.selected != first and g.round_towers.has(g.selected), "Tab wählt reihum die neuen Gems")

	# Behalten: Schilder weg
	g._select(g.round_towers[0])
	g._on_option_chosen(0)
	g._refresh_hud()
	await get_tree().process_frame
	check(g.hud._gem_tags.is_empty(), "Nach dem Behalten keine Schilder mehr")

	# Hover: Ring und Karte nach kurzer Zeit (direkt über die Hilfsfunktion, die Maus gibt es headless nicht)
	g._select(null)
	var t: Tower = g.all_towers().filter(func(x): return not x.is_new and x.can_attack())[0]
	t.set_hovered(true)
	check(t._range_ring.visible, "Hover zeigt den Reichweitenring")
	t.set_hovered(false)
	check(not t._range_ring.visible, "Ohne Hover und Auswahl kein Ring")
	t.set_selected(true)
	t.set_hovered(false)
	check(t._range_ring.visible, "Ausgewählter Tower behält seinen Ring nach dem Hover")
	t.set_selected(false)
	check(g.hover_text(t).contains(t.label()), "Kurzinfo nennt den Tower")

	# Luftwelle: Warnung, solange kein Tower Luft trifft
	g.wave_index = 3
	g.phase = g.Phase.BUILD
	var air_wave := -1
	for i in g.waves.size():
		if g.wave_type(g.waves[i]) == "Flieger":
			air_wave = i
			break
	g.wave_index = air_wave
	var only_ground: bool = g.own_towers().all(func(x): return x.target_mode() == "ground")
	var warn: String = g.wave_warning(air_wave + 1, "Flieger")
	check(not only_ground or warn != "", "Warnung vor Luftwelle ohne Luft-Tower")
	check(g.wave_warning(air_wave + 2, "Flieger") == "", "Nur die nächste Welle wird gewarnt")
	check(g.wave_warning(air_wave + 1, "Boden") == "", "Bodenwelle ohne Warnung")

	# Reiter rechts
	var tabs: SideTabs = g.hud.side_tabs
	tabs.select("tower", false)
	g.hud.dps_meter._process(0.0)
	g.hud.tower_list.refresh()
	g.hud.enemy_panel.refresh()
	check(not g.hud.dps_meter.visible and not g.hud.enemy_panel.visible, "Reiter Tower: DPS und Gegner aus")
	tabs.select("alle", false)
	g.hud.dps_meter._process(0.0)
	check(g.hud.dps_meter.visible, "Reiter Alle: DPS wieder da")
	g.hud.set_panels_hidden(true)
	check(g.hud.left_col.offset_left < -1000 and g.hud.tower_list.offset_right > 1000, "H schiebt beide Seitenleisten weg")
	g.hud.set_panels_hidden(false)

	# Liste nach Sorte: zwei gleiche Tower in einer Zeile
	var tl: TowerList = g.hud.tower_list
	tl.sort = "group"
	g.debug_tower = "ruby:0"
	var r1: Tower = g.place_gem(_free_cell(g, Vector2i(4, 30)))
	r1.is_new = false
	g.debug_tower = "ruby:0"
	var r2: Tower = g.place_gem(_free_cell(g, Vector2i(4, 40)))
	r2.is_new = false
	g.debug_tower = ""
	var reps: Array = tl.towers()
	var rubies: Array = tl._groups.get(r1.label(), [])
	check(rubies.size() >= 2 and reps.filter(func(x): return x.label() == r1.label()).size() == 1, "Gleiche Tower in einer Zeile mit Anzahl")
	g._select(rubies[0])
	check(tl.next_in_group(rubies[0]) == rubies[1], "Klick auf die Zeile wählt reihum den nächsten")

	# Autosave nach einer Welle, Weiterspielen findet ihn, Ende löscht ihn
	check(not g.autosave(), "Kein Autosave in Tests mit skip_setup")
	g.setup_done = true
	Session.skip_setup = false
	var ok: bool = g.autosave()
	check(ok and Session.save_id != "", "Autosave schreibt den Spielstand dieser Partie")
	var cont: Dictionary = load("res://scripts/ui/main_menu.gd").continue_save()
	check(str(cont.get("id", "")) == Session.save_id, "Weiterspielen findet den jüngsten Einzelspiel-Stand")
	var id := Session.save_id
	g.drop_autosave()
	check(not FileAccess.file_exists(SaveGame.path_for(id)) and Session.save_id == "", "Partie vorbei: Spielstand gelöscht")
	Session.skip_setup = true
	g.queue_free()
	await get_tree().process_frame

	# --- Randgruppen: Reichweitenring beim Setzen, Auto-Start ---------------------------------
	Session.game_kind = "randgruppen"
	Session.auto_wave = {"randgruppen": true}
	var rg: Node = _new_game(Session.game_scene(), "res://data/maps/randgruppen.json")
	await get_tree().process_frame
	check(rg.has_auto_wave() and rg.auto_wave and rg.hud.auto_button != null and rg.hud.auto_button.button_pressed, "Randgruppen: Schalter Auto da und an")
	var ids: Array = rg.race_towers(rg.local_player)
	rg.start_placement(str(ids[0]))
	rg._update_hover()
	check(rg.board.hover_range > 0.0, "Randgruppen: Reichweite beim Setzen")
	rg.board.hover_cell = Vector2i(10, 10)
	rg.board.refresh_hover()
	check(rg.board._hover_ring != null and rg.board._hover_ring.visible, "Ring um die Bauvorschau")
	rg.queue_free()
	await get_tree().process_frame

	# --- YouTD: Reichweitenring beim Setzen ---------------------------------------------------
	Session.game_kind = "youtd"
	Session.auto_wave = {}
	var yt: Node = _new_game(Session.game_scene(), "res://data/maps/youtd.json")
	await get_tree().process_frame
	await get_tree().process_frame
	var any_id := ""
	for id2 in YoutdData.towers().keys():
		if float(YoutdData.tower(str(id2)).get("range", 0)) > 0.0:
			any_id = str(id2)
			break
	if any_id != "":
		yt.build_id = any_id
		yt._update_hover()
		check(yt.board.hover_range > 0.0, "YouTD: Reichweite beim Setzen")
	else:
		check(false, "YouTD: kein Tower zum Testen gefunden")
	check(yt.has_auto_wave(), "YouTD hat den Schalter Auto")
	yt.queue_free()
	await get_tree().process_frame

	Session.game_kind = "gemtd"
	Session.speed = 1.0
	Engine.time_scale = 1.0
	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
