extends Node
## Lauf: paar (Name netz)
## Modi: kern
## Mehrspieler-Test mit zwei Prozessen auf demselben Rechner:
##   godot --headless --path . res://tests/net_test.tscn -- --role=host
##   godot --headless --path . res://tests/net_test.tscn -- --role=client
## Der Host spielt eine Runde, der Client schaut zu und prüft Feld, Gegner und Glätte.

const PORT := 24599

var failures := 0
var role := ""
var shot_dir := ""  ## --shot=<ordner>: Bildschirmfotos (nur mit echtem Fenster sinnvoll)


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
		elif a.begins_with("--shot="):
			shot_dir = a.substr(7)
	Session.map_path = Database.first_map().path
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


func _shot(name: String) -> void:
	if shot_dir == "":
		return
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))


func _host() -> void:
	check(Net.host(PORT) == OK and Net.is_active(), "Hosten")
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.net_sync != null and game.net_panel != null, "Mehrspieler-Teile im Spiel")
	check(await _wait(func(): return not Net.watchers.is_empty(), 20.0), "Client schaut zu")
	await get_tree().create_timer(0.5).timeout
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var tries := 0
	while game.phase == game.Phase.BUILD and tries < 5000:
		tries += 1
		var p: Vector2 = game.ground_path[rng.randi_range(0, game.ground_path.size() - 1)]
		var c := Vector2i(p / Board3D.CELL) + Vector2i(rng.randi_range(-3, 1), rng.randi_range(-3, 1))
		if game.can_place(c):
			game.place_gem(c)
	await get_tree().create_timer(0.6).timeout
	game._select(game.round_towers[0])
	game._on_option_chosen(0)
	check(game.phase == game.Phase.WAVE, "Welle gestartet")
	Engine.time_scale = 2.0
	check(await _wait(func(): return game.phase != game.Phase.WAVE, 60.0), "Welle beendet (Leben %d)" % game.lives)
	# Client meldet sich ab, wenn er fertig ist
	await _wait(func(): return Net.players.is_empty(), 15.0)


func _client() -> void:
	await get_tree().create_timer(0.5).timeout
	check(Net.join("127.0.0.1", PORT) == OK, "Beitreten gestartet")
	check(await _wait(func(): return Net.players.has(1) and Net.player_status(1).get("in_game", false), 15.0), "Host sichtbar und im Spiel")
	check(Net.player_name(1) != "?", "Name des Hosts: %s" % Net.player_name(1))
	if shot_dir != "":
		var menu: Node = load(Session.MAIN_MENU).instantiate()
		add_child(menu)
		menu.lobby.show()
		await _shot("lobby")
		menu.queue_free()
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	var panel: NetPanel = game.net_panel
	panel.spectate(1)
	check(not game.board.visible and not game.hud.visible, "eigenes Feld und HUD ausgeblendet")
	check(await _wait(func(): return panel.remote.map != null and not panel.remote.field.is_empty(), 10.0), "Map und Feld empfangen")
	check(await _wait(func(): return panel.remote.towers.size() == 5, 20.0), "5 gesetzte Gems des Hosts sichtbar")
	check(await _wait(func(): return panel.remote.towers.size() == 1 and panel.remote.rocks.size() >= 4, 20.0), "nach der Auswahl: 1 Tower, %d Steine" % panel.remote.rocks.size())
	check(await _wait(func(): return not panel.remote.enemies.is_empty(), 20.0), "Gegner des Hosts erscheinen")
	await _shot("zuschauen")
	check(is_equal_approx(panel.remote.time_scale, 2.0), "Tempo des Hosts übernommen (%.1f)" % panel.remote.time_scale)
	# Glätte: Bewegung pro Bild weicht kaum vom eigenen Tempo ab (keine Korrektursprünge),
	# und die Position bleibt nah an der Vorausberechnung aus den Meldungen
	var last := {}
	var max_jump := 0.0
	var max_err := 0.0
	var moved := 0.0
	var frames := 0
	var end := Time.get_ticks_msec() + 4000
	var dt := 0.0
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame
		# process_frame kommt vor den _process-Aufrufen: gemessen wird also der Schritt des
		# vorigen Bilds, mit dessen Bildzeit wie im Gegner (enemy.gd → _remote_step). Mit der Uhrzeit
		# oder der Zeit dieses Bilds wäre sie bei ungleich langen Bildern daneben, und beim
		# 8×-Schnelllauf wird daraus ein scheinbarer Sprung.
		var step_dt := dt
		dt = get_process_delta_time() / maxf(Engine.time_scale, 0.01) * panel.remote.time_scale
		frames += 1
		for id in panel.remote.enemies:
			var e: Enemy = panel.remote.enemies[id]
			if last.has(id) and frames > 10:
				var step: float = e.traveled - last[id]
				max_jump = maxf(max_jump, absf(step - (e.remote_advance(last[id], step_dt) - last[id])))
				moved += maxf(step, 0.0)
				max_err = maxf(max_err, absf(e.traveled - e.remote_advance(e.net_traveled, e.net_age)))
			last[id] = e.traveled
	print("  Bilder: %d, größter Korrektursprung: %.3f, größte Abweichung: %.3f, gesamt gelaufen: %.1f" % [frames, max_jump, max_err, moved])
	check(moved > 1.0, "Gegner laufen beim Zuschauer")
	check(max_jump < 0.3, "keine Korrektursprünge (größter %.3f Towerbreiten)" % max_jump)
	check(await _wait(func(): return panel.remote.enemies.is_empty(), 60.0), "Gegner verschwinden nach der Welle")
	panel.stop()
	check(game.board.visible and game.hud.visible and panel.remote == null, "zurück zum eigenen Feld")
	Net.leave()
