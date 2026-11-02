extends "res://tools/testlauf/bot_basis.gd"
## Randgruppen-TD-Bot (Schwierigkeit „Normal“, 25 Leben, eine zufällige Rasse je Lauf, solo).
## Stufe 1: kauft zufällige bezahlbare Tower und stellt sie irgendwo an den Weg.
## Stufe 2: Weg grob länger (bester von 20 Plätzen), kauft den Tower mit dem besten Schaden je Gold.
## Stufe 3: jeder Tower wird Teil des Labyrinths (Weg so lang wie möglich), billige Tower als Füller, wenn genug
##   Schaden steht, baut die übrigen Sorten und den Endtower, sobald Holz da ist.
## Stufe 4: wie 3, spart aber auf teure Tower, statt das Gold sofort in billige zu stecken.

var race_id := ""


func play(st: int, sd: int, tempo: float, args: Dictionary) -> Dictionary:
	stufe = st
	Session.game_kind = "randgruppen"
	Session.map_override = null
	Session.skip_setup = false
	game = load(Session.RG_GAME if "RG_GAME" in Session else "res://scenes/rg_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.rng.seed = sd * 7919 + 13
	var races: Array = game.rules.get("races", []).map(func(r): return str(r.id))
	race_id = str(args.get("rasse", races[sd % races.size()]))
	game.submit({"type": "setup", "race": race_id, "difficulty": 2})
	var lives_start: int = game.lives
	Engine.time_scale = tempo
	var frames := 0
	var last := -1
	while game.phase < game.Phase.GAME_OVER and frames < 4000000:
		frames += 1
		if game.wave_index != last and game.phase == game.Phase.WAVE:
			last = game.wave_index
			print("LEVEL %d %s  Leben %d  Weg %d  Tower %d  Gold %d  %ds" % [game.wave_index + 1, game.wave_type(game.waves[game.wave_index]), game.lives, game.path_length,
					game.own_towers().size(), game.gold, Time.get_ticks_msec() / 1000])
			if OS.get_environment("TL_DEBUG") != "":
				print("  Bahnen ", _lanes(), " Weg ", _path_cells().size(), " Abdeckung ", game.own_towers().map(func(t): return [t.cell, _coverage(t, t.tower_id, 0)]))
		if game.phase == game.Phase.BUILD:
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
		"weglaenge": game.path_length, "tower": towers, "gold": game.gold, "rasse": race_id}


func _cost(id: String) -> int:
	return int(Database.towers[id].rg.cost)


## Ein Kauf; false, wenn nichts mehr geht.
func _act() -> bool:
	if not game.setup_done or game.phase >= game.Phase.GAME_OVER:
		return false
	var all: Array = game.race_towers()
	var can: Array = all.filter(func(id): return game.build_reason(id) == "")
	if can.is_empty():
		return false
	var id := ""
	var maze := false
	if stufe == 1:
		id = can[randi() % can.size()]
	else:
		var have: Array = game.own_towers().map(func(t): return t.tower_id)
		var ult: Array = all.filter(func(x): return Database.towers[x].rg.get("ultimate", false))
		if stufe >= 3 and game.lumber > 0 and not ult.is_empty():
			# Endtower: erst die fehlenden Sorten, dann ihn selbst
			if can.has(ult[0]):
				id = ult[0]
			else:
				for x in all:
					if x != ult[0] and not have.has(x):
						if can.has(x):
							id = x
						break
		if id == "":
			var cheapest: String = all[0]
			for x in all:
				if _cost(x) < _cost(cheapest):
					cheapest = x
			# Labyrinth: billige Tower, solange sie den Weg spürbar verlängern (höchstens ein Drittel der Tower)
			# Labyrinth erst, wenn genug Schaden für die nächste Welle steht (doppelte Reserve)
			var pw := _field_power(game.own_towers())
			var need := _next_hp(game.wave_index)
			var strong: bool = pw[0] / need[0] > 2.0 and pw[1] / need[1] > 1.0
			if stufe >= 3 and can.has(cheapest) and strong and have.count(cheapest) * 2 <= have.size() + 4:
				id = cheapest
				maze = true
			else:
				var best_r := 0.0
				for x in all:
					if not x in ult:
						best_r = maxf(best_r, Wert.value(x, 0) / _cost(x))
				var best_c := -1
				for x in can:
					var r := Wert.value(x, 0) / _cost(x)
					if stufe == 2:
						if r >= best_r * 0.99 or id == "" or r > Wert.value(id, 0) / _cost(id):
							id = x
					elif r >= best_r * 0.7 and _cost(x) > best_c:
						id = x
						best_c = _cost(x)
				if id == "":
					for x in can:
						if not x in ult and (id == "" or Wert.value(x, 0) / _cost(x) > Wert.value(id, 0) / _cost(id)):
							id = x
				if stufe >= 4 and id != "":
					# sparen, wenn ein deutlich besserer Tower bald bezahlbar ist
					for x in all:
						if _cost(x) > _cost(id) and _cost(x) <= game.gold * 2 and Wert.value(x, 0) / _cost(x) >= Wert.value(id, 0) / _cost(id) and not x in ult:
							if game.phase == game.Phase.BUILD:
								return false
				if id == "":
					return false
	var ok := func(c): return game.can_build_tower(id, c)
	var a := Vector2i(-1, -1)
	if stufe == 1:
		a = best_block(0, ok, -4, 3)
	elif stufe == 2:
		a = best_block(20, ok)
	else:
		# jeder Tower ist Teil des Labyrinths: dorthin, wo der Weg am längsten wird (Tower stehen dann am Weg)
		a = best_block(400, ok)
	if a == Vector2i(-1, -1):
		return false
	return game.submit({"type": "build", "id": id, "cell": a})
