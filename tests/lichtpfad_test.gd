extends Node
## Lauf: einzeln (Name lichtpfad)
## Modi: kern
## Lichtpfad (path_lights.gd): Lichter im Abstand von 0,5 s entlang der Gegnerwege, Farben je Modus oder Map,
## Umschalter im HUD (GemTD-Familie und Shopping Maul), gespeichert in Display.path_lights.

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	Profile.dir = "user://test_profile"
	RunHistory.path = "user://test_run_history.json"
	Session.skip_setup = true
	var before: bool = Display.path_lights

	# Einheit: Anzahl, Abstand, Farben
	var board := Board3D.new()
	var pl := PathLights.new(board, "eevetd")
	add_child(pl)
	pl.set_paths([PackedVector2Array([Vector2.ZERO, Vector2(10, 0), Vector2(10, 10)]), PackedVector2Array([Vector2.ZERO])])
	check(pl.lane_count() == 1, "Bahn mit nur einem Punkt wird übersprungen")
	var gap := pl.spacing()
	check(is_equal_approx(pl.speed, PathLights.SPEEDS.eevetd) and is_equal_approx(gap, pl.speed * PathLights.INTERVAL), "Tempo wie eeveTD-Gegner, Abstand %.2f" % gap)
	check(pl.light_count() == pl.lights_on(pl._lanes[0].len) and pl.light_count() >= int(19.0 / gap), "Lichter auf 20 Einheiten: %d" % pl.light_count())
	check(pl._colors[0] == Color(PathLights.COLORS.eevetd[0]), "eeveTD-Farben aus COLORS")
	var l0: Dictionary = pl._lanes[0]
	check(pl._at(l0, gap).distance_to(Vector3(gap, PathLights.HOVER, 0)) < 0.05 and pl._at(l0, 15.0).x > 9.0, "Lichter folgen dem Weg um die Ecke")
	var own := PathLights.new(board, "gemtd", ["123456"])
	check(own._colors == [Color("123456")], "Map-Farben gehen vor")
	# Farbe je Ort (Maul: Spielerfarbe des Gebiets), durchsichtig = Modus-Farbe
	own.color_at = func(p: Vector2) -> Color: return Color.RED if p.x < 5.0 else Color(0, 0, 0, 0)
	add_child(own)
	own.set_paths([PackedVector2Array([Vector2.ZERO, Vector2(20, 0)])])
	check(own.light_color(own._lanes[0], 3.0, 0) == Color.RED, "Licht im Gebiet in dessen Farbe")
	check(own.light_color(own._lanes[0], 12.0, 0) == Color("123456"), "Licht außerhalb in Modus-Farbe")
	own.free()
	pl.free()
	board.free()

	# GemTD: Knopf im HUD, Bahnen, Speichern
	Display.set_path_lights(false)
	Session.map_path = "res://data/maps/canyon.json"
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.path_lights != null and not game.path_lights.visible, "GemTD: Lichtpfad aus")
	check(game.path_lights.lane_count() == game.lane_paths.size(), "GemTD: eine Lichterbahn je Bahn (%d)" % game.path_lights.lane_count())
	check(game.path_lights._colors[0] == Color("ffb03a"), "Map Schlucht hat eigene Farben")
	check(game.hud.lights_button != null and not game.hud.lights_button.button_pressed, "GemTD: Knopf Lichtpfad im HUD")
	check(game.board._path.visible, "GemTD: Wegpunkte am Boden ohne Lichtpfad")
	game.hud.lights_button.button_pressed = true
	check(game.path_lights.visible and Display.path_lights, "GemTD: Knopf schaltet ein")
	check(not game.board._path.visible, "GemTD: mit Lichtpfad keine Wegpunkte am Boden")
	var cfg := ConfigFile.new()
	cfg.load(Display.SETTINGS)
	check(bool(cfg.get_value("display", "path_lights", false)), "Einstellung gespeichert")
	game.queue_free()
	await get_tree().process_frame

	# Shopping Maul: startet eingeschaltet (gespeichert), Wege aller Abschnitte
	var maul: MaulGame = load("res://scenes/maul_game.tscn").instantiate()
	add_child(maul)
	await get_tree().process_frame
	check(maul.path_lights.visible and maul.hud.lights_button.button_pressed, "Maul: Lichtpfad bleibt an")
	check(maul.path_lights.lane_count() > 0, "Maul: %d Lichterbahnen" % maul.path_lights.lane_count())
	check(not maul.board._path.visible, "Maul: mit Lichtpfad keine Wegpunkte am Boden")
	var zc := maul.map.zone_center(maul.players[0].zone)
	check(maul._path_light_color(zc) == Board3D.PLAYER_COLORS[maul.players[0].zone], "Maul: Licht im eigenen Gebiet in Spielerfarbe")
	maul.set_path_lights(false)
	check(not maul.path_lights.visible and not maul.hud.lights_button.button_pressed, "Maul: ausschalten")
	maul.queue_free()
	await get_tree().process_frame

	Display.set_path_lights(before)
	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
