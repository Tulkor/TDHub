extends Node
## Lauf: einzeln (Name syswater)
## Modi: system:water
## Wasser: Karten-Rundreise, Geometrie/UVs, Kaskade, Grafikwechsel, Pause und transaktionale Validierung.
## Start: tools/run_tests.sh syswater

var failures := 0


class GameFixture:
	extends Node3D
	var systems := {}
	var map: MapData
	var region_override: Variant = null

	func system_mode() -> String:
		return "gemtd"

	func water_regions() -> Variant:
		return region_override


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	var quality_before: int = Display.quality
	var regions := [
		{"kind": "pool", "center": [4, 0.1, 4], "size": [4, 3], "material": {"speed": 9.0, "foam_width": 0.3}},
		{"kind": "river", "points": [[0, 2, 0], [0, 2, 3], [2, 2, 5]], "width": 2.0},
		{"kind": "waterfall", "points": [[2, 2, 5], [2, 0.1, 5.6]], "width": 2.0}
	]
	var map := MapData.create_empty(16, 16)
	map.water = regions.duplicate(true)
	var copied := MapData.from_dict(map.to_dict())
	check(copied.water == regions, "Wasserdaten überleben Speichern/Laden")
	copied.water[0].center[0] = 99
	check(map.water[0].center[0] == 4, "Kartenkopien teilen keine Wasser-Daten")
	check(not MapData.create_empty(16, 16).to_dict().has("water"), "alte Karten bleiben ohne zusätzliches Wasser-Feld")
	check(MapData.from_dict({"water": {}}) == null, "falscher Wasser-Datentyp wird abgelehnt")
	var source := MaulData.map_dict()
	var had_water := source.has("water")
	var saved_water: Variant = source.get("water")
	source.water = regions.duplicate(true)
	check(MaulMap.create().water == regions, "auch die eigene Maul-Kartenklasse übernimmt Wasser")
	if had_water:
		source.water = saved_water
	else:
		source.erase("water")
	var mode: Dictionary = Database.modes[0]
	var original: Dictionary = mode.get("system_cfg", {}).duplicate(true)
	mode["system_cfg"] = SystemHost.cascade(original, {"water": {"defaults": {"speed": 0.9}, "styles": {"waterfall": {"speed": 2.8}}}})
	var owner_game := GameFixture.new()
	owner_game.map = map
	add_child(owner_game)
	var got := SystemHost.attach(owner_game, "gemtd", ["water"])
	var water := got.water as WaterSystem
	await get_tree().process_frame
	await get_tree().process_frame
	water.set_process(false)
	check(water.bodies.size() == 3, "Karten-Gewässer werden nach Spiel-Ready automatisch aufgebaut")
	check(is_equal_approx(float(water.bodies[0].material.get_shader_parameter("speed")), 0.9), "Modus-Regel gewinnt gegen Karten-Materialwert 9")
	check(is_equal_approx(float(water.bodies[2].material.get_shader_parameter("speed")), water.bodies[2].fall_speed * 2.8), "Modus-Typregel gewinnt gegen allgemeine Modus-Regel (Wasserfall: Faktor auf Fallphysik)")
	check(is_equal_approx(float(water.bodies[0].material.get_shader_parameter("foam_width")), 0.3), "Kartenwert bleibt ohne Modus-Überschreibung erhalten")
	var generic_owner := Node3D.new()
	add_child(generic_owner)
	var generic_water: WaterSystem = SystemHost.attach(generic_owner, "gemtd", ["water"]).water
	check(is_equal_approx(float(generic_water.appearance(regions[0]).speed), 0.9), "Modus-Vorrang funktioniert auch ohne spezielle Spielklasse")
	generic_owner.queue_free()
	check(water.bodies[0].impacts.size() == 1, "Wasserfall schäumt im aufnehmenden Becken auf (nicht auf trockenem Boden)")
	var fall_arrays := water.bodies[2].surface.mesh.surface_get_arrays(0)
	var lowest := INF
	var highest := -INF
	for v: Vector3 in fall_arrays[Mesh.ARRAY_VERTEX]:
		lowest = minf(lowest, v.y)
		highest = maxf(highest, v.y)
	check(is_equal_approx(highest, 2.0) and is_equal_approx(lowest, 0.1), "Fallkurve verbindet Kante und Aufprallhöhe")
	var aeration: PackedColorArray = fall_arrays[Mesh.ARRAY_COLOR]
	var aer_min := 1.0
	var aer_max := 0.0
	for c in aeration:
		aer_min = minf(aer_min, c.r)
		aer_max = maxf(aer_max, c.r)
	check(aer_min < 0.01 and aer_max > 0.99, "Belüftung wächst mit der Fallgeschwindigkeit von 0 auf 1")
	check(water.bodies[2].fall_speed > 1.0, "Fall-Textur läuft mit der Physik-Geschwindigkeit")
	var joined := WaterSystem._connect_flow([
		{"kind": "waterfall", "points": [[0, 2, 0], [0, 0, 1]], "width": 1.0},
		{"kind": "river", "points": [[0, 0, 1], [0, 0, 4]], "width": 1.0},
		{"kind": "pool", "center": [0, 0, 6], "size": [4, 4]}
	])
	check(joined[1].points.size() == 4 and joined[1]._widths.size() == 4, "Fluss reicht unter den Wasserfall zurück und mündet ins Becken")
	check(float(joined[1].points[0][2]) < 1.0 and float(joined[1].points[-1][2]) > 4.0, "Verlängerungen zeigen in die richtige Richtung")
	check(is_equal_approx(float(joined[1].points[-2][2]), 4.0) and joined[1]._dirs[-2] == [0.0, 1.0] and float(joined[1]._widths[-2]) > 1.0, "Fluss trifft senkrecht und aufgeweitet auf den Beckenrand")
	var bent := WaterSystem._connect_flow([
		{"kind": "river", "points": [[-4, 2, -2], [0, 2, 0]], "width": 1.0},
		{"kind": "waterfall", "points": [[0, 2, 0], [0, 0, 1]], "width": 1.4, "right": [1, 0, 0]}
	])
	check(bent[0].points.size() == 2 and bent[0]._dirs[-1] == [0.0, 1.0], "Fluss läuft an der Kante in Fallrichtung aus")
	check(is_equal_approx(float(bent[0]._widths[-1]), 1.4), "Flussende hat die Breite der Fallkante")
	check(WaterSystem.fall_errors(regions).is_empty(), "angeschlossener Wasserfall gilt als gültig")
	var dangling := [{"id": "Los", "kind": "waterfall", "points": [[9, 2, 9], [9, 0.1, 9.5]], "width": 1.0}]
	check(WaterSystem.fall_errors(dangling).size() == 2, "Wasserfall ohne Zu- und Abfluss wird gemeldet")
	check(WaterSystem.fall_errors([regions[1], {"kind": "waterfall", "points": [[2, 2, 5], [2, 0.1, 9.6]], "width": 2.0}]).size() == 1, "Wasserfall ohne Becken am Fuß wird gemeldet")
	check(water.bodies[0].open_a.size() >= 1, "Becken kennt den einmündenden Fluss (kein Uferschaum am Übergang)")
	check(water.bodies[1].open_b.size() >= 1 and water.bodies[1].open_b[0].w == 1.0, "Fluss blendet im Becken aus statt doppelt zu überlappen")
	check(water.bodies[2].open_a.is_empty(), "Wasserfall braucht keine Ufer-Nachbarn")
	check(WaterBody.in_water(Vector3(4, 0.1, 4), WaterBody.footprints_of(regions[0])) and not WaterBody.in_water(Vector3(4, 1.5, 4), WaterBody.footprints_of(regions[0])), "Anschluss prüft auch die Höhe")
	var river := water.bodies[1]
	check(river.path_length > 5.0 and river.path_length < 7.0, "Flusslänge folgt dem geglätteten, zur Kante eingebogenen Pfad")
	var arrays := river.surface.mesh.surface_get_arrays(0)
	var max_v := 0.0
	var finite_normals := true
	for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
		max_v = maxf(max_v, uv.y)
	for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		finite_normals = finite_normals and normal.is_finite() and normal.length() > 0.9
	check(is_equal_approx(max_v, river.path_length), "UV-Abstand in Metern: Strömungsgeschwindigkeit unabhängig von Segmenten")
	check(finite_normals, "Fluss-Normalen sind endlich und normiert")
	check(WaterBody.NORMAL.get_width() == 256 and WaterBody.FLOW.get_height() == 256, "erzeugte Normal-/Strömungstexturen geladen")
	var previous := water.bodies[0]
	check(not water.set_regions([{"kind": "river", "width": -1, "points": [[0, 0, 0], [1, 0, 1]]}]).is_empty(), "negative Breite wird abgelehnt")
	check(water.bodies[0] == previous, "ungültiges Update lässt vorhandenes Wasser intakt")
	water._mode_rules.defaults.speed = NAN
	check(not water.set_regions(regions).is_empty() and water.bodies[0] == previous, "ungültige Modus-Materialwerte beschädigen vorhandenes Wasser nicht")
	water._mode_rules.defaults.speed = 0.9
	check(not WaterSystem.validate_regions(regions, {"step": 0}).is_empty(), "ungültige Unterteilung wird vor Mesh-Aufbau abgelehnt")
	for invalid in [
		{"kind": "river", "points": [[0, 0, 0], [0, 0, 0]]},
		{"kind": "waterfall", "points": [[0, 0, 0], [0, 2, 0]]},
		{"kind": "river", "points": [[0, 0, 0], [NAN, 0, 0]]},
		{"kind": "waterfall", "points": [[0, 2, 0], [1, 2, 0], [1, 0, 0]], "right": [1, 0, 0]},
		{"kind": "pool", "center": [0, 0, 0], "size": [1000, 1000]}
	]:
		check(not WaterSystem.validate_regions([invalid], water.cfg.geometry).is_empty(), "ungültige Geometrie wird abgelehnt: " + str(invalid.kind))
	Display.quality = Display.LOW
	Display.apply_quality()
	check(river.material.shader == WaterBody.SURFACE_SHADERS[0], "Niedrig: Wasser ohne Tiefen-/Bildschirmzugriff")
	Display.quality = Display.HIGH
	Display.apply_quality()
	check(river.material.shader == WaterBody.SURFACE_SHADERS[2], "Hoch: vorhandenes Wasser wechselt zu Brechung")
	water.cfg.refraction = false
	water.refresh_quality()
	check(river.material.shader == WaterBody.SURFACE_SHADERS[1], "Modus kann Brechung auch auf Hoch ausschalten")
	water.cfg.depth = false
	water.refresh_quality()
	check(river.material.shader == WaterBody.SURFACE_SHADERS[0], "Modus kann Tiefeneffekte vollständig ausschalten")
	water.set_time(3.0)
	water._process(0.5)
	check(is_equal_approx(float(river.material.get_shader_parameter("flow_time")), 3.5), "gemeinsame Strömungsuhr wird an Materialien weitergegeben")
	water.set_process(true)
	get_tree().paused = true
	var time_before := water.clock
	await get_tree().create_timer(0.05, true).timeout
	check(is_equal_approx(water.clock, time_before), "Wasseranimation pausiert mit dem Spiel")
	get_tree().paused = false
	owner_game.region_override = regions + [{"id": "Los", "kind": "waterfall", "points": [[9, 2, 9], [9, 0.1, 9.5]], "width": 1.0}]
	water.rebuild()
	check(water.bodies.size() == 3, "losgelöster Wasserfall wird nicht gebaut, der Rest bleibt")
	owner_game.region_override = []
	water.rebuild()
	check(water.bodies.is_empty() and not water.is_processing(), "Modus-Haken kann Kartenwasser entfernen, ohne Leerlauf-Prozess")
	check(map.water == regions, "Darstellung verändert keine Karten-/Spielregeln")
	owner_game.region_override = null
	water.cfg.enabled = false
	water.rebuild()
	check(water.bodies.is_empty(), "Modus kann Wassersystem abschalten")
	mode["system_cfg"] = original
	Display.quality = quality_before
	Display.apply_quality()
	owner_game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
