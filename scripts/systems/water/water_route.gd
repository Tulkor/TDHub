class_name WaterRoute
extends RefCounted
## Wasserlauf-Finder: Aus einer Vorgabe („kind": "stream" mit Quelle, Richtung, Breite und optionalen
## Wegpunkten) sucht sich das Wasser seinen Lauf selbst und wird zu den bekannten Einträgen
## river / waterfall / pool, die WaterSystem._connect_flow verbindet.
## - Höhengelände (Terrain.hilly): fließt bergab, an steilen Stufen entstehen Wasserfälle, in Mulden
##   füllt sich ein Becken bis zum Überlauf, von dort fließt es weiter.
## - Flache Kachelkarten: weicht Hindernissen (Felsen, Towern, Gegnerweg) mit Abstand aus und läuft
##   bis zum Kartenrand, einer Sackgasse (dort ein kleiner See) oder bis die Länge aufgebraucht ist.
## Rein rechnerisch, ohne Knoten; die Karte selbst bleibt unverändert.

const UPHILL := 60.0          ## A*-Kosten je Einheit Anstieg zwischen Wegpunkten
const NEAR := 3.0             ## Zusatzkosten direkt an der Mindestabstandsgrenze zu Hindernissen
const SLOPE_WEIGHT := 20.0    ## freier Lauf: wie stark Gefälle gegenüber Geradeauslauf zählt
const MOMENTUM := 0.6         ## freier Lauf: Neigung, die bisherige Richtung zu halten
const AIM_PULL := 0.5         ## flaches Land: Zug zurück zur vorgegebenen Hauptrichtung
const MIN_POOL_CELLS := 8     ## kleinere Senken (Geländerauschen) werden einfach durchflossen
const FLAT_EPS := 0.02        ## so viel Anstieg je Feld gilt noch als eben
const FALL_SLOPE := 0.9       ## Gefälle (Höhe je Strecke), ab dem es eine Fallstufe ist
const FALL_DROP := 0.3        ## Mindesthöhe einer Stufe, damit ein Wasserfall entsteht
const SURFACE := 0.04         ## Wasser liegt so weit über dem Boden
const MAX_POOL_CELLS := 600   ## Beckengröße in Feldern, danach endet der Lauf im Becken
const MAX_VIA := 16
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## Gelände, auf dem der Lauf gesucht wird. Raster in Spielkoordinaten (x/z), Feldgröße step.
class Terrain:
	var bounds := Rect2(0, 0, 37, 37)
	var step := 0.5
	var height := Callable()      ## (x: float, z: float) -> float; ungültig = flach auf 0
	var blocked_at := Callable()  ## (x: float, z: float) -> bool; zusätzlich zu blocked
	var blocked := {}             ## Rasterfeld (Vector2i) -> true
	var hilly := false            ## true: Wasser fließt nur bergab, Mulden werden zu Becken

	func cols() -> int:
		return maxi(ceili(bounds.size.x / step), 1)

	func rows() -> int:
		return maxi(ceili(bounds.size.y / step), 1)

	func cell_of(x: float, z: float) -> Vector2i:
		return Vector2i(floori((x - bounds.position.x) / step), floori((z - bounds.position.y) / step))

	func center(c: Vector2i) -> Vector2:
		return bounds.position + (Vector2(c) + Vector2(0.5, 0.5)) * step

	func ground(x: float, z: float) -> float:
		return float(height.call(x, z)) if height.is_valid() else 0.0


class _Heap:
	var keys := PackedFloat32Array()
	var vals := PackedInt32Array()

	func push(k: float, v: int) -> void:
		keys.append(k)
		vals.append(v)
		var i := keys.size() - 1
		while i > 0:
			var p := (i - 1) >> 1
			if keys[p] <= keys[i]:
				break
			_swap(i, p)
			i = p

	func pop() -> int:
		var top := vals[0]
		var last := keys.size() - 1
		keys[0] = keys[last]
		vals[0] = vals[last]
		keys.resize(last)
		vals.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var m := i
			if l < last and keys[l] < keys[m]:
				m = l
			if l + 1 < last and keys[l + 1] < keys[m]:
				m = l + 1
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func is_empty() -> bool:
		return keys.is_empty()

	func _swap(a: int, b: int) -> void:
		var k := keys[a]
		keys[a] = keys[b]
		keys[b] = k
		var v := vals[a]
		vals[a] = vals[b]
		vals[b] = v


## Raster mit Bodenhöhe und Abstand zum nächsten Hindernis je Feld.
class _Grid:
	var t: Terrain
	var w := 1
	var hgt := 1
	var h := PackedFloat32Array()
	var wall := PackedByteArray()
	var clear := PackedFloat32Array()  ## Abstand Feldmitte bis Rand des nächsten Hindernisses (Einheiten)

	func _init(terrain: Terrain) -> void:
		t = terrain
		w = t.cols()
		hgt = t.rows()
		h.resize(w * hgt)
		wall.resize(w * hgt)
		clear.resize(w * hgt)
		var dist := PackedFloat32Array()
		dist.resize(w * hgt)
		for y in hgt:
			for x in w:
				var c := Vector2i(x, y)
				var p := t.center(c)
				var i := y * w + x
				h[i] = t.ground(p.x, p.y)
				var blocked := t.blocked.has(c) or (t.blocked_at.is_valid() and bool(t.blocked_at.call(p.x, p.y)))
				wall[i] = 1 if blocked else 0
				dist[i] = 0.0 if blocked else 1e9
		# Abstandstransformation in zwei Durchläufen (Schachbrett-Näherung mit Diagonale √2).
		var d2 := 1.41421
		for y in hgt:
			for x in w:
				var i := y * w + x
				if x > 0:
					dist[i] = minf(dist[i], dist[i - 1] + 1.0)
				if y > 0:
					dist[i] = minf(dist[i], dist[i - w] + 1.0)
					if x > 0:
						dist[i] = minf(dist[i], dist[i - w - 1] + d2)
					if x < w - 1:
						dist[i] = minf(dist[i], dist[i - w + 1] + d2)
		for y in range(hgt - 1, -1, -1):
			for x in range(w - 1, -1, -1):
				var i := y * w + x
				if x < w - 1:
					dist[i] = minf(dist[i], dist[i + 1] + 1.0)
				if y < hgt - 1:
					dist[i] = minf(dist[i], dist[i + w] + 1.0)
					if x < w - 1:
						dist[i] = minf(dist[i], dist[i + w + 1] + d2)
					if x > 0:
						dist[i] = minf(dist[i], dist[i + w - 1] + d2)
		for i in dist.size():
			clear[i] = 0.0 if wall[i] == 1 else dist[i] * t.step - t.step * 0.5

	func inside(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < w and c.y < hgt

	func idx(c: Vector2i) -> int:
		return c.y * w + c.x

	@warning_ignore("integer_division")
	func cell(i: int) -> Vector2i:
		return Vector2i(i % w, i / w)

	func border(c: Vector2i) -> bool:
		return c.x == 0 or c.y == 0 or c.x == w - 1 or c.y == hgt - 1

	func passable(i: int, half: float) -> bool:
		return wall[i] == 0 and clear[i] >= half * 0.9

	func near_penalty(i: int, half: float) -> float:
		var room := clear[i] - half
		var band := maxf(half * 2.0, t.step * 2.0)
		return NEAR * (1.0 - room / band) if room < band else 0.0


## Prüft eine Lauf-Vorgabe; leerer Text = gültig.
static func validate(spec: Variant) -> String:
	if not spec is Dictionary:
		return "Eintrag muss ein Objekt sein"
	if not _xz_ok(spec.get("source")):
		return "stream braucht source [x, z] oder [x, y, z]"
	var width = spec.get("width", 1.0)
	if typeof(width) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(width)) or float(width) <= 0.0 or float(width) > 50.0:
		return "Breite muss zwischen 0 und 50 liegen"
	if spec.has("dir") and (not spec.dir is Array or spec.dir.size() != 2 or not _xz_ok([spec.dir[0], spec.dir[1]])):
		return "dir braucht [dx, dz]"
	var via = spec.get("via", [])
	if not via is Array or via.size() > MAX_VIA:
		return "via braucht höchstens %d Punkte [x, z]" % MAX_VIA
	for p in via:
		if not _xz_ok(p):
			return "ungültiger Wegpunkt in via"
	if spec.has("end") and not _xz_ok(spec.end):
		return "end braucht [x, z]"
	var length = spec.get("length", 1000.0)
	if typeof(length) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(length)) or float(length) <= 0.0:
		return "length muss positiv sein"
	if not spec.get("material", {}) is Dictionary:
		return "material muss ein Objekt sein"
	if spec.has("crest_foam") and not spec.crest_foam is bool:
		return "crest_foam muss boolesch sein"
	return WaterBank.validate(spec.get("banks", {}))


static func _xz_ok(v: Variant) -> bool:
	if not v is Array or v.size() not in [2, 3]:
		return false
	for n in v:
		if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(n)) or absf(float(n)) > 100000.0:
			return false
	return true


## [x, z] oder [x, y, z] -> waagrechter Punkt.
static func _xz(v: Array) -> Vector2:
	return Vector2(float(v[0]), float(v[-1]))


## Ersetzt alle „stream“-Einträge durch die gefundenen Gewässer; andere Einträge bleiben, wie sie sind.
static func expand(regions: Array, terrain: Terrain) -> Dictionary:
	var out := []
	var errors := PackedStringArray()
	var wet := {}  # Feld neben früheren Läufen -> nächstes Feld ihrer Mittellinie (Zusammenfluss)
	for i in regions.size():
		var region = regions[i]
		if region is Dictionary and str(region.get("kind", "")) == "stream":
			var result := resolve(region, terrain, wet)
			var reach := ceili(float(region.get("width", 1.0)) * 0.5 / terrain.step)
			for c: Vector2i in result.cells:
				for y in range(-reach, reach + 1):
					for x in range(-reach, reach + 1):
						var n := c + Vector2i(x, y)
						if not wet.has(n) or Vector2(n - c).length() < Vector2(n - (wet[n] as Vector2i)).length():
							wet[n] = c
			for e in result.errors:
				errors.append("water[%d]: %s" % [i, e])
			out.append_array(result.regions)
		else:
			out.append(region)
	return {"regions": out, "errors": errors}


## Sucht den Lauf. Ergebnis: {regions: Array (river/waterfall/pool), errors, cells: Rasterfelder des Laufs}.
## wet: Felder anderer Läufe; erreicht der freie Lauf eines davon, mündet er dort und endet.
static func resolve(spec: Dictionary, terrain: Terrain, wet := {}) -> Dictionary:
	var errors := PackedStringArray()
	var invalid := validate(spec)
	if invalid != "":
		return {"regions": [], "errors": PackedStringArray([invalid]), "cells": []}
	var g := _Grid.new(terrain)
	var width := float(spec.get("width", 1.0))
	var half := width * 0.5
	var source := _xz(spec.source)
	var start := terrain.cell_of(source.x, source.y)
	if not g.inside(start):
		return {"regions": [], "errors": PackedStringArray(["Quelle liegt außerhalb der Karte"]), "cells": []}
	var budget := float(spec.get("length", 1000.0))
	var pieces := []  # {"path": Array[int]} oder {"pool": {...}}
	var path: Array[int] = [g.idx(start)]
	var visited := {g.idx(start): true}
	var joins := false  # endet in einem anderen Lauf
	var targets := []
	for p in spec.get("via", []):
		targets.append(_xz(p))
	if spec.has("end"):
		targets.append(_xz(spec.end))
	for target: Vector2 in targets:
		var goal := terrain.cell_of(target.x, target.y)
		if not g.inside(goal):
			errors.append("Wegpunkt liegt außerhalb der Karte")
			break
		var leg := _astar(g, path[-1], g.idx(goal), half)
		if leg.is_empty():
			errors.append("kein Weg zum Wegpunkt %s (Hindernisse oder zu breit)" % str(target))
			break
		for k in range(1, leg.size()):
			path.append(leg[k])
			visited[leg[k]] = true
	budget -= _length(g, path)
	if terrain.hilly and _climbs(g, path):
		errors.append("Vorgegebener Weg führt bergauf; das Wasser bleibt dort auf seiner Höhe")
	if not spec.has("end") and budget > 0.0:
		var dir := Vector2.ZERO
		if path.size() > 1:
			dir = Vector2(g.cell(path[-1]) - g.cell(path[maxi(path.size() - 4, 0)])).normalized()
		elif spec.has("dir"):
			dir = Vector2(float(spec.dir[0]), float(spec.dir[1])).normalized()
		if dir == Vector2.ZERO and not terrain.hilly:
			dir = Vector2.RIGHT
		var aim := Vector2.ZERO if terrain.hilly else dir
		var rounds := 0
		while budget > 0.0 and rounds < 64:
			rounds += 1
			var flow := _flow(g, path[-1], dir, budget, half, visited, aim, wet)
			path.append_array(flow.cells)
			budget -= float(flow.length)
			dir = flow.dir
			if flow.stop == "merge":
				# Bis zur Mitte des anderen Laufs weiterführen, damit das Wasser wirklich hineinfließt.
				var into: Vector2i = wet[g.cell(path[-1])]
				var from := Vector2(g.cell(path[-1]))
				var steps := ceili(from.distance_to(Vector2(into)))
				for k in range(1, steps + 1):
					var c := Vector2i((from.lerp(Vector2(into), float(k) / steps)).round())
					if g.inside(c) and g.idx(c) != path[-1]:
						path.append(g.idx(c))
				joins = true
				break
			if flow.stop in ["edge", "length"]:
				break
			# Mulde oder Sackgasse: Becken füllen; auf flachem Land ein kleiner See am Ende.
			var pool := _flood(g, path[-1], int(spec.get("max_pool_cells", MAX_POOL_CELLS))) if terrain.hilly else _end_pool(g, path[-1], width)
			if terrain.hilly and int(pool.spill) >= 0 and pool.cells.size() < MIN_POOL_CELLS:
				# Kleine Senke: einfach weiterfließen.
				for i in pool.cells:
					visited[i] = true
				path.append(int(pool.spill))
				visited[int(pool.spill)] = true
				continue
			# Laufstück nur bis zum ersten Feld im Becken (dort mündet es).
			var cut := path.size() - 1
			for k in path.size():
				if pool.cells.has(path[k]):
					cut = k
					break
			path.resize(cut + 1)
			if path.size() >= 2:
				pieces.append({"path": path})
			pieces.append({"pool": pool})
			for i in pool.cells:
				visited[i] = true
			if int(pool.spill) < 0:
				path = []
				break
			path = [int(pool.spill)]
			visited[int(pool.spill)] = true
			dir = (Vector2(g.cell(int(pool.spill))) - pool.center_cell).normalized()
	if path.size() >= 2:
		pieces.append({"path": path, "joins": joins})
	var cells := []
	for piece in pieces:
		if piece.has("path"):
			for i in piece.path:
				cells.append(g.cell(i))
	return {"regions": _regions(g, pieces, spec, width), "errors": errors, "cells": cells}


static func _length(g: _Grid, path: Array[int]) -> float:
	var total := 0.0
	for k in range(1, path.size()):
		total += Vector2(g.cell(path[k]) - g.cell(path[k - 1])).length() * g.t.step
	return total


static func _climbs(g: _Grid, path: Array[int]) -> bool:
	var low := INF
	for i in path:
		if g.h[i] > low + FALL_DROP:
			return true
		low = minf(low, g.h[i])
	return false


## Kürzester Weg zwischen zwei Feldern mit Abstand zu Hindernissen; bergauf ist auf Höhengelände teuer.
static func _astar(g: _Grid, from: int, to: int, half: float) -> Array[int]:
	var result: Array[int] = []
	if g.wall[to] == 1:
		return result
	var heap := _Heap.new()
	var cost := {from: 0.0}
	var came := {}
	var goal := g.cell(to)
	heap.push(0.0, from)
	var closed := {}
	while not heap.is_empty():
		var i := heap.pop()
		if i == to:
			break
		if closed.has(i):
			continue
		closed[i] = true
		var c := g.cell(i)
		for d in DIRS:
			var n: Vector2i = c + d
			if not g.inside(n):
				continue
			var ni := g.idx(n)
			if ni != to and not g.passable(ni, half):
				continue
			var step_len := g.t.step * (1.41421 if d.x != 0 and d.y != 0 else 1.0)
			var add := step_len * (1.0 + g.near_penalty(ni, half))
			if g.t.hilly:
				add += maxf(g.h[ni] - g.h[i], 0.0) * UPHILL
			var total: float = cost[i] + add
			if total < float(cost.get(ni, INF)):
				cost[ni] = total
				came[ni] = i
				heap.push(total + Vector2(goal - n).length() * g.t.step, ni)
	if not came.has(to) and from != to:
		return result
	var at := to
	result.append(at)
	while at != from:
		at = came[at]
		result.append(at)
	result.reverse()
	return result


## Freier Lauf ab einem Feld: bergab bzw. geradeaus mit Schwung, an Hindernissen vorbei.
## Auf Höhengelände nur echt bergab (ebene Stellen füllt _flood als Becken); auf flachem Land zieht
## aim (Hauptrichtung) das Wasser zurück auf Kurs, rückwärts gegen aim fließt es nie.
static func _flow(g: _Grid, from: int, dir: Vector2, budget: float, half: float, visited: Dictionary, aim := Vector2.ZERO, wet := {}) -> Dictionary:
	var cells: Array[int] = []
	var at := from
	var length := 0.0
	var stop := "length"
	while length < budget:
		var c := g.cell(at)
		var best := -1
		var best_score := INF
		var best_move := Vector2.ZERO
		var best_len := 0.0
		for d in DIRS:
			var n: Vector2i = c + d
			if not g.inside(n):
				continue
			var ni := g.idx(n)
			if visited.has(ni) or not g.passable(ni, half):
				continue
			# Nicht diagonal an einem besuchten Feld vorbei (sonst kreuzt sich der Lauf).
			if d.x != 0 and d.y != 0 and (visited.has(g.idx(c + Vector2i(d.x, 0))) and visited.has(g.idx(c + Vector2i(0, d.y)))):
				continue
			var step_len := g.t.step * (1.41421 if d.x != 0 and d.y != 0 else 1.0)
			var dh := g.h[ni] - g.h[at]
			if g.t.hilly and dh > -0.0005:
				continue
			var move := Vector2(d).normalized()
			if not g.t.hilly and aim != Vector2.ZERO and move.dot(aim) < -0.05:
				continue
			var score := dh / step_len * SLOPE_WEIGHT - move.dot(dir) * MOMENTUM - move.dot(aim) * AIM_PULL + g.near_penalty(ni, half)
			if score < best_score:
				best_score = score
				best = ni
				best_move = move
				best_len = step_len
		if best < 0:
			stop = "basin"
			break
		cells.append(best)
		visited[best] = true
		length += best_len
		dir = best_move if dir == Vector2.ZERO else (dir * 0.75 + best_move * 0.25 + aim * 0.1).normalized()
		at = best
		if wet.has(g.cell(best)):
			stop = "merge"
			break
		if g.border(g.cell(best)):
			stop = "edge"
			break
	return {"cells": cells, "length": length, "stop": stop, "dir": dir}


## Mulde volllaufen lassen (Priority-Flood): bis das Wasser an der niedrigsten Randstelle überläuft.
## Ergebnis: {cells: {Index: true}, level, spill: Index des Überlaufs oder -1, center_cell}.
static func _flood(g: _Grid, from: int, limit: int) -> Dictionary:
	var region := {}
	var seen := {from: true}
	var heap := _Heap.new()
	heap.push(g.h[from], from)
	var level := -INF
	var spill := -1
	while not heap.is_empty():
		var i := heap.pop()
		if g.h[i] < level - 0.001:
			spill = i
			break
		level = maxf(level, g.h[i])
		region[i] = true
		var c := g.cell(i)
		if region.size() >= limit or g.border(c):
			break
		for d in DIRS.slice(0, 4):
			var n: Vector2i = c + d
			if not g.inside(n):
				continue
			var ni := g.idx(n)
			if seen.has(ni) or g.wall[ni] == 1:
				continue
			seen[ni] = true
			heap.push(g.h[ni], ni)
	return _pool_info(g, region, level, spill)


## Kleiner See am Ende eines Laufs auf flachem Land (Sackgasse vor Hindernissen).
static func _end_pool(g: _Grid, at: int, width: float) -> Dictionary:
	var region := {}
	var c := g.cell(at)
	var r := maxi(ceili(width / g.t.step), 1)
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var n := c + Vector2i(x, y)
			if g.inside(n) and g.wall[g.idx(n)] == 0:
				region[g.idx(n)] = true
	return _pool_info(g, region, g.h[at], -1)


static func _pool_info(g: _Grid, region: Dictionary, level: float, spill: int) -> Dictionary:
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-1, -1)
	for i in region:
		var c := g.cell(i)
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return {"cells": region, "level": level, "spill": spill, "lo": lo, "hi": hi, "center_cell": (Vector2(lo) + Vector2(hi)) * 0.5}


## Laufstücke und Becken in Karteneinträge umwandeln; steile Stufen werden zu Wasserfällen.
static func _regions(g: _Grid, pieces: Array, spec: Dictionary, width: float) -> Array:
	var out := []
	var name := str(spec.get("id", "Lauf"))
	var material: Dictionary = spec.get("material", {})
	var counter := {"river": 0, "waterfall": 0, "pool": 0}
	var add := func(kind: String, data: Dictionary) -> void:
		counter[kind] += 1
		data.kind = kind
		data.id = "%s_%s%d" % [name, kind, counter[kind]]
		if not material.is_empty():
			data.material = material.duplicate(true)
		if spec.has("banks"):
			data.banks = spec.banks.duplicate(true)
		if spec.has("crest_foam"):
			data.crest_foam = spec.crest_foam
		out.append(data)
	for k in pieces.size():
		var piece: Dictionary = pieces[k]
		if piece.has("pool"):
			var pool: Dictionary = piece.pool
			var box := _pool_rect(g, pool)
			add.call("pool", {"center": [box.get_center().x, float(pool.level) + SURFACE, box.get_center().y], "size": [box.size.x, box.size.y]})
			continue
		var pool_before: Variant = pieces[k - 1].pool if k > 0 and pieces[k - 1].has("pool") else null
		var pool_after: Variant = pieces[k + 1].pool if k + 1 < pieces.size() and pieces[k + 1].has("pool") else null
		var path: Array = piece.path
		var pts: Array[Vector3] = []
		var level := INF
		for n in path.size():
			var p := g.t.center(g.cell(path[n]))
			level = minf(level, g.h[path[n]] + SURFACE)
			if n == 0 and pool_before != null:
				level = float(pool_before.level) + SURFACE
			pts.append(Vector3(p.x, level, p.y))
		# Am Becken nur bis knapp hinter dessen Rand: dort übernimmt WaterSystem._mouth die Mündung
		# (senkrecht, aufgeweitet, ausblendend), statt dass zwei Flächen übereinander liegen.
		if pool_after != null:
			var box := _pool_rect(g, pool_after)
			for n in pts.size():
				if box.has_point(Vector2(pts[n].x, pts[n].z)):
					pts.resize(maxi(n + 1, 2))
					break
		if pool_before != null:
			var box := _pool_rect(g, pool_before)
			var first := 0
			while first + 2 < pts.size() and box.has_point(Vector2(pts[first + 1].x, pts[first + 1].z)):
				first += 1
			if first > 0:
				for _n in first:
					pts.remove_at(0)
				pts[0] = Vector3(pts[0].x, float(pool_before.level) + SURFACE, pts[0].z)
		if pool_after != null:
			# Mündung genau auf Beckenhöhe, ohne dass das Wasser davor bergauf müsste.
			var entry := pts[-1]
			entry.y = minf(pts[-2].y, float(pool_after.level) + SURFACE) if pts.size() > 1 else float(pool_after.level) + SURFACE
			pts[-1] = entry
		# Steile Stufen zusammenfassen: [Oben-Index, Unten-Index].
		var falls := []
		var run_start := -1
		for n in range(1, pts.size() + 1):
			var steep := false
			if n < pts.size():
				var drop := pts[n - 1].y - pts[n].y
				var dist := Vector2(pts[n].x - pts[n - 1].x, pts[n].z - pts[n - 1].z).length()
				steep = drop > 0.05 and drop / maxf(dist, 0.001) > FALL_SLOPE
			if steep and run_start < 0:
				run_start = n - 1
			elif not steep and run_start >= 0:
				if pts[run_start].y - pts[n - 1].y > FALL_DROP:
					falls.append([run_start, n - 1])
				run_start = -1
		var s := 0
		for f in falls:
			var top: Vector3 = pts[f[0]]
			var bottom: Vector3 = pts[f[1]]
			# Fallrichtung = senkrecht zur Kante (bergab am Gelände), nicht schräg wie der Rasterweg.
			var flat := _downhill(g, top, Vector2(bottom.x - top.x, bottom.z - top.z).normalized())
			var reach := maxf(Vector2(bottom.x - top.x, bottom.z - top.z).dot(flat), g.t.step * 0.5)
			bottom = Vector3(top.x + flat.x * reach, bottom.y, top.z + flat.y * reach)
			pts[f[1]] = bottom
			if f[0] - s >= 1:
				var river_pts := _sample(pts, s, f[0], width, g.t.step)
				var run := _approach(river_pts, top, flat, maxf(width * 1.5, 1.5), width)
				add.call("river", {"points": run.points, "dirs": run.dirs, "width": width})
			elif pool_before == null or s > 0:
				# Fall direkt an der Quelle: kleiner Quelltopf, damit der Fall oben aus Wasser kommt.
				add.call("pool", _small_pool(pts[f[0]], width))
			add.call("waterfall", {"points": [[top.x, top.y, top.z], [bottom.x, bottom.y, bottom.z]], "width": width, "right": [flat.y, 0.0, -flat.x]})
			s = f[1]
		if pts.size() - 1 - s >= 1:
			var tail := {"points": _sample(pts, s, pts.size() - 1, width, g.t.step), "width": width}
			if piece.get("joins", false):
				tail["_joins"] = true  # mündet in einen anderen Fluss: blendet dort aus (WaterBody)
			add.call("river", tail)
		elif not falls.is_empty() and pool_after == null:
			add.call("pool", _small_pool(pts[-1], width))
	return out


## Richtung des steilsten Gefälles an einer Fallkante (waagrecht, normiert); fallback ohne Gefälle.
static func _downhill(g: _Grid, at: Vector3, fallback: Vector2) -> Vector2:
	var e := g.t.step
	var grad := Vector2(g.t.ground(at.x + e, at.z) - g.t.ground(at.x - e, at.z), g.t.ground(at.x, at.z + e) - g.t.ground(at.x, at.z - e))
	if grad.length() < 0.01:
		return fallback
	var down := -grad.normalized()
	# Achsnahe Kanten genau senkrecht anlaufen (Rauschen im Gelände kippt die Richtung sonst leicht).
	if absf(down.x) < 0.2:
		down = Vector2(0.0, signf(down.y))
	elif absf(down.y) < 0.2:
		down = Vector2(signf(down.x), 0.0)
	return down


## Fluss läuft auf den letzten length Einheiten gerade und senkrecht auf die Fallkante zu (top, dir).
## Kommt er schräg an, biegt er in einem Bogen von etwa anderthalb Breiten ein; die Fallstelle rückt dafür
## entlang der Kante (höchstens zwei Breiten). Ergebnis: {points, shift (Verschiebung der Fallstelle)}.
static func _approach(points: Array, top: Vector3, dir: Vector2, length: float, width: float, shift_top := false) -> Dictionary:
	var edge := Vector2(top.x, top.z)
	var perp := Vector2(-dir.y, dir.x)
	var bend := width * 1.5
	var out := [points[0]]
	for k in range(1, points.size() - 1):
		var p := Vector2(float(points[k][0]), float(points[k][2]))
		if (edge - p).dot(dir) > length + bend:
			out.append(points[k])
	var last := Vector2(float(out[-1][0]), float(out[-1][2]))
	var before := Vector2(float(out[-2][0]), float(out[-2][2])) if out.size() > 1 else last - dir
	var v := (last - before).normalized() if last.distance_to(before) > 0.001 else dir
	var along := maxf((edge - last).dot(dir) - length, 0.0)
	var drift := v.dot(perp) / maxf(v.dot(dir), 0.35) * along * 0.5
	var lateral := 0.0 if not shift_top else clampf((last - edge).dot(perp) + drift, -width * 1.25, width * 1.25)
	var shift := perp * lateral
	var new_top := edge + shift
	var y0 := float(out[-1][1])
	if last.distance_to(new_top) > length * 0.6:
		var lead := new_top - dir * length
		out.append([lead.x, lerpf(y0, top.y, 0.8), lead.y])
		# Zweiter Punkt auf der Geraden: das Band ist dort schon ausgerichtet und schließt bündig an den Fall an.
		var mid := new_top - dir * length * 0.5
		out.append([mid.x, lerpf(y0, top.y, 0.9), mid.y])
	out.append([new_top.x, top.y, new_top.y])
	# Richtungsvorgaben: ab dem Vorlauf exakt senkrecht zur Kante (WaterSystem._connect_flow übernimmt sie),
	# davor frei, so wird der Bogen weich statt mit Knick am Vorlaufpunkt.
	var dirs := []
	for k in out.size():
		dirs.append([dir.x, dir.y] if k >= out.size() - 3 and k > 0 else null)
	return {"points": out, "shift": shift, "dirs": dirs}


static func _pool_rect(g: _Grid, pool: Dictionary) -> Rect2:
	var a := g.t.center(pool.lo) - Vector2.ONE * g.t.step * 0.5
	var b := g.t.center(pool.hi) + Vector2.ONE * g.t.step * 0.5
	# Auf der Überlaufseite endet das Becken am Überlauf: dahinter liegt der Abfluss tiefer, ein
	# rechteckiges Becken würde dort als harte Kante über dem Gelände stehen.
	if int(pool.get("spill", -1)) >= 0:
		var s := g.t.center(g.cell(int(pool.spill)))
		var off := Vector2(g.cell(int(pool.spill))) - (pool.center_cell as Vector2)
		var edge := g.t.step * 0.5
		if absf(off.x) >= absf(off.y):
			if off.x > 0.0:
				b.x = minf(b.x, s.x - edge)
			else:
				a.x = maxf(a.x, s.x + edge)
		elif off.y > 0.0:
			b.y = minf(b.y, s.y - edge)
		else:
			a.y = maxf(a.y, s.y + edge)
	return Rect2(a, b - a)


static func _small_pool(at: Vector3, width: float) -> Dictionary:
	return {"center": [at.x, at.y, at.z], "size": [width * 2.0, width * 2.0]}


## Jedes k-te Feld als Kurvenpunkt; Enden und deren Nachbarn bleiben, damit Anschlüsse genau sitzen.
static func _sample(pts: Array[Vector3], from: int, to: int, width: float, step: float) -> Array:
	var every := clampi(roundi(width / step), 2, 6)
	var keep := []
	for n in range(from, to + 1):
		if n == from or n == to or n == from + 1 or n == to - 1 or (n - from) % every == 0:
			keep.append(n)
	var out := []
	for n in keep:
		var p: Vector3 = pts[n]
		if not out.is_empty() and Vector3(out[-1][0], out[-1][1], out[-1][2]).distance_to(p) < 0.001:
			continue
		out.append([p.x, p.y, p.z])
	return out


## Wie tief das Flussbett an (x, z) unter dem Gelände liegen soll, damit das Wasser Tiefe hat (sonst
## schäumt ein flacher Film überall). Für Spiele, die ihr Gelände selbst bauen: Höhe minus diesen Wert.
## Flüsse: zur Mitte hin tiefer (Mulde), Becken: zum Rand hin flacher. 0 = kein Wasser.
static func channel_depth(regions: Array, x: float, z: float, depth := 0.35) -> float:
	var p := Vector2(x, z)
	var best := 0.0
	var fall_ends := []
	for r in regions:
		if r is Dictionary and str(r.get("kind", "")) == "waterfall":
			for e in [r.points[0], r.points[-1]]:
				fall_ends.append(Vector2(float(e[0]), float(e[2])))
	var at_fall := func(v: Vector2) -> bool: return fall_ends.any(func(f): return f.distance_to(v) < 0.3)
	for r in regions:
		if not r is Dictionary:
			continue
		match str(r.get("kind", "")):
			"river":
				var half := float(r.get("width", 1.0)) * 0.5
				var last: int = r.points.size() - 1
				for k in range(1, last + 1):
					var a := Vector2(float(r.points[k - 1][0]), float(r.points[k - 1][2]))
					var b := Vector2(float(r.points[k][0]), float(r.points[k][2]))
					# An Fallkanten nicht über das Ende hinaus graben (sonst Kerbe in der Kante);
					# an Becken und Zusammenflüssen schon, damit das Bett ohne Schwelle übergeht.
					var t := (p - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001)
					if (k == 1 and t < 0.0 and at_fall.call(a)) or (k == last and t > 1.0 and at_fall.call(b)):
						continue
					var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
					# Nur unter dem Wasser graben: am Ufer endet das Bett genau auf Geländehöhe, sonst
					# liegt neben dem Wasser eine abgesenkte Böschung im Schatten und das Wasser wirkt schwebend.
					if d < half:
						best = maxf(best, depth * (1.0 - pow(d / half, 2.0)))
			"pool":
				var c := Vector2(float(r.center[0]), float(r.center[2]))
				var h := Vector2(float(r.size[0]), float(r.size[1])) * 0.5
				var q := Vector2(absf(p.x - c.x) / h.x, absf(p.y - c.y) / h.y)
				var e := q.length()  # rund statt eckig: das Becken liegt in einer Mulde
				if e < 1.0:
					best = maxf(best, depth * 1.6 * (1.0 - e * e))
	return best


## Gelände einer Kachelkarte: blockierte Felder, Nur-Weg-Felder und Markerzonen sind Hindernisse,
## dazu avoid (z. B. Tower-Felder und der aktuelle Gegnerweg).
static func map_terrain(map: MapData, avoid: Array = []) -> Terrain:
	var t := Terrain.new()
	t.step = Board3D.CELL
	t.bounds = Rect2(0, 0, map.width * t.step, map.height * t.step)
	for y in map.height:
		for x in map.width:
			var c := Vector2i(x, y)
			if map.get_tile(c) != MapData.FLOOR or map.is_marker_zone(c):
				t.blocked[c] = true
	for c in avoid:
		t.blocked[Vector2i(c)] = true
	return t
