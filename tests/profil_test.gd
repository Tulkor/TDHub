extends Node
## Lauf: einzeln (Name profil)
## Modi: kern
## Spielerprofil (profile.gd, run_stats.gd): Tower-Werte je Welle und Art, Summen und Rekorde,
## alte Run-History und Maul-Stand aus maul.cfg übernehmen, Profil-Fenster. Eigener Ordner statt user://profile.

var failures := 0


class FakeTower:
	extends RefCounted
	var tower_id := "ruby"
	var tier := 1
	var total_damage := 0.0
	var kills := 0
	var color := Color.RED
	func label() -> String:
		return "%s %d" % [tower_id, tier]


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _clean(dir: String) -> void:
	var g := ProjectSettings.globalize_path(dir)
	for f in ["runs"]:
		var d := DirAccess.open(g.path_join(f))
		if d != null:
			for n in d.get_files():
				d.remove(n)
	for sub in ["backups", ""]:
		if DirAccess.dir_exists_absolute(g.path_join(sub)):
			for n in DirAccess.get_files_at(g.path_join(sub)):
				DirAccess.remove_absolute(g.path_join(sub).path_join(n))


func _ready() -> void:
	RunHistory.path = "user://test_profil_history.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RunHistory.path))
	RunHistory.record({"time": "2026-10-01T10:00:00", "map": "Classic", "victory": true, "wave": 50, "waves": 50, "kills": 3000, "play_time": 3000,
		"top": [{"label": "Silber", "damage": 99}]})
	Profile.dir = "user://test_profil"
	_clean(Profile.dir)
	Profile.reset_cache()
	await get_tree().process_frame

	# Alte Run-History wird beim ersten Mal übernommen
	check(Profile.runs().size() == 1 and Profile.runs()[0].get("imported", false), "alte Run-History übernommen")
	check(int(Profile.mode("gemtd").wins) == 1 and int(Profile.mode("gemtd").kills) == 3000, "Summen aus der alten Run-History")

	# RunStats: Schaden der alten Art gutschreiben, übernommene Kills nicht doppelt
	var rs := RunStats.new()
	var a := FakeTower.new()
	var b := FakeTower.new()
	b.tower_id = "emerald"
	rs.built(a, "keep", 1)
	rs.built(b, "keep", 1)
	a.total_damage = 100.0
	a.kills = 4
	b.total_damage = 50.0
	b.kills = 2
	rs.wave_done([a, b], 1, 3, 6)
	check(rs.waves.size() == 1 and int(rs.waves[0].damage) == 150 and rs.waves[0].towers[0][1] == "ruby", "Welle 1: Schaden je Tower, stärkster zuerst")
	# b wird verbraucht, a kombiniert zu Silber und übernimmt die Kills
	rs.flush(a)
	rs.flush(b)
	a.kills += b.kills
	a.tower_id = "silver"
	a.tier = 0
	rs.built(a, "combine", 2)
	a.total_damage += 1000.0
	a.kills += 10
	rs.wave_done([a], 2, 0, 10)
	var r := rs.result([a])
	check(int(r.types.ruby.damage) == 100 and int(r.types.ruby.kills) == 4, "Rubin behält Schaden und Kills von vorher: %s" % r.types.ruby)
	check(int(r.types.silver.damage) == 1000 and int(r.types.silver.kills) == 10, "Silber zählt nur Neues, übernommene Kills nicht doppelt: %s" % r.types.silver)
	check(int(r.types.silver.best_wave_damage) == 1000 and int(r.types.silver.best_wave) == 2, "bester Wellenschaden je Art")
	check(r.towers.size() == 2 and r.towers[0].alive and not r.towers[1].alive and int(r.towers[0].damage) == 1100, "je Tower: Summe über alle Arten, verbrauchte bleiben drin")
	check(int(r.actions.keep) == 2 and int(r.actions.combine) == 1 and int(r.types.ruby.built) == 1 and int(r.types.ruby.tiers["1"]) == 1, "gebaut je Art und Stufe")

	# Spielstand: Werte überleben Speichern/Laden
	var c := rs.capture([a])
	var rs2 := RunStats.new()
	var a2 := FakeTower.new()
	a2.tower_id = "silver"
	a2.total_damage = a.total_damage
	a2.kills = a.kills
	rs2.restore(JSON.parse_string(JSON.stringify(c)), [a2])
	a2.total_damage += 5.0
	var r2 := rs2.result([a2])
	check(int(r2.types.silver.damage) == 1005 and r2.towers.size() == 2, "nach dem Laden geht es weiter: %s" % r2.types.silver)

	# Ins Profil
	var news := Profile.record_run("gemtd", {"map": "Classic", "difficulty": 2, "victory": false, "wave": 2, "waves": 50,
		"kills": 20, "play_time": 120, "leaks": [3, 0], "path": 300}, r)
	check(not news.has("tower_damage_run") and not news.has("most_kills"), "erster Run mit Tower-Werten: keine 'neuen' Rekorde gegen leer: %s" % news)
	var t: Dictionary = Profile.towers("gemtd")
	check(int(t.silver.kills) == 10 and int(t.silver.best_wave_damage) == 1000 and int(t.ruby.runs) == 1 and int(t.ruby.wins) == 0, "Tower-Statistik im Profil")
	var rec: Dictionary = Profile.mode("gemtd").records
	check(rec.tower_damage_run.label == "silver 0" and int(rec.tower_damage_run.value) == 1100, "Rekord: meister Schaden eines Towers in einem Spiel")
	check(int(rec.tower_damage_wave.value) == 1000 and int(rec.tower_damage_wave.wave) == 2, "Rekord: meister Schaden eines Towers in einer Welle")
	check(int(rec.longest_path.value) == 300 and int(Profile.mode("gemtd").leaks) == 3, "Weg und Leben verloren")
	var rid: String = Profile.runs()[0].id
	var full := Profile.load_run(rid)
	check(full.get("wave_log", []).size() == 2 and full.get("towers", []).size() == 2 and full.map == "Classic", "ganzer Run in eigener Datei")
	check(Profile.best_run("gemtd").get("imported", false), "bester Run bleibt der alte Sieg")
	# Debug-Runs nur in der Liste
	Profile.record_run("gemtd", {"map": "Classic", "victory": true, "wave": 50, "waves": 50, "kills": 99999, "debug": true}, r)
	check(Profile.runs().size() == 3 and int(Profile.mode("gemtd").runs) == 2, "Debug-Run steht in der Liste, zählt aber nicht")
	# Neu laden aus der Datei
	Profile.reset_cache()
	check(Profile.runs().size() == 3 and int(Profile.data().version) == Profile.VERSION and int(Profile.towers("gemtd").silver.kills) == 10, "Profil aus der Datei geladen")
	check(int(Profile.totals().runs) == 2 and int(Profile.totals().best_wave) == 50, "Summen über alle Modi")

	# Spielzeit zählt auch für Debug-Runs (aber kein Run, keine Siege)
	var time_before := int(Profile.mode("gemtd").play_time)
	Profile.record_run("gemtd", {"map": "Classic", "victory": true, "wave": 50, "waves": 50, "play_time": 100, "debug": true}, {})
	check(int(Profile.mode("gemtd").play_time) == time_before + 100 and int(Profile.mode("gemtd").debug_runs) == 2
		and int(Profile.mode("gemtd").wins) == 1, "Debug-Run: Zeit zählt, Sieg nicht")
	# Abgebrochen ohne Speichern: Zeit + aborted; gespeichert: nur Zeit, beim Weiterspielen nicht doppelt
	Profile.record_abort("eeve", {"map": "Hain", "wave": 3, "waves": 57, "play_time": 300})
	check(int(Profile.mode("eeve").aborted) == 1 and int(Profile.mode("eeve").play_time) == 300 and int(Profile.mode("eeve").runs) == 0
		and Profile.runs()[0].get("aborted", false), "abgebrochener Run: Zeit und Liste, kein Run")
	Profile.record_abort("eeve", {"map": "Hain", "wave": 5, "waves": 57, "play_time": 500, "saved": true})
	Profile.record_run("eeve", {"map": "Hain", "victory": true, "wave": 57, "waves": 57, "play_time": 900, "time_counted": 500}, {})
	check(int(Profile.mode("eeve").play_time) == 300 + 500 + 400 and int(Profile.mode("eeve").aborted) == 1 and int(Profile.mode("eeve").runs) == 1,
		"gespeichert verlassen und später gewonnen: Zeit nicht doppelt")
	check(int(Profile.mode("eeve").streak) == 1 and int(Profile.data().daily[Time.get_date_string_from_system()].time) >= 1200, "Siegesserie und Zeit je Tag")
	check(int(Profile.mode("eeve").by_map.Hain.play_time) == 1200, "Zeit je Map")

	# Siegel: unverändert gültig, von Hand geändert fällt auf, Werte bleiben lesbar
	Profile.reset_cache()
	Profile.data()
	check(Profile.sealed() and Profile.integrity == ProfileStore.VALID, "Siegel nach dem Speichern gültig")
	var text := FileAccess.get_file_as_string(Profile.file())
	check(text.begins_with("{\"seal\":\"") and text.contains("\"play_time\""), "Profil bleibt lesbares JSON mit Siegel vorne")
	var f := FileAccess.open(Profile.file(), FileAccess.WRITE)
	f.store_string(text.replace("\"play_time\": ", "\"play_time\": 9"))
	f.close()
	Profile.reset_cache()
	Profile.data()
	check(Profile.integrity == ProfileStore.TAMPERED and not Profile.sealed() and int(Profile.mode("eeve").runs) == 1, "von Hand geändert: Siegel ungültig, Profil bleibt (%s, %s)" % [Profile.integrity, Profile.mode("eeve").runs])
	Profile.reset_cache()
	check(not Profile.sealed(), "Änderung bleibt vermerkt, auch nach neuem Siegel")
	check(ProfileStore.decode(ProfileStore.encode({})).state == ProfileStore.VALID, "leeres Dictionary versiegeln")
	# Kaputte Datei: Sicherung statt leeres Profil, die kaputte Datei bleibt liegen
	f = FileAccess.open(Profile.file(), FileAccess.WRITE)
	f.store_string("{kaputt")
	f.close()
	Profile.reset_cache()
	check(int(Profile.mode("eeve").runs) == 1, "kaputte Datei: Stand aus der Sicherung")
	var run_file := Profile.load_run(Profile.runs()[0].id)
	check(run_file.get("sealed", false), "Run-Datei mit Siegel")

	# Maul: alter Stand aus maul.cfg wird übernommen
	MaulProfile.path = "user://test_profil_maul.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("xp", "tenths", 321)
	cfg.set_value("stats", "games", 7)
	cfg.set_value("shop_ikea", "best_level", 30)
	cfg.set_value("shop_ikea", "best_win", 1)
	cfg.save(MaulProfile.path)
	check(MaulXp.load_xp() == 321 and MaulProfile.totals().games == 7 and MaulProfile.shop("ikea").best_level == 30 and MaulProfile.shop("ikea").best_win == 1,
		"Maul: XP und Rekorde aus maul.cfg übernommen")
	MaulXp.save_xp(400)
	MaulProfile.record("ikea", 2, 50, true, 10, 60.0)
	Profile.reset_cache()
	check(MaulXp.load_xp() == 400 and MaulProfile.shop("ikea").best_win == 2 and MaulProfile.totals().games == 8, "Maul: im Profil gespeichert")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MaulProfile.path))

	# Fenster: Übersicht, jede Detailseite, Run-History
	var panel := ProfilePanel.new()
	add_child(panel)
	await get_tree().process_frame
	check(panel.body.get_child_count() > 0 and panel.title.text != "", "Profil-Übersicht")
	for x in ProfileWc3.MODES:
		panel.show_view(x[0])
		await get_tree().process_frame
		check(panel.tabs != null and panel.tabs.get_child_count() == ProfileWc3.MODES.size() + 1, "Detailseite %s" % x[0])
	panel.show_history()
	await get_tree().process_frame
	var hist: ProfileHistory = panel.body.get_child(panel.body.get_child_count() - 1)
	check(hist.list.get_child_count() > 0, "Run-History zeigt Runs")
	hist.set_filter("eeve")
	await get_tree().process_frame
	check(hist.chart.runs.size() == 2, "Filter je Modus: %d" % hist.chart.runs.size())
	hist.back_requested.emit()
	await get_tree().process_frame
	check(panel.view == ProfileWc3.MODES[-1][0], "Zurück aus der Run-History: %s" % panel.view)
	panel.queue_free()

	_clean(Profile.dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RunHistory.path))
	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
