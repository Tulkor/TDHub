class_name MaulMap
extends MapData
## Karte von Shopping Maul (data/maul/map.json). Statt Bahnen mit Spawn → Checkpoints → Ziel
## laufen die Gegner Routen aus mehreren Abschnitten mit Teleports dazwischen (map.json → maul).
## Board3D zeichnet über die überschriebenen Funktionen Erde und Sperrfelder um die Wegpunkte.

var maul: Dictionary = {}
var route_points: Array[Vector2i] = []   ## alle Wegpunkte und Spawns, einmal
var _near := {}                          ## Felder um Wegpunkte: nicht bebaubar


static func create() -> MaulMap:
	var d := MaulData.map_dict()
	var src := MapData.from_dict(d)
	var m := MaulMap.new()
	m.id = src.id
	m.name = src.name
	m.width = src.width
	m.height = src.height
	m.rows = src.rows
	m.zones = src.zones
	m.lives = src.lives
	m.water = src.water.duplicate(true)
	m.marker_radius = 1
	m.maul = d.get("maul", {})
	m._collect_points()
	return m


static func cell(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func _collect_points() -> void:
	var add := func(c: Vector2i):
		if not route_points.has(c):
			route_points.append(c)
	for s in maul.get("spawns", []):
		add.call(cell(s.cell))
	for r in maul.get("routes", {}).values():
		var all_legs: Array = r.get("legs", []).duplicate()
		for ch in r.get("choices", []):
			all_legs.append_array(ch.get("legs", []))
		for leg in all_legs:
			for p in leg:
				add.call(cell(p))
	for c in route_points:
		for dy in range(-marker_radius, marker_radius + 1):
			for dx in range(-marker_radius, marker_radius + 1):
				_near[c + Vector2i(dx, dy)] = true


## Keine GemTD-Bahnen: Board3D legt Erde nur auf die Gänge ("_") und um die Wegpunkte.
func lane_count() -> int:
	return 0


func all_waypoints() -> Array[Vector2i]:
	return route_points


func is_marker_zone(c: Vector2i) -> bool:
	return _near.has(c)


## Zone (Index in zones), in der das Feld liegt, sonst -1.
func zone_at(c: Vector2i) -> int:
	for i in zones.size():
		if zones[i].rect.has_point(c):
			return i
	return -1


func zone_center(i: int) -> Vector2:
	var r: Rect2i = zones[i].rect
	return (Vector2(r.position) + Vector2(r.size) / 2.0) * Board3D.CELL
