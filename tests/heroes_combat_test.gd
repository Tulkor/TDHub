extends Node
## Lauf: einzeln (Name heroescombat)
## Modi: heroes
## Neue Warn-/Trefferformen, Heil-Orbs und Dodge-Schutz inklusive direkter Schadenspfade.
var checks := 0
var failures := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", text)


func inside(kind: int, at: Vector3, dir := Vector3.FORWARD, extra := 0.0) -> bool:
	return HdTelegraph.in_shape(kind, Vector3.ZERO, dir, 5, 2, 120, 8, 2, at, extra)


func _ready() -> void:
	Sfx.audible = false  # Dummy-Audio gibt laufende WAV-Playbacks beim sofortigen Testende nicht frei.
	check(inside(HdTelegraph.CROSS, Vector3(4, 0, 0)), "Kreuz: horizontaler Arm trifft")
	check(inside(HdTelegraph.CROSS, Vector3(0, 0, -4)), "Kreuz: vertikaler Arm trifft")
	check(not inside(HdTelegraph.CROSS, Vector3(3, 0, 3)), "Kreuz: Zwischenräume sind sicher")
	check(not inside(HdTelegraph.CROSS, Vector3(5.1, 0, 0)), "Kreuz: jenseits des Arms sicher")
	check(inside(HdTelegraph.CROSS, Vector3(5.1, 0, 0), Vector3.FORWARD, .2), "Kreuz berücksichtigt Körperradius")
	check(inside(HdTelegraph.ARC, Vector3(0, 0, -3)), "Sichel: Bogen trifft")
	check(not inside(HdTelegraph.ARC, Vector3(0, 0, -1)), "Sichel: innere Lücke sicher")
	check(not inside(HdTelegraph.ARC, Vector3(0, 0, 3)), "Sichel: Rückseite sicher")
	check(inside(HdTelegraph.ARC, Vector3(3, 0, 0), Vector3.RIGHT), "Sichel dreht Treffer mit Warnfläche")
	check(inside(HdTelegraph.BOX, Vector3(0, 12, 3)), "Riss trifft beidseitig, ignoriert Geländehöhe")
	check(not inside(HdTelegraph.BOX, Vector3(3, 0, 0)), "Riss: seitlich sicher")
	check(inside(HdTelegraph.BOX, Vector3(3, 0, 0), Vector3.RIGHT), "Riss: gedrehte Länge trifft")
	Session.skip_setup = true
	Session.coop = {}
	Session.difficulty = 0
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.bot = true
	g.persist_settings = false
	add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.spawn_queue.clear()
	var h: HdHero = g.hero
	var orbs = g.health_orbs
	g.cfg.health_orbs.normal = 1.0
	h.hp = h.max_hp
	var enemy := g.spawn("sumpfling", h.position)
	g._kill(enemy)
	check(orbs.orbs.size() == 1, "Echter Kill würfelt Orb")
	g._kill(enemy)
	check(orbs.orbs.size() == 1, "Doppelter Kill erzeugt keinen zweiten Drop")
	orbs.step(g.play_time)
	check(orbs.orbs.size() == 1, "Volles Leben verbraucht Orb nicht")
	h.hp = h.max_hp * .5
	orbs.step(g.play_time)
	check(is_equal_approx(h.hp, h.max_hp * .5) and orbs.orbs.is_empty() and orbs.fields.size() == 1, "Orb startet eine Heilfläche ohne sofortigen Heilimpuls")
	orbs.step(g.play_time + .999)
	check(is_equal_approx(h.hp, h.max_hp * .5), "Keine Heilung vor der ersten vollen Sekunde")
	orbs.step(g.play_time + 1)
	orbs.step(g.play_time + 1)
	check(is_equal_approx(h.hp, h.max_hp * .55), "Erster Impuls heilt fünf Prozent und wird nicht doppelt gezählt")
	orbs.step(g.play_time + 3.01)
	check(is_equal_approx(h.hp, h.max_hp * .65) and orbs.fields.is_empty(), "Drei Impulse ergeben 15 Prozent; letzter Tick wird vor Entfernen nachgeholt")
	orbs.step(g.play_time + 4)
	check(is_equal_approx(h.hp, h.max_hp * .65), "Kein vierter Heilimpuls")
	orbs.spawn(h.position)
	h.hp = h.max_hp * .98
	orbs.step(g.play_time)
	orbs.step(g.play_time + 1)
	check(is_equal_approx(h.hp, h.max_hp), "Orb überschreitet Maximalleben nicht")
	orbs.apply_state([])
	enemy = g.spawn("sumpfling", h.position)
	enemy.gold_free = true
	g._kill(enemy)
	check(orbs.orbs.is_empty(), "Beschworene/belohnungsfreie Gegner geben keine farmbaren Orbs")
	enemy = g.spawn("sumpfling", h.position)
	g._remove(enemy)
	check(orbs.orbs.is_empty(), "Entfernen/Durchbruch erzeugt keinen Drop")
	orbs.spawn(h.position)
	h.dead = true
	h.hp = 0
	orbs.step(g.play_time)
	check(orbs.orbs.size() == 1 and is_zero_approx(h.hp), "Orbs beleben Tote nicht wieder")
	h.dead = false
	h.set_meta("offline", true)
	orbs.step(g.play_time)
	check(orbs.orbs.size() == 1, "Offline-Held sammelt nicht")
	h.set_meta("offline", false)
	orbs.step(g.play_time + 31)
	check(orbs.orbs.is_empty(), "Orb läuft nach 30 Sekunden ab")
	g.cfg.health_orbs.limit = 3
	for i in 5: orbs.spawn(h.position + Vector3.RIGHT * 10)
	check(orbs.orbs.size() == 3, "Orb-Budget begrenzt Weltobjekte")
	orbs.apply_state([])
	for id in g.hero_list:
		g.set_hero(id)
		h = g.hero
		h.position = g.roads[0].point(35)
		h.auto_attack = false
		h.dodge_cd = 0
		check(h.dodge(Vector3.FORWARD), id + ": Dodge startet")
		h.add_shield(100, 10)
		var hp := h.hp
		g.damage_hero(500, null, true)
		g.area_hit(null, true, 500, 2)
		check(is_equal_approx(h.hp, hp) and not h.cc.stunned(g.play_time), id + ": HP und Treffer-CC während Dodge geschützt")
		check(is_zero_approx(h.incoming(500)) and is_equal_approx(h.shield, 100), id + ": Direkter Schaden verbraucht keinen Schild")
		var origin := h.position
		h.dodge_t = .01
		g.play_time = h.dodge_iframe_until - .005
		h.step(.02, g.play_time)
		check(origin.distance_to(h.position) <= float(h.def.dodge.distance) / float(h.def.dodge.time) * .0101, id + ": Letzter Dodge-Schritt überschießt nicht")
		check(h.dodge_invulnerable() and is_zero_approx(h.incoming(500)), id + ": Iframes überleben Timerabrundung im letzten Schritt")
		g.play_time = h.dodge_iframe_until + .001
		check(not h.dodge_invulnerable() and h.incoming(500) > 0, id + ": Schaden nach Ende wieder möglich")
		if h is HdHeroRoster and h.passive_kind() == "charge":
			h.charge = 0
			h.dodge_t = .1
			h.incoming(500)
			check(is_zero_approx(h.charge), "Ausgewichener Schaden lädt keine passive Ressource")
	for spec in [["grabhieb", HdTelegraph.ARC], ["seelenmoerser", HdTelegraph.CROSS], ["riss", HdTelegraph.BOX], ["flammenring", HdTelegraph.ARC]]:
		enemy = g.spawn("grabwaechter", g.hero.position + Vector3.FORWARD * 3)
		enemy.target = g.hero
		enemy.start_cast(str(spec[0]), g.play_time)
		var tele: HdTelegraph = enemy.cast.tele[0]
		check(tele.shape == int(spec[1]), str(spec[0]) + ": Daten erzeugen richtige Warnform")
		check(tele.material_override != null and tele.mesh != null, str(spec[0]) + ": Native Geometrie und Shader vorhanden")
		g.hero.dodge_t = 0
		g.hero.dodge_iframe_until = 0
		g.hero.shield = 0
		g.hero.hp = g.hero.max_hp
		g.hero.position = tele.position + tele.forward() * (3 if tele.shape == HdTelegraph.ARC else 0)
		var before := g.hero.hp
		enemy._fire(g.play_time)
		check(g.hero.hp < before, str(spec[0]) + ": Aufgelöste Form verursacht echten Schaden")
		g._remove(enemy)
		g.enemies = g.enemies.filter(func(e): return not e.dead)
		await get_tree().process_frame
	g.queue_free()
	for frame in 3: await get_tree().process_frame
	print("FERTIG, %d Prüfungen, Fehler: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
