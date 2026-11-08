class_name MapData
extends RefCounted
## Datenmodell einer Map, gespeichert als JSON (siehe data/maps/).
##
## Ein Feld ist eine halbe Towerbreite (Board3D.CELL), ein Tower belegt 2×2 Felder.
## Dadurch lassen sich Tower um eine halbe Breite versetzen und Gegner passen durch Lücken von einem Feld.
## Maps im alten Format (format 1, ein Feld = ein Tower) werden beim Laden verdoppelt.
##
## Kacheln (eine Zeile pro String in "tiles"):
##   "."  Boden: begehbar und bebaubar
##   "#"  blockiert: weder begehbar noch bebaubar
##   "_"  nur Weg: begehbar, aber nicht bebaubar
## Gegner laufen spawn -> checkpoints[0] -> ... -> goal.
## Um Spawn, Ziel und Checkpoints herum ist im Umkreis marker_radius nicht bebaubar.
##
## Maul-Maps (Koop): weitere Bahnen in "lanes" [{spawn, checkpoints, player}], alle enden im selben goal;
## Bahn 0 ist spawn/checkpoints oben (Spieler in "spawn_player"). Eine Bahn mit player p spawnt nur, wenn
## Spieler p mitspielt, -1 heißt immer. Eine Bahn mit eigenem "goal" endet dort (YouTD-Koop: jeder sein Weg). "zones" [{rect [x, y, w, h], player}]: gibt es Zonen, baut jeder
## Spieler nur in seinen (player -1 = alle).

const FLOOR := "."
const BLOCKED := "#"
const WALK_ONLY := "_"
const FORMAT := 2

var id := "neue_map"
var name := "Neue Map"
var game := ""  ## Modus aus data/modes.json, leer = GemTD (Feld "game" in der Datei)
var width := 30
var height := 30
var rows := PackedStringArray()
var spawn := Vector2i(1, 1)
var goal := Vector2i(2, 2)
var checkpoints: Array[Vector2i] = []
var spawn_player := -1
var lanes: Array = []   ## weitere Bahnen: {spawn: Vector2i, checkpoints: Array[Vector2i], player: int[, goal: Vector2i]}
var zones: Array = []   ## {rect: Rect2i, player: int}
var marker_radius := 1
var wave_set := "classic"
var lives := 50
var start_gold := 0
## Zufallselemente beim Spielstart. random_rocks: Anzahl Steine, seed: -1 = jedes Mal anders.
var variance := {"random_rocks": 0, "seed": -1}
var path_lights: Array = []  ## Farben des Lichtpfads ("#rrggbb"), leer = Farben des Modus (PathLights.COLORS)
## Bezirk (Umgebungs-Baukasten neben der Karte), leer = Standard des Modus. "ueberwuchert" = BezirkUeberwuchert.
var district := ""
const DISTRICTS := ["", "ueberwuchert"]


static func create_empty(w: int, h: int) -> MapData:
	var m := MapData.new()
	m.width = w
	m.height = h
	for y in h:
		m.rows.append(FLOOR.repeat(w))
	m.spawn = Vector2i(4, 4)
	m.goal = Vector2i(w - 5, h - 5)
	return m


static func load_file(path: String) -> MapData:
	var d = Database.load_json(path)
	if typeof(d) != TYPE_DICTIONARY:
		return null
	return from_dict(d)


static func from_dict(d: Dictionary) -> MapData:
	var m := MapData.new()
	m.id = str(d.get("id", "map"))
	m.name = str(d.get("name", m.id))
	m.game = str(d.get("game", ""))
	m.width = int(d.get("width", 20))
	m.height = int(d.get("height", 20))
	var tiles: Array = d.get("tiles", [])
	for y in m.height:
		var row: String = str(tiles[y]) if y < tiles.size() else ""
		m.rows.append(row.rpad(m.width, FLOOR).substr(0, m.width))
	m.spawn = _vec(d.get("spawn", [0, 0]))
	m.goal = _vec(d.get("goal", [m.width - 1, m.height - 1]))
	for c in d.get("checkpoints", []):
		m.checkpoints.append(_vec(c))
	m.spawn_player = int(d.get("spawn_player", -1))
	for l in d.get("lanes", []):
		var cps: Array[Vector2i] = []
		for c in l.get("checkpoints", []):
			cps.append(_vec(c))
		m.lanes.append({"spawn": _vec(l.get("spawn", [0, 0])), "checkpoints": cps, "player": int(l.get("player", -1))})
		if l.has("goal"):
			m.lanes[-1].goal = _vec(l.goal)
	for z in d.get("zones", []):
		var r: Array = z.get("rect", [0, 0, 0, 0])
		m.zones.append({"rect": Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), "player": int(z.get("player", -1))})
	m.marker_radius = int(d.get("marker_radius", 1))
	m.wave_set = str(d.get("waves", "classic"))
	m.lives = int(d.get("lives", 50))
	m.start_gold = int(d.get("start_gold", 0))
	m.variance = d.get("variance", {"random_rocks": 0, "seed": -1})
	m.path_lights = d.get("path_lights", [])
	m.district = str(d.get("district", ""))
	if int(d.get("format", 1)) < FORMAT:
		m._upscale()
	return m


## Altes Format: jedes Feld wird zu 2×2 Feldern, Sperrzonen wachsen mit.
func _upscale() -> void:
	var new_rows := PackedStringArray()
	for row in rows:
		var wide := ""
		for ch in row:
			wide += ch + ch
		new_rows.append(wide)
		new_rows.append(wide)
	rows = new_rows
	width *= 2
	height *= 2
	spawn *= 2
	goal *= 2
	for i in checkpoints.size():
		checkpoints[i] *= 2
	marker_radius = maxi(marker_radius * 2 - 1, 0)


func to_dict() -> Dictionary:
	var cps := []
	for c in checkpoints:
		cps.append([c.x, c.y])
	var d := {
		"format": FORMAT,
		"id": id,
		"name": name,
		"width": width,
		"height": height,
		"tiles": Array(rows),
		"spawn": [spawn.x, spawn.y],
		"goal": [goal.x, goal.y],
		"checkpoints": cps,
		"marker_radius": marker_radius,
		"waves": wave_set,
		"lives": lives,
		"start_gold": start_gold,
		"variance": variance,
	}
	if game != "" and game != "gemtd":
		d.game = game
	if not path_lights.is_empty():
		d.path_lights = path_lights
	if district != "":
		d.district = district
	if spawn_player >= 0:
		d.spawn_player = spawn_player
	if not lanes.is_empty():
		d.lanes = lanes.map(func(l):
			var ld := {"spawn": [l.spawn.x, l.spawn.y], "player": l.player, "checkpoints": l.checkpoints.map(func(c): return [c.x, c.y])}
			if l.has("goal"):
				ld.goal = [l.goal.x, l.goal.y]
			return ld)
	if not zones.is_empty():
		d.zones = zones.map(func(z): return {"rect": [z.rect.position.x, z.rect.position.y, z.rect.size.x, z.rect.size.y], "player": z.player})
	return d


func save_file(path: String) -> bool:
	return Database.save_json(path, to_dict())


func duplicate_map() -> MapData:
	return MapData.from_dict(to_dict())


static func _vec(v) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO


# --- Abfragen ----------------------------------------------------------------

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func get_tile(c: Vector2i) -> String:
	return rows[c.y][c.x]


func set_tile(c: Vector2i, t: String) -> void:
	var r := rows[c.y]
	rows[c.y] = r.substr(0, c.x) + t + r.substr(c.x + 1)


func lane_count() -> int:
	return 1 + lanes.size()


## Spieler, für den Bahn i spawnt (-1 = immer).
func lane_player(i: int) -> int:
	return spawn_player if i == 0 else int(lanes[i - 1].player)


func waypoints(lane := 0) -> Array[Vector2i]:
	var pts: Array[Vector2i] = [spawn if lane == 0 else lanes[lane - 1].spawn]
	pts.append_array(checkpoints if lane == 0 else lanes[lane - 1].checkpoints)
	pts.append(lane_goal(lane))
	return pts


## Ziel von Bahn lane (eigenes "goal" der Bahn, sonst das gemeinsame).
func lane_goal(lane: int) -> Vector2i:
	if lane > 0 and lanes[lane - 1].has("goal"):
		return lanes[lane - 1].goal
	return goal


## Wegpunkte aller Bahnen (Ziel einmal).
func all_waypoints() -> Array[Vector2i]:
	var pts: Array[Vector2i] = waypoints()
	for i in range(1, lane_count()):
		for p in waypoints(i):
			if not pts.has(p):
				pts.append(p)
	return pts


## Darf Spieler p auf Feld c bauen? Ohne Zonen überall, sonst nur in seinen Zonen (und denen für alle).
func can_build_for(c: Vector2i, p: int) -> bool:
	if zones.is_empty():
		return true
	for z in zones:
		if (z.player == p or z.player < 0) and z.rect.has_point(c):
			return true
	return false


## Index des Gebiets, in dem Feld c liegt (-1 = in keinem).
func zone_index(c: Vector2i) -> int:
	for i in zones.size():
		if zones[i].rect.has_point(c):
			return i
	return -1


func is_marker_zone(c: Vector2i) -> bool:
	for p in all_waypoints():
		if maxi(absi(p.x - c.x), absi(p.y - c.y)) <= marker_radius:
			return true
	return false


func is_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and get_tile(c) != BLOCKED


func is_buildable(c: Vector2i) -> bool:
	return in_bounds(c) and get_tile(c) == FLOOR and not is_marker_zone(c)


func resize(w: int, h: int) -> void:
	var new_rows := PackedStringArray()
	for y in h:
		var row := rows[y] if y < rows.size() else ""
		new_rows.append(row.rpad(w, FLOOR).substr(0, w))
	rows = new_rows
	width = w
	height = h
	var clamp_c := func(c: Vector2i) -> Vector2i: return Vector2i(clampi(c.x, 0, w - 1), clampi(c.y, 0, h - 1))
	spawn = clamp_c.call(spawn)
	goal = clamp_c.call(goal)
	for i in checkpoints.size():
		checkpoints[i] = clamp_c.call(checkpoints[i])
	for l in lanes:
		l.spawn = clamp_c.call(l.spawn)
		for i in l.checkpoints.size():
			l.checkpoints[i] = clamp_c.call(l.checkpoints[i])
