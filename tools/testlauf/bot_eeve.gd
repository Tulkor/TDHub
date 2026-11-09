extends "res://tools/testlauf/bot_basis.gd"
## eeveTD-Bot (Schwierigkeit „Mittel“ = Standard, offenes Feld). Food wird zu Barrikaden (Labyrinth), Gold zu
## Element-Towern auf diesen Barrikaden. Items und Marktplatz nutzt er nicht.
## Stufe 1: Barrikaden zufällig am Weg, wertet zufällige Barrikaden zu zufälligen Towern auf, Punkte zufällig.
## Stufe 2: Weg grob länger (bester von 20 Plätzen), Punkte in zwei Elemente, Aufwertung mit bestem Wert je Gold.
## Stufe 3: Weg so lang wie möglich, Tower dort, wo viel Weg in Reichweite ist, Dual-Tower, wenn möglich.
## Stufe 4: wie 3 und spart Gold für die Zinsen (wertet erst auf, wenn ein Level sonst Leben kosten würde).

const DIFF := 2  # „Mittel“

var main_els: Array = []


func play(st: int, sd: int, tempo: float, _args: Dictionary) -> Dictionary:
	stufe = st
	Session.game_kind = "eevetd"
	Session.map_path = "res://data/maps/eeve.json"
	Session.map_override = null
	Session.skip_setup = false
	game = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.rng.seed = sd * 7919 + 13
	game.submit({"type": "setup", "difficulty": DIFF, "field": 0})
	var els: Array = game.ELEMENT_IDS.duplicate()
	els.shuffle()
	main_els = els.slice(0, 2)
	var lives_start: int = game.lives
	Engine.time_scale = tempo
	var frames := 0
	var last := -1
	var lost_before: int = game.lives
	while game.phase < game.Phase.GAME_OVER and frames < 4000000:
		frames += 1
		if game.wave_index != last and game.phase == game.Phase.WAVE:
			last = game.wave_index
			print("LEVEL %d %s  Leben %d  Weg %d  Tower %d/%d  Gold %d  %ds" % [game.wave_index + 1, game.wave_type(game.waves[game.wave_index]) + " " + game._props_text(game.waves[game.wave_index]), game.lives, game.path_length,
					game.food_used(), game.food_cap, game.gold, Time.get_ticks_msec() / 1000])
		if game.phase == game.Phase.BUILD:
			# Bauphase: so lange handeln, bis nichts mehr geht, dann sofort das Level starten
			if not _act():
				game.submit({"type": "start_level"})
		elif frames % 20 == 0:
			_act()
		await get_tree().process_frame
	var leaks := []
	for i in game.waves.size():
		leaks.append(int(game.leaks_per_wave.get(i, 0)))
	var towers := {}
	for t in game.own_towers():
		towers[t.tower_id] = int(towers.get(t.tower_id, 0)) + 1
	return {"sieg": game.phase == game.Phase.VICTORY, "welle": mini(game.wave_index + 1, game.waves.size()),
		"wellen": game.waves.size(), "leben_start": lives_start, "leben": game.lives, "verluste": leaks, "typen": game.waves.map(func(w): return game.wave_type(w)),
		"weglaenge": game.path_length, "tower": towers, "gold": game.gold, "elemente": game.elements.duplicate()}


func _act() -> bool:
	if not game.setup_done or game.phase >= game.Phase.GAME_OVER:
		return false
	var before: int = game.gold
	_spend_points()
	# erst das Labyrinth: jedes freie Food wird eine Barrikade
	var built := 0
	# nicht alles Food auf einmal: höchstens 8 + 2 je Level unbebaute Barrikaden, der Rest des Golds geht in Tower
	var plain: int = game.own_towers().filter(func(t): return t.tower_id == game.BARRICADE).size()
	var cap: int = 8 + 2 * game.wave_index
	while game.food_used() < game.food_cap and game.gold >= game.barricade_cost() and built < 6 and plain + built < cap:
		var n: int = [0, 0, 20, 400, 400][stufe]
		var a := best_block(n, func(c): return game.can_build(c), -4 if stufe == 1 else -2, 3 if stufe == 1 else 1)
		if a == Vector2i(-1, -1) or not game.submit({"type": "build", "cell": a}):
			break
		built += 1
	_upgrade()
	return game.gold != before


func _spend_points() -> void:
	var guard := 0
	while game.points > 0 and guard < 10:
		guard += 1
		var order: Array
		if stufe == 1:
			order = game.ELEMENT_IDS.duplicate()
			order.shuffle()
		else:
			# Hauptelement bis zur Grenze, dann das zweite, dann der Rest
			order = main_els + game.ELEMENT_IDS.filter(func(e): return not main_els.has(e))
			if stufe == 2:
				order = [main_els[game.points % 2], main_els[(game.points + 1) % 2]] + order
		var done := false
		for el in order:
			if game.submit({"type": "element", "element": el}):
				done = true
				break
		if not done:
			break


func _upgrade() -> void:
	var reserve := 0
	if stufe >= 4 and game.phase == game.Phase.BUILD:
		# Zinsen mitnehmen: nur so viel ausgeben, wie über dem Zinspolster liegt, außer es fehlt Schaden
		reserve = 0 if game.wave_index < 8 else int(game.gold * 0.3)
	var base := [0.0, 0.0]
	var need := [1.0, 1.0]
	var now := 0.0
	if stufe >= 3:
		base = _field_power(game.own_towers())
		need = _next_hp(game.wave_index)
		now = _balance_score(base, [0.0, 0.0], need)
	for _i in 4:
		var best_t = null
		var best_o := {}
		var best_i := -1
		var best_s := -INF
		for t in game.own_towers():
			if not is_instance_valid(t):
				continue
			var opts: Array = game.tower_options(t)
			for i in opts.size():
				var o: Dictionary = opts[i]
				if o.action != "eeve_upgrade" or o.get("reason", "") != "" or int(o.cost) > game.gold - reserve:
					continue
				var nd: Dictionary = Database.towers.get(o.id, {}).get("eeve", {})
				if nd.get("market", false):
					continue
				if nd.get("dual_base", false) and stufe < 3:
					continue
				var gain := Wert.value(o.id, 0) - Wert.value(t.tower_id, 0)
				if nd.get("dual_base", false):
					gain = maxf(gain, Wert.value(t.tower_id, 0) * 0.5 + 200.0)
				var s: float
				if stufe == 1:
					s = randf()
				else:
					s = gain / maxf(float(o.cost), 1.0)
					if stufe >= 3:
						# was am meisten zur schwächeren Seite (Boden oder Luft) der nächsten Wellen beiträgt
						var nv := _placed_value(t.cell, o.id, 0)
						var ov := _placed_value(t.cell, t.tower_id, 0)
						s = (_balance_score(base, [nv[0] - ov[0], nv[1] - ov[1]], need) - now) / maxf(float(o.cost), 1.0)
						if nd.get("dual_base", false):
							s = maxf(s, 0.0) + 0.001
					else:
						s *= 1.0 + randf() * 0.5
				if s > best_s:
					best_s = s
					best_t = t
					best_o = o
					best_i = i
		if best_t == null:
			return
		if not game.submit({"type": "option", "tower": game.tower_ref(best_t), "index": best_i, "action": best_o.action, "id": best_o.id}):
			return
