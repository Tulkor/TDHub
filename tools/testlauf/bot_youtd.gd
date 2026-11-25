extends "res://tools/testlauf/bot_basis.gd"
## YouTD-Bot (Modus „Zufall mit Aufwertungen“, Länge „Voll“, Schwierigkeit „Mittel“, solo, ohne Baumeister und
## Weisheit, Spieler-Level 0). Items legt er nicht ein, Zauber nutzt er nicht (Autocasts laufen von selbst).
## Stufe 1: erforscht zufällige Elemente, baut zufällige Tower aus dem Lager an zufällige Plätze am Weg.
## Stufe 2: zwei Elemente, baut den stärksten Tower je Gold an den Weg, wertet nicht auf.
## Stufe 3: wie 2, wertet aber Tower auf (ab Welle 10 möglich) und spart dafür, wenn eine Aufwertung je Gold mehr
##   bringt als ein neuer Tower.
## Stufe 4: wie 3, legt Items aus dem Lager in die stärksten Tower.

var main_els: Array = []


func play(st: int, sd: int, tempo: float, args: Dictionary) -> Dictionary:
	stufe = st
	await start(sd, args)
	var els: Array = game.elements.keys()
	els.shuffle()
	main_els = els.slice(0, 2)
	if geladen:
		# aus dem Checkpoint: mit den Elementen weitermachen, in die schon investiert ist
		els.sort_custom(func(a, b): return int(game.elements.get(a, 0)) > int(game.elements.get(b, 0)))
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
	wurf()
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
	# Stufe 3+: lohnt eine Aufwertung (je Gold) mehr als ein neuer Tower, wird dafür gespart statt gebaut
	# (sonst geht jedes Gold sofort in neue Tower, und Stufe 3 spielte wie Stufe 2)
	var save_up := false
	if stufe >= 3 and game.own_towers().size() >= 4:
		var up := _best_upgrade()
		if not up.is_empty() and up.s >= _best_build_ratio() * 0.9:
			save_up = true
	# bauen
	for _i in (0 if save_up else 3):
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
		var up := _best_upgrade()
		if not up.is_empty() and int(up.o.cost) <= game.gold:
			game.submit({"type": "option", "tower": game.tower_ref(up.t), "index": up.i, "action": up.o.action, "id": up.o.id})
	if stufe >= 4 and not game.item_stash.is_empty():
		var strongest = null
		for t in game.own_towers():
			if strongest == null or _val(t.yid) > _val(strongest.yid):
				strongest = t
		if strongest != null:
			var it = game.item_stash[0]
			game.submit({"type": "item_put", "tower": game.tower_ref(strongest), "uid": it.get_uid()})


## Beste Aufwertung im Feld, die nur am Gold scheitert: {t, i, o, s} mit s = Stärkegewinn je Gold, leer wenn keine.
func _best_upgrade() -> Dictionary:
	var best := {}
	for t in game.own_towers():
		var opts: Array = game.tower_options(t)
		for i in opts.size():
			var o: Dictionary = opts[i]
			if o.action != "upgrade" or (o.reason != "" and o.reason != tr("zu wenig Gold")):
				continue
			var sc := (_val(o.id) - _val(t.yid)) / maxf(float(o.cost), 1.0)
			if sc > 0.0 and (best.is_empty() or sc > best.s):
				best = {"t": t, "i": i, "o": o, "s": sc}
	return best


## Stärke je Gold des besten Towers, der gerade gebaut werden könnte (ohne aufs Gold zu schauen).
func _best_build_ratio() -> float:
	var r := 0.0
	for id in game.buildable():
		r = maxf(r, _val(id) / maxf(float(YoutdData.tower(id).cost), 1.0))
	return r


## Spiel anlegen und einstellen (Schwierigkeit diff, Aufstieg), ohne zu spielen; auch für druck.gd.
func start(sd: int, args: Dictionary) -> void:
	Session.game_kind = "youtd"
	Session.map_path = "res://data/maps/youtd.json"
	Session.map_override = null
	Session.skip_setup = false
	cp_vormerken()
	game = load("res://scenes/youtd_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.rng.seed = sd * 7919 + 13
	if not geladen:
		game.submit({"type": "setup", "mode": 0, "length": int(args.get("laenge", 1)), "difficulty": diff_index("youtd"), "seed": sd * 101 + 7,
				"ascension": aufstieg})
	take_ascension()
