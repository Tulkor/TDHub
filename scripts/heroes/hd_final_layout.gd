class_name HdFinalLayout
extends RefCounted
## Gemeinsame Kontur für Schlund-Boden, Felsplatzierung und Bewegung. Geometrie lokal, Abfragen in Weltkoordinaten.

var data: Dictionary
var center: Vector3
var _segments: Array = []
var _rooms: Array = []


func _init(config: Dictionary, world_center: Vector3) -> void:
	data = config
	center = world_center
	var court: Dictionary = data.area.layout
	_add_segments(_segments, court.spine, float(court.width))
	for row in court.arms:
		_add_segments(_segments, row.points, float(row.width))
		_rooms.append({"id":str(row.id), "pos":_v(row.points[-1]), "radius":float(row.radius)})
	_rooms.append({"id":"boss", "pos":_v(data.arena.pos), "radius":float(data.arena.radius)})


func floor_segments() -> Array:
	return _segments


func rooms() -> Array:
	return _rooms


func arm(id: String) -> Dictionary:
	for row in data.area.layout.arms:
		if str(row.id) == id:
			return row
	return {}


func arm_axis(id: String) -> Vector3:
	var row := arm(id)
	return (_v(row.points[-1]) - _v(row.points[-2])).normalized() if not row.is_empty() else Vector3.FORWARD


func arm_point_from_room(id: String, distance: float) -> Vector3:
	var row := arm(id)
	for i in range(row.points.size() - 1, 0, -1):
		var a := _v(row.points[i])
		var b := _v(row.points[i - 1])
		var length := a.distance_to(b)
		if distance <= length:
			return center + a.move_toward(b, distance)
		distance -= length
	return center + _v(row.points[0])


## Positiver Rand erweitert die Kontur (für Fels-Fußabdrücke); negativer Rand verkleinert sie für Einheiten.
func inside(world_point: Vector3, margin := 0.0) -> bool:
	var p := world_point - center
	p.y = 0
	for room in rooms():
		if p.distance_to(room.pos) <= maxf(0.1, float(room.radius) + margin):
			return true
	for segment in floor_segments():
		if p.distance_to(_project(p, segment.from, segment.to)) <= maxf(0.1, float(segment.width) * 0.5 + margin):
			return true
	return false


func constrain(world_point: Vector3, radius: float) -> Vector3:
	if inside(world_point, -radius):
		return world_point
	var p := world_point - center
	p.y = 0
	var best := Vector3.ZERO
	var distance := INF
	for room in rooms():
		var q: Vector3 = room.pos + (p - room.pos).limit_length(maxf(0.1, float(room.radius) - radius))
		if q.distance_squared_to(p) < distance:
			distance = q.distance_squared_to(p)
			best = q
	for segment in floor_segments():
		var nearest := _project(p, segment.from, segment.to)
		var q := nearest + (p - nearest).limit_length(maxf(0.1, float(segment.width) * 0.5 - radius))
		if q.distance_squared_to(p) < distance:
			distance = q.distance_squared_to(p)
			best = q
	return center + best


static func _add_segments(target: Array, points: Array, width: float) -> void:
	for i in points.size() - 1:
		target.append({"from":_v(points[i]), "to":_v(points[i + 1]), "width":width})


static func _v(point: Array) -> Vector3:
	return Vector3(float(point[0]), 0, float(point[1]))


static func _project(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	return a + d * clampf((p - a).dot(d) / maxf(d.length_squared(), 0.001), 0, 1)
