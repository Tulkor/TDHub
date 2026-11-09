extends Node
## Lauf: einzeln (Name bezirk)
## Modi: eevetd, youtd, heroes
## Bezirk „Überwuchert“ (BezirkUeberwuchert): alle Teile laden, Feld "district" der Map übersteht Speichern/Laden,
## eeveTD baut den Pilzhof statt des Friedhofs, Wald wächst nicht hinein, Lichter nur nachts.

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

	for t in BezirkUeberwuchert.TEILE:
		var n := BezirkUeberwuchert.teil(t)
		check(n != null and not n.find_children("*", "MeshInstance3D", true, false).is_empty(), "Teil %s lädt" % t)
		if n != null:
			n.free()

	# Feld district: Standard leer (nicht gespeichert), gesetzt bleibt es erhalten
	var md := MapData.load_file("res://data/maps/eeve.json")
	check(md.district == "" and not md.to_dict().has("district"), "ohne Bezirk kein Feld in der Datei")
	md.district = BezirkUeberwuchert.ID
	check(MapData.from_dict(md.to_dict()).district == BezirkUeberwuchert.ID, "district übersteht Speichern/Laden")

	# eeveTD mit Pilzhof
	Session.game_kind = "eevetd"
	Session.map_path = "res://data/maps/eeve.json"
	Session.map_override = md
	var game = load(Session.game_scene()).instantiate()
	add_child(game)
	await get_tree().process_frame
	var sc: EeveScenery = game.scenery
	check(sc.bezirk != null, "eeveTD: Pilzhof gebaut")
	check(sc.bezirk.get_child_count() >= BezirkUeberwuchert.AUFBAU.size(), "Pilzhof hat %d Teile" % sc.bezirk.get_child_count())
	var church := sc.find_children("*church*", "", true, false)
	check(church.is_empty(), "kein Friedhof neben dem Pilzhof")
	var mitte := sc._gy(0.0, 4.0)
	check(sc._in_clearing(mitte) and sc.bezirk.enthaelt(mitte), "Hofmitte bleibt frei von Bäumen")
	check(not sc.bezirk.enthaelt(sc._gy(0.0, 30.0)), "weit draußen wieder Wald")
	sc.set_night(true)
	check(sc.bezirk.lichter.all(func(l): return l.visible or Display.quality == Display.LOW), "nachts leuchten die Hoflichter")
	sc.set_night(false)
	check(sc.bezirk.lichter.all(func(l): return not l.visible), "tags sind die Hoflichter aus")
	game.queue_free()
	await get_tree().process_frame

	# ohne Bezirk: Friedhof wie bisher
	Session.map_override = null
	game = load(Session.game_scene()).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.scenery.bezirk == null, "ohne district bleibt der Friedhof")
	game.queue_free()
	await get_tree().process_frame

	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
