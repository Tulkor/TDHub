extends Node
## Lauf: einzeln (Name sysrunrecord)
## Modi: system:run_record
## System run_record ohne Modus: Run-Ende und Abbruch ins Profil, Haken profile_mode/profile_extra/debug_run,
## feste Werte gewinnen über profile_extra, gebuchte Zeit, Profil-Schlüssel aus der Kaskade.
## Start: tools/run_tests.sh sysrunrecord

var failures := 0


class FakeGame extends Node:
	var systems := {}
	var play_time := 100.0
	var profile_time := 0
	var ascension_unlocked := -1
	var debug := false
	var extra := {}

	func profile_extra() -> Dictionary:
		return extra


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	Profile.dir = "user://test_profile_sysrunrecord"
	Profile.reset_cache()
	await get_tree().process_frame
	var game := FakeGame.new()
	add_child(game)
	SystemHost.attach(game, "heroes", ["run_record"])
	var rr = game.systems.run_record
	check(rr.mode_key() == "heroes", "Profil-Schlüssel aus system_cfg des Modus (Kaskade)")
	check(int(rr.cfg.abort_min_seconds) == 10, "Basiswert bleibt, wo der Modus nichts sagt")
	game.extra = {"race": "x", "difficulty": 99}
	var before := int(Profile.mode("heroes").runs)
	rr.finish({"victory": true, "wave": 3, "waves": 10, "play_time": 100}, {}, {"difficulty": 2})
	check(int(Profile.mode("heroes").runs) == before + 1, "Run steht im Profil")
	check(game.profile_time == 100, "Spielzeit ist danach gebucht")
	check(game.ascension_unlocked == 0, "Freischaltung wird ins Spiel geschrieben")
	var last: Dictionary = Profile.data().runs[0]
	check(int(last.get("difficulty", -1)) == 2, "feste Werte gewinnen über profile_extra")
	check(last.get("debug") == false, "kein Debug-Run")
	game.play_time = 105.0
	check(not rr.abort({"play_time": 105}), "Abbruch nach 5 s zählt nicht")
	game.play_time = 130.0
	check(rr.abort({"play_time": 130}), "Abbruch nach 30 s wird gebucht")
	game.debug = true
	check(rr.is_debug(), "Debug-Run ohne Haken über game.debug")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
