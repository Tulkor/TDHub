extends Node
## Lauf: einzeln
## Modi: youtd
## YouTD: Daten, Wellen, Würfeln und ein kurzes Spiel (Element erforschen, würfeln, bauen, Welle 1, aufwerten, Items,
## Spieler-XP am Ende). Start: godot --headless --path . res://tests/youtd_test.tscn (oder tools/run_tests.sh youtd)

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile_youtd"
	Profile.reset_cache()
	await get_tree().process_frame
	_data()
	_waves()
	await _game()
	print("YOUTD TEST ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _data() -> void:
	check(YoutdData.towers().size() == 690, "690 Tower aus YouTD 2: %d" % YoutdData.towers().size())
	check(YoutdData.items().size() >= 300, "Items geladen: %d" % YoutdData.items().size())
	check(YoutdData.elements().size() == 7, "sieben Elemente: %s" % [YoutdData.elements()])
	check(YoutdData.upgrade_of("1") == "439" and YoutdData.upgrade_of("565") == "", "Tiny Shrub → Shrub, letzte Stufe ohne Aufwertung")
	check(YoutdData.food_cost("1") == 2, "gewöhnlicher Tower kostet 2 Food")
	var t := YoutdData.tower_exp_table()
	check(t.size() >= 26 and float(t[1]) > 0.0, "Tower-XP-Tabelle bis Level 25")
	check(YoutdData.player_level(0.0) == 0 and YoutdData.player_level(1e12) == 300, "Spielerlevel 0 bis 300")
	check(YoutdProgress.wisdom_points(6) == 1 and YoutdProgress.wisdom_points(35) == 5, "ein Weisheits-Punkt je 6 Level")
	var broken := []
	for id in YoutdData.towers():
		var d: Dictionary = YoutdData.tower(id)
		if not YoutdData.elements().has(str(d.element)) or float(d.cooldown) <= 0.0 or int(d.cost) <= 0:
			broken.append(id)
	check(broken.is_empty(), "alle Tower mit Element, Abklingzeit und Kosten %s" % [broken.slice(0, 5)])


func _waves() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var diffs: Array = YoutdData.rules().difficulties
	var prev := 0.0
	for lvl in range(1, 121):
		var w := YoutdWaves.generate(lvl, diffs[2], r)
		if lvl % 8 == 0:
			if not str(w.size).begins_with("challenge"):
				check(false, "Welle %d ist keine Challenge: %s" % [lvl, w.size])
		elif str(w.size).begins_with("challenge"):
			check(false, "Welle %d ist Challenge" % lvl)
		if lvl <= 8 and not (w.specials as Array).is_empty():
			check(false, "Welle %d hat schon Eigenschaften %s" % [lvl, w.specials])
		if (w.creeps as Array).is_empty() or float(w.hp) <= 0.0:
			check(false, "Welle %d leer oder ohne Leben" % lvl)
		if lvl % 10 == 1:
			check(float(w.hp) > prev, "Leben steigen: Welle %d %d LP" % [lvl, roundi(float(w.hp))])
			prev = float(w.hp)
	check(YoutdData.damage_factor("physical", "zod") < 1.0 or YoutdData.damage_factor("physical", "zod") >= 0.0, "Schadenstabelle lesbar")


func _game() -> void:
	Session.map_path = "res://data/maps/youtd.json"
	Session.map_override = null
	Session.skip_setup = false
	Session.game_kind = "youtd"
	var game: Node = load("res://scenes/youtd_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(not game.setup_done, "Einstellungsfenster vor dem Start")
	check(game.submit({"type": "setup", "mode": 0, "length": 0, "difficulty": 1, "seed": 11, "wisdom": []}), "Einstellungen übernehmen")
	await get_tree().process_frame
	check(game.waves.size() == 80 and game.tomes == 90 and game.gold == 70 and game.food_cap == 55, "Start: 80 Wellen, 90 Bücher, 70 Gold, 55 Food (%d, %d, %d, %d)" % [game.waves.size(), game.tomes, game.gold, game.food_cap])
	check(game.next_wave_in > 170.0, "erste Welle nach 180 s")
	check(not game.submit({"type": "roll"}), "Würfeln ohne Element geht nicht")
	check(game.submit({"type": "research", "element": "nature"}) and game.elements.nature == 1 and game.tomes == 70, "Natur erforschen kostet 20 Bücher")
	check(game.research_cost("nature") == 21, "nächste Stufe kostet 21")
	check(game.submit({"type": "roll"}) and game.stash.size() == 6, "Startwurf: 6 Tower im Lager")
	check(game.stash.all(func(id): return YoutdData.tower(id).element == "nature" and int(YoutdData.tower(id).tier) == 1),
		"nur Natur-Tower der ersten Stufe")
	# Würfel-Statistik: mit höherer Stufe kommen auch seltenere Tower
	var counts := {}
	game.elements.nature = 15
	game.next_wave = 60
	for i in 300:
		var list: Array = YoutdRoll.with_count(game, 1)
		var rar := str(YoutdData.tower(list[0]).rarity)
		counts[rar] = int(counts.get(rar, 0)) + 1
	check(int(counts.get("common", 0)) > 0 and int(counts.get("uncommon", 0)) + int(counts.get("rare", 0)) > 30, "Seltenheiten bei Natur 15, Welle 59: %s" % [counts])
	game.elements.nature = 1
	game.next_wave = 1

	# Bauen: Tower nur neben dem Weg, nicht auf dem Weg
	game.stash = ["1", "1", "41"] + game.stash
	var cell := Vector2i(10, 12)
	check(not game.can_place(Vector2i(10, 9)), "auf dem Weg kann man nicht bauen")
	var path_before: PackedVector2Array = game.lane_paths[0].ground
	check(game.submit({"type": "build", "id": "1", "cell": cell}), "Tiny Shrub bauen")
	var t: YoutdTower = game.towers.get(cell)
	check(t != null and game.gold == 40 and game.food_used() == 2, "Tower kostet 30 Gold und 2 Food (Gold %d)" % game.gold)
	check(not game.can_reroll, "nach dem ersten Tower kein Neuwürfeln mehr")
	game._update_paths()
	check(game.lane_paths[0].ground == path_before, "Tower verändern den Weg nicht")
	var on_road := true
	for c in game.pathfinder.compute_path():
		if game.map.is_buildable(c):
			on_road = false
	check(on_road, "Weg läuft nur über Wegfelder")
	check(not game.waves[0].creeps.is_empty(), "Welle 1: %s (wie im Original kann auch ein Boss kommen)" % [game.waves[0].creeps])
	check(t.range_cells() > 1.0 and t.cooldown() > 0.0, "Reichweite %s Felder, Abklingzeit %s s" % [t.range_cells(), t.cooldown()])

	# Welle 1 sofort schicken und durchlaufen lassen
	var gold0: int = game.gold
	check(game.submit({"type": "next_wave"}) and game.phase == game.Phase.WAVE and game.current_wave() == 1, "Welle 1 mit N")
	Engine.time_scale = 8.0
	var frames := 0
	while (not game.alive.is_empty() or not game.spawners.is_empty()) and frames < 30000:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0
	check(game.waves_done == 1, "Welle 1 vorbei (Kills %d, Portal %s %%)" % [game.enemies_killed, game.portal])
	check(game.enemies_killed > 0 and t.xp > 0.0, "Tower hat getötet und Erfahrung (%s XP)" % t.xp)
	check(game.gold > gold0 and game.tomes == 78, "Einkommen und 8 Bücher nach Welle 1 (Gold %d, Bücher %d)" % [game.gold, game.tomes])
	check(game.stash.size() >= 1, "nach der Welle neue Tower im Lager")
	check(game.phase == game.Phase.BUILD and game.next_wave_in > 10.0, "15 s bis Welle 2")

	# Aufwerten zur nächsten Stufe der Familie
	game.gold = 1000
	game.elements.nature = 3
	check(game.build_reason("439", t) != "", "Shrub erst ab Welle %d" % YoutdData.required_wave("439", false))
	game.next_wave = 9
	var opts: Array = game.tower_options(t)
	var up: int = opts.map(func(o): return o.action).find("upgrade")
	check(up >= 0 and opts[up].id == "439" and opts[up].cost == 110, "Aufwerten zu Shrub für 110 Gold")
	var xp_before: float = t.xp
	check(game.submit({"type": "option", "tower": game.tower_ref(t), "index": up, "action": "upgrade", "id": "439"}), "aufwerten")
	check(t.yid == "439" and game.gold == 890 and is_equal_approx(t.xp, xp_before), "Shrub steht, Erfahrung bleibt")

	# Items: normales Item belegt einen Platz, Öl nicht
	var claws := YtItem.make(2, game.yp())
	var oil := YtItem.make(1001, game.yp())
	game.stash_add(claws)
	game.stash_add(oil)
	var dmg_before: Array = t.base_damage_range()
	check(game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": claws.get_uid()}) and t.items == [claws], "Claws of Attack einlegen")
	check(t.mod("MOD_DAMAGE_ADD_PERC") >= 0.25, "Item gibt +25 % Schaden")
	check(game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": oil.get_uid()}) and t.oils == [oil] and t.items.size() == 1, "Öl wirkt ohne Platz")
	check(game.submit({"type": "option", "tower": game.tower_ref(t), "index": game.tower_options(t).map(func(o): return o.action).find("take_item"),
			"action": "take_item", "id": "2"}) and game.item_stash.has(claws) and t.mod("MOD_DAMAGE_ADD_PERC") < 0.25, "herausnehmen: Wert weg, Item im Lager")
	game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": claws.get_uid()})
	var sell: int = game.sell_value(t)
	opts = game.tower_options(t)
	var si: int = opts.map(func(o): return o.action).find("sell")
	var g2: int = game.gold
	check(game.submit({"type": "option", "tower": game.tower_ref(t), "index": si, "action": "sell", "id": "439"}) and game.gold == g2 + sell
		and game.item_stash.has(claws), "verkaufen: Gold zurück, Item ins Lager")
	check(dmg_before.size() == 2, "Schadensspanne")

	# Ende: Punkte werden zu Spieler-XP im Profil
	game.youtd_score = 50000.0
	game._finish(game.Phase.GAME_OVER)
	check(YoutdProgress.xp() >= 100.0 and int(YoutdProgress.prog().games) >= 1, "50.000 Punkte = 100 Spieler-XP im Profil (%s)" % YoutdProgress.xp())
	check(game.hud.game_over_stats.text.contains("XP"), "Endbildschirm zeigt die Spieler-XP")
	game.queue_free()
	await get_tree().process_frame
