extends Node
## Lauf: einzeln (Name sysdifficulty)
## Modi: system:difficulty
## System difficulty ohne Modus: Liste aus Session, rules oder cfg (Kaskade aus modes.json), Index, Name mit
## Aufstiegsstufe, Aufstieg nur auf der höchsten Schwierigkeit, Werte-Änderungen der Stufe.
## Start: tools/run_tests.sh sysdifficulty

var failures := 0


class FakeGame extends Node:
	var systems := {}
	var difficulty := 0
	var ascension := 0
	var rules := {"difficulties": [{"name": "Leicht"}, {"name": "Mittel"}, {"name": "Hart"}]}
	var cfg := {"difficulties": [{"name": "Wache"}, {"name": "Sturm"}]}


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	# GemTD: feste Liste aus Session
	var g := FakeGame.new()
	add_child(g)
	SystemHost.attach(g, "gemtd", ["difficulty"])
	var d = g.systems.difficulty
	Session.difficulty = 2
	check(d.count() == Session.DIFFICULTIES.size() and d.index() == 2, "gemtd: Liste und Wahl aus Session")
	check(d.key() == "", "ohne Haken und cfg.key: leerer Schlüssel (GemTD nutzt profile_mode)")
	# Randgruppen: Liste aus rules (system_cfg in modes.json gewinnt über die Basis "session")
	var r := FakeGame.new()
	add_child(r)
	SystemHost.attach(r, "randgruppen", ["difficulty"])
	var dr = r.systems.difficulty
	check(str(dr.cfg.source) == "rules", "randgruppen: Quelle rules aus der Kaskade")
	r.difficulty = 1
	check(dr.count() == 3 and str(dr.current().name) == "Mittel", "rules: aktuelle Schwierigkeit")
	r.difficulty = 9
	check(str(dr.current().name) == "Hart", "Index außerhalb: nächste gültige")
	# Bollwerk: Liste aus cfg, Schlüssel aus system_cfg
	var h := FakeGame.new()
	add_child(h)
	SystemHost.attach(h, "heroes", ["difficulty"])
	check(h.systems.difficulty.count() == 2 and h.systems.difficulty.key() == "heroes", "heroes: Liste aus cfg, Schlüssel aus modes.json")
	# Maul: Aufstieg nur auf der höchsten angebotenen Schwierigkeit
	var m := FakeGame.new()
	add_child(m)
	SystemHost.attach(m, "shoppingmaul", ["difficulty"])
	var dm = m.systems.difficulty
	check(dm.key() == "maul", "maul: Schlüssel maul")
	m.difficulty = dm.top()
	check(dm.take_ascension(3) == 3 and m.ascension == 3, "Aufstieg auf der höchsten Schwierigkeit")
	check(dm.label().ends_with("+3"), "Name mit Aufstiegsstufe: " + dm.label())
	check(not dm.ascension_mods().is_empty(), "Werte-Änderungen der Stufe")
	m.difficulty = 0 if dm.top() != 0 else 1
	check(dm.take_ascension(3) == 0 and m.ascension == 0, "Aufstieg auf niedriger Schwierigkeit fällt weg")
	check(dm.take_ascension(-2) == 0, "negative Stufe wird 0")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
