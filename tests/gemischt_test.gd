extends Node
## Lauf: trio
## Modi: eevetd
## Gemischte Sitzung mit drei Prozessen (eeveTD): der Host spielt allein, A und B zusammen auf einem Feld,
## das A rechnet (Befehle von B gehen über den Host weiter an A).
##   godot --headless --path . res://tests/gemischt_test.tscn -- --role=host   (und --role=a, --role=b)
## Ablauf: Host startet mit den Gruppen [[A, B]], B baut eine Barrikade, A sieht sie und B sieht sie zurück,
## der Host speichert die Sitzung mit dem gemeinsamen Feld von A und B.

const PORT := 24603
const MAP := "res://data/maps/eeve.json"

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
	await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	RunHistory.path = "user://test_run_history_%s.json" % role
	Profile.dir = "user://test_profile_%s" % role
	Session.map_path = MAP
	Session.game_kind = "eevetd"
	Session.skip_setup = true
	Net.uid = role + "-uid"
	Net.my_name = role.to_upper()
	if role == "host":
		await _host()
	else:
		await _player()
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


func _game() -> Node:
	await _wait(func(): return Net.game != null and is_instance_valid(Net.game) and Net.game.is_inside_tree(), 20.0)
	await get_tree().process_frame
	return Net.game


func _host() -> void:
	check(Net.host(PORT) == OK, "Sitzung gehostet")
	check(await _wait(func(): return Net.session_slots().filter(func(s): return s.online).size() == 3, 30.0), "A und B in der Lobby")
	Net.start_session(MapData.load_file(MAP).to_dict(), [["host-uid"], ["a-uid", "b-uid"]])
	var g := await _game()
	check(g != null and g.coop == null and str(Net.session.mode) == "eevetd", "Host spielt eeveTD allein")
	check(Net.session.groups == [["a-uid", "b-uid"]], "Gruppe A + B gemerkt")
	check(await _wait(func(): return Net.players.keys().all(func(p): return Net.player_status(p).get("in_game", false)), 30.0), "A und B im Spiel")
	# warten, bis B gebaut hat (A meldet den Stand seiner Gruppe beim Speichern)
	await get_tree().create_timer(4.0).timeout
	var ok: bool = await Net.save_session(g)
	var data := SaveGame.read(SaveGame.path_for(Net.session.id))
	var ps: Dictionary = data.get("players", {})
	var a_state: Dictionary = ps.get("a-uid", {}).get("state", {})
	check(ok and data.get("groups", []) == [["a-uid", "b-uid"]], "Spielstand kennt die Gruppe")
	check((a_state.get("players", []) as Array).size() == 2 and (a_state.get("towers", []) as Array).size() >= 1,
		"gemeinsames Feld von A und B gesichert (Tower %d)" % (a_state.get("towers", []) as Array).size())
	check(ps.get("b-uid", {}).get("state", {}).is_empty(), "B hat keinen eigenen Stand")
	check(not a_state.get("mode", {}).get("players", []).is_empty(), "eeveTD-Werte im Spielstand")
	SaveGame.remove(str(data.id))
	await get_tree().create_timer(1.0).timeout


func _player() -> void:
	await get_tree().create_timer(0.5 if role == "a" else 1.0).timeout
	check(Net.join("127.0.0.1", PORT) == OK, "Beitreten gestartet")
	var g := await _game()
	check(g != null and g.coop != null, "Koop-Spiel gestartet")
	if role == "a":
		check(not g.mirror and g.local_player == 0 and g.players.size() == 2, "A rechnet das Feld für A und B")
		check(await _wait(func(): return g.all_towers().any(func(t): return t.owner_player == 1), 30.0), "Barrikade von B kommt bei A an")
		check(g.players[1].gold == 198 and g.players[0].gold == 200, "Gold von B abgezogen")
	else:
		check(g.mirror and g.local_player == 1, "B spielt mit, A rechnet")
		await _wait(func(): return Net.group_host() > 1, 10.0)
		g.submit({"type": "build", "cell": Vector2i(30, 60)})
		check(await _wait(func(): return g.towers.has(Vector2i(30, 60)), 20.0), "B sieht seine Barrikade vom Stand von A")
		check(await _wait(func(): return g.gold == 198, 10.0), "B hat 198 Gold")
	check(await _wait(func(): return not Net.is_active(), 60.0), "Host hat die Sitzung beendet")
