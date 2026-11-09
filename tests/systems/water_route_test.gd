extends Node
## Lauf: einzeln (Name wasserlauf)
## Modi: system:water
## Wasserlauf-Finder: Ausweichen auf Kachelkarten, Wegpunkte, Fälle an Stufen, Becken in Mulden mit Überlauf.
## Start: tools/run_tests.sh wasserlauf

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func kinds(regions: Array) -> Array:
	return regions.map(func(r): return str(r.kind))


## Alle erzeugten Einträge müssen für das Wassersystem gültig und Wasserfälle angeschlossen sein.
func check_valid(regions: Array, label: String) -> void:
	var errors := WaterSystem.validate_regions(regions)
	check(errors.is_empty(), label + ": Einträge gültig " + "; ".join(errors))
	var dangling := WaterSystem.fall_errors(regions)
	check(dangling.is_empty(), label + ": Wasserfälle oben und unten angeschlossen " + "; ".join(dangling))


func hill_terrain(height: Callable, size := 30.0) -> WaterRoute.Terrain:
	var t := WaterRoute.Terrain.new()
	t.bounds = Rect2(0, 0, size, size)
	t.step = 0.5
	t.height = height
	t.hilly = true
	return t


func _ready() -> void:
	# 1) Flache Karte: Felsblock mitten im geraden Lauf, das Wasser muss mit Abstand vorbeifließen.
	var map := MapData.create_empty(60, 60)
	for y in range(22, 38):
		for x in range(26, 32):
			map.set_tile(Vector2i(x, y), MapData.BLOCKED)
	map.spawn = Vector2i(2, 58)
	map.goal = Vector2i(57, 58)
	var flat := WaterRoute.map_terrain(map)
	var result := WaterRoute.resolve({"id": "Bach", "kind": "stream", "source": [1.0, 15.0], "dir": [1, 0], "width": 1.0}, flat)
	check(result.errors.is_empty(), "flach: keine Fehler " + "; ".join(result.errors))
	check(kinds(result.regions) == ["river"], "flach: ein durchgehender Fluss %s" % str(kinds(result.regions)))
	var hits := 0
	var near := 0
	for c: Vector2i in result.cells:
		if map.get_tile(c) != MapData.FLOOR:
			hits += 1
		for y in range(22, 38):
			for x in range(26, 32):
				if Vector2(c - Vector2i(x, y)).length() < 1.5:
					near += 1
	check(hits == 0 and near == 0, "flach: Lauf meidet Felsen mit Abstand (%d/%d)" % [hits, near])
	var last: Vector2i = result.cells[-1]
	check(last.x == 59, "flach: läuft bis zum Kartenrand (%s)" % str(last))
	check_valid(result.regions, "flach")

	# 2) Gegnerweg und Tower als Hindernisse (avoid), dazu ein Wegpunkt.
	var avoid := []
	for y in 60:
		avoid.append(Vector2i(40, y))
	var walled := WaterRoute.map_terrain(map, avoid)
	result = WaterRoute.resolve({"kind": "stream", "source": [1.0, 5.0], "via": [[10.0, 25.0]], "width": 1.0}, walled)
	var crossed: bool = result.cells.any(func(c): return c.x == 40)
	var via_hit: bool = result.cells.any(func(c): return Vector2(c).distance_to(Vector2(20, 50)) <= 1.5)
	check(not crossed, "flach: Gegnerweg wird nicht überquert")
	check(via_hit, "flach: Wegpunkt wird angelaufen")
	check_valid(result.regions, "flach mit Weg")
	# Eingeschlossen von Weg und Towern: Sackgasse endet in einem kleinen See.
	var pen := []
	for i in 41:
		pen.append(Vector2i(40, i))
		pen.append(Vector2i(i, 40))
	result = WaterRoute.resolve({"kind": "stream", "source": [2.0, 2.0], "dir": [1, 1], "width": 1.0}, WaterRoute.map_terrain(map, pen))
	check(kinds(result.regions)[-1] == "pool", "flach: Sackgasse endet in einem See %s" % str(kinds(result.regions)))
	check(not result.cells.any(func(c): return c.x >= 40 or c.y >= 40), "flach: bleibt im eingeschlossenen Bereich")
	check_valid(result.regions, "Sackgasse")

	# 3) Gelände mit Stufe: oben eben, Kante bei z = 12, unten 2 Einheiten tiefer und leicht fallend.
	var step_h := func(x: float, z: float) -> float: return (2.0 if z < 12.0 else 0.0) - z * 0.01
	result = WaterRoute.resolve({"id": "Fall", "kind": "stream", "source": [15.0, 2.0], "dir": [0, 1], "width": 1.5}, hill_terrain(step_h))
	var k := kinds(result.regions)
	check(k.has("waterfall"), "Stufe: Wasserfall entsteht %s" % str(k))
	check(k.find("waterfall") > 0 and k[k.find("waterfall") - 1] == "river" and k[k.find("waterfall") + 1] == "river", "Stufe: Fluss → Fall → Fluss")
	var fall: Dictionary = result.regions[k.find("waterfall")]
	check(absf(float(fall.points[0][2]) - 12.0) < 1.0 and float(fall.points[0][1]) - float(fall.points[-1][1]) > 1.5, "Stufe: Fall sitzt an der Kante und überwindet die Höhe")
	check_valid(result.regions, "Stufe")
	var down := true
	for r in result.regions:
		if str(r.kind) == "river":
			for n in range(1, r.points.size()):
				down = down and float(r.points[n][1]) <= float(r.points[n - 1][1]) + 0.001
	check(down, "Stufe: Flüsse fließen nie bergauf")

	# 4) Mulde ohne Ausgang: das Wasser läuft hinein und bildet ein Becken.
	var bowl := func(x: float, z: float) -> float: return Vector2(x - 15.0, z - 15.0).length_squared() * 0.004
	result = WaterRoute.resolve({"kind": "stream", "source": [4.0, 15.0], "width": 1.0, "max_pool_cells": 200}, hill_terrain(bowl))
	k = kinds(result.regions)
	check(k.size() >= 2 and k[-1] == "pool" and k[-2] == "river", "Mulde: Fluss mündet in Becken %s" % str(k))
	if k[-1] == "pool":
		var pool: Dictionary = result.regions[-1]
		check(Vector2(float(pool.center[0]), float(pool.center[2])).distance_to(Vector2(15, 15)) < 2.0, "Mulde: Becken liegt am tiefsten Punkt")
	check_valid(result.regions, "Mulde")

	# 5) Mulde mit Überlauf: Becken füllt sich bis zur niedrigen Seite, dann geht es weiter bergab.
	# Schüssel um (12, 15) mit einer Rinne nach rechts, die ab etwa x = 15 tiefer liegt als die Schüssel.
	var lip := func(x: float, z: float) -> float:
		var bowl_h := Vector2(x - 12.0, z - 15.0).length_squared() * 0.03
		var channel := 0.3 - (x - 12.0) * 0.04 if x > 12.0 and absf(z - 15.0) < 1.5 else INF
		return minf(bowl_h, channel)
	result = WaterRoute.resolve({"kind": "stream", "source": [12.0, 4.0], "dir": [0, 1], "width": 1.0}, hill_terrain(lip))
	k = kinds(result.regions)
	var pool_at: int = k.find("pool")
	check(pool_at >= 0 and k.size() > pool_at + 1, "Überlauf: nach dem Becken fließt es weiter %s" % str(k))
	check_valid(result.regions, "Überlauf")

	# Zusammenfluss: ein zweiter Lauf quer zum ersten endet in ihm, statt ihn zu kreuzen.
	var two := WaterRoute.expand([
		{"kind": "stream", "source": [1.0, 15.0], "dir": [1, 0], "width": 1.0},
		{"kind": "stream", "source": [10.0, 1.0], "dir": [0, 1], "width": 1.0}], flat)
	var second: Dictionary = two.regions[-1]
	check(float(second.points[-1][2]) < 16.5 and float(second.points[-1][2]) > 13.0, "Zusammenfluss: zweiter Lauf mündet in den ersten (z = %.2f)" % float(second.points[-1][2]))

	# 6) Ungültige Vorgaben und expand.
	check(WaterRoute.validate({"kind": "stream"}) != "", "ohne Quelle abgelehnt")
	check(WaterRoute.validate({"kind": "stream", "source": [1, 1], "width": -1}) != "", "negative Breite abgelehnt")
	check(WaterRoute.validate({"kind": "stream", "source": [1, 1], "via": [[1]]}) != "", "kaputter Wegpunkt abgelehnt")
	var out_of := WaterRoute.resolve({"kind": "stream", "source": [-5, 1]}, flat)
	check(not out_of.errors.is_empty() and out_of.regions.is_empty(), "Quelle außerhalb gemeldet")
	var pool_entry := {"kind": "pool", "center": [5, 0, 5], "size": [2, 2]}
	var expanded := WaterRoute.expand([pool_entry, {"kind": "stream", "source": [1.0, 15.0], "dir": [1, 0]}], flat)
	check(expanded.regions[0] == pool_entry and expanded.regions.size() >= 2 and expanded.errors.is_empty(), "expand ersetzt nur Läufe")
	var with_banks := WaterRoute.resolve({"kind": "stream", "source": [1, 15], "dir": [1, 0], "length": 4, "banks": {"height": 0.25}, "crest_foam": false}, flat)
	check(not with_banks.regions.is_empty() and with_banks.regions.all(func(r): return r.get("banks", {}).get("height") == 0.25 and r.get("crest_foam") == false), "Lauf vererbt Ufer- und Kantenschaumregeln an erzeugte Gewässer")
	check(WaterRoute.validate({"kind": "stream", "source": [1, 1], "banks": {"width": -1}}) != "", "ungültige Böschung wird vor der Laufsuche abgelehnt")

	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
