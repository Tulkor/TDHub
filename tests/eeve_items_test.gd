extends Node
## Lauf: einzeln (Name eeveitems)
## Modi: eevetd
## eeveTD Items und Marktplatz: Daten, Item-Plätze, Drops, Marktplatz bauen, kaufen, verkaufen, Upgrades,
## Items einsetzen und benutzen, Abreißen, Spielstand.
## Start: godot --headless --path . res://tests/eeve_items_test.tscn (oder tools/run_tests.sh eeveitems)

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
	var d := EeveItems.data()
	check(not d.is_empty(), "data/eeve_items.json geladen")
	var missing := []
	for pool in d.drops.pools:
		for id in pool:
			if EeveItems.item(id).is_empty():
				missing.append(id)
	for s in EeveItems.shop():
		if EeveItems.item(str(s.item)).is_empty():
			missing.append(s.item)
	check(missing.is_empty(), "alle Drops und Marktplatz-Items haben Daten %s" % [missing])
	check((d.items as Dictionary).size() == 23, "23 Items wie im Original (ohne Zauberschild, Läuterungstrank und Doppel der Marktplatz-Versionen): %d" % (d.items as Dictionary).size())
	check(EeveItems.sell_price("razorblades") == 100 and EeveItems.shop_price("lumber") == 900, "Verkauf zum halben Wert, Holz 900 Gold")
	check(EeveItems.effect_text("killer_claws").contains("+50") and EeveItems.effect_text("killer_claws").contains("15%"), "Wirkung als Text: %s" % EeveItems.effect_text("killer_claws"))

	# Drops: erst ab Level 11, Golems immer zwei
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var early := 0
	for i in 200:
		if EeveItems.roll_level_drop(10, r) != "":
			early += 1
	check(early == 0, "bis Level 10 keine Drops")
	var counts := {"item": 0, "use": 0, "none": 0}
	for i in 2000:
		var id := EeveItems.roll_level_drop(50, r)
		counts["none" if id == "" else ("use" if int(EeveItems.item(id).get("stage", 0)) == 0 else "item")] += 1
	# Level 50: Stufe 9 → 52 % Item aus Pool 4, bis 76 % Verbrauchs-Item, Rest nichts
	check(absi(counts.item - 1040) < 120 and absi(counts.use - 480) < 100, "Drop-Chancen Level 50: %s" % [counts])
	var golem := EeveItems.roll_challenge(22, r)
	check(golem.size() == 2 and int(EeveItems.item(golem[1]).get("stage", 0)) == 3, "Golem Level 22: Verbrauchs-Item + Item der Stufe III %s" % [golem])

	# Spiel
	Session.map_path = "res://data/maps/eeve.json"
	Session.map_override = null
	Session.skip_setup = true
	var game: Node = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.gold = 20000
	game.lumber = 3
	game.food_cap = 60
	for el in game.elements:
		game.elements[el] = 6
	var mcell := Vector2i(30, 60)
	check(game.submit({"type": "build", "cell": mcell}), "Barrikade bauen")
	var m: Tower = game.towers.get(mcell)
	var opts: Array = game.tower_options(m)
	var mi: int = opts.map(func(o): return o.id).find("eeve_marketplace")
	check(mi >= 0 and opts[mi].reason == "" and int(opts[mi].cost) == 38, "Barrikade → Marktplatz für 38 Gold (zusammen 40)")
	check(game.eitems.buy_reason("lumber") != "", "ohne Marktplatz nichts kaufen")
	check(game.submit({"type": "option", "tower": game.tower_ref(m), "index": mi, "action": "eeve_upgrade", "id": "eeve_marketplace"}), "Marktplatz bauen")
	check(game.eitems.has_market(0) and not m.can_attack(), "Marktplatz steht und greift nicht an")
	var mopts: Array = game.tower_options(m)
	check(mopts.any(func(o): return o.action == "market_open"), "Marktplatz hat „Marktplatz öffnen“")
	check(game.submit({"type": "build", "cell": Vector2i(10, 60)}), "zweite Barrikade")
	var o2: Array = game.tower_options(game.towers.get(Vector2i(10, 60)))
	check(o2[o2.map(func(o): return o.id).find("eeve_marketplace")].reason != "", "nur ein Marktplatz je Spieler")

	# Kaufen
	var g: int = game.gold
	check(game.submit({"type": "market_buy", "id": "lumber"}) and game.lumber == 4 and game.gold == g - 900, "Holz für 900 Gold")
	check(game.submit({"type": "market_buy", "id": "expansion"}) and game.ep().items == ["expansion"], "Erweiterungstrank ins Lager")

	# Tower mit Item-Plätzen
	var tcell := Vector2i(14, 60)
	while not game.can_build(tcell) and tcell.x < 80:
		tcell.x += 2
	check(game.submit({"type": "build", "cell": tcell}), "Barrikade für den Tower")
	var t: Tower = game.towers.get(tcell)
	t.set_tower("eeve_camp_fire", 0)
	check(EeveItems.slots(t) == 0, "Elementstufe 1: keine Item-Plätze")
	game.eitems.give(0, "razorblades")
	check(game.eitems.use_reason(1, t) != "", "Rasierklingen passen nicht in Stufe 1")
	t.set_tower("eeve_ancient_pyramide", 0)
	check(EeveItems.slots(t) == 3, "Elementstufe 5: drei Item-Plätze")
	check(EeveItems.slots(game.towers.get(Vector2i(10, 60))) == 0 and EeveItems.slots(m) == 0, "Barrikade und Marktplatz ohne Plätze")
	game._update_auras()
	var dmg_before: float = t._roll_damage()
	check(game.submit({"type": "item_use", "index": 1, "tower": game.tower_ref(t)}), "Rasierklingen einsetzen")
	check(t.items == ["razorblades"] and is_equal_approx(t.flat_damage, 50.0) and game.ep().items == ["expansion"], "Item im Tower, +50 Schaden")
	var lo: float = float(t.stats.damage[0]) * (1.0 + t.damage_bonus + t.kill_bonus() + t.rogue_damage) + 50.0
	check(t._roll_damage() >= lo - 0.01 and dmg_before > 0.0, "Schuss mit Zusatzschaden")
	check(game.submit({"type": "item_use", "index": 0, "tower": game.tower_ref(t)}) and EeveItems.slots(t) == 4, "Erweiterungstrank: vierter Platz")
	game.eitems.give(0, "orb_fire")
	check(game.submit({"type": "item_use", "index": 0, "tower": game.tower_ref(t)}) and not t.ability("orb").is_empty(), "Kugel des Feuers gibt die Fähigkeit orb")
	check(not t._orb(t.ability("orb")), "Kugel schießt nicht ohne Gegner")

	# Upgrades
	var bonus: float = t.rogue_damage
	check(game.submit({"type": "market_upgrade", "kind": "damage"}) and is_equal_approx(t.rogue_damage, bonus + 0.1) and game.lumber == 3,
		"Schaden-Upgrade: +10 %% für alle Tower, kostet 1 Holz (%s)" % t.rogue_damage)
	var reach: float = t.range_cells()
	check(game.submit({"type": "market_upgrade", "kind": "range"}) and is_equal_approx(t.range_cells(), reach + 0.3125), "Reichweite +40 (0,31 Towerbreiten)")
	check(game.submit({"type": "market_upgrade", "kind": "speed"}) and game.ep().market.speed == 1, "Tempo-Upgrade Stufe 1")
	check(int(game.eitems.upgrade_cost("damage").gold) == 600, "zweite Stufe kostet 600 Gold")
	game.lumber = 0
	check(not game.submit({"type": "market_upgrade", "kind": "damage"}), "ohne Holz kein Upgrade")

	# Verbrauchs-Items, Verkauf
	game.eitems.give(0, "xp_potion")
	t.kills = 0
	check(game.submit({"type": "item_use", "index": 0, "tower": game.tower_ref(t)}) and t.kills == 10, "Erfahrungstrank: +10 Kills")
	game.eitems.give(0, "xp_vial")
	check(game.submit({"type": "item_use", "index": 0, "tower": game.tower_ref(t)}) and t.kills == 0 and game.ep().items == ["xp_potion"],
		"Phiole zieht die Kills ab und wird zum Erfahrungstrank")
	g = game.gold
	check(game.submit({"type": "item_sell", "index": 0}) and game.gold == g + 75 and game.ep().items.is_empty(), "Trank verkauft für 75 Gold")
	# WC3-Inventar: ziehen und tauschen (item_move), Verbrauchs-Items auf Tower werden verbraucht
	var ref: Dictionary = game.tower_ref(t)
	check(t.items == ["razorblades", "orb_fire"], "Ausgang: zwei Items im Tower %s" % [t.items])
	check(game.submit({"type": "item_move", "from": {"tower": ref, "slot": 0}, "to": {"stash": 0}}) and t.items == ["orb_fire"]
		and game.ep().items == ["razorblades"], "Tower-Item ins Lager gezogen")
	check(game.submit({"type": "item_move", "from": {"tower": ref, "slot": 0}, "to": {"stash": 0}}) and t.items == ["razorblades"]
		and game.ep().items == ["orb_fire"], "Tower-Item auf Lager-Item: getauscht")
	check(game.submit({"type": "item_move", "from": {"stash": 0}, "to": {"tower": ref, "slot": 0}}) and t.items == ["orb_fire"]
		and game.ep().items == ["razorblades"], "Lager-Item auf Tower-Item: getauscht")
	check(game.submit({"type": "item_move", "from": {"tower": ref, "slot": 0}, "to": {"stash": 3}}) and t.items.is_empty()
		and game.ep().items == ["razorblades", "orb_fire"], "auf freies Lagerfeld")
	check(is_zero_approx(t.flat_damage) and t.ability("orb").is_empty(), "ohne Items kein Zusatzschaden und keine Kugel mehr")
	check(game.submit({"type": "item_move", "from": {"stash": 1}, "to": {"stash": 0}}) and game.ep().items == ["orb_fire", "razorblades"],
		"im Lager getauscht")
	var bar: Tower = game.towers.get(Vector2i(10, 60))
	check(game.inv_drop_reason(bar, {"inv": true, "from": {"stash": 0}}) != "", "Barrikade nimmt kein Item: %s" % game.inv_drop_reason(bar, {"inv": true, "from": {"stash": 0}}))
	game.eitems.give(0, "xp_potion")
	t.kills = 0
	var potion := {"inv": true, "from": {"stash": 2}}
	check(game.inv_drop_reason(t, potion) == "", "Trank auf Tower in der Welt ziehbar")
	game.systems.inventory.drop(t, potion)
	check(t.kills == 10 and game.ep().items == ["orb_fire", "razorblades"], "Trank verbraucht: +10 Kills")
	game.systems.inventory.drop(t, {"inv": true, "from": {"stash": 1}})
	check(t.items == ["razorblades"] and is_equal_approx(t.flat_damage, 50.0), "Item auf Tower in der Welt gezogen wirkt")
	check(t.items.size() == 1, "Item wieder einsetzen")
	for k in 3:
		game.eitems.give(0, "razorblades")
		game.submit({"type": "item_move", "from": {"stash": 1}, "to": {"tower": ref, "slot": -1}})
	check(t.items.size() == EeveItems.slots(t), "Tower voll (%d)" % t.items.size())
	check(game.inv_drop_reason(t, {"inv": true, "from": {"stash": 0}}) == TranslationServer.translate("Inventar voll"), "voller Tower: „Inventar voll“")
	check(game.submit({"type": "item_move", "from": {"stash": 0}, "to": {"tower": ref, "slot": 3}}) and t.items[3] == "orb_fire",
		"auf ein Item im vollen Tower ziehen tauscht")

	# Lager voll: wird verkauft
	while game.ep().items.size() < 8:
		game.eitems.give(0, "razorblades")
	g = game.gold
	game.eitems.give(0, "burning_blade")
	check(game.ep().items.size() == 8 and game.gold == g + 300, "Lager voll: Brennende Klinge für 300 Gold verkauft")
	check(game.eitems.buy_reason("expansion") != "" and game.eitems.buy_reason("lumber") == "", "voll: Tränke nicht kaufbar, Holz schon")

	# Drop beim ersten Kill und von Golems
	game.ep().items.clear()
	game.ep().drop = "orb_ice"
	var e := Enemy.new()
	e.enemy_id = "eeve_keiler_1"
	e.last_hit_by = 0
	game.eitems.on_kill(e)
	game.eitems.on_kill(e)
	check(game.ep().items == ["orb_ice"] and game.ep().drop == "", "erster Kill des Levels bringt das ausgewürfelte Item, nur einmal")
	e.enemy_id = "eeve_lehmgolem"
	game.wave_index = 10
	game.eitems.on_kill(e)
	check(game.ep().items.size() >= 2, "Golem bringt zwei Items (Holz zählt sofort): %s" % [game.ep().items])
	e.free()

	# Spielstand
	var save: Dictionary = game.save_extra()
	var held: Array = t.items.duplicate()
	t.items.clear()
	t.extra_slots = 0
	game.ep().items.clear()
	game.load_extra(JSON.parse_string(JSON.stringify(save)), game.all_towers())
	check(t.items == held and t.extra_slots == 1 and game.ep().items.size() >= 2 and int(game.ep().market.damage) == 1,
		"Spielstand: Items im Tower, Zusatzplatz, Lager und Upgrades")

	# Abreißen: Items zurück ins Lager
	game.ep().items.clear()
	var ti: int = game.tower_options(t).map(func(o): return o.action).find("scrap")
	game.submit({"type": "option", "tower": game.tower_ref(t), "index": ti, "action": "scrap", "id": t.tower_id})
	check(game.ep().items == held, "Abreißen gibt die Items zurück ins Lager")

	# Oberfläche
	game.items_panel.refresh()
	game.market_panel.open()
	await get_tree().process_frame
	check(game.market_panel.visible and game.market_panel._buy.get_child_count() > 0, "Marktplatz-Fenster zeigt das Angebot")
	game.market_panel.close()
	game.items_panel.picked = 0
	game._select(game.towers.get(Vector2i(10, 60)))
	await get_tree().process_frame
	check(game.items_panel._use.visible and game.items_panel._use.disabled, "Lager: Item gewählt, Barrikade hat keinen Platz")

	print("FERTIG: ", failures, " Fehler")
	get_tree().quit(1 if failures > 0 else 0)
