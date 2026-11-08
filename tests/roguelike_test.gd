extends Node
## Lauf: einzeln (Name roguelike)
## Modi: gemtd
## GemTD-Variante Roguelike (rogue.gd): Angebot nach jeder zehnten Welle, Setzen gesperrt bis zur Wahl,
## alle Bonusarten (Werte, Fähigkeiten, Luftabwehr, Elementflächen, globale Boni), eigene Gegnerwerte,
## Fenster, Spielstand und Einstellungen vor Runde 1.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _new_game() -> Node:
	Session.map_path = Database.first_map().path
	Session.map_override = null
	var g: Node = load(Session.GAME).instantiate()
	add_child(g)
	return g


func _free_cell(g: Node) -> Vector2i:
	for y in range(4, g.map.height - 4, 2):
		for x in range(4, g.map.width - 4, 2):
			if g.can_place(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _boon(effect: String, id: String, params := {}, extra := {}) -> Dictionary:
	var b := {"boon": effect, "effect": effect, "id": id, "kind": "global" if id == "" else "gem", "rarity": "common", "params": params, "wave": 10}
	b.merge(extra)
	return b


func _place(g: Node, key: String) -> Tower:
	g.debug_tower = key
	var t: Tower = g.place_gem(_free_cell(g))
	g.debug_tower = ""
	return t


func _enemy(g: Node) -> Enemy:
	var grp: Dictionary = g.waves[0].groups[0].duplicate()
	g._spawn_enemy(grp)
	var e: Enemy = g.enemies[-1]
	e.max_hp = 10000.0
	e.hp = 10000.0
	e.armor = 0.0
	return e


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Session.game_kind = "gemtd"
	check(int(Database.roguelike.get("every", 0)) == 10 and int(Database.roguelike.get("choices", 0)) == 3, "Regeln geladen: alle 10 Wellen 3 Boni")

	# Einstellungen vor Runde 1: Variante Roguelike einschalten
	Session.skip_setup = false
	Session.rogue = false
	var s: Node = _new_game()
	await get_tree().process_frame
	check(s.rogue == null and not s.setup_done, "Klassisch: kein Roguelike vor den Einstellungen")
	check(s.submit({"type": "setup", "difficulty": 1, "score_mode": false, "rogue": true}), "Einstellungen mit Roguelike angenommen")
	check(s.rogue != null and Session.rogue, "Roguelike nach den Einstellungen an")
	s.queue_free()

	Session.skip_setup = true
	Session.rogue = true
	var g: Node = _new_game()
	await get_tree().process_frame
	var r: Rogue = g.rogue
	check(r != null and not r.pending(0), "Roguelike an, vor Welle 1 kein Angebot")

	# Würfeln: nie Fallen, nie doppelt, alle Arten kommen vor, Texte vorhanden
	var ok := true
	var effects := {}
	for i in 400:
		var offer := r.roll(0)
		var seen := {}
		ok = ok and offer.size() == 3
		for o in offer:
			effects[o.effect] = true
			var key: String = o.boon + o.id + str(o.params.get("type", ""))
			ok = ok and not seen.has(key) and Rogue.headline(o) != "" and Rogue.details(o) != ""
			seen[key] = true
			if o.kind != "global":
				var def: Dictionary = Database.towers[o.id]
				ok = ok and str(def.get("kind", "tower")) != "trap" and str(def.get("category", "")) == o.kind
			if o.effect == "anti_air":
				ok = ok and o.id != "amethyst" and Rogue._ground_only(o.id)
			if o.effect == "flask":
				ok = ok and o.kind == "gem" and o.params.has("element")
			if o.effect == "ability":
				ok = ok and not Rogue._has_ability(o.id, str(o.params.type))
	check(ok, "400 Angebote: je 3 verschiedene, keine Fallen, Luftabwehr nur für Bodentower, keine doppelten Fähigkeiten")
	var all_kinds := ["stat", "ability", "anti_air", "flask", "double_pick", "pct_damage", "execute", "explode", "gold", "interest", "luck"]
	check(all_kinds.all(func(k): return effects.has(k)), "alle Bonusarten kommen vor: %s" % [effects.keys()])

	# nach Welle 10: Angebot, Setzen gesperrt, Fenster offen
	g.wave_index = 10
	g._enter_build()
	check(r.pending(0) and r.offers[0].size() == 3, "Nach Welle 10: drei Boni im Angebot")
	check(not g.submit({"type": "place", "cell": _free_cell(g)}), "Gems setzen ist bis zur Wahl gesperrt")
	await get_tree().process_frame
	check(not g.hud.find_children("*", "RoguePanel", true, false).is_empty(), "Auswahlfenster ist offen")
	var o: Dictionary = r.offers[0][1]
	check(not g.submit({"type": "rogue_pick", "index": 1, "id": "falsch", "boon": o.boon}), "Fremdes Angebot wird abgelehnt")
	check(g.submit({"type": "rogue_pick", "index": 1, "id": o.id, "boon": o.boon}), "Bonus gewählt")
	check(not r.pending(0) and r.boons[0].size() == 1 and r.boons[0][0].boon == o.boon and r.boons[0][0].wave == 10, "Bonus gespeichert, Angebot weg")
	for i in 3:
		await get_tree().process_frame
	check(g.hud.find_children("*", "RoguePanel", true, false).is_empty(), "Fenster nach der Wahl zu")
	g.wave_index = 11
	g._enter_build()
	check(not r.pending(0), "Nach Welle 11 kein neues Angebot")

	# Werte, Fähigkeit, Luftabwehr: nur auf den gewählten Tower (alle Stufen)
	r.boons[0] = [
		_boon("stat", "ruby", {}, {"boon": "damage", "stat": "damage", "value": 0.5}),
		_boon("stat", "ruby", {}, {"boon": "speed", "stat": "speed", "value": 0.25}),
		_boon("stat", "ruby", {}, {"boon": "range", "stat": "range", "value": 0.2}),
		_boon("stat", "ruby", {}, {"boon": "damage", "stat": "damage", "value": 0.1}),
		_boon("ability", "ruby", {"type": "poison", "dps_factor": 0.5, "duration": 3.0}),
		_boon("ability", "ruby", {"type": "chain", "count": 2, "radius": 2.5, "factor": 0.75}, {"boon": "bounce"}),
		_boon("anti_air", "diamond"),
	]
	var ruby := _place(g, "ruby:3")
	var topaz := _place(g, "topaz:0")
	var diamond := _place(g, "diamond:1")
	check(is_equal_approx(ruby.rogue_damage, 0.6) and is_equal_approx(ruby.rogue_speed, 0.25) and is_equal_approx(ruby.rogue_range, 0.2),
		"Rubin Stufe 3: +60 % Schaden, +25 % Tempo, +20 % Reichweite (gleiche Boni addieren sich)")
	check(is_equal_approx(ruby.range_cells(), float(ruby.stats.range) * 1.2) and is_equal_approx(ruby.cooldown(), float(ruby.stats.cooldown) / 1.25),
		"Reichweite und Abklingzeit des Rubins mit Bonus")
	var poison := ruby.ability("poison")
	check(not poison.is_empty() and float(poison.dps) > 0.0 and not ruby.ability("chain").is_empty() and ruby._has_projectile_mods(),
		"Rubin hat Gift (%.1f/s aus dem Tower-Schaden) und Abpraller dazu" % float(poison.get("dps", 0)))
	check(topaz.rogue_damage == 0.0 and topaz.ability("poison").is_empty(), "Topas bekommt nichts")
	check(diamond.target_mode() == "both" and Database.tower_tier("diamond", 1).get("targets", Database.towers.diamond.get("targets")) == "ground",
		"Luftabwehr: Diamant greift auch Flieger an")
	check(str(TowerStats.view(ruby).tiles).contains(tr("Roguelike-Bonus")), "Infofenster zeigt den Roguelike-Bonus")
	ruby.owner_player = 1
	g._update_auras()
	check(ruby.rogue_damage == 0.0 and ruby.ability("poison").is_empty(), "Boni gelten nur für eigene Tower")
	ruby.owner_player = 0
	g._update_auras()

	# Elementflächen: jede Wirkung einmal
	var el: Dictionary = Rogue.boon_def("flask").elements
	var e := _enemy(g)
	var hp0 := e.hp
	var fire := {"params": el.ruby, "tower": ruby, "dps": 100.0}
	r._on_patch(e, fire, 0.5)
	check(is_equal_approx(hp0 - e.hp, 100.0), "Feuerfläche: doppelter Schaden ohne Rüstung (%.0f)" % (hp0 - e.hp))
	e.armor = 5.0
	hp0 = e.hp
	r._on_patch(e, fire, 0.5)
	check(is_equal_approx(hp0 - e.hp, 50.0), "Feuerfläche: einfacher Schaden mit Rüstung")
	r._on_patch(e, {"params": el.emerald, "tower": ruby, "dps": 20.0}, 0.1)
	hp0 = e.hp
	for i in 10:
		r._tick_states(0.5)
	check(e.hp < hp0 and e.armor_reduction > 2.0, "Giftfläche: Gift wirkt nach und frisst Rüstung (%.1f)" % e.armor_reduction)
	for i in 4:
		r._on_patch(e, {"params": el.sapphire, "tower": ruby, "dps": 0.0}, 0.5)
		r._tick_states(0.5)
	check(e.slow_factor > 0.0 and e.stun_time > 0.0, "Frostfläche: verlangsamt und friert nach einer Weile ein")
	r._on_patch(e, {"params": el.diamond, "tower": ruby, "dps": 0.0}, 0.1)
	r._on_patch(e, {"params": el.opal, "tower": ruby, "dps": 0.0}, 0.1)
	r._tick_states(0.1)
	check(is_equal_approx(e.crit_mark, 0.2) and is_equal_approx(e.damage_taken, 1.15), "Diamantstaub +20 % Krit-Chance, Opalnebel +15 % Schaden")
	hp0 = e.hp
	e.take_raw_damage(100.0)
	check(is_equal_approx(hp0 - e.hp, 115.0), "Verwundbar: 115 statt 100 Schaden")
	r._tick_states(10.0)
	check(e.crit_mark == 0.0 and e.damage_taken == 1.0, "Schwachstelle und Verwundbar laufen aus")
	e.stun_time = 0.0
	r._on_patch(e, {"params": el.topaz, "tower": ruby, "dps": 0.0}, 0.1)
	r._tick_states(0.1)
	check(e.stun_time > 0.0, "Blitzfeld: Ministun")
	e.stun_time = 0.0
	r._tick_states(1.6)
	check(e.stun_time > 0.0, "Blitzfeld: nächster Ministun nach dem Abstand")

	# Treffer-Wirkungen: Fläche legen, Prozentschaden, Henker
	r.boons[0].append(_boon("flask", "ruby", Rogue._scaled(el.ruby.merged({"radius": 0.9, "duration": 4.0, "cooldown": 2.5}), 1.0)))
	r.boons[0].append(_boon("pct_damage", "", {"pct": 0.01, "boss_factor": 0.25}))
	g._update_auras()
	hp0 = e.hp
	r.on_hit(ruby, e)
	check(r.patches.size() == 1 and is_equal_approx(hp0 - e.hp, e.max_hp * 0.01 * e.damage_taken), "Treffer legt eine Feuerfläche und macht 1 % der max. Leben")
	r.on_hit(ruby, e)
	check(r.patches.size() == 1, "Fläche erst wieder nach der Abklingzeit")
	r.boons[0].append(_boon("execute", "", {"chance": 1.0, "boss_pct": 0.05}))
	g._update_auras()
	r.on_hit(ruby, e)
	check(e.dead, "Henker: Gegner sofort tot")
	g.phase = g.Phase.WAVE
	var e3 := _enemy(g)
	e3.place_on_path(0.0)
	r._add_patch(e3.pos, r.boons[0][-3].params, ruby)
	hp0 = e3.hp
	r._process(0.5)
	check(e3.hp < hp0 and r.patches[-1].left < 4.0, "Feuerfläche brennt im Wellenablauf")
	r.on_kill(e3)
	r._process(0.1)
	g.phase = g.Phase.BUILD
	r.clear_field()
	check(r.patches.is_empty(), "Flächen verschwinden zum Wellenende")

	# Globale Boni: Gold, Glück, Zinsen, Kettenreaktion
	r.boons[0] = [_boon("gold", "", {"bonus": 0.2}), _boon("luck", "", {"levels": 1}), _boon("interest", "", {"rate": 0.1, "max": 5}),
		_boon("explode", "", {"pct": 0.2, "radius": 1.5})]
	check(is_equal_approx(r.gold_factor(0), 1.2) and r.luck(0) == 1, "Goldader +20 %, Glückssträhne +1 Chance-Stufe")
	var e2 := _enemy(g)
	e2.last_hit_by = 0
	r.on_kill(e2)
	check(r._booms.size() == 1 and is_equal_approx(r._booms[0].dmg, e2.max_hp * 0.2), "Kettenreaktion vorgemerkt")
	r._booms.clear()
	for x in g.enemies.duplicate():
		g._remove_enemy(x)
	g.players[0].gold = 100
	g.wave_index = 11
	g._enter_build()
	check(g.players[0].gold == 105, "Zinsen 10 %%, höchstens 5: %d Gold" % g.players[0].gold)

	# Doppelfund: in jeder dritten Auswahlphase zwei Gems behalten
	r.boons[0] = [_boon("double_pick", "", {"every": 3})]
	g.wave_index = 14   # Welle 15
	g._enter_build()
	check(r.extra_keeps_left(0) == 1, "Doppelfund: in Runde 15 ein Gem mehr")
	for i in g.gems_per_round():
		g.place_gem(_free_cell(g))
	var first: Tower = g.round_towers[0]
	g._select(first)
	g._on_option_chosen(0)
	check(g.stage() == g.Phase.CHOOSE and not first.is_new and g.round_towers.size() == 4, "Erster Gem behalten, die anderen bleiben zur Wahl")
	g._select(g.round_towers[0])
	g._on_option_chosen(0)
	check(g.stage() != g.Phase.CHOOSE and g.round_towers.is_empty(), "Zweiter Gem behalten beendet die Runde")
	for x in g.enemies.duplicate():
		g._remove_enemy(x)
	g.phase = g.Phase.BUILD

	# Gegnerwerte im Roguelike
	var late := ""
	for id in Database.roguelike_enemies.enemies:
		if int(Database.roguelike_enemies.enemies[id].get("hp", 0)) != int(Database.enemies[id].get("hp", 0)):
			late = id
			break
	check(late != "" and g.enemy_def(late).hp == Database.roguelike_enemies.enemies[late].hp and Database.enemies[late].hp != g.enemy_def(late).hp,
		"Eigene Gegnerwerte im Roguelike (%s)" % late)

	# Spielstand: Boni und offenes Angebot bleiben
	r.boons[0] = [_boon("stat", "ruby", {}, {"boon": "damage", "stat": "damage", "value": 0.6})]
	g.wave_index = 20
	g._enter_build()
	var a: Dictionary = SaveGame.capture(g)
	check(a.has("rogue") and a.rogue.boons[0].size() == 1 and a.rogue.offers[0].size() == 3, "Spielstand enthält Boni und Angebot")
	Session.rogue = false
	Session.load_state = a.duplicate(true)
	var g2: Node = _new_game()
	await get_tree().process_frame
	check(g2.rogue != null and Session.rogue and g2.rogue.boons[0].size() == 1 and g2.rogue.pending(0), "Geladenes Spiel: Roguelike, Boni und Angebot wieder da")
	var r2: Tower = null
	for t in g2.all_towers():
		if t.tower_id == "ruby":
			r2 = t
	check(r2 != null and is_equal_approx(r2.rogue_damage, 0.6), "Geladener Rubin hat seinen Bonus")
	Session.load_state = {}
	Session.rogue = false
	_finish()


func _finish() -> void:
	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
