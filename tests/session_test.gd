extends Node
## Lauf: paar (Name sitzung)
## Modi: kern
## Sitzungs-Test (Speichern im Mehrspieler und Wiedereinsteigen) mit zwei Prozessen:
##   godot --headless --path . res://tests/session_test.tscn -- --role=host
##   godot --headless --path . res://tests/session_test.tscn -- --role=client
## Ablauf: Host startet die Sitzung, beide spielen eine Runde, der Host speichert mit dem Feld des
## Mitspielers, beendet die Sitzung und lädt sie neu. Der Mitspieler tritt wieder bei und steigt
## mit „Mitspielen“ genau an seinem gespeicherten Stand ein.

const PORT := 24598

var failures := 0
var role := ""


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   [%s] %s" % [role, msg])
	else:
		failures += 1
		printerr("FAIL [%s] %s" % [role, msg])


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--role="):
			role = a.substr(7)
	# Szenenwechsel (Session.goto) sollen den Test nicht beenden: ein Platzhalter ist die aktuelle Szene
	await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	Session.map_path = Database.first_map().path
	Net.uid = role + "-uid"
	Net.my_name = "Host" if role == "host" else "Gast"
	if role == "host":
		await _host()
	else:
		await _client()
	print("FERTIG [%s], Fehler: %d" % [role, failures])
	Net.leave()
	get_tree().quit(1 if failures > 0 else 0)


func _wait(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true


## Eine Runde spielen: Gems setzen, ersten behalten, Welle bis zum Ende.
func _play_round(g: Node, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tries := 0
	while g.phase == g.Phase.BUILD and tries < 5000:
		tries += 1
		var p: Vector2 = g.ground_path[rng.randi_range(0, g.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if g.can_place(c):
			g.place_gem(c)
	g._select(g.round_towers[0])
	g._on_option_chosen(0)
	Engine.time_scale = 4.0
	await _wait(func(): return g.phase != g.Phase.WAVE, 60.0)
	Engine.time_scale = 1.0


func _new_game(old) -> Node:
	# Nur die Id festhalten: das alte Spiel wird freigegeben, eine eingefangene Referenz darauf meldet Godot als Fehler.
	var old_id: int = old.get_instance_id() if is_instance_valid(old) else 0
	await _wait(func(): return is_instance_valid(Net.game) and Net.game.get_instance_id() != old_id and Net.game.is_inside_tree(), 15.0)
	await get_tree().process_frame
	return Net.game


func _host() -> void:
	check(Net.host(PORT) == OK, "Sitzung gehostet")
	check(await _wait(func(): return Net.session_slots().size() == 2, 20.0), "Mitspieler in der Lobby")
	var map := MapData.load_file(Session.map_path)
	Net.start_session(map.to_dict())
	var g := await _new_game(null)
	check(g != null and Net.session.started, "Sitzung gestartet, eigenes Spiel läuft")
	await _play_round(g, 3)
	check(g.phase == g.Phase.BUILD and g.wave_index == 1, "Host: Runde 1 gespielt")
	var my_towers: int = g.all_towers().size()
	var my_rocks: int = g.rocks.size()
	check(await _wait(func(): return int(Net._state_of("client-uid").get("wave_index", 0)) == 1, 60.0), "Zwischenstand des Mitspielers nach Runde 1 da")

	var ok: bool = await Net.save_session(g)
	var data := SaveGame.read(SaveGame.path_for(Net.session.id))
	check(ok and data.kind == "multi", "Sitzung gespeichert")
	var ps: Dictionary = data.get("players", {})
	check(ps.has("host-uid") and ps.has("client-uid") and ps["client-uid"].name == "Gast", "Spielstand enthält beide Spieler: %s" % [ps.keys()])
	check(int(ps.get("client-uid", {}).get("state", {}).get("wave_index", -1)) == 1
		and (ps.get("client-uid", {}).get("state", {}).get("towers", []) as Array).size() == 1, "Feld des Mitspielers gesichert")
	check(SaveGame.list().any(func(e): return e.id == data.id and e.kind == "multi" and "Gast" in e.meta.players), "Sitzung in „Spiel laden“")

	# Sitzung beenden und aus der Datei neu hosten
	Net.leave()
	await get_tree().create_timer(1.0).timeout
	check(Net.host(PORT) == OK, "neu gehostet")
	Net.load_session(data)
	check(Net.session.loaded and not Net._state_of("client-uid").is_empty() and not Net._state_of(Net.uid).is_empty(), "Sitzung aus Datei geladen")
	var slots := Net.session_slots()
	check(slots.size() == 2 and not slots[1].online and slots[1].has_state, "Platz des Mitspielers wartet: %s" % [slots])
	Net.start_session({})
	var g2 := await _new_game(g)
	check(g2 != null and g2.wave_index == 1 and g2.all_towers().size() == my_towers and g2.rocks.size() == my_rocks,
		"Host spielt an seinem Stand weiter (Welle %d)" % (g2.wave_index + 1 if g2 else 0))
	# Mitspieler steigt später ein und meldet sich danach wieder ab
	check(await _wait(func(): return Net.players.size() == 1 and Net.player_status(Net.players.keys()[0]).get("in_game", false), 30.0), "Mitspieler wieder im Spiel")
	await _wait(func(): return Net.players.is_empty(), 30.0)
	SaveGame.remove(str(data.id))


func _client() -> void:
	await get_tree().create_timer(0.5).timeout
	check(Net.join("127.0.0.1", PORT) == OK, "Beitreten gestartet")
	check(await _wait(func(): return not Net.session_info.is_empty(), 15.0), "Sitzungsinfo vom Host")
	check(not Net.session_info.has_state, "neue Sitzung, noch kein eigener Stand")
	var g := await _new_game(null)
	check(g != null, "vom Host gestartet")
	await _play_round(g, 5)
	check(g.phase == g.Phase.BUILD and g.wave_index == 1, "Gast: Runde 1 gespielt")
	var my_towers: int = g.all_towers().size()
	var my_rocks: int = g.rocks.size()
	var my_gold: int = g.gold

	# Host beendet die Sitzung; danach wieder verbinden
	check(await _wait(func(): return not Net.is_active(), 60.0), "Host hat die Sitzung beendet")
	var joined := false
	for i in 30:
		Net.join("127.0.0.1", PORT)
		if await _wait(func(): return Net.is_active() or not Net.is_connecting(), 3.0) and Net.is_active():
			joined = true
			break
		await get_tree().create_timer(0.5).timeout
	check(joined, "wieder verbunden")
	check(await _wait(func(): return Net.session_info.get("started", false) and Net.session_info.get("has_state", false), 20.0),
		"Lobby: Sitzung läuft, eigener Stand gespeichert (Welle %d)" % int(Net.session_info.get("wave", 0)))
	check(int(Net.session_info.get("wave", 0)) == 2, "gespeicherter Stand ist Welle 2")
	Net.join_session()
	var g2 := await _new_game(g)
	check(g2 != null and g2.wave_index == 1 and g2.all_towers().size() == my_towers and g2.rocks.size() == my_rocks and g2.gold == my_gold,
		"Gast steigt an seinem Stand wieder ein (Tower %d, Steine %d, Gold %d)" % ([g2.all_towers().size(), g2.rocks.size(), g2.gold] if g2 else [0, 0, 0]))
	await get_tree().create_timer(1.0).timeout
