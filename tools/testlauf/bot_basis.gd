extends Node
## Gemeinsame Helfer der Testlauf-Bots: Weglänge, Plätze am Weg, Abdeckung.

const Wert := preload("res://tools/testlauf/wert.gd")

var game: Node
var stufe := 3
## Luftwellen brauchen in der Praxis deutlich mehr Abwehr, als Strecke mal Schaden sagt (Flieger laufen kein
## Labyrinth, kommen gebündelt, Rüstung): so viel mehr verlangt der Bot für die Luft (aus Testläufen geschätzt).
var air_factor := 3.0


func _lanes() -> Array:
	return game.active_lanes() if game.has_method("active_lanes") else range(game.map.lane_count())


func _path_cells() -> Array:
	var all := []
	for i in _lanes():
		all.append_array(game.pathfinder.compute_path(i))
	return all


func _path_len() -> float:
	var total := 0.0
	for i in _lanes():
		var cells: Array = game.pathfinder.compute_path(i)
		if cells.is_empty():
			return -1.0
		for j in range(1, cells.size()):
			total += (cells[j] - cells[j - 1]).length()
	return total


func _gain(a: Vector2i, base: float) -> float:
	var cells: Array[Vector2i] = Board3D.footprint(a)
	game.pathfinder.set_solid_cells(cells, true)
	var l := _path_len()
	game.pathfinder.set_solid_cells(cells, false)
	return l - base if l >= 0 else -1.0


## Anker am Weg, deren Felder frei und bebaubar sind (ohne die teure Wegprüfung).
func _near_path(reach_lo: int, reach_hi: int) -> Array:
	var seen := {}
	var out := []
	for p in _path_cells():
		for dy in range(reach_lo, reach_hi + 1):
			for dx in range(reach_lo, reach_hi + 1):
				var a: Vector2i = p + Vector2i(dx, dy)
				if seen.has(a):
					continue
				seen[a] = true
				if _free(a):
					out.append(a)
	return out


## Belegte oder unbegehbare Felder rund um einen 2×2-Platz (12 Nachbarfelder).
func _walls_next_to(a: Vector2i) -> int:
	var n := 0
	for d in [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, -1), Vector2i(1, -1),
			Vector2i(0, 2), Vector2i(1, 2)]:
		var c: Vector2i = a + d
		if game.occupied.has(c) or not game.map.is_walkable(c):
			n += 1
	return n


func _free(a: Vector2i) -> bool:
	for c in Board3D.footprint(a):
		if not game.map.is_buildable(c) or game.occupied.has(c):
			return false
	return true


## Bester Platz für ein Hindernis: probiert n zufällige Plätze am Weg und nimmt den mit dem längsten Weg.
## ok: Prüfung je Platz (z. B. can_build im Modus). n <= 0: zufälliger Platz, ohne zu rechnen.
func best_block(n: int, ok: Callable, reach_lo := -2, reach_hi := 1, cand: Array = []) -> Vector2i:
	if cand.is_empty():
		cand = _near_path(reach_lo, reach_hi)
	cand.shuffle()
	var base := _path_len()
	var best := -INF
	var a := Vector2i(-1, -1)
	var tried := 0
	for c in cand:
		if not ok.call(c):
			continue
		if n <= 0:
			return c
		# Gleichstand (ein Block allein verlängert im offenen Feld oft nichts): an vorhandene Wände anbauen
		var g := _gain(c, base) + 0.15 * _walls_next_to(c) + randf() * 0.01
		if g > best:
			best = g
			a = c
		tried += 1
		if tried >= n:
			break
	return a


func _coverage(t, id: String, tier: int) -> float:
	var st := Wert.tier_stats(id, tier)
	var r := float(st.get("range", 5.0))
	var c := Vector2(t.cell) + Vector2(1, 1)
	var n := 0
	for p in _path_cells():
		if (Vector2(p) + Vector2(0.5, 0.5)).distance_to(c) <= r:
			n += 1
	return float(n)




## Punkte entlang der Flugbahnen (gerade Linien zwischen den Wegpunkten), alle halbe Felder.
func _air_points() -> Array:
	var out := []
	for i in _lanes():
		var wps: Array = game.map.waypoints(i)
		for j in range(1, wps.size()):
			var a := Vector2(wps[j - 1]) + Vector2(0.5, 0.5)
			var b := Vector2(wps[j]) + Vector2(0.5, 0.5)
			var steps := maxi(1, int(a.distance_to(b) * 2.0))
			for k in steps:
				out.append(a.lerp(b, float(k) / steps))
	return out


## Wie viel Flugbahn ein Tower id/tier auf Platz cell abdeckt (in Feldern).
func _air_coverage(cell: Vector2i, id: String, tier: int) -> float:
	var st := Wert.tier_stats(id, tier)
	var r := float(st.get("range_air", st.get("range", 5.0)))
	var c := Vector2(cell) + Vector2(1, 1)
	var n := 0
	for p in _air_points():
		if p.distance_to(c) <= r:
			n += 1
	return n * 0.5


## Wert eines Towers an seinem Platz für Boden und Luft getrennt: [Boden, Luft].
func _placed_value(cell: Vector2i, id: String, tier: int) -> Array:
	var v := Wert.value(id, tier)
	var targets := str(Database.towers.get(id, {}).get("targets", "both"))
	var st := Wert.tier_stats(id, tier)
	var r := float(st.get("range", 5.0))
	var c := Vector2(cell) + Vector2(1, 1)
	var n := 0
	for p in _path_cells():
		if (Vector2(p) + Vector2(0.5, 0.5)).distance_to(c) <= r:
			n += 1
	# Schaden, den ein vorbeilaufender Gegner abbekommt: Stärke mal Strecke in Reichweite
	var g := 0.0 if targets == "air" else v * float(n)
	var a := 0.0 if targets == "ground" else v * _air_coverage(cell, id, tier)
	return [g, a]


## Gesamte Leben der nächsten Boden- und Luftwelle ab Welle from (Index): [Boden, Luft].
func _next_hp(from: int) -> Array:
	var hg := 0.0
	var ha := 0.0
	for i in range(from, game.waves.size()):
		var w: Dictionary = game.waves[i]
		var air := 0.0
		var ground := 0.0
		for g in w.get("groups", []):
			var d: Dictionary = Database.enemies.get(str(g.get("enemy", "")), {})
			var hp := float(g.get("hp", d.get("hp", 100))) * int(g.get("count", 1))
			if d.get("flying", false) or g.get("flying", false):
				air += hp
			else:
				ground += hp
		if hg == 0.0 and ground > 0.0:
			hg = ground
		if ha == 0.0 and air > 0.0:
			ha = air
		if hg > 0.0 and ha > 0.0:
			break
	return [maxf(hg, 1.0), maxf(ha * air_factor, 1.0)]


## Wie viel des Bedarfs ist gedeckt, wenn zu den Towern noch extra ([Boden, Luft]) dazukommt? Der schwächere
## Teil zählt, der andere ein wenig mit.
func _balance_score(base: Array, extra: Array, need: Array) -> float:
	var g: float = (base[0] + extra[0]) / need[0]
	var a: float = (base[1] + extra[1]) / need[1]
	return minf(g, a) + 0.15 * (g + a)


func _field_power(towers: Array) -> Array:
	var g := 0.0
	var a := 0.0
	for t in towers:
		if is_instance_valid(t):
			var pv := _placed_value(t.cell, t.tower_id, t.tier)
			g += pv[0]
			a += pv[1]
	return [g, a]


## Guter Platz für einen Tower: viel Bodenweg und Flugbahn im Umkreis r (Felder). air: Gewicht der Flugbahn.
## Probiert n zufällige freie Plätze am Weg (ok prüft sie).
func best_spot(n: int, ok: Callable, r := 6.0, air := 1.0) -> Vector2i:
	var cand := _near_path(-3, 2)
	cand.shuffle()
	var path := _path_cells()
	var airp := _air_points()
	var best := -INF
	var a := Vector2i(-1, -1)
	var tried := 0
	for c in cand:
		var center := Vector2(c) + Vector2(1, 1)
		var s := 0.0
		for p in path:
			if (Vector2(p) + Vector2(0.5, 0.5)).distance_squared_to(center) <= r * r:
				s += 1.0
		for p in airp:
			if p.distance_squared_to(center) <= r * r:
				s += 0.5 * air
		s += randf() * 0.01
		if s <= best:
			continue
		if not ok.call(c):
			continue
		best = s
		a = c
		tried += 1
		if tried >= n:
			break
	return a
