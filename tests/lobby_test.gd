extends Node
## Lauf: paar
## Lobby-Test (Abstimmung über den TD-Modus) mit zwei Prozessen:
##   godot --headless --path . res://tests/lobby_test.tscn -- --role=host
##   godot --headless --path . res://tests/lobby_test.tscn -- --role=client
## Für den Test sind alle Modi spielbar, Shopping Maul nur solo. Ablauf: Gast stimmt für eeveTD, Host für
## GemTD (Gleichstand, Host entscheidet), Maul wird abgelehnt, Host wechselt zu eeveTD und startet;
## beim Gast kommt eeveTD als Modus an. Mit --bild=<pfad> (Host, nicht headless) Bild der Lobby.

const PORT := 24601

var failures := 0
var role := ""
var shot := ""


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
		elif a.begins_with("--bild="):
			shot = a.substr(7)
	await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	_test_modes()
	Session.map_path = Database.first_map().path
	Session.game_kind = "gemtd"
	Net.uid = role + "-uid"
	Net.my_name = "Host" if role == "host" else "Gast"
	if role == "host":
		await _host()
	else:
		await _client()
	print("FERTIG [%s], Fehler: %d" % [role, failures])
	Net.leave()
	get_tree().quit(1 if failures > 0 else 0)


## Alle Modi spielbar, Shopping Maul und YouTD nur solo (das Hauptmenü lädt die Daten neu, danach wieder aufrufen).
func _test_modes() -> void:
	for m in Database.modes:
		m.ready = true
		m.scene = Session.GAME
		m.max_players = 1 if m.id in ["shoppingmaul", "youtd", "heroes"] else 8


func _wait(cond: Callable, seconds: float) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true


func _host() -> void:
	check(Net.host(PORT) == OK, "Sitzung gehostet")
	check(await _wait(func(): return Net.session_slots().size() == 2, 20.0), "Gast in der Lobby")
	var ids := Net.vote_tally().map(func(e): return e.id)
	check(ids == ["gemtd", "eevetd", "randgruppen"], "für 2 Spieler wählbar: %s (Maul nur solo)" % [ids])
	check(await _wait(func(): return Net.votes().size() == 1, 10.0), "Stimme des Gasts angekommen")
	check(Net.vote_winner(false) == "eevetd", "eine Stimme: eeveTD vorne")
	Net.vote("gemtd")
	check(Net.vote_leaders().size() == 2 and Net.vote_winner() == "gemtd", "Gleichstand: Stimme des Hosts entscheidet (GemTD)")
	Net.vote("shoppingmaul")
	check(Net.my_vote() == "gemtd", "Shopping Maul für 2 Spieler abgelehnt, Stimme bleibt GemTD")
	Net.vote("")
	check(Net.my_vote() == "" and Net.vote_winner() == "eevetd", "Stimme zurückgezogen: eeveTD vorne")
	Net.vote("eevetd")
	check(Net.vote_tally()[0].count == 2, "beide für eeveTD")
	if shot != "":
		Net.vote("gemtd")
		var menu: Node = load(Session.MAIN_MENU).instantiate()
		add_child(menu)
		await get_tree().process_frame
		_test_modes()
		menu.show_page("lobby")
		menu.lobby._refresh()
		for i in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		print("BILD ", shot)
		menu.queue_free()
		Net.vote("eevetd")
	# Gast wartet, bis er beide Stimmen sieht
	await get_tree().create_timer(1.0).timeout
	Net.start_session(MapData.load_file(Session.map_path).to_dict())
	check(Net.session.get("mode", "") == "eevetd" and Session.game_kind == "eevetd", "Sitzung startet mit eeveTD")
	check(await _wait(func(): return Net.player_status(Net.players.keys()[0]).get("in_game", false) if not Net.players.is_empty() else false, 20.0), "Gast ist im Spiel")
	await _wait(func(): return Net.players.is_empty(), 15.0)


func _client() -> void:
	await get_tree().create_timer(0.5).timeout
	check(Net.join("127.0.0.1", PORT) == OK, "Beitreten gestartet")
	check(await _wait(func(): return not Net.session_info.get("slots", []).is_empty(), 15.0), "Lobby-Stand vom Host")
	Net.vote("eevetd")
	check(await _wait(func(): return Net.my_vote() == "eevetd", 10.0), "eigene Stimme beim Host gezählt")
	check(await _wait(func(): return Net.vote_tally().size() > 0 and Net.vote_tally()[0].count == 2, 20.0), "Gast sieht beide Stimmen für eeveTD")
	check(await _wait(func(): return Net.game != null, 20.0), "Spiel gestartet")
	check(Session.game_kind == "eevetd", "Modus eeveTD beim Gast angekommen")
	await get_tree().create_timer(1.0).timeout
