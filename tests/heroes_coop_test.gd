extends Node
## Lauf: paar (Name heroescoop)
## Modi: heroes
## Echter ENet-Host und Client: eigener Held, Eingaben, Kauf, Fähigkeiten, Tageszeit und Event-Teleport.

const PORT := 24614
var failures := 0
var role := "host"
var remote_saw_enemy := false


func check(ok: bool, text: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL [%s] %s" % [role, text])
	else:
		print("OK [%s] %s" % [role, text])


func wait_for(condition: Callable, seconds := 15.0) -> bool:
	var until := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call():
		if Time.get_ticks_msec() > until:
			return false
		await get_tree().process_frame
	return true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	await get_tree().process_frame
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	Profile.dir = "user://heroes_coop_" + role
	Profile.reset_cache()
	Session.game_kind = "heroes"
	Session.skip_setup = false
	Session.difficulty = 0
	Net.uid = "heroes-" + role
	Net.my_name = role
	if role == "host":
		await host_run()
	else:
		await client_run()
	print("FERTIG [%s], Fehler: %d" % [role, failures])
	Net.leave()
	get_tree().quit(1 if failures else 0)


func host_run() -> void:
	Net.coop_command.connect(func(_peer, data):
		if data.get("tested_enemy", false):
			remote_saw_enemy = true)
	check(Net.host(PORT) == OK, "Host gestartet")
	if not await wait_for(func(): return Net.players.size() == 1):
		check(false, "Client tritt bei")
		return
	Net.vote("heroes")
	Net.start_coop({"name":"Bollwerk"})
	if not await wait_for(func(): return Net.game is HdGame and Net.game.coop != null and Net.game.coop.slots.size() == 2):
		check(false, "Zwei Helden auf dem Host")
		return
	var g: HdGame = Net.game
	check(g.coop.host and g.players == 2, "Host autoritativ, zwei Spieler")
	g.coop.with_player(1, func():
		g.set_hero("torvik")
		g.hero.add_xp(g.hero.xp_needed(g.hero.level)))
	check(g.coop.slots[0].hero != g.coop.slots[1].hero and g.hero == g.coop.slots[0].hero, "Heldenwechsel im Spielerkontext erhält getrennte Helden")
	g.start(0)
	g.spawn_queue.clear()
	g.wave_time = -10000
	g.day_cycle.set_hour(23)
	check(await wait_for(func(): return g.coop.slots[1].hero.skills.ranks[0] == 2), "Client verstärkt seine eigene Fähigkeit")
	check(g.hero.skills.ranks[0] == 1, "Host-Rang bleibt unabhängig")
	check(await wait_for(func(): return not g.coop.slots[1].shop.inv.all(func(x): return x == null) or not g.coop.slots[1].shop.stash.all(func(x): return x == null)), "Persönlicher Itemkauf wird auf dem Host ausgeführt")
	check(g.shop.inv.all(func(x): return x == null) and g.shop.stash.all(func(x): return x == null), "Host-Inventar bleibt unabhängig")
	var foe := g.spawn("sumpfling", g.coop.slots[1].hero.position + Vector3.RIGHT * 2)
	foe.max_hp = 1000
	foe.hp = 1000
	var before: Vector3 = g.coop.slots[1].hero.position
	check(await wait_for(func(): return g.coop.slots[1].hero.position.distance_to(before) > 1), "Eingabestrom bewegt den Client-Helden auf dem Host")
	check(await wait_for(func(): return g.coop.slots[1].hero.attack_cd > 0), "Gehaltenes M1 wird autoritativ ausgeführt")
	check(await wait_for(func(): return foe.hp < 1000), "Client-Angriff trifft Gegner auf dem Host")
	check(await wait_for(func(): return remote_saw_enemy), "Client bestätigt replizierten Treffer")
	g.events.start("schrein")
	check(g.playing_heroes().all(func(h): return h.position.distance_to(g.event_arena.center) < 10), "Beide Helden betreten Ereignisgebiet")
	check(await wait_for(func(): return not g.event_arena.active), "Client beantwortet Ereignis und beide kehren zurück")
	check(g.playing_heroes().all(func(h): return h.position.x > -150), "Beide Helden wieder auf Hauptkarte")
	await get_tree().create_timer(2.0).timeout


func client_run() -> void:
	await get_tree().create_timer(0.5).timeout
	check(Net.join("127.0.0.1", PORT) == OK, "Client verbindet")
	if not await wait_for(func(): return Net.game is HdGame and Net.game.coop != null):
		check(false, "Bollwerk auf Client geladen")
		return
	var g: HdGame = Net.game
	g.coop.command({"kind":"hero", "id":"torvik"})
	check(await wait_for(func(): return g.state == "play" and g.hero.skills.points > 0), "Host-Start und persönlicher Fortschritt kommen an")
	check(not g.coop.host and g.coop.player == 1, "Client simuliert keine eigene Welle")
	check(await wait_for(func(): return g.is_night()), "Autoritative Nacht kommt beim Client an")
	g.hero.skills.upgrade(0)
	check(await wait_for(func(): return g.hero.skills.ranks[0] == 2), "Upgrade vom Host bestätigt")
	g.shop.act({"kind":"buy", "id":"heiltrank"})
	check(await wait_for(func(): return g.shop.inv.any(func(x): return x != null and x.id == "heiltrank") or g.shop.stash.any(func(x): return x != null and x.id == "heiltrank")), "Itemkauf vom Host bestätigt")
	for seq in range(1, 36):
		Net.send_hero_input({"seq":1000 + seq, "move":Vector3.RIGHT, "aim":g.hero.position + Vector3.RIGHT * 10, "attack":true})
		await get_tree().create_timer(0.02).timeout
	check(await wait_for(func(): return g.enemies.any(func(e): return e.max_hp == 1000 and e.hp < 1000)), "Client sieht dieselben Gegner-Trefferpunkte")
	Net.send_coop_command({"tested_enemy":true})
	check(await wait_for(func(): return g.event_arena.active), "Ereignis-Teleport repliziert")
	g.shop.act({"kind":"event", "pick":2})
	check(await wait_for(func(): return not g.event_arena.active), "Rückkehr repliziert")
	check(g.hero.position.x > -150, "Client sieht eigene Rückkehr")
	await get_tree().create_timer(0.5).timeout
