extends Node
## Lauf: einzeln (Name heroesboss)
## Modi: heroes
## Fünf Endboss-Begegnungen: Wellenintegration, Rotation, Warnzeiten, Treffer, Phasen und Cleanup.

var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _ready() -> void:
	get_tree().create_timer(90).timeout.connect(func():
		printerr("FAIL Boss-Test Zeitlimit")
		get_tree().quit(1))
	Profile.dir = "user://test_heroes_boss_profile"
	Profile.reset_cache()
	for id in Database.load_json(HdBossCatalog.DATA).final_bosses:
		await encounter(str(id))
	print("Endbosse: %d Prüfungen, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func encounter(id: String) -> void:
	Session.skip_setup = true
	Session.difficulty = 0
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.force_hero = "torvik"
	g.force_final_boss = id
	add_child(g)
	await get_tree().process_frame
	g.set_physics_process(false)
	g.rng.seed = 4207
	g.obstacles.clear()
	g.spawn_queue.clear()
	for unit in g.enemies.duplicate():
		g._remove(unit)
	g.enemies.clear()
	g.hero.max_hp = 1000000
	g.hero.hp = g.hero.max_hp
	g.start_wave(39)
	g.spawn_queue.clear()
	check(str(g._boss_def(40).id) == id, id + ": Ansage")
	g.rng.randi()
	g.start_wave(40)
	var queued: Array = g.spawn_queue.filter(func(q): return str(g.enemy_defs[q.id].rank) == "boss")
	check(queued.size() == 1 and str(queued[0].id) == id, id + ": Welle 40 passt zur Ansage")
	if queued.is_empty():
		g.queue_free()
		await get_tree().process_frame
		return
	g._spawn_queued(queued[0])
	g.spawn_queue.clear()
	var boss: HdEnemy = g.enemies.back()
	check(boss.boss_visual != null and boss.boss_visual.get_child_count() >= 10, id + ": eigene Silhouette")
	check(boss.zone == "siege", id + ": Landung vor der Festung")
	boss.position = g.zones.center("arena")
	boss.home = boss.position
	g.hero.position = boss.position + Vector3(0, 0, 7)
	boss.target = g.hero
	g.play_time = 10
	boss.start_cast(str(boss.abilities()[0]), g.play_time)
	boss.take(boss.max_hp * 0.36)
	check(boss.phase == 1 and not boss.casting(), id + ": Phase 2 stoppt laufenden Angriff")
	check(boss.gap_until >= g.play_time + 2, id + ": Phasenpause")
	boss.take(boss.max_hp * 0.36)
	check(boss.phase == 2 and boss.abilities().size() == 6 and boss.cd_mult < 0.82, id + ": Phase 3 schaltet sechs Moves frei")
	var chosen: Array = []
	var rotation: Array = boss.boss_brain.rotation()
	for _i in rotation.size():
		g.play_time += 3
		boss.ab_ready.clear()
		boss.gap_until = 0
		if boss._try_ability(g.play_time):
			chosen.append(boss.cast.id)
			boss.cancel_cast(true)
	check(chosen == rotation, id + ": faire vollständige Rotation")
	g.hero.position = boss.position + Vector3(0, 0, boss.radius + g.hero.radius + 0.1)
	boss.gap_until = g.play_time + 2
	boss.attack_cd = 0
	var hp: float = g.hero.hp
	boss.step(0.2, g.play_time)
	check(g.hero.hp == hp and not boss.casting(), id + ": echtes Erholungsfenster")
	boss.start_cast(str(rotation[0]), g.play_time)
	var ready: float = boss.ab_ready[rotation[0]]
	boss.cc.hard(1, g.play_time)
	boss.step(0.1, g.play_time)
	check(not boss.casting() and boss.ab_ready[rotation[0]] == ready, id + ": Unterbrechung behält Cooldown")
	boss.cc = HdCc.new(g.cfg.cc, "boss")
	for aid in rotation:
		move(g, boss, str(aid))
	if id == "astrael":
		boss.boss_brain.history.assign([boss.position + Vector3(3, 0, 3), boss.position + Vector3(-3, 0, 3)])
		boss.start_cast("zeit_echo", g.play_time)
		var remembered: Vector3 = boss.cast.memory[0]
		g.hero.position += Vector3(10, 0, 0)
		check(boss.cast.tele[0].position.distance_to(remembered) < 0.1, "Astrael: Echo bleibt an vergangener Position")
		boss.cancel_cast(true)
	for _i in 3:
		g.summon(boss, "sporenwicht", 99, 4)
	check(boss.boss_brain.remaining_adds() == 0, id + ": Add-Limit")
	for _i in 20:
		g.add_pool(boss.position, 2, 1, 10, boss)
	check(g.pools.size() <= 12, id + ": Flächenlimit")
	for _i in 90:
		g.enemy_projectile(boss, boss.position, Vector3.RIGHT, 1, 100, 0.3, 1)
	check(g.projectiles.filter(func(p): return p.get("src") == boss).size() <= 72, id + ": Geschosslimit")
	boss.hp = 1
	g.hero.position = boss.position + Vector3(0, 0, 12)
	g.shoot(boss.position + Vector3(0, 0, -1), Vector3.BACK, 30, 5, 0.3, 10000000)
	g._step_projectiles(0.05)
	check(boss.dead, id + ": Heldengeschoss beendet Bosskampf")
	check(g.pools.is_empty(), id + ": eigene Gefahren entfernt")
	check(g.projectiles.filter(func(p): return p.get("src") == boss).is_empty(), id + ": Geschosse beim Tod sicher entfernt")
	check(g.enemies.filter(func(e): return not e.dead and int(e.get_meta("boss_owner", 0)) == boss.get_instance_id()).is_empty(), id + ": Adds entfernt")
	g.step(1.0 / 30.0)
	check(g.state == "over" and g.lives > 0, id + ": Sieg in Welle 40")
	print("BOSS ", id, " geprüft")
	g.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func move(g: HdGame, boss: HdEnemy, aid: String) -> void:
	g.play_time += 30
	g.hero.hp = g.hero.max_hp
	g.hero.dodge_t = 0
	g.hero.position = boss.position + Vector3(0, 0, 7)
	boss.target = g.hero
	boss.start_cast(aid, g.play_time)
	check(not boss.cast.tele.is_empty(), aid + ": Warnfläche vorhanden")
	if boss.cast.tele.is_empty():
		boss.cancel_cast(true)
		return
	var tele: HdTelegraph = boss.cast.tele[0]
	var ab: Dictionary = boss.cast.ab
	var point := tele.position
	match tele.shape:
		HdTelegraph.RING: point += tele.forward() * (tele.inner + tele.radius) * 0.5
		HdTelegraph.CONE: point += tele.forward() * tele.radius * 0.5
		HdTelegraph.LINE: point += tele.forward() * minf(tele.length * 0.4, 6)
	g.hero.position = point
	var hp: float = g.hero.hp
	boss._step_cast(float(ab.windup) * 0.45, g.play_time)
	check(g.hero.hp == hp, aid + ": kein Schaden vor Ablauf der Warnzeit")
	boss._step_cast(float(ab.windup) * 0.6, g.play_time)
	match str(ab.kind):
		"summon": check(boss.boss_brain.remaining_adds() < 8, aid + ": Adds beschworen")
		"skillshot":
			check(not g.projectiles.is_empty(), aid + ": Geschosse erzeugt")
			for _i in 60:
				g._step_projectiles(0.025)
			check(g.hero.hp < hp, aid + ": Projektil trifft")
		"whirl":
			g.hero.position = boss.position
			boss._step_cast(float(ab.tick) + 0.01, g.play_time)
			check(g.hero.hp < hp, aid + ": Wirbel trifft")
		_: check(g.hero.hp < hp, aid + ": Warnform und Treffer stimmen überein")
	for _i in 240:
		if not boss.casting():
			break
		g.play_time += 0.1
		boss._step_cast(0.1, g.play_time)
	check(not boss.casting() and boss.gap_until > g.play_time, aid + ": Combo endet mit Erholung")
