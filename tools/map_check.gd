extends Node
## Prüft alle Maps unter data/maps (oder die angegebenen) und gibt Kennzahlen aus.
## Aufruf: godot --headless --path . res://tools/map_check.tscn -- [--kurz] [classic maul_2 ...]
## (oder python3 tools/map_check.py [--kurz] [maps ...])
## Pro Map: Größe (Felder und Towerbreiten), bebaubare Fläche, Weglänge ohne Maze je Bahn,
## Abstände zwischen den Wegpunkten, Zonen. Fehler: Wegpunkt außerhalb oder auf Hindernis,
## Bahn blockiert, Zone außerhalb der Map. Exit-Code 1 bei Fehlern.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var short := args.has("--kurz")
	var names: Array[String] = []
	for a in args:
		if not a.begins_with("--"):
			names.append(a)
	if names.is_empty():
		for f in DirAccess.get_files_at("res://data/maps"):
			if f.ends_with(".json"):
				names.append(f.get_basename())
	var errors := 0
	for n in names:
		errors += _check(n, short)
	print("Maps: %d geprüft, %d Fehler" % [names.size(), errors])
	get_tree().quit(1 if errors > 0 else 0)


func _check(n: String, short: bool) -> int:
	var m := MapData.load_file("res://data/maps/%s.json" % n)
	if m == null:
		print("FEHLER %s: lässt sich nicht laden" % n)
		return 1
	var errs: Array[String] = []
	var water_cfg := SystemHost.config(m.game if m.game != "" else "gemtd", "water")
	var water_errors := WaterSystem.validate_regions(m.water, water_cfg.geometry, int(water_cfg.max_bodies))
	if water_errors.is_empty():
		water_errors = WaterSystem.fall_errors(m.water)
	for error in water_errors:
		errs.append(error)
	var buildable := 0
	for y in m.height:
		for x in m.width:
			if m.is_buildable(Vector2i(x, y)):
				buildable += 1
	var pf := Pathfinder.new(m)
	var lane_info: Array[String] = []
	for lane in m.lane_count():
		var pts := m.waypoints(lane)
		for p in pts:
			if not m.in_bounds(p):
				errs.append("Bahn %d: Wegpunkt %s außerhalb" % [lane, p])
			elif not m.is_walkable(p):
				errs.append("Bahn %d: Wegpunkt %s liegt auf Hindernis" % [lane, p])
		var path := pf.compute_path(lane)
		if path.is_empty():
			errs.append("Bahn %d: kein Weg" % lane)
			continue
		var segs: Array[String] = []
		for i in pts.size() - 1:
			segs.append(str(pf.astar.get_id_path(pts[i], pts[i + 1]).size() - 1))
		lane_info.append("Bahn %d (Spieler %d): %d Felder Weg [Abschnitte %s]" % [lane, m.lane_player(lane), path.size(), " ".join(segs)])
	for z in m.zones:
		if not Rect2i(0, 0, m.width, m.height).encloses(z.rect):
			errs.append("Zone von Spieler %d reicht über den Rand" % z.player)
	print("%s %s: %d×%d Felder (%s×%s Tower), %d bebaubar, %d Bahn(en), %d Zone(n)%s" % [
		"✗" if errs.size() > 0 else "✓", n, m.width, m.height, _half(m.width), _half(m.height),
		buildable, m.lane_count(), m.zones.size(), "" if lane_info.is_empty() else ", " + lane_info[0].split(": ")[1].split(" [")[0]])
	if not short:
		for l in lane_info:
			print("    ", l)
	for e in errs:
		print("    FEHLER ", e)
	return errs.size()


func _half(v: int) -> String:
	return str(v / 2) if v % 2 == 0 else "%d,5" % (v / 2)
