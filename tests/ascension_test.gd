extends Node
## Lauf: einzeln (Name aufstieg)
## Modi: kern
## Aufstiegsstufen (ascension.gd, data/ascension.json): angebotene Schwierigkeiten je Modus, Regeln je Stufe,
## Gegner verstärken, Freischalten im Profil (nur Sieg auf der höchsten, ohne Debug und Punkte-Wertung).

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	Profile.dir = "user://test_aufstieg"
	var g := ProjectSettings.globalize_path(Profile.dir)
	for sub in ["runs", "backups", ""]:
		if DirAccess.dir_exists_absolute(g.path_join(sub)):
			for n in DirAccess.get_files_at(g.path_join(sub)):
				DirAccess.remove_absolute(g.path_join(sub).path_join(n))
	Profile.reset_cache()
	await get_tree().process_frame

	# Drei Schwierigkeiten in jedem Modus, Namen Einfach/Mittel/Schwer
	var lists := {"gemtd": Session.DIFFICULTIES, "eeve": Database.eeve.difficulties, "randgruppen": Database.randgruppen.difficulties,
		"maul": MaulData.rules().difficulties, "youtd": YoutdData.rules().difficulties}
	for m in lists:
		var list: Array = lists[m]
		var ch := Ascension.choices(m, list.size())
		var names: Array = ch.map(func(i): return str(list[i].name))
		check(names == ["Einfach", "Mittel", "Schwer"], "%s bietet Einfach/Mittel/Schwer an (%s)" % [m, ", ".join(names)])
		check(Ascension.top(m, list.size()) == ch.back(), "%s: Aufstieg auf der letzten" % m)
		check(Ascension.difficulty_count(m) == list.size(), "%s: Anzahl Schwierigkeiten" % m)
	check(Ascension.snap("eeve", 5, 6) == 3 and Ascension.snap("eeve", 0, 6) == 1, "alte Wahl rückt auf die nächste angebotene")
	check(not Ascension.cfg("roguelike").is_empty(), "Roguelike nutzt die Regeln von GemTD")

	# Standardregeln: jede Stufe Leben +5 %, alle 3 Tempo +3 %, alle 5 Rüstung +1
	var m0 := Ascension.mods("gemtd", 0)
	check(is_equal_approx(m0.hp, 1.0) and m0.lines.is_empty(), "Stufe 0 ändert nichts")
	var m10 := Ascension.mods("gemtd", 10)
	check(is_equal_approx(m10.hp, 1.5), "Stufe 10: Leben +50 %")
	check(is_equal_approx(m10.speed, 1.09), "Stufe 10: Tempo dreimal +3 %")
	check(is_equal_approx(m10.armor_add, 2.0) and is_equal_approx(m10.armor, 1.0), "Stufe 10: Rüstung +2")
	check(Ascension.mods("gemtd", 2).speed == 1.0 and Ascension.mods("gemtd", 4).armor_add == 0.0, "Tempo erst ab 3, Rüstung erst ab 5")
	check(Ascension.times({"every": 2, "from": 1}, 1) == 1 and Ascension.times({"every": 2, "from": 1}, 4) == 2, "from und every")

	# Erweiterbar: Schalter (flag) aus den Daten
	var saved: Dictionary = Database.ascension.duplicate(true)
	Database.ascension.modes.gemtd.rules.append({"type": "flag", "flag": "no_pause", "every": 7, "text": "Keine Pause"})
	Database.ascension.modes.gemtd.rules.append({"type": "kommt_noch", "every": 1, "text": "Später"})
	check(not Ascension.flag("gemtd", 6, "no_pause") and Ascension.flag("gemtd", 7, "no_pause"), "Schalter ab Stufe 7")
	check(Ascension.mods("gemtd", 7).lines.has("Keine Pause") and Ascension.mods("gemtd", 1).lines.has("Später"), "Sonderregeln mit Text, unbekannte Typen nur angezeigt")
	Database.ascension = saved

	# Gegner verstärken
	var e := Enemy.new()
	e.max_hp = 100.0
	e.hp = 100.0
	e.speed = 2.0
	e.armor = 3.0
	Ascension.apply(e, m10)
	check(is_equal_approx(e.max_hp, 150.0) and is_equal_approx(e.hp, 150.0), "Gegner-Leben ×1,5")
	check(is_equal_approx(e.speed, 2.18) and is_equal_approx(e.armor, 5.0), "Tempo ×1,09, Rüstung +2")
	e.free()

	# Freischalten im Profil
	check(Ascension.unlocked("gemtd") == 0 and Ascension.best("gemtd") == -1, "am Anfang nichts frei")
	var win := {"map": "Classic", "difficulty": 2, "victory": true, "wave": 50, "waves": 50, "ascension": 0}
	var news := Profile.record_run("gemtd", win, {})
	check(Ascension.unlocked("gemtd") == 1 and int(news.get("ascension_unlocked", 0)) == 1, "Sieg auf Schwer schaltet +1 frei")
	Profile.record_run("gemtd", win, {})
	check(Ascension.unlocked("gemtd") == 1, "nochmal +0 gewinnen schaltet nichts weiter frei")
	var w1 := win.duplicate()
	w1.ascension = 1
	Profile.record_run("gemtd", w1, {})
	check(Ascension.unlocked("gemtd") == 2 and Ascension.best("gemtd") == 1, "Sieg auf +1 schaltet +2 frei")
	check(Profile.runs()[0].get("ascension", 0) == 1, "Stufe steht im Run")
	var lose := w1.duplicate()
	lose.ascension = 2
	lose.victory = false
	Profile.record_run("gemtd", lose, {})
	var mid := win.duplicate()
	mid.difficulty = 1
	mid.ascension = 2
	Profile.record_run("gemtd", mid, {})
	var dbg := lose.duplicate()
	dbg.victory = true
	dbg.debug = true
	Profile.record_run("gemtd", dbg, {})
	var pts := dbg.duplicate()
	pts.debug = false
	pts.score_mode = true
	Profile.record_run("gemtd", pts, {})
	check(Ascension.unlocked("gemtd") == 2, "Niederlage, Mittel, Debug und Punkte-Wertung schalten nichts frei")
	check(Ascension.unlocked("eeve") == 0 and Ascension.unlocked("roguelike") == 0, "Freischaltung je Modus getrennt")
	Profile.reset_cache()
	check(Ascension.unlocked("gemtd") == 2, "bleibt nach Neuladen im Profil")
	var maul_win := {"map": "x", "difficulty": 2, "victory": true, "ascension": 0}
	Profile.record_run("maul", maul_win, {})
	check(Ascension.unlocked("maul") == 1, "Maul: Sieg auf Schwer schaltet +1 frei")

	# Startfenster-Baustein
	var p := AscensionPicker.new().setup("gemtd", 3, 2, 9)
	add_child(p)
	check(p.level == 2 and p.chosen() == 2, "Wahl auf das Freigeschaltete begrenzt")
	p.set_difficulty(1)
	check(p.chosen() == 0, "auf Mittel keine Stufe")
	p.queue_free()

	print("FERTIG" if failures == 0 else "FEHLER: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
