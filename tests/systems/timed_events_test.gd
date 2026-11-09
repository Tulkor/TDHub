extends Node
## Lauf: einzeln (Name systimedevents)
## Modi: system:timed_events
## System timed_events (timed_events) ohne Modus: an einem leeren Spiel-Knoten angelegt und geprüft.
## Start: tools/run_tests.sh systimedevents

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	var game := Node.new()
	add_child(game)
	var got := SystemHost.attach(game, "", ["timed_events"])
	check(got.has("timed_events"), "timed_events lässt sich ohne Modus anlegen")
	var te = got.timed_events
	te.pool = [{"id": "a", "weight": 1.0}, {"id": "b", "weight": 1.0, "from": 5}, {"id": "c", "weight": 0.0}]
	te.cfg = {"interval": 10.0, "no_repeat": 1}
	te.reset()
	for k in 9:
		te.tick(1.0)
	check(te.history.is_empty(), "vor dem Abstand kein Ereignis")
	te.tick(1.0)
	check(te.history.size() == 1 and te.history[0][1] == "a", "nach dem Abstand eins; from und Gewicht 0 filtern")
	check(te.candidates().is_empty(), "no_repeat: das letzte nicht gleich wieder")
	te.force = "c"
	check(str(te.pick().id) == "c" and te.force == "", "force gewinnt einmal")
	check(is_equal_approx(te.remaining(), 10.0), "Restzeit bis zum nächsten")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
