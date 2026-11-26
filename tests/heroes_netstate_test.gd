extends Node
## Lauf: einzeln (Name heroesnetstate)
## Modi: heroes
## Acht Spieler, Zustands-Rundreise, Konstrukte, CC und verlorene/ungeordnete MTU-Frames.

var failures := 0
var checks := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", text)


func make_game(host: bool) -> HdGame:
	Session.coop = {}
	Session.skip_setup = true
	var game: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	game.bot = true
	game.force_hero = "torvik"
	game.persist_settings = false
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.spawn_queue.clear()
	game.coop = HdCoop.new()
	game.add_child(game.coop)
	game.coop.setup(game, {"role":"host" if host else "client", "player":0 if host else 1, "names":["A", "B", "C", "D", "E", "F", "G", "H"]})
	game.coop.set_process(false)
	return game


func deliver(peer: HdCoop, packet: Dictionary, drop_first := false) -> void:
	var raw := var_to_bytes(packet)
	var bytes := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var count := ceili(bytes.size() / 900.0)
	for part in range(count - 1, -1, -1):
		if drop_first and part == 0:
			continue
		var chunk := {"hd_chunk":true, "rev":packet.rev, "part":part, "parts":count, "size":raw.size(), "bytes":bytes.slice(part * 900, mini((part + 1) * 900, bytes.size()))}
		check(var_to_bytes(chunk).size() < 1200, "Netzwerkfragment bleibt unter MTU")
		peer.accept_chunk(chunk)


func _ready() -> void:
	var server := make_game(true)
	var client := make_game(false)
	var ids := ["torvik", "unrat", "vesna", "zix", "brennholt", "grauhirte", "albe", "lior"]
	for index in range(1, 8):
		server.coop.ensure_player(index, ids[index])
	server.coop.with_player(1, func():
		server.shop.inv[0] = {"id":"eisenklinge", "n":1}
		server.hero.set_bonus(server.shop.bonus())
		server.hero.skills.points = 2
		server.hero.skills.upgrade(0)
		server.hero.cc.slow("test", 0.4, 10, server.play_time))
	server.coop.slots[1].hero.item_ready = {"mobility":server.play_time + 18.0}
	server.coop.slots[1].hero.mastery_ready = server.play_time + 3.0
	server.coop.with_player(3, func():
		server.hero.mana = 9999
		server.hero.cast(0, server.hero.position + Vector3.RIGHT * 3))
	for index in 40:
		server.spawn("sumpfling", server.roads[0].point(index * 2))
	server.enemies[0].immortal=true
	server.enemies[1].visible=false
	server.health_orbs.spawn(Vector3(20, 0, 20))
	server.coop.with_player(1, func(): server.hero.dodge(Vector3.FORWARD))
	var packet := server.coop.snapshot()
	client.coop.apply_state(bytes_to_var(var_to_bytes(packet)))
	check(client.coop.slots.size() == 8, "Acht unabhängige Helden repliziert")
	check(client.hero.item_ready == server.coop.slots[1].hero.item_ready and client.hero.mastery_ready == server.coop.slots[1].hero.mastery_ready, "Item- und Meisterschaftssperren werden autoritativ repliziert")
	check(client.hero.dodge_invulnerable() and is_equal_approx(client.hero.dodge_iframe_until, server.coop.slots[1].hero.dodge_iframe_until), "Dodge-Iframes werden autoritativ repliziert")
	check(client.health_orbs.snapshot() == server.health_orbs.snapshot(), "Orb-Positionen, IDs und Lebensdauer repliziert")
	var orb_actor: HdHero = server.coop.slots[1].hero
	var orb_origin := orb_actor.position
	orb_actor.position = Vector3(20, 0, 20)
	orb_actor.hp = orb_actor.max_hp * .5
	var second_actor: HdHero = server.coop.slots[2].hero
	var second_origin := second_actor.position
	second_actor.position = Vector3(23.5, 0, 20)
	second_actor.hp = second_actor.max_hp * .5
	client.hero.position = Vector3(20, 0, 20)
	client.hero.hp = client.hero.max_hp * .5
	client.health_orbs.step(client.play_time)
	check(client.health_orbs.orbs.size() == 1 and is_equal_approx(client.hero.hp, client.hero.max_hp * .5), "Client sammelt oder heilt nicht eigenmächtig")
	server.health_orbs.step(server.play_time)
	check(server.health_orbs.fields.size() == 1 and is_equal_approx(orb_actor.hp, orb_actor.max_hp * .5), "Aufnahme startet dreisekündige Heilfläche ohne Sofortheilung")
	server.play_time += 1
	server.health_orbs.step(server.play_time)
	check(is_equal_approx(orb_actor.hp, orb_actor.max_hp * .55) and is_equal_approx(second_actor.hp, second_actor.max_hp * .55), "Erster Impuls heilt beide Spieler um je fünf Prozent")
	client.coop.apply_state(server.coop.snapshot())
	check(client.health_orbs.orbs.is_empty() and is_equal_approx(client.hero.hp, client.hero.max_hp * .55), "Aufnahme und Heilung erreichen Client ohne doppelten Effekt")
	check(client.health_orbs.field_snapshot() == server.health_orbs.field_snapshot(), "Laufende Heilfläche mit Radius und Startzeit erreicht auch späteren Client")
	second_actor.position = Vector3(30, 0, 20)
	server.play_time += 1
	server.health_orbs.step(server.play_time)
	check(is_equal_approx(orb_actor.hp, orb_actor.max_hp * .6) and is_equal_approx(second_actor.hp, second_actor.max_hp * .55), "Wer die Fläche verlässt, erhält den nächsten Impuls nicht")
	second_actor.position = Vector3(23.5, 0, 20)
	server.play_time += 1
	server.health_orbs.step(server.play_time)
	check(is_equal_approx(orb_actor.hp, orb_actor.max_hp * .65) and is_equal_approx(second_actor.hp, second_actor.max_hp * .6) and server.health_orbs.fields.is_empty(), "Wiedereintritt heilt beim dritten Impuls; danach verschwindet Fläche")
	check(packet.fx.any(func(f): return f.get("id", "") == "health_orb") == false, "Vor der Aufnahme keine Heilfläche gesendet")
	var outside: HdHero = server.coop.slots[4].hero
	var outside_origin := outside.position
	outside.position = Vector3(27, 0, 20)
	outside.hp = outside.max_hp * .5
	orb_actor.hp = orb_actor.max_hp
	second_actor.hp = second_actor.max_hp * .5
	server.health_orbs.spawn(Vector3(20, 0, 20))
	server.health_orbs.step(server.play_time)
	server.play_time += 1
	server.health_orbs.step(server.play_time)
	check(is_equal_approx(second_actor.hp, second_actor.max_hp * .55) and server.health_orbs.orbs.is_empty(), "Auch gesunder Spieler löst Orb für verletzten Freund in der Heilfläche aus")
	check(is_equal_approx(outside.hp, outside.max_hp * .5), "Außerhalb der Heilfläche keine Heilung")
	check(is_equal_approx(float(server.health_orbs.field_snapshot()[0].radius), 5.0), "Grüne Heilfläche überträgt tatsächlichen Radius an Clients")
	server.health_orbs.apply_state([])
	outside.position = outside_origin
	orb_actor.position = orb_origin
	second_actor.position = second_origin
	orb_actor.dodge_t = 0
	orb_actor.dodge_iframe_until = 0
	check(client.hero.def.id == "unrat" and client.hero.skills.ranks[0] == 2 and client.hero.skills.points == 1, "Client erhält eigenen Helden und Fortschritt")
	check(client.shop.inv[0].id == "eisenklinge" and client.coop.slots[0].shop.inv[0] == null, "Inventare bleiben getrennt")
	check(absf(client.hero.cc.speed_factor(client.play_time) - 0.6) < 0.001, "Client kennt autoritative Verlangsamung")
	check(client.enemies.size() == 40, "Gegnerpopulation vollständig repliziert")
	check(client.enemies[0].immortal and not client.hud.minimap.enemy_available(client.enemies[0]),"Client blendet nicht bekämpfbare Gegner auf der Karte aus")
	check(not client.enemies[1].visible and not client.hud.minimap.enemy_available(client.enemies[1]),"Verborgene Gegner werden auch beim Client nicht verraten")
	check(client.hud.minimap.map_markers().filter(func(m):return m.kind=="friend").size()>=7,"Alle sieben anderen Koop-Helden sind als Freunde markiert")
	server.enemies[0].immortal=false
	server.enemies[1].visible=true
	check(client.buildings.any(func(b): return b is HdGadget and b.zix == client.coop.slots[3].hero), "Zix-Konstrukt verwendet richtigen Spieler und Modelltyp")
	var next := server.coop.snapshot()
	deliver(client.coop, next)
	check(client.coop.last_revision == int(next.rev), "Ungeordnet gelieferte Fragmente ergeben vollständigen Frame")
	var missing := server.coop.snapshot()
	deliver(client.coop, missing, true)
	check(client.coop.last_revision == int(next.rev), "Unvollständiger Frame ersetzt keinen guten Zustand")
	var recovered := server.coop.snapshot()
	deliver(client.coop, recovered)
	check(client.coop.last_revision == int(recovered.rev), "Folgeframe erholt sich nach Paketverlust")
	client.coop.apply_state(packet)
	check(client.coop.last_revision == int(recovered.rev), "Veralteter Zustand wird verworfen")
	check(not HdCoop.valid_input({"seq":1,"move":Vector3(INF,0,0),"aim":Vector3.ZERO,"attack":false}), "Nicht endliche Eingaben abgewiesen")
	var home_positions := server.playing_heroes().map(func(h): return h.position)
	server.coop.with_player(1, func(): server.events.start("schrein"))
	check(server.playing_heroes().all(func(h): return h.position.distance_to(server.event_arena.center) < 15), "Alle acht Helden werden ins Ereignisgebiet teleportiert")
	client.coop.apply_state(server.coop.snapshot())
	check(client.event_arena.active and client.enemies.is_empty(), "Client zeigt keine eingefrorenen Wellengegner im Ereignisgebiet")
	server.events._decide(2)
	server.event_arena.step(0)
	check(server.hero.position.distance_to(home_positions[0]) < 0.1 and server.coop.slots[1].hero.position.distance_to(home_positions[1]) < 0.1, "Host und auslösender Client kehren jeweils zu ihrem eigenen Ausgangspunkt zurück")
	client.coop.apply_state(server.coop.snapshot())
	check(not client.event_arena.active and client.enemies.size() == 40, "Alle Wellengegner kehren nach Ereignis zurück")
	check(client.buildings.any(func(b): return b is HdGadget), "Konstrukte kehren ohne falsche Torwerk-Modelle zurück")
	server.play_time = 100.0
	var runner: HdHero = server.coop.slots[1].hero
	runner.position = Vector3(-25,0,0)
	runner.combat_until = 99.0
	runner.cc._slows.clear()
	client.hero.position = runner.position
	client.coop.pending = [{"seq":999999,"move":Vector3.LEFT,"dt":0.1}]
	client.coop.apply_state(server.coop.snapshot())
	check(is_equal_approx(client.hero.combat_until,99.0) and client.hero.out_of_combat(), "Kampffrist und Laufbonus kommen beim Client an")
	var replay_x: float = -25.0-runner.movement_speed(server.play_time)*0.1*0.45
	check(is_equal_approx(client.hero.position.x,replay_x), "Wiederholte offene Eingaben berücksichtigen auch den Laufbonus")
	client.coop.pending.clear()
	server.final.enter()
	client.coop.apply_state(server.coop.snapshot())
	check(server.playing_heroes().all(func(h): return h.position.x > 200), "Alle acht Helden betreten Endgebiet")
	check(client.final.active and client.hero.position.x > 200, "Endgebiet auf Client repliziert")
	check(client.final_boss_id == server.final_boss_id, "Bossauswahl vor Aufbau des Client-Endgebiets synchronisiert")
	check(client.final.arena_theme == HdFinalStyle.theme_id(server.final_boss_id), "Client baut dieselbe thematische Bossarena wie der Host")
	server.final.start_boss({"hero":{"shield":123}}, "gate")
	check(server.playing_heroes().all(func(h): return server.final.layout.inside(h.position, -h.radius) and h.position.distance_to(server.final.arena_pos()) < float(server.final.data.arena.radius)), "Endkampf versammelt alle acht Helden auf der Bossplattform")
	check(server.playing_heroes().all(func(h): return h.shield >= 123), "Challenge-Schild gilt für alle acht Helden")
	server.add_event_buff("test_party", {"speed":0.25}, 1)
	check(server.playing_heroes().all(func(h): return h.b("speed") >= 0.25), "Gemeinsamer Ereignisbonus gilt sofort für alle Helden")
	server.play_time += 2
	server._step_event_buffs()
	check(server.playing_heroes().all(func(h): return h.b("speed") < 0.25), "Gemeinsamer Ereignisbonus läuft bei allen Helden ab")
	server.bot = false
	server.wave = 10
	server.offer_imprint()
	check(server.imprint_pending.size() == 8, "Alle acht Spieler erhalten eigene drei Prägungen")
	client.coop.apply_state(server.coop.snapshot())
	check(client.imprint_choices.size() == 3 and client.imprint_choices[0].hero == "unrat", "Client sieht seine eigenen Offensive/Defensive/Utility-Karten")
	check(server.choose_imprint(1) and server.paused, "Host-Auswahl lässt Pause für Mitspieler bestehen")
	for index in range(1,8):
		server.coop.with_player(index, func(): check(server.choose_imprint(0), "Mitspieler wählt eigene Prägung"))
	check(not server.paused and server.imprints.size() == 8, "Erst letzte Auswahl beendet Prägungspause")
	check(server.coop.slots[0].hero.b("armor") == 2 and server.coop.slots[4].hero.b("armor") == 0, "Prägungswerte bleiben beim Besitzer")
	server.coop.with_player(4, func():
		server.hero.level = 18
		server.hero.mana = 5000
		server.hero.cast(3, server.hero.position + Vector3.RIGHT * 4))
	server.coop.with_player(5, func():
		server.hero.mana = 5000
		server.hero.cast(0, server.hero.position + Vector3.RIGHT * 4))
	client.coop.apply_state(server.coop.snapshot())
	check(client.buildings.any(func(b): return b is HdRosterConstruct and b.owner_hero == client.coop.slots[5].hero and str(b.def.pet) == "wolf"), "Wölfe mit richtigem Besitzer repliziert")
	check(client.buildings.any(func(b): return b is HdRosterConstruct and b.blocks(b.position)), "Schildwand mit echter Blockform repliziert")
	server.coop.with_player(6, func():
		server.hero.mana = 5000
		server.hero.cast(1, server.hero.position))
	var albe: HdHeroRoster = server.coop.slots[6].hero
	var until := float(albe.fields[0].until)
	server.event_arena.enter()
	check(albe.fields.is_empty(), "Heilfeld bleibt beim Betreten im Ursprungsgebiet eingefroren")
	server.event_arena.elapsed = 20
	server.play_time += 20
	server.event_arena.leave()
	check(albe.fields.size() == 1 and is_equal_approx(float(albe.fields[0].until), until + 20), "Heilfeld kommt mit erhaltener Restdauer zurück")
	server.queue_free()
	client.queue_free()
	await get_tree().process_frame
	print("FERTIG, %d Prüfungen, Fehler: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
