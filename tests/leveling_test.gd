extends Node
## Lauf: einzeln (Name leveling)
## Modi: kern
## Gemeinsames Level- und EP-System (leveling.gd, data/leveling.json): EP-Kurven und Formeln, Boni je Level,
## Freischaltungen von Werten und Fähigkeiten, Abweichungen je Tower, YouTD-Tabellen aus dem System und
## ein Tower im echten eeveTD-Spiel, der durch Kills aufsteigt.
## Start: godot --headless --path . res://tests/leveling_test.tscn (oder tools/run_tests.sh leveling)

var failures := 0
var game: Node


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
	_curves()
	_bonuses()
	_modes()
	Session.map_path = "res://data/maps/eeve.json"
	Session.map_override = null
	Session.skip_setup = true
	game = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.setup_done, "eeveTD gestartet")
	_tower()
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _p(curve: Dictionary, max_level := 3) -> Dictionary:
	return {"max_level": max_level, "curve": curve}


func _curves() -> void:
	var gem := Leveling.for_tower("gemtd", "ruby")
	check(gem._table == [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120], "GemTD: alle 10 EP ein Level bis 12 (%s)" % [gem._table])
	check(Leveling.table(_p({"type": "linear", "base": 10, "step": 5})) == [0, 10, 25, 45], "linear")
	check(Leveling.table(_p({"type": "exponentiell", "base": 10, "growth": 2.0})) == [0, 10, 30, 70], "exponentiell")
	check(Leveling.table(_p({"type": "formel", "base": 10, "formula": "base * level * level"})) == [0, 10, 50, 140], "eigene Formel")
	check(Leveling.table(_p({"type": "tabelle", "table": [5, 7]})) == [0, 5, 12, 19], "Tabelle, letzter Wert wiederholt sich")
	check(Leveling.table(_p({"type": "konstant", "base": 10, "factor": 2.5})) == [0, 25, 50, 75], "factor erhöht alle Stufen")
	check(Leveling.table(_p({"type": "formel", "formula": "level +", "base": 4})) == [0, 4, 8, 12], "kaputte Formel: base statt Absturz")
	check(Leveling.formula_error("level +") != "" and Leveling.formula_error("max(base, 10 + level)") == "", "Formel-Prüfung")
	check(Leveling.level_at(gem, 9.99) == 0 and Leveling.level_at(gem, 10) == 1 and Leveling.level_at(gem, 5000) == 12, "Level aus EP, gedeckelt")
	var inf := Leveling.info(gem, 23)
	check(inf.level == 2 and is_equal_approx(inf.need, 7.0) and is_equal_approx(inf.progress, 0.3) and not inf.maxed, "Fortschritt: %s" % [inf])
	check(Leveling.info(gem, 500).maxed, "Höchstlevel")
	# YouTD holt beide Tabellen aus dem System, Werte wie im Original
	var xp = Database.load_json("res://data/youtd/xp.json")
	check(YoutdData.tower_exp_table() == xp.tower.map(func(v): return int(v)), "YouTD-Tower-Tabelle aus leveling.json gleich xp.json")
	check(YoutdData.player_exp_table() == xp.player.map(func(v): return int(v)), "YouTD-Spieler-Tabelle aus leveling.json gleich xp.json")


func _bonuses() -> void:
	var p := {"max_level": 10, "per_level": {"damage": 0.05, "speed": 0.02},
		"unlocks": [
			{"level": 5, "ability": {"type": "crit", "chance": 0.1, "multiplier": 2.0}},
			{"level": 3, "stat": "range", "value": 0.1},
			{"level": 8, "ability": {"type": "crit", "chance": 0.25, "multiplier": 2.5}},
			{"level": 8, "ability": {"type": "slow", "factor": 0.2, "duration": 1.0}}]}
	var b := Leveling.bonuses(p, 4)
	check(is_equal_approx(b.damage, 0.2) and is_equal_approx(b.speed, 0.08) and is_equal_approx(b.range, 0.1) and b.abilities.is_empty(), "Level 4: Boni je Level und Reichweite ab 3")
	b = Leveling.bonuses(p, 5)
	check(b.abilities.size() == 1 and is_equal_approx(b.abilities[0].chance, 0.1), "Level 5: Kritischer Treffer frei")
	b = Leveling.bonuses(p, 9)
	check(b.abilities.size() == 2 and is_equal_approx(b.abilities[0].chance, 0.25) and b.abilities[1].type == "slow", "Level 8 ersetzt den Krit und bringt Verlangsamung: %s" % [b.abilities])
	check(Leveling.next_unlock(p, 5).level == 8 and Leveling.next_unlock(p, 8).is_empty(), "nächste Freischaltung")
	check(Leveling.unlock_text(p.unlocks[1]).contains("10") and Leveling.per_level_text(p).contains("5"), "Texte: %s / %s" % [Leveling.unlock_text(p.unlocks[1]), Leveling.per_level_text(p)])
	var e := {"max_hp": 200.0, "boss": true, "flying": false}
	check(is_equal_approx(Leveling.kill_ep({"ep": {"kill": 1.0, "boss": 3.0, "hp": 0.01}}, e), 9.0), "EP für einen Boss mit Lebens-Anteil")


func _modes() -> void:
	check(Leveling.mode_profile_id("shoppingmaul") == "", "Shopping Maul: keine Tower-Level (wie im Original)")
	for m in ["gemtd", "roguelike", "eeve", "randgruppen"]:
		check(not Leveling.for_tower(m, "x").is_empty(), "%s hat Tower-Level" % m)
	check(Leveling.profile("eevetd").get("per_level", {}).get("damage") == 0.1, "eeveTD erbt von GemTD")


func _place(id: String, x: int, y := 60) -> Tower:
	for dx in 20:
		var a := Vector2i(x + dx, y)
		if game.debug_place(id, a):
			return game.towers.get(a, game.traps.get(a))
	return null


func _tower() -> void:
	var t := _place("eeve_earth_base_tower", 14)
	check(t != null and t.has_levels() and t.lvl == 0, "Tower mit Level-Profil")
	if t == null:
		return
	var g: Dictionary = (game.waves[0].groups[0] as Dictionary).duplicate()
	game._spawn_enemy(g, 0)
	var e: Enemy = game.enemies[-1]
	for i in 10:
		t.credit_kill(e)
	check(t.kills == 10 and t.lvl == 1 and is_equal_approx(t.kill_bonus(), 0.1), "10 Kills = Level 1 = +10 %% Schaden (Level %d)" % t.lvl)
	# Eigene Freischaltungen für diesen Tower: Reichweite und eine Fähigkeit
	var saved: Dictionary = Database.leveling.duplicate(true)
	Database.leveling.profiles.eevetd["towers"] = {"eeve_earth_base_tower": {"ep_factor": 2.0, "unlocks": [
		{"level": 2, "stat": "range", "value": 0.2}, {"level": 3, "ability": {"type": "crit", "chance": 0.5, "multiplier": 3.0}}]}}
	Leveling.reset()
	var range0: float = t.range_cells()
	t.set_tower(t.tower_id, t.tier)
	check(t.lvl == 1 and t.ability("crit").is_empty(), "nach Datenwechsel noch Level 1, Krit erst ab 3")
	t.gain_ep(5)  # mal ep_factor 2 = 10 EP
	check(t.lvl == 2 and is_equal_approx(t.range_cells(), range0 * 1.2), "Level 2: +20 %% Reichweite (%.2f → %.2f)" % [range0, t.range_cells()])
	t.gain_ep(5)
	check(t.lvl == 3 and not t.ability("crit").is_empty(), "Level 3: Kritischer Treffer freigeschaltet")
	var li := TowerStats.level_info(t)
	check(li.levels and li.level == 3 and (li.unlocked as Array).size() == 2, "Infofenster: %s" % [li])
	var rows: Array = TowerStats.view(t).tiles[0].rows
	check(rows.any(func(r): return "Level 3" in r[0]), "Reichweiten-Kachel nennt den Level-Bonus: %s" % [rows])
	t.set_ep(0)
	check(t.lvl == 0 and t.ability("crit").is_empty() and is_equal_approx(t.range_cells(), range0), "EP auf 0: alles wieder weg")
	Database.leveling = saved
	Leveling.reset()
	t.set_tower(t.tower_id, t.tier)
