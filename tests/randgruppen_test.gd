extends Node
## Lauf: einzeln
## Modi: randgruppen
## Randgruppen TD: Daten, Karte, ein kurzes Spiel (Rasse, bauen, Weg offen, Endtower gesperrt, Level 1, verkaufen)
## und Koop ohne Netz (Rasse je Spieler, Zonen, Bereitschaft, gespiegelte Gegner).
## Start: godot --headless --path . res://tests/randgruppen_test.tscn (oder tools/run_tests.sh randgruppen)

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile"
	await get_tree().process_frame
	var rules: Dictionary = Database.randgruppen
	check(not rules.is_empty(), "data/randgruppen.json geladen")
	var races: Array = rules.get("races", [])
	check(races.size() == 13, "13 Rassen (11 aus der Karte + Punks und Emos): %d" % races.size())
	var broken := []
	for r in races:
		var list: Array = r.towers
		if list.size() != 7:
			broken.append("%s hat %d Tower" % [r.id, list.size()])
		for id in list:
			if not Database.towers.has(id):
				broken.append(id)
		var ult: Dictionary = Database.towers.get(list[-1], {}).get("rg", {})
		if not ult.get("ultimate", false) or int(ult.get("lumber", 0)) != 1 or (ult.get("requires", []) as Array).size() != 6:
			broken.append("Endtower von %s" % r.id)
	check(broken.is_empty(), "jede Rasse hat 7 vorhandene Tower, der letzte ist der Endtower (1 Holz, braucht 6) %s" % [broken])
	var looks := {}
	for r in races:
		looks[r.id] = str(r.get("look", {}).get("style", ""))
	check(looks.get("punks") == "punk" and looks.get("emos") == "emo" and looks.get("hiphop") == "graffiti" and looks.get("ritter") == "clean",
		"Look je Rasse: %s" % [looks])
	# bunte Schrift bekommt eine schwarze Kontur, schwarze nicht
	var box := VBoxContainer.new()
	add_child(box)
	var red := UiUtil.label("rot", box, 12)
	red.add_theme_color_override("font_color", Color("e8372a"))
	var ink := UiUtil.label("schwarz", box, 12)
	ink.add_theme_color_override("font_color", Color("151515"))
	PosterTheme.outline_colored(box)
	check(red.get_theme_constant("outline_size") == 3 and ink.get_theme_constant("outline_size") == 0, "Kontur nur um bunte Schrift")
	box.queue_free()
	var levels: Array = rules.get("levels", [])
	check(levels.size() == 35, "35 Level")
	check(levels.all(func(lv): return Database.enemies.has(str(lv.enemy))), "alle Gegner der Level vorhanden")
	check(Database.enemies[str(levels[4].enemy)].flying and Database.enemies[str(levels[34].enemy)].boss, "Level 5 fliegt, Level 35 ist der Boss")
	check(is_equal_approx(Database.damage_factor("pierce", "rg_small"), 2.0) and is_equal_approx(Database.damage_factor("magic", "rg_large"), 2.0),
		"WC3-Schadenstabelle: Durchbohrend gegen Leicht ×2, Magie gegen Schwer ×2")
	var map := MapData.load_file("res://data/maps/randgruppen.json")
	check(map != null and map.width == 168 and map.zones.size() == 9 and map.lane_count() == 12, "Karte 168 × 168, 9 Zonen, 12 Bahnen")
	var pf := Pathfinder.new(map)
	var bad := range(map.lane_count()).filter(func(i): return pf.compute_path(i).is_empty())
	check(bad.is_empty(), "alle 12 Bahnen haben einen Weg zur Hochburg %s" % [bad])

	# Kurzes Spiel: Kleingartenverein auf Normal
	Session.game_kind = "randgruppen"
	Session.map_path = "res://data/maps/randgruppen.json"
	Session.map_override = null
	Session.skip_setup = false
	Session.rg_choice = {}
	var game: Node = load("res://scenes/rg_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(not game.setup_done and game.gold == 50, "Startfenster offen, 50 Gold (550 − 500 Baumeister)")
	check(game.submit({"type": "setup", "race": "kleingarten", "difficulty": 0}), "Rasse und Schwierigkeit wählen")
	check(game.setup_done and game.lives == 50 and str(game.rp().race) == "kleingarten", "Gemütlich: 50 Leben, Rasse Kleingartenverein")
	check(game.active_lanes().size() == 2 and game.lanes_for("main").size() == 2 and game.lanes_for("two").is_empty(),
		"allein: nur die zwei roten Bahnen")
	var first: String = game.race_towers()[0]
	var zone: Rect2i = map.zones[0].rect
	var built := 0
	for y in range(zone.position.y + 4, zone.end.y - 4, 2):
		for x in range(zone.position.x + 2, zone.end.x - 2, 2):
			if game.gold >= 12 and game.submit({"type": "build", "id": first, "cell": Vector2i(x, y)}):
				built += 1
		if built >= 4:
			break
	check(built == 4 and game.gold == 50 - 4 * 12, "4 Gartenzwerge für je 12 Gold (gebaut %d, Gold %d)" % [built, game.gold])
	check(not game.submit({"type": "build", "id": first, "cell": Vector2i(140, 20)}), "nicht in einer fremden Zone")
	check(not game.submit({"type": "build", "id": "rg_wuehltisch_kunde", "cell": Vector2i(zone.position.x + 20, zone.position.y + 30)}),
		"keine Tower einer anderen Rasse")
	game.gold = 5000
	check(game.build_reason("rg_der_obmann").begins_with("zu wenig Holz"), "Endtower ohne Holz gesperrt: %s" % game.build_reason("rg_der_obmann"))
	game.lumber = 1
	check(game.build_reason("rg_der_obmann") != "", "Endtower braucht die anderen 6 Tower")
	var t: Tower = game.own_towers()[0]
	var gold_before: int = game.gold
	check(game.submit({"type": "option", "tower": game.tower_ref(t), "index": 0, "action": "rg_sell", "id": t.tower_id, "tier": 0})
		and game.gold == gold_before + 9, "verkaufen gibt 75 % zurück (12 → 9)")
	game.gold = 50

	check(game.submit({"type": "start_level"}), "Level 1 sofort starten")
	for i in 3:
		await get_tree().process_frame
	check(game.phase == game.Phase.WAVE, "Level 1 läuft")
	check(game.spawn_queue.size() + game.enemies.size() >= 23, "Level 1: 2 × 12 Gegner an den roten Bahnen")
	Engine.time_scale = 8.0
	var frames := 0
	while game.phase == game.Phase.WAVE and frames < 30000:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0
	check(game.phase == game.Phase.BUILD and game.wave_index == 1, "Level 1 vorbei, Pause vor Level 2")
	check(game.enemies_killed + (50 - game.lives) == 24, "alle 24 Gegner getötet oder durch (Kills %d, Leben %d)" % [game.enemies_killed, game.lives])
	check(game.level_pause > 25.0, "30 s Pause nach dem Level")
	game.queue_free()
	await get_tree().process_frame
	await _coop_tests(map)
	print("FERTIG: %d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Koop ohne Netz: Host und Mitspieler auf der einen Karte, jeder in seiner Zone, Befehle und Stand direkt
## (wie über ENet als Bytes).
func _coop_tests(map: MapData) -> void:
	Session.map_path = ""
	Session.map_override = null
	Session.rg_choice = {}
	Session.coop = {"role": "host", "player": 0, "names": ["Host", "Gast"]}
	var host: Node = load("res://scenes/rg_game.tscn").instantiate()
	add_child(host)
	Session.coop = {"role": "client", "player": 1, "names": ["Host", "Gast"]}
	var client: Node = load("res://scenes/rg_game.tscn").instantiate()
	add_child(client)
	await get_tree().process_frame
	check(host.coop != null and client.mirror and client.local_player == 1, "Koop: Host und Mitspieler angelegt")
	check(host.map.game == "randgruppen" and client.map.game == "randgruppen", "Karte kommt vom Modus, nicht aus der Lobby")
	client.coop.command_sink = func(cmd): host.coop.receive(1, _wire(cmd))
	var pump := func():
		client.coop.apply_state(_wire(host.coop.snapshot()))
		client.coop.apply_enemies(_wire(host.coop.enemy_packet()))
	check(host.players.size() == 2 and host.players[1].gold == 50, "jeder startet mit 50 Gold")
	check(host.active_lanes().size() == 4, "zwei Spieler: Bahnen von Rot und Gelb (%d)" % host.active_lanes().size())
	host.submit({"type": "setup", "race": "kleingarten", "difficulty": 1})
	check(not host.setup_done, "Host gewählt, wartet auf die Rasse des Gasts")
	client.submit({"type": "setup", "race": "zocker", "difficulty": 4})
	pump.call()
	check(host.setup_done and client.setup_done and host.difficulty == 1 and client.difficulty == 1 and host.lives == 35,
		"beide gewählt: los geht's, Schwierigkeit vom Host (%d, Leben %d)" % [host.difficulty, host.lives])
	check(str(host.rp(1).race) == "zocker" and str(client.rp(1).race) == "zocker" and str(client.rp(0).race) == "kleingarten",
		"Rasse je Spieler")
	# Gast baut in seiner Zone (Gelb), nicht in der des Hosts
	var own: Rect2i = map.zones[1].rect
	var tid: String = client.race_towers()[0]
	var none := Vector2i(-99, -99)
	var cell := none
	for y in range(own.position.y + 4, own.end.y - 4, 2):
		for x in range(own.position.x + 2, own.end.x - 2, 2):
			if cell == none and client.can_build_tower(tid, Vector2i(x, y)):
				cell = Vector2i(x, y)
	check(cell != none, "freies Feld in der Zone des Gasts")
	var cost := int(Database.towers[tid].rg.cost)
	client.submit({"type": "build", "id": tid, "cell": cell})
	pump.call()
	var t: Tower = host.towers.get(cell)
	check(t != null and t.owner_player == 1 and t.tower_id == tid, "Host baut den Tower für den Gast")
	check(client.towers.has(cell) and host.players[1].gold == 50 - cost and host.players[0].gold == 50 and client.gold == 50 - cost,
		"Gold je Spieler (Gast %d)" % client.gold)
	var hz: Rect2i = map.zones[0].rect
	client.submit({"type": "build", "id": tid, "cell": hz.position + Vector2i(6, 10)})
	check(host.towers.size() == 1, "Gast baut nicht in der Zone des Hosts")
	# „Überall bauen“ (Host): dann auch in der Zone des Hosts
	host.foreign_build = true
	pump.call()
	check(client.foreign_build, "„Überall bauen“ kommt beim Gast an")
	var foreign := none
	for y in range(hz.position.y + 4, hz.end.y - 4, 2):
		for x in range(hz.position.x + 2, hz.end.x - 2, 2):
			if foreign == none and client.can_build_tower(tid, Vector2i(x, y)):
				foreign = Vector2i(x, y)
	client.submit({"type": "build", "id": tid, "cell": foreign})
	pump.call()
	check(foreign != none and host.towers.has(foreign) and host.towers[foreign].owner_player == 1, "mit „Überall bauen“ baut der Gast in der Zone des Hosts")
	host.foreign_build = false
	pump.call()
	check(host.tower_options(t).is_empty(), "Host verkauft den Tower des Gasts nicht")
	check(int(client.towers[cell].get_meta("spent", 0)) == cost, "Ausgegeben kommt beim Gast an")
	# Level startet früher erst, wenn beide bereit sind
	host.submit({"type": "start_level"})
	await get_tree().process_frame
	check(host.phase == host.Phase.BUILD and host.rp(0).ready, "Host bereit, Level wartet auf den Gast")
	client.submit({"type": "start_level"})
	for i in 3:
		await get_tree().process_frame
	pump.call()
	check(host.phase == host.Phase.WAVE and client.phase == client.Phase.WAVE, "beide bereit: Level 1 läuft bei beiden")
	var frames := 0
	while host.enemies.is_empty() and frames < 600:
		await get_tree().process_frame
		frames += 1
	pump.call()
	check(client.enemies.size() == host.enemies.size() and client.enemies.size() > 0, "Gegner gespiegelt: %d" % client.enemies.size())
	# Geldteilen (Host): Kopfgeld gleich an beide, egal wer trifft
	host.share_gold = true
	pump.call()
	check(client.share_gold, "Geldteilen kommt beim Gast an")
	var e: Enemy = host.enemies[0]
	e.bounty = 4
	e.last_hit_by = 1
	var g0: int = host.players[0].gold
	var g1: int = host.players[1].gold
	host.on_enemy_killed(e)
	check(host.players[0].gold == g0 + 2 and host.players[1].gold == g1 + 2, "Geldteilen: 4 Kopfgeld → je 2 (%d/%d)" % [host.players[0].gold - g0, host.players[1].gold - g1])
	check(bool(host.save_extra().get("share", false)), "Geldteilen im Spielstand")
	host.queue_free()
	client.queue_free()
	Session.coop = {}
	await get_tree().process_frame


func _wire(v):
	return bytes_to_var(var_to_bytes(v))
