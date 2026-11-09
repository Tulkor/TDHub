extends Node
## Modi: shoppingmaul
## Test für Shopping Maul: godot --headless --path . res://tests/maul_test.tscn
## Lädt die Daten, prüft alle Wege, baut im Zentrum und spielt die ersten Level im Zeitraffer.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	Profile.dir = "user://test_maul_profil"
	await get_tree().process_frame
	check(MaulData.shops().size() == 20, "20 Filialen geladen")
	check(MaulData.towers().size() >= 200, "Tower geladen: %d" % MaulData.towers().size())
	check(MaulData.levels().size() == 50, "50 Level geladen")
	for s in MaulData.shops():
		for t in s.towers:
			if t.upgrade_from != null:
				check(MaulData.tower(str(t.upgrade_from)).get("upgrades_to", []).has(t.id), "Upgrade %s hängt an %s" % [t.id, t.upgrade_from])
	for s in MaulData.shops().filter(func(x): return x.kind == "standard"):
		check(not MaulData.buyable(str(s.id)).is_empty(), "Filiale %s hat kaufbare Tower" % s.id)

	var game: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	for leg in game.all_legs():
		var r := game._compute_route(leg[0], leg[1], "ground", game.pathfinder)
		check(not r.path.is_empty(), "Weg von %s über %d Punkte" % [leg[0], leg[1].size()])
		for pt in r.path:
			var c := Vector2i((pt / Board3D.CELL).floor())
			if game.board.city.is_city(c):
				check(false, "Stadt steht auf dem Weg bei %s" % c)
				break
	check(game.board.city.part_count() > 500, "Blockstadt gebaut: %d Teile" % game.board.city.part_count())
	check(game.board.city.lamp_count() > 50, "Laternen: %d" % game.board.city.lamp_count())
	for z in game.map.zones:
		check(not game.board.city.is_city(z.rect.get_center()), "Keine Stadt im Gebiet %s" % z.rect)

	game.start_game("hm", 1, "group")
	check(game.phase == MaulGame.Phase.COUNTDOWN, "Countdown läuft nach der Filialwahl")
	check(game.players[0].gold == 545, "Startgold 500 + 45 für P1: %d" % game.players[0].gold)
	check(game.lives == 150, "Normal: 150 Leben")

	# Bauen: eigene Zone, nicht außerhalb, nicht blockierend
	var zone: Rect2i = game.map.zones[0].rect
	var cheap := str(MaulData.buyable("hm")[0].id)
	check(game.build_problem(cheap, Vector2i(5, 5), 0) != "", "außerhalb des Gebiets wird nicht gebaut")
	var other: Vector2i = _spots(game, game.map.zones[1].rect)[0]
	check(game.build_problem(cheap, other, 0) != "", "ohne „Überall bauen“ nicht im fremden Gebiet")
	game.foreign_build = true
	check(game.build_problem(cheap, other, 0) == "", "mit „Überall bauen“ im fremden Gebiet: %s" % game.build_problem(cheap, other, 0))
	check(game.build_problem(cheap, Vector2i(5, 5), 0) != "", "auch mit „Überall bauen“ nicht außerhalb der Gebiete")
	game.foreign_build = false
	var built := 0
	var spots := _spots(game, zone)
	for a in spots:
		if game.players[0].gold < 100:
			break
		var id := str(MaulData.buyable("hm")[2].id) if game.players[0].gold >= 200 else cheap
		if game.submit({"type": "build", "tower": id, "cell": a}):
			built += 1
	check(built >= 4, "%d Tower im Zentrum gebaut" % built)
	for leg in game.all_legs():
		check(not game._route(leg[0], leg[1], "ground").path.is_empty(), "Weg nach dem Bauen offen")
		break
	# Verkaufen bringt 75 %
	var t: MaulTower = game.towers.values()[0]
	var gold_before: int = game.players[0].gold
	var refund := game.sell_value(t)
	check(game.submit({"type": "sell", "cell": t.cell}), "Verkaufen klappt")
	check(game.players[0].gold == gold_before + refund, "Verkauf bringt %d Gold" % refund)

	# Level 1 im Zeitraffer
	game.submit({"type": "start_now"})
	Engine.time_scale = 8.0
	var waited := 0.0
	while game.level < 3 and waited < 240.0 and game.phase < MaulGame.Phase.GAME_OVER:
		await get_tree().create_timer(0.5, true, false, true).timeout
		waited += 0.5
		if game.phase == MaulGame.Phase.COUNTDOWN:
			game.submit({"type": "start_now"})
			# Gold sofort verbauen
			for a in spots:
				if game.players[0].gold < 30:
					break
				game.submit({"type": "build", "tower": str(MaulData.buyable("hm")[1].id), "cell": a})
	Engine.time_scale = 1.0
	check(game.level >= 3, "Level 1 und 2 gespielt (jetzt Level %d)" % game.level)
	check(game.enemies_killed > 0, "Gegner besiegt: %d" % game.enemies_killed)
	check(game.income_pot > 185, "Einkommen gewachsen: %d" % game.income_pot)
	print("Leben %d, durchgelassen %d, JE %.2f, Gold %d, Tower %d" % [game.lives, game.enemies_leaked, game.je, game.players[0].gold, game.towers.size()])
	game.queue_free()
	await get_tree().process_frame
	await _pro_tests()
	await _ability_tests()
	await _bank_tests()
	await _save_tests()
	await _debug_tests()
	await _coop_tests()
	await _team_tests()
	print("FERTIG mit %d Fehlern" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Bauplätze im Gebiet mit Abstand, damit der Weg frei bleibt.
func _spots(game: MaulGame, zone: Rect2i) -> Array:
	var list := []
	for y in range(zone.position.y + 1, zone.end.y - 2, 4):
		for x in range(zone.position.x + 1, zone.end.x - 2, 4):
			list.append(Vector2i(x, y))
	# nahe an der Mittelbahn zuerst (dort laufen die Gegner)
	var mid := Vector2(zone.get_center())
	list.sort_custom(func(a, b): return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
	return list


## Profil: Partien und Rekorde bleiben gespeichert (eigener Profil-Ordner statt user://profile).
func _profile_tests() -> void:
	MaulProfile.path = "user://test_maul_profile.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MaulProfile.path))
	Profile.dir = "user://test_maul_profil"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.file()))
	Profile.reset_cache()
	check(MaulProfile.shop("ikea").best_win == -1 and MaulProfile.totals().games == 0, "Profil: leer am Anfang")
	var n := MaulProfile.record("ikea", 1, 12, false, 300, 600.0)
	check(n.has("best_level") and not n.has("best_win"), "Profil: erstes Level ist Rekord")
	n = MaulProfile.record("ikea", 2, 50, true, 900, 1800.0)
	check(n.has("best_level") and n.has("best_win"), "Profil: Sieg ist Rekord")
	n = MaulProfile.record("ikea", 0, 50, true, 10, 60.0)
	check(n.is_empty(), "Profil: leichterer Sieg ist kein Rekord")
	var r := MaulProfile.shop("ikea")
	var t := MaulProfile.totals()
	check(r.games == 3 and r.wins == 2 and r.best_level == 50 and r.best_win == 2, "Profil: Filiale %s" % r)
	check(t.games == 3 and t.wins == 2 and t.levels == 112 and t.kills == 1210 and t.minutes == 41, "Profil: Summen %s" % t)
	var u := MaulProfile.unlocks(250)
	check(u.size() > 5 and u[0].open and not u[-1].open, "Profil: Freischaltungen sortiert")
	check(int(MaulProfile.next_unlock(250).xp) > 250 and MaulProfile.next_unlock(99999).is_empty(), "Profil: nächste Freischaltung")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MaulProfile.path))


## Etappe 2: XP, Hauptgebäude, Profi-Filialen, Items, Einheiten (Sandbox, damit alles offen ist).
func _pro_tests() -> void:
	_profile_tests()
	check(not MaulXp.pro_unlocked(10) and MaulXp.pro_unlocked(250), "Profi-Filialen ab 25 XP")
	var a: Array = MaulXp.gain(10, 0.0, 10, 1, 1.0)
	var b: Array = MaulXp.gain(5000, 0.0, 10, 1, 1.0)
	check(int(a[0]) > 10, "XP nach Level 10: %s" % MaulXp.text(int(a[0])))
	check(int(b[0]) - 5000 < int(a[0]) - 10, "Hohe XP wachsen langsamer")
	check(MaulXp.text(123) == "12,3", "XP-Text 12,3")
	check(MaulData.bonus_cost(1, false, 1) == 500 and MaulData.bonus_cost(4, false, 1) == 4000, "Bonus kostet n·⌊√n⌋·500")
	check(MaulData.bonus_cost(2, true, 2) == 300, "Rabatt für 2 Spieler halb so teuer")

	var game: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(not game._pick_shop(0, "post"), "Ohne Start keine Filiale")
	game.start_game("post", 1, "group", true)
	check(game.shop_of() == "post" and game.sandbox, "Sandbox: Profi-Filiale Post eröffnet")
	var me: MaulGame.Player = game.players[0]
	me.gold = 100000
	# Hauptgebäude: Post hat Rabatt
	check(game.submit({"type": "bonus"}) and me.bonus == 1, "Rabatt-Stufe 1 gekauft")
	check(me.gold == 100000 - 300, "Rabatt Stufe 1 kostet 300")
	var zone: Rect2i = game.map.zones[0].rect
	var spots := _spots(game, zone).filter(func(c): return game.build_problem("h01P", c, 0) == "")
	check(game.submit({"type": "build", "tower": "h01P", "cell": spots[0]}), "Paketladen gebaut")
	var g0 := me.gold
	check(game.submit({"type": "build", "tower": "h01O", "cell": spots[1]}), "Postamt (2 Slots) gebaut")
	check(me.gold == g0 - 120 + 6, "Rabatt: 5 %% von 120 zurück (%d)" % (g0 - me.gold))
	var office: MaulTower = game.towers[spots[1]]
	check(office.slots() == 2, "Postamt hat 2 Slots")
	check(game.items_for(0, "weapon").has("I000"), "Paketladen verkauft Werbesendung")
	check(game.submit({"type": "item", "cell": office.cell, "item": "I002"}), "Item gekauft")
	check(game.submit({"type": "item", "cell": office.cell, "item": "I002"}), "zweites Item gekauft")
	check(not game.submit({"type": "item", "cell": office.cell, "item": "I000"}), "Slots voll")
	check(game.sell_value(office) > floori(office.value * 0.75), "Verkaufswert enthält die Items")
	check(game.submit({"type": "item_sell", "cell": office.cell, "slot": 0}) and office.items.size() == 1, "Item verkauft")
	# WC3-Inventar: Items zwischen Towern ziehen, auf ein Item = tauschen, voller Tower nimmt nichts
	check(game.submit({"type": "build", "tower": "h01O", "cell": spots[4]}), "zweites Postamt gebaut")
	var office2: MaulTower = game.towers[spots[4]]
	check(game.submit({"type": "item", "cell": office2.cell, "item": "I000"}), "Werbesendung ins zweite Postamt")
	check(game.submit({"type": "item_move", "from": {"tower": office.cell, "slot": 0}, "to": {"tower": office2.cell, "slot": 0}})
		and office.items == ["I000"] and office2.items == ["I002"], "Item auf Item in anderem Tower: getauscht")
	check(game.submit({"type": "item_move", "from": {"tower": office.cell, "slot": 0}, "to": {"tower": office2.cell, "slot": -1}})
		and office.items.is_empty() and office2.items == ["I002", "I000"], "auf freien Slot verschoben")
	check(game.move_reason(0, {"tower": office2.cell, "slot": 0}, {"tower": office2.cell, "slot": -1}) != "", "im selben Tower auf freien Slot: nichts zu tun")
	game.submit({"type": "item", "cell": office.cell, "item": "I000"})
	check(game.move_reason(0, {"tower": office.cell, "slot": 0}, {"tower": office2.cell, "slot": -1}) == game.tr("Inventar voll"), "voller Tower: „Inventar voll“")
	check(game.submit({"type": "item_move", "from": {"tower": office2.cell, "slot": 1}, "to": {"tower": office2.cell, "slot": 0}})
		and office2.items == ["I000", "I002"], "im selben Tower umsortiert")
	check(game.submit({"type": "sell", "cell": office2.cell}), "zweites Postamt verkauft")
	# XPert: ein XP-Tower erlaubt
	check(game.submit({"type": "build", "tower": "h00S", "cell": spots[2]}), "XP-Tower Haystack gebaut")
	check(game.build_problem("h01L", spots[3], 0) != "", "zweiter XP-Tower gesperrt")
	check(game.requirement_problem(MaulData.tower("o01J"), 0) != "", "Ultimate erst ab Level 21")
	# Schaden: Fitness-Doping und Bonusfaktor
	var t := MaulTower.new()
	t.owner_player = 0
	game.board.add_child(t)
	t.setup(game, Vector2i(-10, -10), "H03A", 0)
	game._take_drug(t, MaulData.item("I00U"))
	check(t.flat == 25.0, "Amphetamin: +25 Schaden")
	game._take_drug(t, MaulData.item("I01T"))
	check(t.side == 10 and is_equal_approx(t.side_factor(), 0.5), "Steroide: 10 Stufen Nebenwirkungen")
	# IKEO-Combo
	var combo: Array = MaulData.pro().combos[0]
	t.items = [combo[0], combo[1]]
	game._combine(t)
	check(t.items == [combo[2]], "Combo %s + %s → %s" % combo)
	t.queue_free()
	# Einheiten: Zombie zerfällt, Drohne verbraucht Energie
	var z := game.spawn_unit("u001", 0, null)
	var d := game.spawn_unit("battle", 0, null)
	var hp := z.hp
	for i in 10:
		await get_tree().process_frame
	check(z.hp < hp, "Zombie verliert Leben (%.1f → %.1f)" % [hp, z.hp])
	check(game.units.size() == 2 and d.drone, "2 Einheiten unterwegs")
	check(d.max_energy() == 15.0, "Drohne hat 15 Energie")
	d.modules["battery"] = "I018"
	check(d.max_energy() == 25.0, "Batterie Mk1: +10 Energie")
	check(game.submit({"type": "post", "unit": d.net_id, "x": game.map.zone_center(0).x, "y": game.map.zone_center(0).y}), "Posten gesetzt")
	game.remove_unit(z)
	check(game.units.size() == 1, "Zombie entfernt")
	game.queue_free()
	await get_tree().process_frame


## Debug-Menü: Gold, XP (ohne Speichern), Filiale wechseln, freies Bauen, Items ohne Laden, Level springen.
func _debug_tests() -> void:
	var game: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_game("hm", 1, "group")
	game.hud.toggle_debug()
	check(game.hud._debug != null and game.hud._debug.visible, "Debug-Menü geht auf")
	# Esc: erst Bauwahl aufheben, dann Menü; Einstellungen gehen aus dem Menü auf
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	game.build_id = str(MaulData.buyable(game.shop_of())[0].id)
	game._unhandled_input(esc)
	check(game.build_id == "" and not game.hud._menu.visible, "Esc bricht erst die Bauwahl ab")
	game._unhandled_input(esc)
	check(game.hud._menu.visible, "Esc ohne Auswahl öffnet das Menü")
	game.hud.settings_panel.open()
	game._unhandled_input(esc)
	check(not game.hud.settings_panel.visible and game.hud._menu.visible, "Esc schließt erst die Einstellungen")
	game._unhandled_input(esc)
	check(not game.hud._menu.visible, "Esc schließt das Menü")
	var xp: int = game.players[0].xp
	game.debug_add_xp(100)
	check(game.players[0].xp == xp + 100 and game.debug_xp, "Debug: +10 XP, wird nicht gespeichert")
	game.debug_set_shop("post")
	check(game.shop_of() == "post", "Debug: Filiale gewechselt")
	var zone: Rect2i = game.map.zones[0].rect
	var foreign := str(MaulData.buyable("porsche")[0].id)
	game.players[0].gold += 100000
	game.debug_free = true
	var a: Vector2i = game.NO_CELL
	for spot in _spots(game, zone):
		if game.build_problem(foreign, spot, 0, true) == "":
			a = spot
			break
	game.debug_free = false
	check(a != game.NO_CELL and game.build_problem(foreign, a, 0) != "", "fremder Tower ohne freies Bauen gesperrt")
	game.hud._debug._set_free(true)
	check(game.submit({"type": "build", "tower": foreign, "cell": a}) and game.towers.get(a).tower_id == foreign, "Debug: freies Bauen setzt Tower einer anderen Filiale")
	check(not game.items_for(0, "weapon").is_empty() and game.store_has(0, str(game.items_for(0, "weapon")[0])), "Debug: alle Items ohne Laden")
	game.debug_jump_to_level(5)
	check(game.level == 4, "Debug im Countdown: Level 5 kommt als nächstes")
	game.submit({"type": "start_now"})
	await get_tree().process_frame
	check(game.level == 5 and game.phase == MaulGame.Phase.WAVE, "Level 5 läuft (jetzt %d)" % game.level)
	game.debug_jump_to_level(8)
	check(game.level == 8 and game.phase == MaulGame.Phase.WAVE, "Debug in der Welle: Level 8 startet sofort")
	game.queue_free()
	await get_tree().process_frame


## Koop ohne Netz: Host- und Mitspieler-Spiel, Befehle und Stand laufen direkt (wie über ENet als Bytes).
func _coop_tests() -> void:
	Session.coop = {"role": "host", "player": 0, "names": ["Host", "Gast"]}
	var host: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(host)
	Session.coop = {"role": "client", "player": 1, "names": ["Host", "Gast"]}
	var client: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(client)
	await get_tree().process_frame
	check(host.sync != null and client.mirror and client.local_player == 1, "Koop: Host und Mitspieler angelegt")
	var own_paths := client.board.path_points.size()
	check(own_paths > 0 and client.has_other_paths(), "Mitspieler sieht anfangs nur die eigenen Wege (%d Punkte)" % own_paths)
	client.set_show_all_paths(true)
	check(client.board.path_points.size() > own_paths, "Knopf zeigt auch die Wege der anderen")
	client.set_show_all_paths(false)
	check(client.board.path_points.size() == own_paths, "Knopf blendet sie wieder aus")
	client.sync.command_sink = func(cmd): host.sync.receive(1, _wire(cmd))
	var pump := func():
		client.sync.apply_state(_wire(host.sync.snapshot()))
		client.sync.apply_enemies(_wire(host.sync.enemy_packet()))
	host.start_game("hm", 1, "group")
	pump.call()
	check(client.phase == MaulGame.Phase.COUNTDOWN, "Mitspieler sieht den Countdown")
	client.start_game("aldi", 0, "group")
	pump.call()
	check(host.shop_of(1) == "aldi" and client.shop_of() == "aldi", "Mitspieler hat Oldi eröffnet")
	check(not client.hud.setup_visible(), "Filialwahl beim Mitspieler zu")
	var zone: Rect2i = host.map.zones[1].rect
	var cheap := str(MaulData.buyable("aldi")[0].id)
	var spot: Vector2i = _spots(host, zone).filter(func(c): return host.build_problem(cheap, c, 1) == "")[0]
	client.submit({"type": "build", "tower": cheap, "cell": spot})
	pump.call()
	check(host.towers.has(spot) and host.towers[spot].owner_player == 1, "Host baut für den Mitspieler")
	check(client.towers.has(spot), "Mitspieler sieht seinen Tower")
	check(client.players[1].gold == host.players[1].gold, "Gold gleich: %d" % client.players[1].gold)
	client.submit({"type": "build", "tower": cheap, "cell": _spots(host, host.map.zones[0].rect)[0]})
	check(host.towers.size() == 1, "Mitspieler baut nicht im Gebiet des Hosts")
	host.foreign_build = true
	pump.call()
	check(client.foreign_build, "„Überall bauen“ kommt beim Mitspieler an")
	var foreign: Vector2i = _spots(host, host.map.zones[0].rect).filter(func(c): return host.build_problem(cheap, c, 1) == "")[0]
	client.submit({"type": "build", "tower": cheap, "cell": foreign})
	pump.call()
	check(host.towers.has(foreign) and host.towers[foreign].owner_player == 1, "mit „Überall bauen“ baut der Mitspieler im Gebiet des Hosts")
	host.submit({"type": "start_now"})
	for i in 30:
		await get_tree().process_frame
	pump.call()
	check(client.phase == MaulGame.Phase.WAVE and client.level == 1, "Mitspieler sieht Level 1")
	check(client.enemies.size() == host.enemies.size() and client.enemies.size() > 0, "Gegner gespiegelt: %d" % client.enemies.size())
	host.queue_free()
	client.queue_free()
	Session.coop = {}
	await get_tree().process_frame


## Tower-Fähigkeiten: Flash/Neid, Flirten, Life, Bond Of Death (Hellboy); keine offenen "todo" mehr.
func _ability_tests() -> void:
	for s in MaulData.shops() + [MaulData.xpert()]:
		check(s.get("todo", []).is_empty(), "Filiale %s: alle Fähigkeiten umgesetzt %s" % [s.id, s.get("todo", [])])
	var game: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_game("media_markt", 1, "group", true)
	game.level = 1
	var made := {}
	for id in ["o004", "o008", "o02F", "o01Y"]:
		var t := MaulTower.new()
		t.owner_player = 0
		game.board.add_child(t)
		t.setup(game, Vector2i(20 + made.size() * 20, 20), id, 0)
		game.towers[t.cell] = t
		made[id] = t
	for i in 2:
		game._spawn(0)
	var a = game.enemies[0]
	var b = game.enemies[1]
	var cam: MaulTower = made.o004
	a.pos = cam.pos + Vector2(1, 0)
	b.pos = cam.pos + Vector2(0, 1)
	b.armor_type = "hero"
	check(cam._cast(cam.ability("stun_spell")), "Flash gewirkt")
	check(is_equal_approx(a.stun_time, 3.0) and is_equal_approx(b.stun_time, 1.5), "Flash: 3 s, Boss 1,5 s (%.1f/%.1f)" % [a.stun_time, b.stun_time])
	var model: MaulTower = made.o008
	a.stun_time = 0.0
	b.stun_time = 0.0
	b.armor_type = "medium"
	a.pos = model.pos + Vector2(1, 0)
	b.pos = model.pos + Vector2(0, 1)
	a.hp = 100.0
	b.hp = 500.0
	check(model._cast(model.ability("flirt_spell")), "Flirten gewirkt")
	check(is_equal_approx(b.stun_time, 20.0) and a.stun_time == 0.0, "Flirten hält den stärksten 20 s fest")
	var fries: MaulTower = made.o02F
	game.lives = game.max_lives - 100
	var before: int = game.lives
	for i in 300:
		fries._killed(a)
	check(game.lives > before and game.players[0].aok_lives <= 30, "Life: Leben zurück (%d), höchstens 30" % (game.lives - before))
	check(game.cult_heal_at(made.o01Y.pos, 0) == 690.0, "Hellboy: Bond Of Death heilt 690/s")
	game.queue_free()
	await get_tree().process_frame


## Konto, Deutsche Bank und Stammkundin (maul_bank.gd).
func _bank_tests() -> void:
	var game: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_game("tante_emma", 1, "group")
	var me: MaulGame.Player = game.players[0]
	me.gold = 1000
	check(game.submit({"type": "deposit"}) and me.account == 1000 and me.gold == 0, "Einzahlen: 1000 Gold aufs Konto")
	MaulBank.end_level(game)
	check(me.account == 1040, "4 %% Zinsen am Levelende: %d" % me.account)
	check(not game.submit({"type": "bank_upgrade"}), "Bank-Upgrade ohne Gold geht nicht")
	me.gold = 100
	check(game.submit({"type": "bank_upgrade"}) and me.bank_level == 1 and me.gold == 25, "Bank-Upgrade 1 kostet 75")
	check(game.submit({"type": "withdraw"}) and is_equal_approx(me.withdraw_in, 20.0), "Abheben dauert nach Upgrade 20 s")
	check(not game.submit({"type": "withdraw"}), "Zweite Überweisung geht nicht")
	MaulBank.process(game, 19.0)
	check(me.account == 1040 and me.gold == 25, "Nach 19 s noch nicht ausgezahlt")
	MaulBank.process(game, 2.0)
	check(me.account == 0 and me.gold == 1065, "Überweisung ausgezahlt: %d Gold" % me.gold)
	me.account = 10000
	MaulBank.end_level(game)
	check(me.account == 10300, "Zinsen höchstens auf 5000 Gold (6 %%): %d" % me.account)
	me.account = 0
	check(game.submit({"type": "auto_deposit"}) and me.auto_deposit, "Auto-Einzahlen an")
	MaulBank.end_level(game)
	check(me.gold == 0 and me.account == 1065 + floori(1065 * 0.06), "Auto-Einzahlen legt das Gold aufs Konto: %d" % me.account)
	# Stammkundin: Altenheim bauen, dann alle 10 s 10 Gold
	me.gold = 500
	var home := str(MaulBank.emma_cfg().tower)
	var spot: Vector2i = _spots(game, game.map.zones[0].rect).filter(func(c): return game.build_problem(home, c, 0) == "")[0]
	check(game.submit({"type": "build", "tower": home, "cell": spot}), "Altenheim gebaut")
	var gold := me.gold
	MaulBank.process(game, 25.0)
	check(me.gold == gold + 20 and me.emma_mined == 20, "Stammkundin bringt 2 × 10 Gold: %d" % (me.gold - gold))
	# Deutsche Bank: kein Konto, 5 % aller Konten, höchstens 750
	var other := MaulGame.Player.new()
	other.shop = "aldi"
	other.account = 4000
	game.players.append(other)
	me.shop = MaulBank.OWNER
	me.gold = 100
	check(not game.submit({"type": "deposit"}), "Deutsche Bank kann nicht einzahlen")
	MaulBank.end_level(game)
	check(me.account == 0 and me.gold == 100 + 1128 + 200, "Bank zahlt ihr Konto aus und bekommt 5 %% (200): %d" % me.gold)
	other.account = 20000
	check(MaulBank.owner_income(game) == 750, "Ab 15.000 auf allen Konten fest 750 Gold")
	game.queue_free()
	await get_tree().process_frame


## Spielstand (maul_save.gd): Countdown speichert jetzt, mitten im Level der Stand vom Levelbeginn.
func _save_tests() -> void:
	var game: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	check(MaulSave.capture(game).is_empty(), "Vor der Filialwahl kein Spielstand")
	game.start_game("aldi", 2, "group")
	var me: MaulGame.Player = game.players[0]
	me.gold = 5000
	var cheap := str(MaulData.buyable("aldi")[1].id)
	var built := 0
	for a in _spots(game, game.map.zones[0].rect):
		if built < 5 and game.submit({"type": "build", "tower": cheap, "cell": a}):
			built += 1
	me.account = 777
	me.bank_level = 2
	game.lives = 60
	var gold := me.gold
	game._start_level(1)
	check(game.phase == MaulGame.Phase.WAVE, "Level 1 läuft")
	me.gold += 999
	var st: Dictionary = _wire(MaulSave.capture(game))
	check(int(st.sync.level) == 0 and int(st.sync.players[0].gold) == gold, "Mitten im Level: Stand vom Levelbeginn")
	game.queue_free()
	await get_tree().process_frame
	Session.load_state = st
	var loaded: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(loaded)
	await get_tree().process_frame
	var p: MaulGame.Player = loaded.players[0]
	check(loaded.phase == MaulGame.Phase.COUNTDOWN and loaded.countdown >= 10.0, "Geladen: Countdown vor Level 1")
	check(loaded.shop_of() == "aldi" and loaded.difficulty == 2 and loaded.lives == 60, "Filiale, Schwierigkeit, Leben geladen")
	check(loaded.towers.size() == built and p.gold == gold, "%d Tower und %d Gold geladen" % [loaded.towers.size(), p.gold])
	check(p.account == 777 and p.bank_level == 2, "Konto und Bank-Upgrade geladen")
	check(not loaded.hud.setup_visible(), "Keine Filialwahl nach dem Laden")
	loaded.submit({"type": "start_now"})
	for i in 10:
		await get_tree().process_frame
	check(loaded.phase == MaulGame.Phase.WAVE and loaded.level == 1, "Geladenes Spiel startet Level 1")
	loaded.queue_free()
	await get_tree().process_frame


## Geldteilen, Konzernbonus, Teampunkte und Koop-Spielstand.
func _team_tests() -> void:
	Session.coop = {"role": "host", "player": 0, "names": ["Host", "Gast"]}
	var host: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(host)
	Session.coop = {"role": "client", "player": 1, "names": ["Host", "Gast"]}
	var client: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(client)
	await get_tree().process_frame
	client.sync.command_sink = func(cmd): host.sync.receive(1, _wire(cmd))
	var pump := func(): client.sync.apply_state(_wire(host.sync.snapshot()))
	host.start_game("hm", 1, "group", false, false, true)
	pump.call()
	client.start_game("aldi", 0, "group")
	pump.call()
	check(client.share_gold, "Geldteilen kommt beim Mitspieler an")
	check(host.players[0].team_points == 2 and host.players[1].team_points == 1, "Teampunkte: Host 2, Mitspieler 1")
	check(client.players[1].team_points == 1, "Mitspieler sieht seinen Teampunkt")
	# Geldteilen: Kopfgeld gleich verteilt, Rest bleibt im Topf
	var g0: int = host.players[0].gold
	var g1: int = host.players[1].gold
	host._share_bounty(5)
	check(host.players[0].gold == g0 + 2 and host.players[1].gold == g1 + 2 and host.gold_pot == 1, "Geldteilen: 5 Gold → je 2, 1 im Topf")
	host._share_bounty(1)
	check(host.players[0].gold == g0 + 3 and host.gold_pot == 0, "Topf wird ausgezahlt, sobald er reicht")
	# Konzernbonus nur ohne Geldteilen: wer weniger trifft, bekommt mehr
	check(is_equal_approx(host.income_factor(0), 1.0), "Mit Geldteilen kein Konzernbonus")
	host.share_gold = false
	host.players[0].level_kills = 10
	host.players[1].level_kills = 2
	check(is_equal_approx(host.income_factor(0), 1.1) and is_equal_approx(host.income_factor(1), 1.3), "Konzernbonus bei 2 Spielern: 110 %% / 130 %% (%.2f / %.2f)" % [host.income_factor(0), host.income_factor(1)])
	host.share_gold = true
	# Teampunkte einlösen (der Mitspieler über den Host)
	host.lives = host.max_lives
	client.submit({"type": "team", "use": "lives"})
	check(host.players[1].team_points == 1, "Leben voll: kein Teampunkt verbraucht")
	host.lives = host.max_lives - 25
	client.submit({"type": "team", "use": "lives"})
	check(host.lives == host.max_lives - 15 and host.players[1].team_points == 0, "Mitspieler löst +10 Leben ein")
	check(not client.submit({"type": "team", "use": "winter"}) or host.winter_until < host.game_time, "ohne Teampunkt kein Winter")
	check(host.submit({"type": "team", "use": "winter"}) and host.winter_factor() < 0.2, "Host löst Winter ein: Tempo ×%.1f" % host.winter_factor())
	check(host.submit({"type": "team", "use": "sight"}) and host.players[0].team_points == 0, "Host löst Durchblick ein")
	host.submit({"type": "start_now"})
	for i in 20:
		await get_tree().process_frame
	var e: MaulEnemy = host.enemies[0] if not host.enemies.is_empty() else null
	if e != null:
		e.invisible = true
		check(host.is_detected(e), "Durchblick: Unsichtbare angreifbar")
		var before := e.traveled
		for i in 10:
			await get_tree().process_frame
		var slow := e.traveled - before
		host.winter_until = -1.0
		before = e.traveled
		for i in 10:
			await get_tree().process_frame
		check(slow < (e.traveled - before) * 0.5, "Winter bremst die Gegner (%.2f statt %.2f)" % [slow, e.traveled - before])
	pump.call()
	check(client.sight_until > client.game_time - 1.0, "Durchblick kommt beim Mitspieler an")
	host.debug_jump_to_level(10)
	host.spawn_queue.clear()
	host._end_level()
	check(host.players[0].team_points == 1 and host.players[1].team_points == 1, "Nach Level 10: +1 Teampunkt für alle")
	# Koop speichern und laden: Stand vom Levelbeginn bzw. jetzt, Mitspieler behält seine eigenen XP
	host.players[1].gold = 4321
	var st: Dictionary = _wire(MaulSave.capture(host))
	check(not st.is_empty(), "Koop-Spielstand erzeugt")
	host.queue_free()
	client.queue_free()
	await get_tree().process_frame
	Session.coop = {"role": "host", "player": 0, "names": ["Host", "Gast"]}
	Session.load_state = st
	var host2: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(host2)
	Session.coop = {"role": "client", "player": 1, "names": ["Host", "Gast"]}
	var client2: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(client2)
	await get_tree().process_frame
	client2.players[1].xp = 345
	client2.sync.command_sink = func(cmd): host2.sync.receive(1, _wire(cmd))
	client2.sync.apply_state(_wire(host2.sync.snapshot()))
	check(host2.phase == MaulGame.Phase.COUNTDOWN and host2.shop_of(1) == "aldi" and host2.players[1].gold == 4321, "Koop geladen: Phase, Filiale und Gold des Mitspielers")
	check(host2.share_gold and host2.players[1].team_points == 1, "Koop geladen: Geldteilen und Teampunkte")
	check(not client2.hud.setup_visible() and client2.shop_of() == "aldi", "Mitspieler steigt ohne Filialwahl ein")
	check(host2.players[1].xp == 345 and client2.players[1].xp == 345, "Mitspieler behält seine eigenen XP")
	host2.queue_free()
	client2.queue_free()
	Session.coop = {}
	await get_tree().process_frame


## Wie über das Netz: als Bytes und zurück, damit nichts geteilt wird.
func _wire(v):
	return bytes_to_var(var_to_bytes(v))
