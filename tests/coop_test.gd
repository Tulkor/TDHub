extends Node
## Lauf: paar (Name koop)
## Modi: gemtd
## Koop-Test über eine echte Verbindung mit zwei Prozessen:
##   godot --headless --path . res://tests/coop_test.tscn -- --role=host
##   godot --headless --path . res://tests/coop_test.tscn -- --role=client
## Ablauf: Host startet Koop, beide setzen ihre Gems auf demselben Feld und behalten einen, die Welle
## startet erst danach. Der Mitspieler sieht die Gegner vom Host und verlässt dann das Spiel; beim Host
## gilt er als weg und hält die nächste Runde nicht auf. Verlässt der Host, ist die Partie für alle vorbei.

const PORT := 24597

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
	Net.my_name = "Anna" if role == "host" else "Ben"
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


## Gems der Runde setzen (Mitspieler: jeder Befehl wartet auf den Stand vom Host), dann den ersten behalten.
func _play_round(g: Node, row: int) -> bool:
	var x := 6
	while g.gems_left() > 0 and x < g.map.width - 4:
		var c := Vector2i(x, row)
		x += 3
		if not g.can_place(c):
			continue
		var before: int = g.round_towers.size()
		g.submit({"type": "place", "cell": c})
		await _wait(func(): return g.round_towers.size() > before or not g.can_place(c), 3.0)
	if not await _wait(func(): return g.stage() == g.Phase.CHOOSE, 3.0):
		return false
	g._select(g.round_towers[0])
	g._on_option_chosen(0)
	return await _wait(func(): return g.stage() == g.Phase.WAVE, 3.0)


func _host() -> void:
	check(Net.host(PORT) == OK, "hostet")
	check(await _wait(func(): return Net.players.size() == 1 and Net.players.values()[0].has("uid"), 15.0), "Ben ist verbunden")
	var m := MapData.load_file(Session.map_path)
	Net.start_coop(m.to_dict())
	check(await _wait(func(): return Net.game != null and is_instance_valid(Net.game), 10.0), "Koop-Spiel läuft")
	var g: Node = Net.game
	var peer: int = Net.players.keys()[0]
	check(g.coop != null and not g.mirror and g.players.size() == 2 and g.players[1].name == "Ben", "Host rechnet, Spieler Anna und Ben")
	check(Net.coop_player_of(peer) == 1, "Ben ist Spieler 2")
	check(not g.setup_done and g.submit({"type": "setup", "difficulty": 1, "score_mode": false}), "Anna wählt die Einstellungen")
	check(await _wait(func(): return Net.player_status(peer).get("in_game", false), 15.0), "Ben ist im Spiel")
	check(await _play_round(g, 40), "Anna hat gesetzt und behalten")
	check(await _wait(func(): return g.phase == g.Phase.WAVE, 30.0), "Welle startet, nachdem auch Ben fertig ist")
	check(g.all_towers().any(func(t): return t.owner_player == 1 and not t.is_new), "Bens Tower steht beim Host")
	# Ben verlässt das Spiel während der Welle, die nächste Runde läuft ohne ihn
	check(await _wait(func(): return not Net.player_status(peer).get("in_game", true) or not Net.players.has(peer), 40.0), "Ben hat das Spiel verlassen")
	check(await _wait(func(): return g.players[1].away, 3.0), "Ben gilt als weg")
	Engine.time_scale = 4.0
	check(await _wait(func(): return g.phase == g.Phase.BUILD, 90.0), "Welle vorbei")
	check(await _play_round(g, 44), "Anna spielt die nächste Runde allein")
	check(g.phase == g.Phase.WAVE, "ohne Ben startet die Welle sofort")
	check(g.save_mode() == "host" and g.save_coop(), "Koop gespeichert")
	Session.goto(Session.MAIN_MENU)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not Net.session.has("coop") and not Net.session.get("started", true), "Partie beendet, Sitzung frei")


func _client() -> void:
	var ok := false
	for i in 20:
		if Net.join("127.0.0.1", PORT) == OK and await _wait(func(): return Net.is_active(), 1.5):
			ok = true
			break
		await get_tree().create_timer(0.5).timeout
	check(ok, "verbunden")
	check(await _wait(func(): return Net.game != null and is_instance_valid(Net.game), 20.0), "Koop-Spiel gestartet")
	var g: Node = Net.game
	check(g.mirror and g.local_player == 1, "Ben spiegelt als Spieler 2")
	check(await _wait(func(): return g.players.size() == 2 and not g.rocks.is_empty() and g.setup_done, 20.0), "Stand und Einstellungen vom Host da")
	check(await _play_round(g, 30), "Ben hat gesetzt und behalten")
	check(g.round_towers.is_empty() and g.all_towers().any(func(t): return t.owner_player == 1 and not t.is_new), "Bens Tower steht")
	check(await _wait(func(): return g.phase == g.Phase.WAVE and not g.enemies.is_empty(), 30.0), "Ben sieht die Welle und Gegner")
	check(g.enemies.all(func(e): return e.remote), "Gegner laufen bei Ben nur nach")
	var first: Enemy = g.enemies[0]
	var start: float = first.traveled
	await get_tree().create_timer(1.0).timeout
	check(not is_instance_valid(first) or first.traveled > start, "Gegner laufen bei Ben weiter")
	check(g.save_mode() == "client", "Ben speichert nicht selbst")
	g.leave(false)
	check(await _wait(func(): return Net.game == null or not is_instance_valid(Net.game), 5.0), "Ben hat das Spiel verlassen")
	# Ende der Partie kommt vom Host
	await _wait(func(): return "beendet" in Net.status_text or not Net.is_active(), 60.0)
	check("beendet" in Net.status_text or not Net.is_active(), "Host hat die Partie beendet: %s" % Net.status_text)
