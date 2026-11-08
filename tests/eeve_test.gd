extends Node
## Modi: eevetd
## eeveTD: Daten, Wellen und ein kurzes Spiel (Barrikade bauen, Element setzen, aufwerten, Level 1 spielen).
## Start: godot --headless --path . res://tests/eeve_test.tscn (oder tools/run_tests.sh eeve)

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
	var rules: Dictionary = Database.eeve
	check(not rules.is_empty(), "data/eeve.json geladen")
	var ids: Array = Database.tower_ids().filter(func(id): return str(Database.towers[id].get("category", "")) == "eeve")
	check(ids.size() >= 80, "eeve-Tower geladen: %d" % ids.size())
	var broken := []
	for id in ids:
		for n in Database.towers[id].eeve.get("next", []):
			if not Database.towers.has(n):
				broken.append("%s → %s" % [id, n])
	check(broken.is_empty(), "alle Aufwertungen zeigen auf vorhandene Tower %s" % [broken])
	check(ids.size() == 109, "108 eeve-Tower wie im Original und der Marktplatz: %d" % ids.size())
	check((Database.towers["eeve_barricade"].eeve.next as Array).size() == 8, "Barrikade wird zu sechs Element-Grundtürmen, zum Dual-Grundturm oder zum Marktplatz")
	check((Database.towers["eeve_dual_element_base_tower"].eeve.next as Array).size() == 15, "Dual-Grundturm hat 15 Dual-Tower")
	var trap_count := ids.filter(func(id): return Database.towers[id].get("kind", "") == "trap").size()
	check(trap_count == 6, "sechs Fallen, eine je Element: %d" % trap_count)
	for s in range(1, 11):
		for kind in ["ground", "ground_mass", "air", "air_mass", "boss"]:
			if EeveWaves.enemy_for(s, kind) == "":
				check(false, "Gegner für Stufe %d %s fehlt" % [s, kind])
	check(EeveWaves.stage_of(5) == 1 and EeveWaves.stage_of(6) == 2 and EeveWaves.stage_of(16) == 3 and EeveWaves.stage_of(54) == 10,
		"Gegnerstufe = abgerundet(Level / 5,5) + 1")
	check(EeveWaves.stage_end(1) == 5 and EeveWaves.stage_end(3) == 16 and EeveWaves.stage_end(10) == 54, "letztes Level je Stufe")

	# Wellen: 57 Level, feste Challenges, HP-Formel
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var hard: Dictionary = rules.difficulties[3]
	var waves := EeveWaves.generate(rules, hard, r)
	check(waves.size() == 57, "57 Level")
	check(waves[10].type == "Challenge" and waves[21].type == "Challenge" and waves[56].groups[0].enemy == "eeve_hoellengolem",
		"Challenges in Level 11, 22 … 57")
	check(waves[0].eeve.kind == "ground" and waves[0].groups[0].count == 10, "Level 1 sind 10 Bodengegner")
	# Level 1 Boden auf Schwer: 500 − 4 · 100 = 100 Leben
	check(is_equal_approx(float(waves[0].groups[0].hp), 100.0), "HP Level 1: %s (erwartet 100)" % waves[0].groups[0].hp)
	var types := {}
	for i in 2000:
		var k := EeveWaves.roll_kind(rules, 20, r)
		types[k] = types.get(k, 0) + 1
	# 20 % Boss, 25 % Luft-Zweig, 55 % Boden-Zweig, in den Zweigen 35 % Masse
	check(absi(types.get("boss", 0) - 400) < 80 and absi(types.get("air", 0) + types.get("air_mass", 0) - 500) < 90
		and absi(types.get("ground", 0) - 715) < 100, "Wellentypen gewürfelt: %s" % [types])
	# Abstände wie im Original: Boden/Luft 1,2 s, Masse in Reihen zu 4 alle 0,15 s
	var mass_wave := {}
	for w in waves:
		if str(w.eeve.kind).ends_with("_mass"):
			mass_wave = w
			break
	check(is_equal_approx(float(waves[0].groups[0].interval), 1.2), "Level 1: alle 1,2 s ein Gegner")
	check(mass_wave.is_empty() or (int(mass_wave.groups[0].count) == 40 and int(mass_wave.groups[0].row) == 4
		and is_equal_approx(float(mass_wave.groups[0].interval), 0.15)), "Masse: 40 Gegner, Reihen zu 4 alle 0,15 s")
	var eg: GDScript = load("res://scripts/game/eeve_game.gd")
	check(eg.boss_leak_damage(20, 11.0, 100.0) == 31 and eg.boss_leak_damage(5, 100.0, 100.0) == 105
		and eg.boss_leak_damage(30, 0.0, 100.0) == 30, "Boss kostet Level + Rest-Leben in Prozent")
	check(int(waves[54].groups[0].row) == 4 and int(waves[55].groups[0].row) == 1, "Massen-Challenge in Reihen, Luft-Challenge einzeln")
	check(is_equal_approx(Database.damage_factor("electric", "eeve_small"), 1.2) and is_equal_approx(Database.damage_factor("spells", "eeve_hero"), 0.5),
		"Schadenstabelle aus der Karte")

	# Spiel: bauen, Element setzen, aufwerten
	Session.map_path = "res://data/maps/eeve.json"
	Session.map_override = null
	Session.skip_setup = true
	var game: Node = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.gold == 200 and game.lives == 50 and game.food_cap == 40, "Start: 200 Gold, 50 Leben, 40 Food")
	check(game.phase == game.Phase.BUILD and game.level_pause > 0.0, "Pause vor Level 1")
	check(game.scene_file_path == Session.EEVE_GAME, "Nochmal spielen startet wieder eeveTD (gleiche Szene)")
	var cell := Vector2i(30, 60)
	check(game.submit({"type": "build", "cell": cell}), "Barrikade bauen")
	var t: Tower = game.towers.get(cell)
	check(t != null and t.tower_id == "eeve_barricade" and game.gold == 198 and game.food_used() == 1, "Barrikade kostet 2 Gold und 1 Food")
	# Auswahlkarte beim ersten Klick gleich in richtiger Höhe (früher kurz bildschirmhoch)
	game._select(t)
	await get_tree().process_frame
	check(game.hud.bottom.size.y < game.hud.root.size.y * 0.8, "Auswahlkarte beim ersten Klick nicht bildschirmhoch: %d" % game.hud.bottom.size.y)
	var opts: Array = game.tower_options(t)
	var nature: int = opts.map(func(o): return o.id).find("eeve_nature_base_tower")
	check(nature >= 0 and opts[nature].reason != "", "Grundturm ohne Elementpunkt gesperrt")
	check(game.submit({"type": "element", "element": "nature"}) and game.elements.nature == 1 and game.points == 0, "Elementpunkt in Natur")
	opts = game.tower_options(t)
	check(game.submit({"type": "option", "tower": game.tower_ref(t), "index": nature, "action": "eeve_upgrade", "id": "eeve_nature_base_tower"}),
		"zum Natur-Grundturm aufwerten")
	check(t.tower_id == "eeve_nature_base_tower" and game.gold == 150, "Grundturm kostet 48 Gold (Gold jetzt %d)" % game.gold)
	check(is_equal_approx(t.damage_bonus, 0.1), "Elementbonus +10 %% je Stufe: %s" % t.damage_bonus)
	# Den Weg zubauen geht nicht
	var blocked := 0
	for x in range(1, 84, 2):
		if game.submit({"type": "build", "cell": Vector2i(x, 70)}):
			blocked += 1
	check(not game.pathfinder.compute_path().is_empty(), "Weg bleibt offen (%d Barrikaden in einer Reihe)" % blocked)

	# Level 1 spielen
	var gold_before: int = game.gold
	game.submit({"type": "start_level"})
	await get_tree().process_frame
	check(game.phase == game.Phase.WAVE, "Level 1 läuft")
	var saved_queue: Array = game.spawn_queue.duplicate()
	game.spawn_queue = []
	for i in 8:
		game.spawn_queue.append({"enemy": "eeve_huhn", "count": 8, "interval": 0.15, "row": 4})
	game._queue_rows()
	check(is_zero_approx(float(game.spawn_queue[0].interval)) and is_equal_approx(float(game.spawn_queue[3].interval), 0.15)
		and int(game.spawn_queue[5].row_slot) == 1, "Massenwelle: 4 Gegner je Reihe ohne Abstand, dann 0,15 s")
	game.spawn_queue = saved_queue
	check(game.gold == gold_before + floori(gold_before * 0.05) + 14, "Zinsen und Einkommen zu Level 1 (%d → %d)" % [gold_before, game.gold])
	Engine.time_scale = 8.0
	var frames := 0
	while game.phase == game.Phase.WAVE and frames < 20000:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0
	check(game.phase == game.Phase.BUILD and game.wave_index == 1, "Level 1 vorbei, Pause vor Level 2")
	check(game.enemies_killed + (50 - game.lives) / 4 >= 10, "alle 10 Gegner getötet oder durch (Kills %d, Leben %d)" % [game.enemies_killed, game.lives])
	check(game.enemies_killed == 0 or game.eeve_score.creeps >= game.enemies_killed * game.score_factor(),
		"Punkte je Kill × Punktefaktor (%s bei %d Kills)" % [game.eeve_score.creeps, game.enemies_killed])
	check(game.food_cap == 42, "Food nach Level 1: %d (erwartet 42)" % game.food_cap)

	# Fallen: ab Elementstufe 4, 900 Gold + 1 Holz, liegen auf dem Weg und versperren ihn nicht
	game.gold = 20000
	game.lumber = 5
	game.food_cap = 60
	check(game.trap_reason("eeve_earthbind_trap") != "", "Falle ohne Erde 4 gesperrt")
	game.elements.earth = 4
	check(game.trap_reason("eeve_earthbind_trap") == "", "Falle mit Erde 4 baubar")
	var path: PackedVector2Array = game.pathfinder.compute_path()
	var length_before: float = game.path_length
	var spot: Vector2i = game.NO_CELL
	# gleich hinter dem Start, damit die Gegner darüber laufen, bevor die Tower sie töten
	for i in range(2, path.size()):
		var a := Vector2i(path[i]) - Vector2i.ONE  # Wegpunkte sind Felder
		if game.can_build_trap("eeve_earthbind_trap", a):
			spot = a
			break
	check(spot != game.NO_CELL, "Platz für eine Falle auf dem Weg gefunden")
	var gold_trap: int = game.gold
	check(game.submit({"type": "trap", "id": "eeve_earthbind_trap", "cell": spot}), "Erdfessel-Falle bauen")
	var trap: Tower = game.traps.get(spot)
	check(trap != null and trap is EeveTower and game.gold == gold_trap - 900 and game.lumber == 4, "Falle kostet 900 Gold und 1 Holz")
	game._update_paths()
	check(is_equal_approx(game.path_length, length_before), "Falle versperrt den Weg nicht")
	check(not game.can_build(spot) and not game.can_build_trap("eeve_earthbind_trap", spot), "auf der Falle kann nichts anderes stehen")

	# Dual-Tower: Barrikade → Dual-Grundturm (ab 3 + 3) → kostenlos zum Dual-Tower der beiden Elemente
	var dcell := Vector2i(10, 60)
	check(game.submit({"type": "build", "cell": dcell}), "Barrikade für den Dual-Tower")
	var d: Tower = game.towers.get(dcell)
	var dopts: Array = game.tower_options(d)
	var di: int = dopts.map(func(o): return o.id).find("eeve_dual_element_base_tower")
	check(di >= 0 and dopts[di].reason != "", "Dual-Grundturm ohne zwei Elemente auf 3 gesperrt")
	game.elements.water = 3
	game.elements.nature = 3
	dopts = game.tower_options(d)
	check(dopts[di].reason == "" and int(dopts[di].cost) == 1998 and int(dopts[di].lumber) == 1, "Dual-Grundturm: 1998 Gold + 1 Holz")
	check(game.submit({"type": "option", "tower": game.tower_ref(d), "index": di, "action": "eeve_upgrade", "id": "eeve_dual_element_base_tower"}),
		"zum Dual-Grundturm aufwerten")
	dopts = game.tower_options(d)
	var dual_ids: Array = dopts.filter(func(o): return o.action == "eeve_upgrade").map(func(o): return o.id)
	# Erde ist von der Falle auf 4: Wasser + Natur, Wasser + Erde, Erde + Natur
	dual_ids.sort()
	check(dual_ids == ["eeve_acid_fountain", "eeve_gaea_spring", "eeve_thornweed_field"],
		"nur Dual-Tower, deren beide Elemente auf 3 sind: %s" % [dual_ids])
	var gold_dual: int = game.gold
	check(game.submit({"type": "option", "tower": game.tower_ref(d), "index": 0, "action": "eeve_upgrade", "id": "eeve_acid_fountain"}),
		"zum Säurebrunnen aufwerten")
	check(d.tower_id == "eeve_acid_fountain" and game.gold == gold_dual, "Dual-Tower kostenlos")
	check(is_equal_approx(d.damage_bonus, 0.3), "Elementbonus Dual-Tower aus beiden Elementen: %s" % d.damage_bonus)

	# Zeitkristall betäubt alle Gegner, Wolke nimmt einmalig Leben: Level 2 spielen
	game.elements.magic = 3
	var ccell := Vector2i(14, 60)
	while not game.can_build(ccell) and ccell.x < 80:
		ccell.x += 2
	check(game.submit({"type": "build", "cell": ccell}), "Barrikade für den Zeitkristall")
	var c: Tower = game.towers.get(ccell)
	c.set_tower("eeve_icy_time_crystal", 0)
	game.submit({"type": "start_level"})
	await get_tree().process_frame
	Engine.time_scale = 8.0
	var stunned := false
	frames = 0
	while game.phase == game.Phase.WAVE and frames < 20000:
		await get_tree().process_frame
		frames += 1
		if not stunned:
			stunned = game.enemies.any(func(e): return e.stun_time > 0.0)
	Engine.time_scale = 1.0
	check(game.phase == game.Phase.BUILD and game.wave_index == 2, "Level 2 vorbei")
	check(stunned, "Zeitsperre des Eisigen Zeitkristalls betäubt Gegner")
	var ground: bool = not Database.enemies[str(game.waves[1].groups[0].enemy)].get("flying", false)
	check(not ground or trap.total_damage > 0.0, "Falle trifft Bodengegner, die darüber laufen (Schaden %d)" % trap.total_damage)

	# Kegelangriff (Feuerspeiender Schneemann): trifft im Kegel vor dem Tower, nicht daneben oder dahinter
	c.set_tower("eeve_fire_breathing_snowman", 0)
	var probes := {}
	for k in ["ziel", "im_kegel", "daneben", "dahinter"]:
		var en := Enemy.new()
		en.game = game
		en.max_hp = 1e7
		en.hp = 1e7
		probes[k] = en
	probes.ziel.pos = c.pos + Vector2(2.0, 0.0)
	probes.im_kegel.pos = c.pos + Vector2(4.0, 1.0)
	probes.daneben.pos = c.pos + Vector2(2.0, 2.0)
	probes.dahinter.pos = c.pos + Vector2(-1.0, 0.0)
	var keep: Array = game.enemies
	game.enemies = probes.values()
	c._attack(probes.ziel)
	game.enemies = keep
	check(probes.ziel.hp < 1e7 and probes.im_kegel.hp < 1e7, "Kegel trifft Ziel und Gegner im Kegel")
	check(probes.daneben.hp == 1e7 and probes.dahinter.hp == 1e7, "Kegel trifft nichts daneben oder hinter dem Tower")
	for en in probes.values():
		en.free()
	game.queue_free()
	await get_tree().process_frame
	await _debug_tests()
	await _coop_tests()
	await _save_tests()
	await _bonus_tests()
	print("eeve: %d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Debug-Menü: Knopf sichtbar, Ressourcen, Elemente auf Maximum, Tower und Falle direkt setzen.
func _debug_tests() -> void:
	Session.skip_setup = true
	var game: Node = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.hud.debug_button.visible and not game.hud.debug_gems_row.visible, "Debug-Knopf in eeveTD, ohne Gems pro Runde")
	check(game.hud.debug_keys.has("eeve_tsunami_cannon") and game.hud.debug_keys.has("eeve_flame_grate") and game.hud.debug_keys.has("eeve_volcano"),
		"Debug-Auswahl hat Element-Tower, Fallen und Dual-Tower")
	var sc: EeveScenery = game.scenery
	check(sc != null and sc.get_child_count() > 20, "Wald und Laternen um die Karte")
	check(FieldStyle.night and sc._lights[0].visible, "eeveTD startet nachts")
	sc.set_night(false)
	var day_sun: float = sc.sun().light_energy
	sc.set_night(true)
	var church := sc.find_children("*", "Node3D", true, false).any(func(n): return str(n.scene_file_path).ends_with("church.glb"))
	check(church, "Friedhof mit Kirche neben der Karte")
	# zwei Laternen am Friedhofstor, zwei am Bergwerk
	check(sc._lights.size() == game.map.all_waypoints().size() + 4 and sc._lights[0].visible and sc._fireflies.emitting
		and sc.sun().light_energy < day_sun, "Nacht: Laterne an jedem Wegpunkt leuchtet, Mondlicht")
	sc.set_night(false)
	check(not sc._lights[0].visible and is_equal_approx(sc.sun().light_energy, day_sun), "Tag: Laternen aus, Sonne wie vorher")
	var lumber: int = game.lumber
	var food: int = game.food_cap
	var pts: int = game.points
	game._debug_add("lumber", 5)
	game._debug_add("food_cap", 10)
	game._debug_add("points", 1)
	check(game.lumber == lumber + 5 and game.food_cap == food + 10 and game.points == pts + 1, "Debug: Holz, Food, Elementpunkte")
	game._debug_max_elements()
	check(game.elements.values().all(func(v): return v == 8) and game.dual_pair_ready(["fire", "water"]), "Debug: alle Elemente auf 8")
	var gold: int = game.gold
	var cell := Vector2i(30, 60)
	game.debug_tower = "eeve_tsunami_cannon"
	check(game.submit({"type": "debug_place", "id": game.debug_tower, "cell": cell}), "Debug: Tower direkt setzen")
	var t: Tower = game.towers.get(cell)
	check(t != null and t.tower_id == "eeve_tsunami_cannon" and game.gold == gold, "Debug-Tower steht und kostet nichts")
	var path: PackedVector2Array = game.pathfinder.compute_path()
	var spot: Vector2i = game.NO_CELL
	for i in range(2, path.size()):
		var a := Vector2i(path[i]) - Vector2i.ONE
		if game.debug_can_place("eeve_flame_grate", a):
			spot = a
			break
	check(spot != game.NO_CELL and game.submit({"type": "debug_place", "id": "eeve_flame_grate", "cell": spot}) and game.traps.has(spot),
		"Debug: Falle direkt auf den Weg setzen")
	game.debug_jump_to_wave(10)
	check(game.wave_index == 9, "Debug: Level 10 kommt als nächstes")
	game.queue_free()
	await get_tree().process_frame


## Koop ohne Netz: Host- und Mitspieler-Spiel, Befehle und Stand laufen direkt (wie über ENet als Bytes).
func _coop_tests() -> void:
	Session.skip_setup = false
	Session.coop = {"role": "host", "player": 0, "names": ["Host", "Gast"]}
	var host: Node = load(Session.EEVE_GAME).instantiate()
	add_child(host)
	Session.coop = {"role": "client", "player": 1, "names": ["Host", "Gast"]}
	var client: Node = load(Session.EEVE_GAME).instantiate()
	add_child(client)
	await get_tree().process_frame
	check(host.coop != null and client.mirror and client.local_player == 1, "Koop: Host und Mitspieler angelegt")
	client.coop.command_sink = func(cmd): host.coop.receive(1, _wire(cmd))
	var pump := func():
		client.coop.apply_state(_wire(host.coop.snapshot()))
		client.coop.apply_enemies(_wire(host.coop.enemy_packet()))
	check(host.players.size() == 2 and host.players[1].gold == 200, "jeder Spieler startet mit 200 Gold")
	client.submit({"type": "setup", "difficulty": 0, "field": 0})
	check(not host.setup_done, "nur der Host wählt die Einstellungen")
	host.submit({"type": "setup", "difficulty": 3, "field": 0})
	pump.call()
	check(client.setup_done and client.difficulty == 3 and client.wave_seed == host.wave_seed, "Mitspieler übernimmt Einstellungen und Wellen")
	check(is_equal_approx(float(client.waves[5].groups[0].hp), float(host.waves[5].groups[0].hp)), "gleiche Wellen bei Host und Mitspieler")
	check(client.bonus_tiles == host.bonus_tiles and host.bonus_tiles.size() == 45, "Mitspieler sieht dieselben Bonusfelder")
	check(is_equal_approx(host.coop_hp_factor(), 1.75), "Gegner mit 2 Spielern +75 %% Leben: %s" % host.coop_hp_factor())
	# Mitspieler baut und setzt einen Elementpunkt, beides für sich
	var cell := Vector2i(30, 60)
	client.submit({"type": "build", "cell": cell})
	client.submit({"type": "element", "element": "fire"})
	pump.call()
	var t: Tower = host.towers.get(cell)
	check(t != null and t.owner_player == 1, "Host baut die Barrikade für den Mitspieler")
	check(client.towers.has(cell) and client.towers[cell] is EeveTower, "Mitspieler sieht seine Barrikade")
	check(host.players[1].gold == 198 and host.players[0].gold == 200 and client.gold == 198, "Gold je Spieler (Gast %d)" % client.gold)
	check(host.ep(1).elements.fire == 1 and host.ep(0).elements.fire == 0 and client.elements.fire == 1 and client.points == 0,
		"Elementpunkte je Spieler")
	check(host.tower_options(t).is_empty(), "Host wertet den Tower des Mitspielers nicht auf")
	var opts: Array = client.tower_options(client.towers[cell])
	var fire: int = opts.map(func(o): return o.id).find("eeve_fire_base_tower")
	check(fire >= 0 and opts[fire].reason == "", "Mitspieler darf mit seinem Feuerpunkt aufwerten")
	client.submit({"type": "option", "tower": client.tower_ref(client.towers[cell]), "index": fire, "action": "eeve_upgrade", "id": "eeve_fire_base_tower"})
	pump.call()
	check(t.tower_id == "eeve_fire_base_tower" and client.towers[cell].tower_id == "eeve_fire_base_tower", "Feuer-Grundturm bei beiden")
	check(int(client.towers[cell].get_meta("spent", 0)) == int(t.get_meta("spent", 0)) and int(t.get_meta("spent", 0)) > 2, "Ausgegeben kommt beim Mitspieler an")
	# Level startet erst, wenn beide bereit sind
	host.submit({"type": "start_level"})
	await get_tree().process_frame
	check(host.phase == host.Phase.BUILD and host.ready_players.has(0), "Host bereit, Level wartet auf den Gast")
	client.submit({"type": "start_level"})
	await get_tree().process_frame
	await get_tree().process_frame
	pump.call()
	check(host.phase == host.Phase.WAVE and client.phase == client.Phase.WAVE, "beide bereit: Level 1 läuft bei beiden")
	check(host.players[1].gold > 198 - 50 and client.log_lines.size() > 0, "Einkommen und Meldung für den Gast")
	var frames := 0
	while host.enemies.is_empty() and frames < 600:
		await get_tree().process_frame
		frames += 1
	pump.call()
	check(client.enemies.size() == host.enemies.size() and client.enemies.size() > 0, "Gegner gespiegelt: %d" % client.enemies.size())
	host.queue_free()
	client.queue_free()
	Session.coop = {}
	await get_tree().process_frame


## Spielstand: Elemente, Food, Holz, Wellen und Tower kommen genau so zurück.
func _save_tests() -> void:
	Session.skip_setup = false
	Session.game_kind = "eevetd"
	var game: Node = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.submit({"type": "setup", "difficulty": 4, "field": 1})
	var cell := Vector2i(30, 60)
	while (not game.can_build(cell) or game.bonus_tiles.has(cell)) and cell.x < 80:
		cell.x += 2
	game.submit({"type": "build", "cell": cell})
	game.submit({"type": "element", "element": "water"})
	var t: Tower = game.towers[cell]
	var opts: Array = game.tower_options(t)
	var i: int = opts.map(func(o): return o.id).find("eeve_water_base_tower")
	game.submit({"type": "option", "tower": game.tower_ref(t), "index": i, "action": "eeve_upgrade", "id": "eeve_water_base_tower"})
	game.lumber = 3
	game.food_cap = 47
	game.level_pause = 12.5
	game.eeve_score.challenges = 1234.0
	var st := SaveGame.capture(game)
	var waves_before: Array = game.waves.map(func(w): return [w.type, w.groups[0].enemy, w.groups[0].hp])
	var rocks: int = game.rocks.size()
	var tiles: Dictionary = game.bonus_tiles.duplicate()
	var gold: int = game.gold
	var spent := int(t.get_meta("spent", 0))
	game.queue_free()
	await get_tree().process_frame
	Session.load_state = _wire(st)
	var loaded: Node = load(Session.EEVE_GAME).instantiate()
	add_child(loaded)
	await get_tree().process_frame
	check(loaded.setup_done and loaded.difficulty == 4 and loaded.field_type == 1 and loaded.rocks.size() == rocks, "Spielstand: Schwierigkeit, Feld und Felsen")
	check(loaded.waves.map(func(w): return [w.type, w.groups[0].enemy, w.groups[0].hp]) == waves_before, "Spielstand: dieselben Wellen")
	check(loaded.elements.water == 1 and loaded.lumber == 3 and loaded.food_cap == 47 and loaded.points == 0, "Spielstand: Elemente, Holz und Food")
	check(loaded.gold == gold and absf(loaded.level_pause - 12.5) < 0.5, "Spielstand: Gold %d (%d) und Pause %s" % [loaded.gold, gold, loaded.level_pause])
	var lt: Tower = loaded.towers.get(cell)
	check(lt is EeveTower and lt.tower_id == "eeve_water_base_tower" and int(lt.get_meta("spent", 0)) == spent if lt != null else false,
		"Spielstand: Wasser-Grundturm als EeveTower mit ausgegebenem Gold")
	check(is_equal_approx(lt.damage_bonus, 0.1) if lt != null else false, "Spielstand: Elementbonus wieder da")
	check(loaded.bonus_tiles == tiles and tiles.size() == 45, "Spielstand: dieselben Bonusfelder (%d)" % tiles.size())
	check(is_equal_approx(loaded.eeve_score.challenges, 1234.0), "Spielstand: Challenge-Punkte")
	loaded.queue_free()
	await get_tree().process_frame


## Wie über das Netz: als Bytes und zurück, damit nichts geteilt wird.
func _wire(v):
	return bytes_to_var(var_to_bytes(v))


## Bonusfelder (Lava, Eis, Marmor) und die Wertung am Ende.
func _bonus_tests() -> void:
	Session.skip_setup = false
	var game: Node = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.submit({"type": "setup", "difficulty": 3, "field": 2})
	var per_kind := {}
	for a in game.bonus_tiles:
		per_kind[game.bonus_tiles[a]] = per_kind.get(game.bonus_tiles[a], 0) + 1
	check(per_kind == {"lava": 18, "ice": 18, "marble": 18}, "WTF-Feld: je 18 Bonusfelder: %s" % [per_kind])
	check(game.rocks.keys().all(func(r): return not game._on_bonus_tile(r)), "keine Felsen auf Bonusfeldern")
	check(game.bonus_view.get_child_count() == 3, "Bonusfelder werden gezeichnet")
	# Tower genau auf Lava, Eis und Marmor
	game.bonus_tiles = {}
	var cells := []
	var c := Vector2i(20, 20)
	while cells.size() < 4 and c.x < 80:
		if game.can_build(c):
			cells.append(c)
		c.x += 3
	var kinds := ["lava", "ice", "marble"]
	for i in 3:
		game.bonus_tiles[cells[i]] = kinds[i]
	game.points = 3
	game.submit({"type": "element", "element": "fire"})
	var made := []
	for cell in cells:
		game.submit({"type": "build", "cell": cell})
		var t: Tower = game.towers[cell]
		var opts: Array = game.tower_options(t)
		var i: int = opts.map(func(o): return o.id).find("eeve_fire_base_tower")
		game.submit({"type": "option", "tower": game.tower_ref(t), "index": i, "action": "eeve_upgrade", "id": "eeve_fire_base_tower"})
		made.append(game.towers[cell])
	check(is_equal_approx(made[0].damage_bonus, 0.5) and made[0].damage_source.contains("Lava"), "Lava: +40 %% Schaden (%s)" % made[0].damage_bonus)
	check(is_equal_approx(made[1].speed_bonus, 0.35) and is_equal_approx(made[1].damage_bonus, 0.1), "Eis: +35 %% Angriffstempo")
	made[2].gain_ep(10)
	made[3].gain_ep(10)
	check(made[2].kill_bonus() > made[3].kill_bonus() and is_equal_approx(made[2].xp_factor, 2.0), "Marmor: doppelte Erfahrung für Kill-Ränge")
	check(is_equal_approx(made[3].damage_bonus, 0.1) and made[3].speed_bonus == 0.0, "daneben kein Bonus")
	check(made[0].base_tint == Color("#ff6a1a") and made[3].base_tint.a == 0.0, "Sockel in der Farbe des Bonusfelds")
	# Challenge: 64 % Schaden an einem Golem mit 3000 Punkten auf Schwer (× 2)
	var golem := Enemy.new()
	golem.max_hp = 100.0
	golem.hp = 36.0
	golem.set_meta("challenge_score", 3000.0)
	game._score_challenge(golem, false)
	golem.free()
	check(is_equal_approx(game.eeve_score.challenges, 3840.0), "Challenge: 64 %% von 3000 × 2 = 3840 (%s)" % game.eeve_score.challenges)
	check(int(game.waves[54].groups[0].challenge_score) == 500 and int(game.waves[10].groups[0].challenge_score) == 3000,
		"Massen-Challenge: 20000 / 40 je Gegner, Lehmgolem 3000")
	# Ende: Leben × 100, Gold × 0,5, WTF-Feld 5000, alles × 2
	game.eeve_score.creeps = 1000.0
	game.lives = 40
	game.players[0].gold = 1000
	var parts: Dictionary = game.score_parts(true)
	check(is_equal_approx(parts.lives, 8000.0) and is_equal_approx(parts.gold, 1000.0) and is_equal_approx(parts.field, 10000.0),
		"Sieg: Leben 8000, Gold 1000, Feldbonus 10000: %s" % [parts])
	check(game.score_total(true) == 1000 + 3840 + 8000 + 1000 + 10000 and game.score_total(false) == 4840, "Gesamtpunkte, verloren ohne Bonus")
	game._finish(game.Phase.VICTORY)
	check(game.hud.game_over_table.visible and game.hud.game_over_stats.text.contains("23840"), "Endbildschirm zeigt die Wertung")
	game.queue_free()
	await get_tree().process_frame
