extends "res://tools/testlauf/bot_basis.gd"
## Shopping-Maul-Bot (Normal, 150 Leben, Gruppenmodus, solo, zufällige Standard-Filiale je Lauf).
## Keine Items, Forschung, Teampunkte oder Einheiten.
## Stufe 1: kauft zufällige bezahlbare Tower und stellt sie zufällig ins eigene Gebiet.
## Stufe 2: kauft den Tower mit dem besten Schaden je Gold und stellt ihn an den Weg.
## Stufe 3: wie 2, achtet auf Boden/Luft, wertet Tower auf, wenn das mehr bringt als ein neuer, ersetzt bei vollem
##   Gebiet schwache Tower durch stärkere, startet Level sofort.
## Stufe 4: wie 3 und baut mit billigen Towern ein Labyrinth im eigenen Gebiet.

var shop_id := ""
var zone_rect: Rect2i


func play(st: int, sd: int, tempo: float, args: Dictionary) -> Dictionary:
	stufe = st
	Session.game_kind = "shoppingmaul"
	Session.skip_setup = true
	game = load("res://scenes/maul_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var shops: Array = MaulData.shops().filter(func(s): return s.kind == "standard").map(func(s): return str(s.id))
	shop_id = str(args.get("filiale", shops[sd % shops.size()]))
	game.start_game(shop_id, 1, "group")
	zone_rect = game.map.zones[game.players[0].zone].rect
	var lives_start: int = game.lives
	Engine.time_scale = tempo
	var frames := 0
	var last := -1
	var leaks := {}
	var lives_at: int = game.lives
	while game.phase < MaulGame.Phase.GAME_OVER and frames < 4000000:
		frames += 1
		if game.level != last:
			if last >= 1:
				leaks[last - 1] = lives_at - game.lives
			lives_at = game.lives
			last = game.level
			print("LEVEL %d %s  Leben %d  Tower %d  Gold %d  %ds" % [game.level, game.level_title(maxi(game.level, 1)), game.lives,
					game.tower_count(0), game.players[0].gold, Time.get_ticks_msec() / 1000])
		if frames % 10 == 0:
			for _i in 5:
				if not _act():
					break
		if game.phase == MaulGame.Phase.COUNTDOWN and stufe >= 3 and frames % 10 == 5:
			game.submit({"type": "start_now"})
		await get_tree().process_frame
	leaks[last - 1] = lives_at - game.lives
	var list := []
	for i in game.levels.size():
		list.append(int(leaks.get(i, 0)))
	var towers := {}
	for t in game.towers.values():
		towers[t.tower_id] = int(towers.get(t.tower_id, 0)) + 1
	return {"sieg": game.phase == MaulGame.Phase.VICTORY, "welle": mini(game.level, game.levels.size()),
		"wellen": game.levels.size(), "leben_start": lives_start, "leben": game.lives, "verluste": list, "typen": range(1, game.levels.size() + 1).map(func(n): return str(game.level_def(n).get("kind", ""))),
		"tower": towers, "gold": game.players[0].gold, "filiale": shop_id}


# --- Wege im eigenen Gebiet --------------------------------------------------------------------------

func _own_points() -> Array:
	var out := []
	for p in game._own_path_pts:
		var c := Vector2(p) / Board3D.CELL
		if zone_rect.grow(8).has_point(Vector2i(c.floor())):
			out.append(c)
	return out


func _maul_len() -> float:
	var total := 0.0
	for leg in game.all_legs():
		var r: Dictionary = game._compute_route(leg[0], leg[1], "ground", game.pathfinder)
		if r.path.is_empty():
			return -1.0
		total += r.path.size()
	return total


func _cover(cell: Vector2i, st: Dictionary, pts: Array) -> float:
	var r := float(st.get("range", 6.0))
	var c := Vector2(cell) + Vector2(1, 1)
	var n := 0
	for p in pts:
		if p.distance_squared_to(c) <= r * r:
			n += 1
	return float(n)


func _free_cells(id: String) -> Array:
	var out := []
	for y in range(zone_rect.position.y, zone_rect.end.y - 1):
		for x in range(zone_rect.position.x, zone_rect.end.x - 1):
			var a := Vector2i(x, y)
			var ok := true
			for c in Board3D.footprint(a):
				if game.occupied.has(c) or game.map.get_tile(c) != MapData.FLOOR or game.map.is_marker_zone(c):
					ok = false
					break
			if ok:
				out.append(a)
	return out


func _value(st: Dictionary) -> float:
	return Wert.value_of(st, str(st.get("targets", "both")))


func _power(pts: Array) -> Array:
	var g := 0.0
	var a := 0.0
	for t in game.towers.values():
		if t.owner_player != 0:
			continue
		var st := MaulData.tower(t.tower_id)
		var v := _value(st) * _cover(t.cell, st, pts)
		var tg := str(st.get("targets", "both"))
		if tg != "air":
			g += v
		if tg != "ground":
			a += v
	return [g, a]


func _need() -> Array:
	var g := 0.0
	var a := 0.0
	for n in range(game.level + 1, game.levels.size() + 1):
		var d: Dictionary = game.level_def(n)
		var b: float = game.level_budget(n)
		if str(d.get("kind", "ground")) == "air":
			if a == 0.0:
				a = b
		elif g == 0.0:
			g = b
		if g > 0.0 and a > 0.0:
			break
	return [maxf(g, 1.0), maxf(a, 1.0)]


## Ein Kauf oder Ausbau; false, wenn nichts mehr geht.
func _act() -> bool:
	if game.phase == MaulGame.Phase.SETUP or game.phase >= MaulGame.Phase.GAME_OVER:
		return false
	var gold: int = game.players[0].gold
	var buy: Array = MaulData.buyable(shop_id).filter(func(d): return int(d.cost) <= gold)
	var pts := _own_points()
	var base := _power(pts)
	var need := _need()
	var now := _balance_score(base, [0.0, 0.0], need)
	var best_s := -INF
	var act := {}
	# Ausbau vorhandener Tower
	if stufe >= 3:
		for t in game.towers.values():
			if t.owner_player != 0:
				continue
			for to in t.def.get("upgrades_to", []):
				var nd := MaulData.tower(str(to))
				if nd.is_empty() or int(nd.cost) > gold or game.requirement_problem(nd, 0, t) != "":
					continue
				var od := MaulData.tower(t.tower_id)
				var cov := _cover(t.cell, nd, pts)
				var dv := (_value(nd) - _value(od)) * cov
				var tg := str(nd.get("targets", "both"))
				var s := (_balance_score(base, [dv if tg != "air" else 0.0, dv if tg != "ground" else 0.0], need) - now) / maxf(float(nd.cost), 1.0)
				if s > best_s:
					best_s = s
					act = {"type": "upgrade", "cell": t.cell, "to": str(to)}
	if game.tower_count(0) < game.food_limit(0) and not buy.is_empty():
		var id := ""
		if stufe == 1:
			id = str(buy[randi() % buy.size()].id)
		else:
			var best := -INF
			for d in buy:
				var v := _value(d) / maxf(float(d.cost), 1.0)
				var tg := str(d.get("targets", "both"))
				if tg == "air" and str(game.level_def(game.level + 1).get("kind", "")) != "air":
					v *= 0.1  # reine Luft-Tower nur kurz vor einem Luft-Level
				if stufe >= 3:
					var dv := _value(d) * 40.0
					v = (_balance_score(base, [dv if tg != "air" else 0.0, dv if tg != "ground" else 0.0], need) - now) / maxf(float(d.cost), 1.0)
				if v > best:
					best = v
					id = str(d.id)
			# Labyrinth (Stufe 4): genug Schaden da, dann billigster Tower als Wegverlängerung
			if stufe >= 4 and base[0] / need[0] > 2.0 and game.tower_count(0) < game.food_limit(0) - 4:
				var cheapest: Dictionary = buy[0]
				for d in buy:
					if int(d.cost) < int(cheapest.cost):
						cheapest = d
				var a := _maze_spot(str(cheapest.id))
				if a != Vector2i(-1, -1):
					return game.submit({"type": "build", "tower": str(cheapest.id), "cell": a})
			if stufe >= 3 and best <= best_s:
				id = ""
		if id != "":
			var a := _spot(id, pts)
			if a != Vector2i(-1, -1):
				return game.submit({"type": "build", "tower": id, "cell": a})
	if not act.is_empty() and best_s > 0.0:
		return game.submit(act)
	# Gebiet voll (Food): schwächsten Tower verkaufen, wenn ein deutlich stärkerer bezahlbar wird
	if stufe >= 3 and game.tower_count(0) >= game.food_limit(0):
		var weakest = null
		for t in game.towers.values():
			if t.owner_player == 0 and (weakest == null or _value(MaulData.tower(t.tower_id)) < _value(MaulData.tower(weakest.tower_id))):
				weakest = t
		if weakest != null:
			var budget: int = gold + game.sell_value(weakest)
			var wv := _value(MaulData.tower(weakest.tower_id))
			for d in MaulData.buyable(shop_id):
				if int(d.cost) <= budget and _value(d) > wv * 1.5 and game.requirement_problem(d, 0) == "":
					return game.submit({"type": "sell", "cell": weakest.cell})
	return false


func _spot(id: String, pts: Array) -> Vector2i:
	var cand := _free_cells(id)
	cand.shuffle()
	if stufe == 1:
		for a in cand:
			if game.build_problem(id, a, 0, true) == "":
				return a
		return Vector2i(-1, -1)
	var st := MaulData.tower(id)
	cand.sort_custom(func(x, y): return _cover(x, st, pts) > _cover(y, st, pts))
	for a in cand.slice(0, 40):
		if game.build_problem(id, a, 0, true) == "":
			return a
	return Vector2i(-1, -1)


func _maze_spot(id: String) -> Vector2i:
	var pts := _own_points()
	var cand := _free_cells(id).filter(func(a):
		var c := Vector2(a) + Vector2(1, 1)
		for p in pts:
			if p.distance_squared_to(c) <= 4.0:
				return true
		return false)
	cand.shuffle()
	var base := _maul_len()
	var best := 0.5
	var out := Vector2i(-1, -1)
	for a in cand.slice(0, 60):
		if game.build_problem(id, a, 0, true) != "":
			continue
		var cells: Array[Vector2i] = Board3D.footprint(a)
		game.pathfinder.set_solid_cells(cells, true)
		var l := _maul_len()
		game.pathfinder.set_solid_cells(cells, false)
		if l - base > best:
			best = l - base
			out = a
	return out
