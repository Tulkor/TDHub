extends Node
## Lauf: einzeln (Name survivors)
## Modi: survivors
## Tower Survivors: Daten, Start, Laden (Kaufen, Stufe hoch, Verkaufen, Neu würfeln), Upgrades,
## jede Waffe trifft, Bonus-Wahl, Bot-Lauf bis zum Ende (Einfach und Schwer), Eintrag im Profil.
## Balance genauer: tools/survivors_sim.tscn (mehrere Läufe je Stufe).

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	Profile.dir = "user://test_survivors_profile"
	Profile.reset_cache()
	_data()
	await _basics()
	await _all_weapons()
	await _bot_run(0)
	await _bot_run(2)
	print("FERTIG, Fehler: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _data() -> void:
	var cfg = Database.load_json(SvGame.DATA)
	check(cfg is Dictionary, "survivors.json lädt")
	check(Database.mode("survivors").get("scene", "") == "res://scenes/survivors_game.tscn", "Modus in modes.json")
	var kinds := ["bullet", "lob", "beam", "line", "cone", "nova"]
	var per_rarity := {}
	for w in cfg.weapons:
		check(cfg.rarities.has(w.rarity) and cfg.damage_types.has(w.type) and kinds.has(w.kind), "Waffe %s: Seltenheit, Art, Typ gültig" % w.id)
		check(not w.get("model", []).is_empty(), "Waffe %s hat ein Modell" % w.id)
		per_rarity[w.rarity] = int(per_rarity.get(w.rarity, 0)) + 1
	check(per_rarity.size() == 4, "alle 4 Seltenheiten haben Waffen")
	var types := {}
	for w in cfg.weapons:
		types[w.type] = true
	check(types.size() == 5, "alle 5 Schadensarten kommen vor")


func _new_game(diff: int) -> SvGame:
	Session.skip_setup = true
	Session.difficulty = diff
	var g: SvGame = load("res://scenes/survivors_game.tscn").instantiate()
	g.fixed_seed = 7  # vor _ready, sonst hängt der Bot-Lauf vom Zufall ab (in CI einmal nur bis Welle 9)
	add_child(g)
	g.set_physics_process(false)
	await get_tree().process_frame
	return g


func _basics() -> void:
	var g := await _new_game(1)
	check(g.state == "play" and g.wave == 1, "Spiel startet in Welle 1")
	check(g.weapons[0] != null and g.weapons[0].id == "mg", "Startwaffe auf Platz 1")
	check(g.platform.pads[0].mount.get_child_count() == 1, "Startwaffe ist auf der Plattform zu sehen")
	check(g.platform.pads[4].state == "locked" and g.platform.pads[1].state == "free", "Plätze 4–6 gesperrt, 2–3 frei")
	check(g.platform.pads[0].phase == "opening" and not g.platform.is_up(0), "Klappe geht auf, Waffe noch unten")
	for i in 40:
		g.step(1.0 / 30.0)
	check(g.platform.is_up(0) and is_equal_approx(g.platform.pads[0].lift.position.y, 0.0), "Waffe nach gut 1 s oben")
	check(g.platform.pads[0].halves[0].node.position.y < -0.1, "Klappenhälften versenkt")
	# Kaufen: gleiche Waffe hebt die Stufe, andere Waffe geht auf einen freien Platz
	g.gold = 5000
	g.offers = ["mg", "kanone", "tesla", "laser"]
	check(g.buy_offer(0) and g.weapons[0].level == 2, "MG nochmal kaufen: Stufe 2")
	check(g.platform.pads[0].pips.get_child_count() == 2, "zwei Stufen-Lämpchen")
	check(g.buy_offer(1) and g.weapons[1] != null and g.weapons[1].id == "kanone", "Kanone auf Platz 2")
	check(g.buy_offer(2) and g.weapons[2] != null, "Teslaspule auf Platz 3")
	check(g.target_slot("laser") == -1 and not g.buy_offer(3), "ohne freien Platz kein Kauf")
	check(g.buy_upgrade("slot") and g.slots_open == 4 and g.platform.pads[3].state == "free", "Montageplatz öffnet Platz 4")
	check(g.buy_offer(3) and g.weapons[3].id == "laser", "Laserlanze auf Platz 4")
	var before: float = g.weapons[0].dps()
	check(g.buy_upgrade("damage") and g.weapons[0].dps() > before, "Schaden-Upgrade erhöht DPS")
	var hp_before := g.max_hp()
	check(g.buy_upgrade("hull") and g.max_hp() > hp_before and is_equal_approx(g.hp, g.max_hp()), "Hülle: mehr Leben")
	var gold_before := g.gold
	for i in 40:
		g.step(1.0 / 30.0)
	g.sell(1)
	check(g.weapons[1] == null and g.gold > gold_before and g.platform.pads[1].phase == "lowering", "Verkaufen gibt Gold, Waffe fährt runter")
	for i in 40:
		g.step(1.0 / 30.0)
	check(g.platform.pads[1].mount.get_child_count() == 0 and g.platform.pads[1].phase == "closed", "danach Platz leer, Klappe zu")
	check(g.reroll() and g.rerolls == 1, "Neu würfeln")
	# Wellen laufen, Gegner kommen, Bonus nach Welle 5
	g.gold = 0
	for i in 30 * 30:
		g.step(1.0 / 30.0)
	check(g.wave == 2, "nach 30 s Welle 2")
	check(g.kills > 0, "Waffen töten Gegner (%d)" % g.kills)
	g.wave = 5
	g.wave_time = 29.99
	g.step(0.05)
	check(g.state == "perk" and g.perk_choice.size() == 3, "nach Welle 5: drei Boni zur Wahl")
	var perk: String = g.perk_choice[0]
	g.choose_perk(0)
	check(g.state == "play" and g.wave == 6 and g.perks.has(perk), "Bonus gewählt, Welle 6 läuft")
	g.queue_free()
	await get_tree().process_frame


## Jede Waffe einzeln gegen einen Gegner vor dem Turm: Schaden kommt an.
func _all_weapons() -> void:
	var g := await _new_game(1)
	g.spawn_queue.clear()
	g.sell(0)
	for w in g.cfg.weapons:
		for e in g.enemies.duplicate():
			g.enemies.erase(e)
			e.queue_free()
		g.platform.clear(0)
		g._equip(str(w.id), 0)
		var sw: SvWeapon = g.weapons[0]
		var pos := sw.origin()
		g._spawn("brocken", atan2(pos.z, pos.x))
		var e: SvEnemy = g.enemies[0]
		e.max_hp = 1e6
		e.hp = 1e6
		e.speed = 0.0
		# vor den Montageplatz stellen, innerhalb jeder Reichweite
		var dir := Vector3(pos.x, 0, pos.z).normalized()
		e.position = dir * 4.5
		for i in 120:
			g.step(1.0 / 30.0)
		check(sw.damage_done > 0.0, "%s trifft (%d Schaden in 4 s)" % [w.id, roundi(sw.damage_done)])
		g.sell(0)
	g.queue_free()
	await get_tree().process_frame


## Bot spielt alle Wellen (oder bis der Turm fällt), am Ende steht der Run im Profil.
func _bot_run(diff: int) -> void:
	var g := await _new_game(diff)
	var runs_before := Profile.runs("survivors").size()
	var k := 0
	while g.state != "over" and k < 30 * 60 * 30:
		g.step(1.0 / 30.0)
		k += 1
		if k % 15 == 0:
			g.bot_turn()
	print("     Bot auf %s: Welle %d, %s, Kills %d, Leben %d, Waffen %s, Boni %s" % [g.cfg.difficulties[diff].name, g.wave,
		"Sieg" if g.state == "over" and g.hp > 0 else "Niederlage", g.kills, roundi(g.hp),
		", ".join(g.weapons.filter(func(w): return w != null).map(func(w): return "%s %d" % [w.id, w.level])), ", ".join(g.perks)])
	check(g.state == "over", "Lauf endet (%s)" % g.cfg.difficulties[diff].name)
	check(g.wave >= 10, "Bot kommt mindestens bis Welle 10")
	check(Profile.runs("survivors").size() == runs_before + 1, "Run steht im Profil")
	g.queue_free()
	await get_tree().process_frame
