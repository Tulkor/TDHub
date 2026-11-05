extends Node
## Lauf: einzeln (Name heroes)
## Bollwerk (Hero Defense, Modus heroes): Daten, CC mit abnehmender Wirkung (normal/Elite/Boss,
## Zurücksetzen, Verlangsamung und Rüstungssenkung auf Bossen halb), Warnflächen-Formen,
## Gegner-KI (Straße, Aggro, Leine, Angreifer, Helden vor Gebäuden), Fähigkeit beim Aufladen
## unterbrechen = trotzdem Cooldown, niemand bleibt stecken, Heldenfähigkeiten, Bot-Lauf bis zum Ende.

var failures := 0
const DT := 1.0 / 30.0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	Profile.dir = "user://test_heroes_profile"
	Profile.reset_cache()
	_data()
	_cc()
	_shapes()
	await _ai()
	await _interrupt()
	await _hero_kit()
	await _no_stuck()
	await _bot_run(0)
	print("FERTIG, Fehler: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)


func _data() -> void:
	var cfg = Database.load_json(HdGame.DATA)
	check(cfg is Dictionary, "heroes.json lädt")
	check(Database.mode("heroes").get("scene", "") == "res://scenes/heroes_game.tscn", "Modus in modes.json")
	var ids := {}
	for e in cfg.enemies:
		ids[e.id] = true
		for a in e.abilities:
			check(cfg.abilities.has(a), "Fähigkeit %s von %s existiert" % [a, e.id])
	check(cfg.waves.list.size() == int(cfg.waves.count) and int(cfg.waves.count) == 10, "10 Wellen")
	for w in cfg.waves.list:
		for g in w.groups:
			check(ids.has(g[0]), "Wellen-Gegner %s existiert" % g[0])
	var kinds := {}
	for k in cfg.abilities:
		kinds[cfg.abilities[k].kind] = true
	for k in ["circle", "cone", "ring", "charge", "skillshot", "whirl", "summon"]:
		check(kinds.has(k), "Fähigkeitsart %s kommt vor" % k)


func _cc() -> void:
	var cfg: Dictionary = Database.load_json(HdGame.DATA).cc
	var n := HdCc.new(cfg, "normal")
	var got: Array = []
	var t := 0.0
	for k in 5:
		got.append(snappedf(n.hard(1.0, t), 0.01))
		t += 1.5
	check(_same(got, [1.0, 0.75, 0.5, 0.35, 0.35]), "normal: 100/75/50/35/35 %%: %s" % [got])
	# 10 s ohne harte CC → zurück auf volle Wirkung
	check(is_equal_approx(n.hard(1.0, t + 10.5), 1.0), "normal: nach 10 s ohne CC wieder volle Dauer")
	# 10 s am Maximum → zurück, auch wenn weiter betäubt wird
	var m := HdCc.new(cfg, "normal")
	t = 0.0
	for k in 3:
		m.hard(0.5, t)
		t += 1.0
	check(is_equal_approx(m.next_factor(t), 0.35), "normal: nach 3 CC am Maximum (35 %)")
	var start := t
	while t < start + 9.5:
		m.hard(0.5, t)
		t += 2.0
	check(is_equal_approx(m.next_factor(start + 10.1), 1.0), "normal: 10 s am Maximum setzen den Zähler zurück")
	var el := HdCc.new(cfg, "elite")
	var last := 0.0
	for k in 6:
		last = el.hard(1.0, k * 1.0)
	check(is_equal_approx(last, 0.1), "Elite: sinkt bis 10 %% (%.2f)" % last)
	var b := HdCc.new(cfg, "boss")
	var bt: Array = []
	for k in 4:
		bt.append(snappedf(b.hard(1.0, k * 1.5), 0.01))
	check(_same(bt, [1.0, 0.6, 0.3, 0.0]), "Boss: 100/60/30 %%, dann immun: %s" % [bt])
	check(b.immune(10.0) and not b.immune(3.0 + 0.3 + float(cfg.boss.immune) + 0.1), "Boss: Immunität endet nach %s s" % cfg.boss.immune)
	check(is_equal_approx(b.hard(1.0, 20.0), 1.0), "Boss: nach der Immunität wieder volle Dauer")
	# Verlangsamung und Rüstungssenkung: immer, auf Bossen halb
	var s1 := HdCc.new(cfg, "normal")
	s1.slow("x", 0.4, 2.0, 0.0)
	var s2 := HdCc.new(cfg, "boss")
	s2.slow("x", 0.4, 2.0, 0.0)
	check(is_equal_approx(s1.speed_factor(1.0), 0.6) and is_equal_approx(s2.speed_factor(1.0), 0.8), "Verlangsamung 40 %, auf Boss 20 %")
	for k in 5:
		s1.slow("x", 0.4, 2.0, 1.0 + k)
	check(is_equal_approx(s1.speed_factor(5.5), 0.6), "Verlangsamung nimmt nicht ab")
	check(is_equal_approx(s1.speed_factor(9.0), 1.0), "Verlangsamung läuft aus")
	s1.reduce_armor("r", 4.0, 3.0, 0.0)
	s2.reduce_armor("r", 4.0, 3.0, 0.0)
	check(is_equal_approx(s1.armor_reduction(1.0), 4.0) and is_equal_approx(s2.armor_reduction(1.0), 2.0), "Rüstungssenkung 4, auf Boss 2")


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(float(a[i]) - float(b[i])) > 0.001:
			return false
	return true


func _shapes() -> void:
	var o := Vector3.ZERO
	var f := Vector3(0, 0, -1)
	check(HdTelegraph.in_shape(HdTelegraph.CIRCLE, o, f, 2, 0, 0, 0, 0, Vector3(1.9, 0, 0)), "Kreis: innen")
	check(not HdTelegraph.in_shape(HdTelegraph.CIRCLE, o, f, 2, 0, 0, 0, 0, Vector3(2.5, 0, 0)), "Kreis: außen")
	check(not HdTelegraph.in_shape(HdTelegraph.RING, o, f, 6, 2, 0, 0, 0, Vector3(1, 0, 0)), "Ring: sichere Mitte")
	check(HdTelegraph.in_shape(HdTelegraph.RING, o, f, 6, 2, 0, 0, 0, Vector3(4, 0, 0)), "Ring: im Band")
	check(HdTelegraph.in_shape(HdTelegraph.CONE, o, f, 4, 0, 90, 0, 0, Vector3(0.5, 0, -3)), "Kegel: vorne")
	check(not HdTelegraph.in_shape(HdTelegraph.CONE, o, f, 4, 0, 90, 0, 0, Vector3(0, 0, 3)), "Kegel: hinten nicht")
	check(HdTelegraph.in_shape(HdTelegraph.LINE, o, f, 0, 0, 0, 10, 2, Vector3(0.8, 0, -9)), "Linie: am Ende")
	check(not HdTelegraph.in_shape(HdTelegraph.LINE, o, f, 0, 0, 0, 10, 2, Vector3(2, 0, -5)), "Linie: daneben")
	var t := HdTelegraph.cone(4, 90)
	t.aim(Vector3(1, 0, 0))
	check(t.contains(Vector3(3, 0, 0)) and not t.contains(Vector3(-3, 0, 0)), "Warnfläche zeigt in Zielrichtung")
	t.free()


func _new_game() -> HdGame:
	Session.skip_setup = true
	Session.difficulty = 1
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.bot = true
	add_child(g)
	await get_tree().process_frame
	g.set_physics_process(false)
	g.spawn_queue.clear()
	for e in g.enemies:
		g._remove(e)
	g.enemies.clear()
	g.leaks = 0
	return g


func _run(g: HdGame, secs: float, bot := false) -> void:
	var k := 0
	var left := secs
	while left > 0.0 and g.state == "play":
		if bot and k % 3 == 0:
			g.bot_turn()
		g.step(DT)
		left -= DT
		k += 1


func _park_hero(g: HdGame) -> void:
	g.hero.position = Vector3(40, 0, 45)
	g.hero.move_dir = Vector3.ZERO


func _ai() -> void:
	var g := await _new_game()
	_park_hero(g)
	var e := g.spawn("sumpfling")
	_run(g, 3.0)
	check(e.state == "road" and e.road_s > 5.0, "Gegner läuft die Straße (s=%.1f)" % e.road_s)
	# Held in Aggro-Reichweite → folgt
	g.hero.position = e.position + Vector3(5, 0, 0)
	_run(g, 0.2)
	check(e.state == "chase" and e.target == g.hero, "Held in Aggro-Reichweite: Gegner folgt")
	# Held weit weg → Leine reißt, zurück zur Straße
	g.hero.position = e.position + Vector3(30, 0, 10)
	g.hero.position.x = clampf(g.hero.position.x, -40, 40)
	_run(g, 6.0)
	check(e.target == null and e.state in ["return", "road"], "Leine gerissen: zurück zur Straße (%s)" % e.state)
	_run(g, 6.0)
	check(e.state == "road", "wieder auf der Straße")
	# Angegriffen außerhalb der Aggro-Reichweite (aber in Leine) → greift an
	var at := g.road_point(e.road_s + 2.0)
	var side := (g.road_point(e.road_s + 3.0) - at).normalized().cross(Vector3.UP)
	g.hero.position = e.position + side * 12.0
	g._resolve(g.hero)
	g.step(DT)
	check(e.target == null, "12 m entfernt: kein Aggro (Aggro %s)" % e.def.aggro)
	g.hero_hit(e, 1.0, "test")
	g.step(DT)
	check(e.target == g.hero, "vom Helden angegriffen: greift ihn an, obwohl außerhalb der Aggro-Reichweite")
	e.hp = 0.0
	g._kill(e)
	# Helden vor Gebäuden
	var b: HdBuilding = g.buildings[0]
	var e2 := g.spawn("moorklauer", b.position + Vector3(3, 0, 0), g.road_project(b.position, 0, g.road_len))
	g.hero.position = b.position + Vector3(7, 0, 2)
	g.step(DT)
	check(e2.target == g.hero, "Held und Gebäude in Reichweite: Held zuerst")
	_park_hero(g)
	g.step(DT)
	g.step(DT)
	check(e2.target == b, "kein Held in Reichweite: greift das Gebäude an")
	g.queue_free()
	await get_tree().process_frame


func _interrupt() -> void:
	var g := await _new_game()
	var e := g.spawn("schlammwerfer")
	e.ab_ready["moerser"] = 0.0
	g.hero.position = e.position + Vector3(0, 0, 9)
	var k := 0
	while not e.casting() and k < 120:
		g.step(DT)
		k += 1
	check(e.casting() and str(e.cast.id) == "moerser", "Schlammwerfer setzt Mörser an")
	var teles: Array = e.cast.tele.duplicate()
	check(teles.size() == 1 and teles[0].shape == HdTelegraph.CIRCLE, "Mörser zeigt eine Kreis-Warnfläche")
	g.step(DT * 10)
	var p: float = teles[0].progress
	check(p > 0.1 and p < 0.9, "Füllung wächst mit der Aufladung (%.2f)" % p)
	g.stun(e, 1.0)
	g.step(DT)
	check(not e.casting(), "Betäubung beim Aufladen bricht die Fähigkeit ab")
	check(float(e.ab_ready.moerser) > g.play_time + 5.0, "abgebrochene Fähigkeit ist trotzdem auf Cooldown")
	await get_tree().process_frame
	check(not is_instance_valid(teles[0]) or teles[0].is_queued_for_deletion(), "Warnfläche verschwindet")
	_run(g, 3.0)
	check(e.casts_started == 1, "kein neuer Mörser während des Cooldowns")
	# Treffer: Held bleibt stehen → Schaden; ausweichen → kein Schaden
	e.ab_ready["moerser"] = 0.0
	var hp0 := g.hero.hp
	g.hero.position = e.position + Vector3(0, 0, 9)
	k = 0
	while e.casts_started < 2 and k < 200:
		g.step(DT)
		k += 1
	g.hero.position = e.cast.tele[0].position
	g.hero.move_dir = Vector3.ZERO
	var tries := 0
	while e.casting() and tries < 100:
		g.hero.position = e.cast.tele[0].position if e.casting() and str(e.cast.phase) == "windup" else g.hero.position
		g.step(DT)
		tries += 1
	check(g.hero.hp < hp0 - 50.0, "Mörser trifft den Helden (%d → %d)" % [hp0, g.hero.hp])
	# Ausweichen während des Auslösens
	g.hero.hp = g.hero.max_hp
	e.ab_ready["moerser"] = 0.0
	e.gap_until = 0.0
	k = 0
	while not e.casting() and k < 200:
		g.step(DT)
		k += 1
	while e.casting() and float(e.cast.t) < float(e.cast.windup) - DT * 2:
		g.hero.position = e.cast.tele[0].position
		g.step(DT)
	g.hero.dodge_cd = 0.0
	g.hero.dodge(Vector3(1, 0, 0))
	var hp1 := g.hero.hp
	g.step(DT)
	g.step(DT)
	g.step(DT)
	check(g.hero.hp >= hp1 - 5.0, "Ausweichen im richtigen Moment: kein Mörser-Schaden")
	g.queue_free()
	await get_tree().process_frame


func _hero_kit() -> void:
	var g := await _new_game()
	var h := g.hero
	var e := g.spawn("moorbrute", h.position + Vector3(0, 0, -2.5), g.road_len - 6.0)
	e.ab_ready.clear()
	for a in e.def.abilities:
		e.ab_ready[a] = 999.0
	var hp0 := e.hp
	check(h.cast(0, e.position), "Donnerhieb wirkt")
	check(e.hp < hp0 and e.cc.stunned(g.play_time), "Donnerhieb trifft und betäubt")
	check(not h.cast(0, e.position), "Donnerhieb danach auf Abklingzeit")
	var eff1 := e.cc.stun_until - g.play_time
	h.cd[0] = 0.0
	g.play_time += 1.0
	h.cast(0, e.position)
	var eff2 := e.cc.stun_until - g.play_time
	check(eff2 < eff1 - 0.05, "zweite Betäubung kürzer (%.2f → %.2f)" % [eff1, eff2])
	check(not h.cast(3, e.position), "Windaufstieg erst ab Stufe 6")
	h.add_xp(100000.0)
	check(h.level == int(h.def.level.max), "Stufenaufstieg bis %d" % h.level)
	h.mana = h.max_mana
	check(h.cast(3, e.position) and h.form_t > 0.0, "Windaufstieg wirkt")
	check(h.ability(0).name == "Windschlag", "in Luftgestalt wird Donnerhieb zu Windschlag")
	h.mana = h.max_mana
	var hp1 := e.hp
	check(h.cast(1, e.position) and e.hp < hp1 and e.burn_until > g.play_time, "Glutnova trifft und setzt in Brand")
	h.mana = h.max_mana
	check(h.cast(2, e.position), "Erdschock wirft ein Geschoss")
	_run(g, 0.5)
	check(e.cc.speed_factor(g.play_time) < 1.0 or e.dead, "Erdschock verlangsamt")
	check(h.dodge(Vector3(1, 0, 0)) and h.dodging(), "Ausweichen")
	check(not h.dodge(Vector3(1, 0, 0)), "Ausweichen hat Abklingzeit")
	g.queue_free()
	await get_tree().process_frame


## 40 Gegner ohne Helden: alle müssen die Feste erreichen, niemand steckt in einem Felsen fest.
func _no_stuck() -> void:
	var g := await _new_game()
	g.hero.die()
	g.hero.respawn_t = 9999.0
	g.lives = 9999
	g.buildings[0].destroy()
	var ids := ["sumpfling", "moorbrute", "giftkroete", "moorklauer"]
	for k in 40:
		g.spawn_queue.append({"t": k * 0.4, "id": ids[k % ids.size()]})
	var inside := 0
	var t := 0.0
	while t < 150.0 and not (g.spawn_queue.is_empty() and g.enemies.is_empty()):
		g.step(DT)
		t += DT
		for e in g.enemies:
			for ob in g.obstacles:
				if Vector2(e.position.x - ob[0].x, e.position.z - ob[0].z).length() < ob[1] + e.radius - 0.05:
					inside += 1
	check(g.leaks == 40, "alle 40 Gegner erreichen die Feste (%d, %.0f s)" % [g.leaks, t])
	check(inside == 0, "kein Gegner steckt in einem Felsen (%d)" % inside)
	# Verfolgung um einen Felsen herum: Held hinter einem Felsen, Gegner muss drumherum
	g.hero.dead = false
	g.hero.visible = true
	g.hero.hp = 99999.0
	var ob: Array = g.obstacles[2]
	var c: Vector3 = ob[0]
	var r: float = ob[1]
	var e := g.spawn("moorbrute", c + Vector3(r + 1.2, 0, 0), g.road_project(c, 0, g.road_len))
	e.ab_ready.clear()
	for a in e.def.abilities:
		e.ab_ready[a] = 999.0
	g.hero.position = c - Vector3(r + 1.5, 0, 0)
	e.provoke(g.hero)
	var reached := false
	t = 0.0
	while t < 8.0:
		g.step(DT)
		t += DT
		if e.position.distance_to(g.hero.position) < float(e.def.attack.range) + e.radius + g.hero.radius + 0.2:
			reached = true
			break
	check(reached, "Gegner findet um den Felsen herum zum Helden (%.1f s, %d mal festgehangen)" % [t, e.stuck_events])
	g.queue_free()
	await get_tree().process_frame


func _bot_run(diff: int) -> void:
	Session.skip_setup = true
	Session.difficulty = diff
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.bot = true
	add_child(g)
	await get_tree().process_frame
	g.set_physics_process(false)
	var runs_before: int = Profile.data().get("runs", []).size() if Profile.data().has("runs") else -1
	_run(g, 900.0, true)
	var h := g.hero
	print("Bot %s: Welle %d, Feste %d/%d, Kills %d, Stufe %d, Tode %d, ausgewichen %d, Zeit %.0f s" % [
		g.cfg.difficulties[diff].name, g.wave, g.lives, g.max_lives, g.kills, h.level, h.deaths, h.dodges, g.play_time])
	check(g.state == "over", "Bot-Lauf endet (%s)" % g.state)
	check(g.wave >= 5, "Bot kommt mindestens bis Welle 5 (%d)" % g.wave)
	check(h.dodges > 0, "Bot weicht Warnflächen aus (%d)" % h.dodges)
	var stuck := 0
	for e in g.enemies:
		stuck += e.stuck_events
	check(not g.result_news.is_empty() or g.state == "over", "Run im Profil eingetragen")
	g.queue_free()
	await get_tree().process_frame
