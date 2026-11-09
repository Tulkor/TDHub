class_name WaterSystem
extends GameSystem
## Rein visuelle Wasser-Landschaft. MapData.water oder Haken water_regions() liefert Platzierungen.
## Basis → Typ → Platzierung → Modus: explizite Modus-Materialregeln gewinnen auch gegen Kartenwerte.

var bodies: Array[WaterBody] = []
var definitions: Array = []
var last_errors := PackedStringArray()
var layer: Node3D
var clock := 0.0
var _mode_rules := {}


func setup(owner_game: Node, config: Dictionary) -> void:
	super.setup(owner_game, config)
	var mode := str(get_meta("mode_id", game.system_mode() if game.has_method("system_mode") else ""))
	for entry in Database.modes:
		if str(entry.get("id", "")) == mode:
			_mode_rules = SystemHost.cascade({}, entry.get("system_cfg", {}).get("water", {}))


func _ready() -> void:
	set_process(false)
	Display.quality_changed.connect(refresh_quality)
	# Systeme hängen schon in _init am Spiel; die Karte entsteht erst in dessen _ready.
	rebuild.call_deferred()


func rebuild() -> void:
	if not is_inside_tree() or game == null:
		return
	var regions = hook("water_regions", [], null)
	if regions == null:
		regions = cfg.get("regions")
	if regions == null:
		var map_data = game.get("map") if "map" in game else null
		regions = map_data.water if map_data is MapData else []
	var errors := set_regions(regions)
	if not errors.is_empty():
		push_warning("Wasser: " + "; ".join(errors))


static func validate_regions(regions: Variant, geometry: Dictionary = {}, max_bodies := 64) -> PackedStringArray:
	var errors := PackedStringArray()
	var step = geometry.get("step", 0.5)
	var budget = geometry.get("max_segments", 2048)
	if typeof(step) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(step)) or float(step) < 0.1:
		return PackedStringArray(["geometry.step muss endlich und mindestens 0.1 sein"])
	if typeof(budget) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(budget)) or float(budget) < 1.0 or float(budget) > 65536.0:
		return PackedStringArray(["ungültiges Geometriebudget"])
	if not regions is Array:
		return PackedStringArray(["water muss eine Liste sein"])
	if regions.size() > max_bodies:
		return PackedStringArray(["zu viele Wasserflächen (maximal %d)" % max_bodies])
	for i in regions.size():
		var error := WaterBody.validate(regions[i], geometry)
		if error != "":
			errors.append("water[%d]: %s" % [i, error])
	return errors


## Wasserfälle müssen oben aus Wasser kommen und unten in Wasser münden (Fluss oder Becken auf
## passender Höhe). Liefert je fehlendem Anschluss eine Meldung; solche Fälle werden nicht gebaut.
static func fall_errors(regions: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	var boxes := []
	for region in regions:
		if region is Dictionary:
			boxes.append_array(WaterBody.footprints_of(region))
	for i in regions.size():
		var region = regions[i]
		if not region is Dictionary or str(region.get("kind", "")) != "waterfall":
			continue
		var name := str(region.get("id", "water[%d]" % i))
		if not WaterBody.in_water(WaterBody.vec(region.points[0]), boxes):
			errors.append("%s: Wasserfall beginnt nicht an einem Fluss oder Becken" % name)
		if not WaterBody.in_water(WaterBody.vec(region.points[-1]), boxes):
			errors.append("%s: Wasserfall mündet nicht in einen Fluss oder ein Becken" % name)
	return errors


static func _fall_ok(region: Dictionary, boxes: Array) -> bool:
	return str(region.get("kind", "")) != "waterfall" or (WaterBody.in_water(WaterBody.vec(region.points[0]), boxes) and WaterBody.in_water(WaterBody.vec(region.points[-1]), boxes))


## Leichtes Strömungsmodell: Gewässer, die ineinander fließen, werden geometrisch verbunden, statt
## nur übereinander zu liegen. Liefert Kopien; die Karte selbst bleibt unverändert.
## Flüsse werden als Kurve mit Richtungsvorgaben an den Anschlüssen gebaut (`_dirs`, `_widths`):
## - Fluss → Wasserfall: Ende sitzt exakt auf der Fallkante und läuft in Fallrichtung aus, in Fallbreite.
## - Wasserfall → Fluss: Anfang liegt unter der ganzen Fallkurve und beginnt in Fallrichtung.
## - Fluss ↔ Becken: trifft senkrecht auf den Beckenrand, weitet sich zur Mündung auf und reicht nur
##   knapp hinein (dort blendet er im Shader aus).
static func _connect_flow(regions: Array) -> Array:
	var out := regions.duplicate(true)
	var pools := []
	for region in out:
		if str(region.kind) == "pool":
			pools.append(WaterBody.footprints_of(region)[0])
	var rivers := {}
	for k in out.size():
		if str(out[k].kind) == "river":
			var w := float(out[k].get("width", 2.0))
			var nodes := []
			for point in out[k].points:
				nodes.append({"p": WaterBody.vec(point), "w": w, "d": null})
			rivers[k] = nodes
	for fall in out:
		if str(fall.kind) != "waterfall":
			continue
		var top := WaterBody.vec(fall.points[0])
		var bottom := WaterBody.vec(fall.points[-1])
		var fall_dir := Vector3(bottom.x - top.x, 0.0, bottom.z - top.z)
		if fall_dir.length() < 0.05:
			var right := WaterBody.vec(fall.get("right", [1, 0, 0]))
			fall_dir = Vector3(-right.z, 0.0, right.x)
		fall_dir = fall_dir.normalized()
		var fall_width := float(fall.get("width", 2.0))
		for k in rivers:
			var nodes: Array = rivers[k]
			var w := float(out[k].get("width", 2.0))
			if _near(nodes[-1].p, top, w):
				nodes[-1] = {"p": top, "w": fall_width, "d": fall_dir}
			if _near(nodes[0].p, bottom, w):
				var y: float = nodes[0].p.y
				var back := maxf(Vector2(top.x - bottom.x, top.z - bottom.z).length() * 0.9, 0.3)
				var landing := Vector3(bottom.x, y, bottom.z)
				nodes[0] = {"p": landing, "w": maxf(fall_width, w), "d": fall_dir}
				nodes.insert(0, {"p": landing - fall_dir * back, "w": maxf(fall_width, w), "d": fall_dir})
	for k in rivers:
		for pool in pools:
			_mouth(rivers[k], pool, true)
			_mouth(rivers[k], pool, false)
		var points := []
		var widths := []
		var dirs := []
		for node in rivers[k]:
			points.append([node.p.x, node.p.y, node.p.z])
			widths.append(node.w)
			dirs.append(null if node.d == null else [node.d.x, node.d.z])
		out[k].points = points
		out[k]["_widths"] = widths
		out[k]["_dirs"] = dirs
	return out


static func _near(a: Vector3, b: Vector3, width: float) -> bool:
	return absf(a.y - b.y) <= WaterBody.HEIGHT_TOLERANCE and Vector2(a.x - b.x, a.z - b.z).length() <= width * 0.5 + WaterBody.LINK_TOLERANCE


## Mündung in ein Becken (at_end) bzw. Abfluss aus einem Becken (Anfang).
static func _mouth(nodes: Array, pool: Dictionary, at_end: bool) -> void:
	if nodes.size() < 2:
		return
	var tip: Vector3 = nodes[-1].p if at_end else nodes[0].p
	var prev: Vector3 = nodes[-2].p if at_end else nodes[1].p
	if absf(tip.y - float(pool.y)) > WaterBody.HEIGHT_TOLERANCE or WaterBody.box_distance(tip, pool) > WaterBody.LINK_TOLERANCE or WaterBody.box_distance(prev, pool) <= 0.0:
		return
	# Eintrittspunkt am Rand (Bisektion zwischen prev außen und einem Punkt innen).
	var a := prev
	var b := tip + (tip - prev).normalized() * (WaterBody.LINK_TOLERANCE + 0.01)
	for _i in 24:
		var m := (a + b) * 0.5
		if WaterBody.box_distance(m, pool) > 0.0:
			a = m
		else:
			b = m
	var entry := Vector3(b.x, tip.y, b.z)
	var c: Vector2 = pool.c
	var h: Vector2 = pool.h
	var local := Vector2(entry.x, entry.z) - c
	var q := Vector2(absf(local.x) - h.x, absf(local.y) - h.y)
	var inward := Vector3(-signf(local.x), 0.0, 0.0) if q.x > q.y else Vector3(0.0, 0.0, -signf(local.y))
	var w: float = nodes[-1].w if at_end else nodes[0].w
	var flow := inward if at_end else -inward
	var inside := entry + inward * minf(w * 0.25, 0.4)
	var mouth := [{"p": entry, "w": w * 1.5, "d": flow}, {"p": inside, "w": w * 1.6, "d": flow}]
	if at_end:
		nodes.resize(nodes.size() - 1)
		nodes.append_array(mouth)
	else:
		nodes.remove_at(0)
		mouth.reverse()
		for node in mouth:
			nodes.insert(0, node)


func appearance(region: Dictionary) -> Dictionary:
	var kind := str(region.kind)
	var out := SystemHost.cascade(cfg.get("defaults", {}), cfg.get("styles", {}).get(kind, {}))
	out = SystemHost.cascade(out, region.get("material", {}))
	out = SystemHost.cascade(out, _mode_rules.get("defaults", {}))
	return SystemHost.cascade(out, _mode_rules.get("styles", {}).get(kind, {}))


## Transaktional: bei ungültigen Daten bleiben die bisherigen Flächen erhalten.
func set_regions(regions: Variant) -> PackedStringArray:
	last_errors = validate_regions(regions, cfg.get("geometry", {}), int(cfg.get("max_bodies", 64)))
	if last_errors.is_empty():
		for i in regions.size():
			var resolved: Dictionary = regions[i].duplicate(true)
			resolved.material = appearance(resolved)
			var error := WaterBody.validate(resolved, cfg.get("geometry", {}))
			if error != "":
				last_errors.append("water[%d]: %s" % [i, error])
	if not last_errors.is_empty():
		return last_errors
	_clear_layer()
	definitions = regions.duplicate(true)
	if definitions.is_empty() or not bool(cfg.get("enabled", true)):
		return last_errors
	layer = Node3D.new()
	layer.name = "WaterLandscape"
	var parent: Node = game.get("board") if "board" in game and game.get("board") is Node3D else game
	parent.add_child(layer)
	var boxes := []
	for region: Dictionary in definitions:
		boxes.append_array(WaterBody.footprints_of(region))
	var dangling := fall_errors(definitions)
	if not dangling.is_empty():
		push_warning("Wasser: " + "; ".join(dangling))
	var built := _connect_flow(definitions.filter(func(r): return _fall_ok(r, boxes)))
	var by_index := {}
	for i in built.size():
		var region: Dictionary = built[i]
		var body := WaterBody.new()
		body.name = str(region.get("id", "Water%d" % bodies.size())).validate_node_name()
		body.gravity = float(cfg.get("gravity", 9.8))
		body.configure(region, appearance(region), cfg.geometry)
		layer.add_child(body)
		bodies.append(body)
		by_index[i] = body
	# Aufprall: Schaum und Ringe entstehen im aufnehmenden Wasser selbst, also nie auf trockenem Boden.
	for i in built.size():
		var fall: Dictionary = built[i]
		if str(fall.kind) != "waterfall" or not bool(fall.get("impact", true)):
			continue
		var bottom := WaterBody.vec(fall.points[-1])
		for j in built.size():
			if str(built[j].kind) != "waterfall" and WaterBody.in_water(bottom, WaterBody.footprints_of(built[j])):
				by_index[j].add_impact(bottom, float(fall.get("width", 2.0)) * 0.6)
				break
	# Wo Wasser an Wasser grenzt, gibt es kein Ufer und damit keinen Uferschaum.
	for body in bodies:
		if str(body.definition.kind) == "waterfall":
			continue
		var others := []
		for other in bodies:
			if other != body:
				others.append_array(WaterBody.footprints_of(other.definition))
		body.set_open_neighbors(others)
	refresh_quality()
	set_process(true)
	return last_errors


func refresh_quality() -> void:
	var quality := mini(Display.quality, int(cfg.get("max_quality", 2)))
	if not bool(cfg.get("refraction", true)):
		quality = mini(quality, 1)
	if not bool(cfg.get("depth", true)):
		quality = 0
	for body in bodies:
		body.apply_quality(quality)
		body.set_time(clock)


func set_time(seconds: float) -> void:
	clock = maxf(seconds, 0.0)
	for body in bodies:
		body.set_time(clock)


func _process(delta: float) -> void:
	set_time(clock + delta)


func clear() -> void:
	definitions.clear()
	_clear_layer()


func _clear_layer() -> void:
	set_process(false)
	if is_instance_valid(layer):
		layer.hide()
		layer.queue_free()
	layer = null
	bodies.clear()


func _exit_tree() -> void:
	_clear_layer()
