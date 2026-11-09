extends "res://tools/testlauf/bot_basis.gd"
## YouTD-Bot (Modus „Zufall mit Aufwertungen“, Länge „Voll“, Schwierigkeit „Mittel“, solo, ohne Baumeister und
## Weisheit, Spieler-Level 0). Items legt er nicht ein, Zauber nutzt er nicht (Autocasts laufen von selbst).
## Stufe 1: erforscht zufällige Elemente, baut zufällige Tower aus dem Lager an zufällige Plätze am Weg.
## Stufe 2: zwei Elemente, baut den stärksten Tower je Gold an den Weg, wertet nicht auf.
## Stufe 3: zwei Elemente, Plätze mit viel Weg in Reichweite, wertet Tower auf, wenn das je Gold mehr bringt.
## Stufe 4: wie 3, legt Items aus dem Lager in die stärksten Tower.

var main_els: Array = []


func play(st: int, sd: int, tempo: float, args: Dictionary) -> Dictionary:
	stufe = st
	Session.game_kind = "youtd"
	Session.map_path = "res://data/maps/youtd.json"
	Session.map_override = null
	Session.skip_setup = false
	game = load("res://scenes/youtd_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.rng.seed = sd * 7919 + 13
	game.submit({"type": "setup", "mode": 0, "length": int(args.get("laenge", 1)), "difficulty": 2, "seed": sd * 101 + 7})
	var els: Array = game.elements.keys()
	els.shuffle()
	main_els = els.slice(0, 2)
	var lives_start := float(game.portal)
	Engine.time_scale = tempo
	var frames := 0
	var last := -1
	var leaks := {}
	var portal_at := float(game.portal)
	while game.phase < game.Phase.GAME_OVER and frames < 8000000:
		frames += 1
		var w: int = game.current_wave()
		if w != last:
			if last >= 1:
				leaks[last - 1] = portal_at - float(game.portal)
			portal_at = float(game.portal)
			last = w
			print("WELLE %d  Portal %.0f  Tower %d  Gold %d  Bücher %d  %ds" % [w, game.portal, game.own_towers().size(),
					game.gold, game.tomes, Time.get_ticks_msec() / 1000])
		if frames % 15 == 0:
			_act()
		await get_tree().process_frame
	leaks[last - 1] = portal_at - float(game.portal)
	var list := []
	for i in game.max_wave():
		list.append(snappedf(float(leaks.get(i, 0.0)), 0.1))
	var towers := {}
	for t in game.own_towers():
		var n := str(YoutdData.tower(t.yid).get("name", t.yid))
		towers[n] = int(towers.get(n, 0)) + 1
	return {"sieg": game.phase == game.Phase.VICTORY, "welle": mini(game.current_wave(), game.max_wave()),
		"wellen": game.max_wave(), "leben_start": lives_start, "leben": game.portal, "verluste": list,
		"tower": towers, "gold": game.gold, "elemente": game.elements.duplicate()}


func _stats(id: String) -> Dictionary:
	var d := YoutdData.tower(id)
	return {"damage": d.get("damage", [0, 0]), "cooldown": d.get("cooldown", 1.0), "range": float(d.get("range", 800)) / 64.0}


func _val(id: String) -> float:
	return Wert.value_of(_stats(id), str(YoutdData.tower(id).get("targets", "both")))


func _act() -> void:
	if not game.setup_done or game.phase >= game.Phase.GAME_OVER:
		return
	# Elemente erforschen
	for _i in 3:
		var order: Array = game.elements.keys()
		order.shuffle()
		if stufe >= 2:
			order = main_els.duplicate()
			order.sort_custom(func(a, b): return int(game.elements[a]) < int(game.elements[b]))
		var done := false
		for el in order:
			if game.submit({"type": "research", "element": el}):
				done = true
				break
		if not done:
			break
	if game.stash.is_empty() and game.own_towers().is_empty():
		game.submit({"type": "roll"})
	# bauen
	for _i in 3:
		var can: Array = game.buildable().filter(func(id): return game.build_reason(id) == "")
		if can.is_empty():
			break
		var id: String = can[randi() % can.size()]
		if stufe >= 2:
			can.sort_custom(func(a, b): return _val(a) / maxf(float(YoutdData.tower(a).cost), 1.0) > _val(b) / maxf(float(YoutdData.tower(b).cost), 1.0))
			id = can[0]
		var ok := func(c): return game.can_build(c)
		var a: Vector2i
		if stufe == 1:
			a = best_block(0, ok, -6, 5)
		else:
			a = best_spot(200, ok, _stats(id).range, 1.0)
		if a == Vector2i(-1, -1) or not game.submit({"type": "build", "id": id, "cell": a}):
			break
	# aufwerten
	if stufe >= 3:
		var best_s := 0.0
		var best_t = null
		var best_i := -1
		var best_o := {}
		for t in game.own_towers():
			var opts: Array = game.tower_options(t)
			for i in opts.size():
				var o: Dictionary = opts[i]
				if o.action != "upgrade" or o.reason != "":
					continue
				var s := (_val(o.id) - _val(t.yid)) / maxf(float(o.cost), 1.0)
				if s > best_s:
					best_s = s
					best_t = t
					best_i = i
					best_o = o
		if best_t != null:
			game.submit({"type": "option", "tower": game.tower_ref(best_t), "index": best_i, "action": best_o.action, "id": best_o.id})
	if stufe >= 4 and not game.item_stash.is_empty():
		var strongest = null
		for t in game.own_towers():
			if strongest == null or _val(t.yid) > _val(strongest.yid):
				strongest = t
		if strongest != null:
			var it = game.item_stash[0]
			game.submit({"type": "item_put", "tower": game.tower_ref(strongest), "uid": it.get_uid()})
