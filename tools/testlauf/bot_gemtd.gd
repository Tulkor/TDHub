extends "res://tools/testlauf/bot_basis.gd"
## GemTD-Bot für Testläufe (klassische Map, Normal, Leben-Wertung).
## Stufe 1 „Gelegenheit“: Gems irgendwo nahe am Weg, kein Labyrinth, behält den stärksten Gem, kombiniert nichts.
## Stufe 2 „Solide“: baut den Weg grob länger (bester von 20 zufälligen Plätzen), behält das Beste inkl. 2/4 gleiche
##   und angebotener Rezepte, wertet Spezial-Tower mit Gold auf, plant aber keine Rezepte über mehrere Runden.
## Stufe 3 „Gut“: jeder Gem dorthin, wo der Weg am längsten wird, plant Rezepte über mehrere Runden (behält Zutaten),
##   kombiniert im Feld während der Welle, behält bevorzugt Tower mit viel Weg in Reichweite und achtet auf genug Luftabwehr.
## Stufe 4 „Sehr gut“: wie 3, baut auf ein vorab berechnetes Labyrinth hin (classic_plan.txt = Maze 1 „Weglänge“
##   aus tools/maze, 200 Steine) und kauft
##   mit übrigem Gold die Extra Chance.

const PLAN := "res://tools/testlauf/classic_plan.txt"

var plan: Array = []
var air_weight := 1.0
var log_waves: Array = []


func play(st: int, sd: int, tempo: float, args: Dictionary) -> Dictionary:
	stufe = st
	Session.game_kind = "gemtd"
	Session.map_path = str(args.get("map", "res://data/maps/classic.json"))
	Session.map_override = null
	Session.skip_setup = true
	game = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.rng.seed = sd * 7919 + 13
	if stufe >= 4:
		_load_plan()
	var lives_start: int = game.lives
	Engine.time_scale = tempo
	var frames := 0
	var last_wave := -1
	var wave_timer := 0
	while game.phase < game.Phase.GAME_OVER and frames < 4000000:
		frames += 1
		if game.phase == game.Phase.WAVE:
			if game.wave_index != last_wave:
				last_wave = game.wave_index
				print("WELLE %d %s  Leben %d  Weg %d  Tower %d  Gold %d  %ds" % [game.wave_index + 1, game.wave_type(game.waves[game.wave_index]), game.lives,
						game.path_length, game.own_towers().size(), game.gold, Time.get_ticks_msec() / 1000])
			wave_timer += 1
			if stufe >= 2 and wave_timer % 30 == 0:
				_wave_actions()
			await get_tree().process_frame
			continue
		wave_timer = 0
		if game.stage() == game.Phase.BUILD and game.gems_left() > 0:
			_place_one()
		elif game.stage() == game.Phase.CHOOSE:
			_choose()
			await get_tree().process_frame
		else:
			await get_tree().process_frame
	var leaks := []
	for i in game.waves.size():
		leaks.append(int(game.leaks_per_wave.get(i, 0)))
	var towers := []
	for t in game.own_towers():
		towers.append("%s:%d" % [t.tower_id, t.tier])
	return {
		"sieg": game.phase == game.Phase.VICTORY,
		"welle": mini(game.wave_index + 1, game.waves.size()),
		"wellen": game.waves.size(),
		"leben_start": lives_start,
		"leben": game.lives,
		"verluste": leaks, "typen": game.waves.map(func(w): return game.wave_type(w)),
		"weglaenge": game.path_length,
		"tower": towers,
		"gold": game.gold,
	}


# --- Bauen -----------------------------------------------------------------------------------------

func _place_one() -> void:
	if stufe >= 4 and game.can_buy_extra_chance() and game.gold >= 275:
		var best_id := ""
		var best_v := -INF
		for id in Database.gem_ids():
			var v := Wert.value(id, 4)
			if str(Database.towers[id].get("targets", "both")) == "air":
				v *= air_weight
			if v > best_v:
				best_v = v
				best_id = id
		game.submit({"type": "extra_chance", "id": best_id})
	var a := Vector2i(-1, -1)
	var ok := func(c): return game.can_place(c)
	if stufe == 1:
		a = best_block(0, ok, -4, 3)
	else:
		if stufe >= 3 and game.round_towers.size() < 2:
			# die ersten zwei Gems der Runde an Stellen mit viel Weg und Flugbahn in Reichweite
			a = best_spot(300, ok, 6.0, air_weight)
		if a == Vector2i(-1, -1) and stufe >= 4:
			a = best_block(400, ok, 0, 0, plan.duplicate())
		if a == Vector2i(-1, -1):
			a = best_block(20 if stufe == 2 else 400, ok)
		plan.erase(a)
	if a == Vector2i(-1, -1):
		# nichts Sinnvolles frei: irgendwo bauen
		for y in game.map.height:
			for x in game.map.width:
				if game.can_place(Vector2i(x, y)):
					a = Vector2i(x, y)
					break
			if a != Vector2i(-1, -1):
				break
	game.submit({"type": "place", "cell": a})


func _load_plan() -> void:
	var f := FileAccess.open(PLAN, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var p := f.get_line().strip_edges().split(" ", false)
		if p.size() == 2 and p[0].is_valid_int():
			plan.append(Vector2i(int(p[0]), int(p[1])))


# --- Auswählen -------------------------------------------------------------------------------------

func _choose() -> void:
	var base := [0.0, 0.0]
	var need := [1.0, 1.0]
	if stufe >= 3:
		base = _field_power(game.own_towers().filter(func(t): return not t.is_new))
		need = _next_hp(game.wave_index)
		air_weight = clampf((base[0] / need[0]) / maxf(base[1] / need[1], 0.0001), 0.3, 4.0)
		if OS.get_environment("TL_DEBUG") != "":
			print("  Feld Boden %.1f Luft %.1f (Bedarf je Leben)" % [base[0] / need[0], base[1] / need[1]])
	var best_t = null
	var best_o := {}
	var best_i := -1
	var best_v := -INF
	for t in game.round_towers.duplicate():
		var opts: Array = game.tower_options(t)
		for i in opts.size():
			var o: Dictionary = opts[i]
			if o.action != "keep":
				continue
			var special := str(Database.towers.get(o.id, {}).get("category", "gem")) != "gem"
			if stufe == 1 and (i > 0 or special):
				continue
			var v := Wert.potential(o.id) if special else Wert.value(o.id, o.tier)
			if stufe == 1:
				v = o.tier * 1000.0 + v
			if stufe >= 3:
				# Boden und Luft getrennt: was gerade fehlt, zählt mehr (gute Spieler halten Luftabwehr bereit)
				var pv := _placed_value(t.cell, o.id, o.tier)
				if special:
					# Spezial-Tower mit ihren späteren Aufwertungen bewerten
					var f := Wert.potential(o.id) / maxf(Wert.value(o.id, o.tier), 1.0)
					pv = [pv[0] * f, pv[1] * f]
				var rb := _recipe_bonus(t.cell, o.id, o.tier)
				v = _balance_score(base, [pv[0] + rb[0], pv[1] + rb[1]], need)
			v += randf() * 0.001
			if v > best_v:
				best_v = v
				best_t = t
				best_o = o
				best_i = i
	if best_t == null:
		return
	game.submit({"type": "option", "tower": game.tower_ref(best_t), "index": best_i, "action": best_o.action,
			"id": best_o.id, "tier": best_o.tier})


## Rezepte im Kopf behalten (Stufe 3+): ein Gem, der einem Spezial-Rezept mit den schon gesetzten Towern
## näher kommt, ist mehr wert. Bonus = Spezial-Tower an diesem Platz, geteilt durch die noch fehlenden Zutaten.
func _recipe_bonus(cell: Vector2i, id: String, tier: int) -> Array:
	var field: Array = game.own_towers().filter(func(o): return not o.is_new)
	var best := [0.0, 0.0]
	var best_sum := 0.0
	for sid in Database.special_ids():
		var def: Dictionary = Database.towers[sid]
		if def.get("recipe_same_round", false):
			continue
		var recipe: Array = def.get("recipe", [])
		if recipe.is_empty():
			continue
		var pool := field.duplicate()
		var missing := 0
		var uses_me := false
		for ing in recipe:
			var found = null
			for o in pool:
				if _ing_ok(ing, o.tower_id, o.tier):
					found = o
					break
			if found != null:
				pool.erase(found)
			elif not uses_me and _ing_ok(ing, id, tier):
				uses_me = true
			else:
				missing += 1 + (2 if _ing_tier(ing) >= 4 else (1 if _ing_tier(ing) >= 3 else 0))
		if not uses_me:
			continue
		var pv := _placed_value(cell, sid, 0)
		var f := Wert.potential(sid) / maxf(Wert.value(sid, 0), 1.0) * 0.6 / (missing + 1)
		if (pv[0] + pv[1]) * f > best_sum:
			best_sum = (pv[0] + pv[1]) * f
			best = [pv[0] * f, pv[1] * f]
	return best


func _ing_ok(ing: Dictionary, id: String, tier: int) -> bool:
	if ing.has("any_of"):
		for alt in ing.any_of:
			if _ing_ok(alt, id, tier):
				return true
		return false
	return id == str(ing.get("tower", "")) and tier == int(ing.get("tier", 0))


func _ing_tier(ing: Dictionary) -> int:
	if ing.has("any_of"):
		var t := 9
		for alt in ing.any_of:
			t = mini(t, _ing_tier(alt))
		return t
	return int(ing.get("tier", 0))


# --- Während der Welle -----------------------------------------------------------------------------

func _wave_actions() -> void:
	for t in game.own_towers():
		if not is_instance_valid(t) or t.is_new:
			continue
		var opts: Array = game.tower_options(t)
		for i in opts.size():
			var o: Dictionary = opts[i]
			if o.action == "upgrade":
				if o.cost > game.gold:
					continue
				if not o.consume.is_empty() and stufe < 3:
					continue
			elif o.action == "combine":
				if stufe < 3:
					continue
				var used := Wert.value(t.tower_id, t.tier)
				for c in o.consume:
					used += Wert.value(c.tower_id, c.tier)
				if Wert.potential(o.id) < used * 0.8:
					continue
			else:
				continue
			game.submit({"type": "option", "tower": game.tower_ref(t), "index": i, "action": o.action, "id": o.id, "tier": o.tier})
			return
