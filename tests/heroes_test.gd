extends Node
## Lauf: einzeln (Name heroes)
## Modi: heroes
## Bollwerk (Hero Defense, Modus heroes): Daten, CC mit abnehmender Wirkung (normal/Elite/Boss,
## Zurücksetzen, Verlangsamung und Rüstungssenkung auf Bossen halb), Warnflächen-Formen,
## Gegner-KI (Straße, Aggro, Leine, Angreifer, Helden vor Gebäuden), Fähigkeit beim Aufladen
## unterbrechen = trotzdem Cooldown, niemand bleibt stecken, Heldenfähigkeiten, Bot-Lauf bis zum Ende.
## Etappe 3: 40 Wellen in 4 Fraktionen (Wiederauferstehen, Todesexplosion, Leerenschild), Flieger,
## Elite-Eigenschaften, Kriegsherren mit Ansage und Rast, Endboss mit Landung/Belagerung/Phasen,
## Sonderzonen (Arena, Holzhain, Schmiede, Prüfungen), Ereignisse, Kriegsherren-Händler.
## Etappe 2a: Straßen nach Spielerzahl, Torwerke (schneller nach Fall, reparieren, neu bauen),
## Teleport-Steine, Gold/Holz, Shop, Fernkauf ins Lager, Rezepte, Item-Werte am Helden, Tränke, Warnflächen-Farbe.

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
	await _unrat()
	await _vesna()
	await _zix()
	_items_data()
	await _roads_gates()
	await _economy()
	_stage3_data()
	await _factions()
	await _flyer_elite()
	await _bosses()
	await _zones()
	await _events()
	await _timed_events()
	await _final_area()
	for held in ["torvik", "unrat", "vesna", "zix"]:
		await _bot_run(0, held)
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
	check(cfg.waves.list.size() == int(cfg.waves.count) and int(cfg.waves.count) == 40, "40 Wellen")
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


func _new_game(held := "torvik") -> HdGame:
	Session.skip_setup = true
	Session.difficulty = 1
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.bot = true
	g.force_hero = held
	g.force_final_boss = "verschlinger"  # stabiler Legacy-Regressionslauf; neue Bosse: heroesboss
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
	# Torwerke beiseite, damit nur der Held lockt (Gegner greifen nahe Torwerke sonst an)
	var spots: Array = []
	for b in g.buildings:
		spots.append(b.position)
		b.position = Vector3(75, 0, 75)
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
	for i in g.buildings.size():
		g.buildings[i].position = spots[i]
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


## Gegner vor den Helden stellen, ohne dass er eigene Fähigkeiten einsetzt.
func _dummy(g: HdGame, id: String, at: Vector3) -> HdEnemy:
	var r := g.nearest_road(at)
	var e := g.spawn(id, at, r.project(at, 0.0, r.length), r)
	for a in e.def.abilities:
		e.ab_ready[a] = 999.0
	return e


func _unrat() -> void:
	var g := await _new_game("unrat")
	var h := g.hero
	check(h is HdHeroUnrat, "König Unrat gewählt")
	var e := _dummy(g, "moorbrute", h.position + Vector3(0, 0, -6))
	var e2 := _dummy(g, "moorklauer", h.position + Vector3(1.5, 0, -6))
	for x in [e, e2]:
		x.max_hp = 99999.0
		x.hp = x.max_hp
	var hp0 := e.hp
	check(h.cast(0, e.position), "Schrottbombe wirkt")
	_run(g, 2.2)
	check(e.hp < hp0 and e.cc.speed_factor(g.play_time) < 1.0, "Schrottbombe: Schaden und Verlangsamung")
	var arm0 := e.cc.armor_reduction(g.play_time)
	check(h.cast(1, e.position) and e.rats > 0 and e.rats <= 5, "Rattenschwarm: bis 5 Ratten je Ziel (%d)" % e.rats)
	_run(g, 2.1)
	check(e.cc.armor_reduction(g.play_time) > arm0, "Ratten senken die Rüstung")
	_run(g, 3.5)
	check(e.rats == 0 and e.plagued(), "Ratten fallen ab, Rattenseuche bleibt")
	var dmg_plague := e.out_mult()
	check(dmg_plague < e.dmg_mult, "Seuche senkt den Schaden (%.2f < %.2f)" % [dmg_plague, e.dmg_mult])
	e2.plague_until = 0.0
	g._kill(e)
	check(e2.plagued(), "Seuche springt beim Tod über")
	check(h.cast(2, h.position) and h.shield_left() > 0.0, "Königsgewand gibt Schild")
	var before := h.hp
	g.damage_hero(30.0, null)
	check(is_equal_approx(h.hp, before), "Schild fängt Schaden ab")
	h.add_xp(100000.0)
	h.mana = h.max_mana
	check(h.cast(3, h.position + Vector3(0, 0, -2)), "Rattenbanner wirkt")
	_run(g, 0.3)
	check(h.slow_immune() and h.speed_mult() > 1.0, "im Banner schneller und immun gegen Verlangsamung")
	var e3 := _dummy(g, "moorbrute", h.position + Vector3(2, 0, -2))
	e3.hp = 99999.0
	e3.max_hp = 99999.0
	_run(g, 12.2)
	check(e3.rats > 0 or e3.plagued(), "Ausbruch am Ende: Rattenschwarm auf Getroffene")
	g.queue_free()
	await get_tree().process_frame


func _vesna() -> void:
	var g := await _new_game("vesna")
	var h := g.hero
	check(h is HdHeroVesna, "Vesna gewählt")
	var e := _dummy(g, "moorbrute", h.position + Vector3(0, 0, -8))
	h.aim = e.position
	h.attack_held = true
	var hp0 := e.hp
	_run(g, 0.6)
	check(e.hp < hp0 and e.heal_cut_until > g.play_time, "Spritzengewehr trifft und senkt Heilung")
	_run(g, 3.0)
	check(h.ammo < 8 or h.reload_t > 0.0, "Magazin leert sich, Nachladen")
	h.attack_held = false
	# Schuss heilt eigenes Gebäude
	var b: HdBuilding = g.buildings[0]
	b.hp = b.max_hp * 0.5
	var bhp := b.hp
	h.position = b.position + Vector3(0, 0, 6)
	h.reload_t = 0.0
	h.ammo = 8
	h.attack_cd = 0.0
	e.position = h.position + Vector3(20, 0, 20)
	h._ranged_shot((b.position - h.position).normalized(), null)
	_run(g, 0.5)
	check(b.hp > bhp, "Schuss heilt das Vorwerk")
	e.position = h.position + Vector3(0, 0, -6)
	h.hp = h.max_hp * 0.5
	var hhp := h.hp
	check(h.cast(0, e.position) and not h.link.is_empty(), "Aderlass bindet einen Gegner")
	_run(g, 1.0)
	check(h.hp > hhp, "Aderlass heilt Vesna")
	h.link = {}
	e.position = h.position + Vector3(25, 0, 25)
	var e2 := _dummy(g, "moorklauer", h.position + Vector3(0, 0, -5))
	e2.start_cast("klauenhieb", g.play_time)
	var cast_ok := h.cast(1, e2.position)
	_run(g, 0.4)
	check(cast_ok and not e2.casting() and e2.cc.stunned(g.play_time), "Betäubungspfeil trifft, betäubt und unterbricht")
	check(h.cast(2, h.position) and h.capsules.size() == 1, "Notfallkapsel auf sich selbst")
	h.hp = h.max_hp * 0.2
	_run(g, 0.1)
	check(h.hp > h.max_hp * 0.4 and h.capsules.is_empty(), "Kapsel platzt unter 30 %%")
	h.add_xp(100000.0)
	h.mana = h.max_mana
	check(h.cast(3, h.position) and h.has_buff("hochdosis") and h.out_mult() > 1.4, "Hochdosis auf sich selbst")
	g.queue_free()
	await get_tree().process_frame


func _zix() -> void:
	var g := await _new_game("zix")
	var h := g.hero
	check(h is HdHeroZix, "Zix gewählt")
	check(g.set_zix_kit(["bolzenturm", "teslaspule", "schrottbot"]), "Baukasten ohne Gegner änderbar")
	check(h.ability(0).name == "Bolzenturm" and h.ability(2).name == "Schrottbot", "Baukasten auf Q W E")
	var all: Array = g.gadget_defs.keys()
	check(all.size() == 10, "10 Gebäude im Baukasten")
	for id in all:
		var gd: Dictionary = g.gadget_defs[id]
		var gg := HdGadget.new()
		gg.setup_gadget(g, id, gd, h.position + Vector3(4, 0, -4), h, Vector3(0, 0, -1))
		g.add_child(gg)
		g.buildings.append(gg)
		h.gadgets.append(gg)
	var e := _dummy(g, "moorbrute", h.position + Vector3(4, 0, -7))
	e.hp = 99999.0
	e.max_hp = 99999.0
	_run(g, 3.5)
	check(e.hp < 99999.0, "Gebäude machen Schaden")
	check(e.taunt_src != null or e.target is HdGadget, "Schrottbot/Magnetköder ziehen den Gegner auf sich")
	h.free_kit()
	check(h.gadgets.is_empty(), "Gebäude entfernt")
	h.mana = h.max_mana
	check(h.cast(0, h.position + Vector3(0, 0, -5)) and h.cast(0, h.position + Vector3(0, 0, -5)) == false, "Bolzenturm gestellt, danach Abklingzeit")
	h.cd[0] = 0.0
	h.mana = h.max_mana
	h.cast(0, h.position + Vector3(3, 0, -5))
	h.cd[0] = 0.0
	h.mana = h.max_mana
	h.cast(0, h.position + Vector3(-3, 0, -5))
	check(h.count("bolzenturm") == 2, "höchstens 2 Bolzentürme (%d)" % h.count("bolzenturm"))
	var t = h.gadgets[0]
	t.hp = t.max_hp * 0.5
	var thp: float = t.hp
	e.position = h.position + Vector3(30, 0, 30)
	e.provoked_hero = false
	h.attack_cd = 0.0
	h._kit_step(0.0, g.play_time)
	check(t.hp > thp, "Funkenpistole repariert eigene Gebäude")
	h.add_xp(100000.0)
	h.mana = h.max_mana
	t.hp = t.max_hp * 0.5
	check(h.cast(3, h.position) and t.over() and is_equal_approx(t.hp, t.max_hp), "Überspannung: volle Reparatur, Gebäude verstärkt")
	check(not g.set_zix_kit(["bolzenturm", "teslaspule", "magnetkoeder"]) or g.enemies.is_empty(), "Baukasten in der Welle gesperrt")
	g.queue_free()
	await get_tree().process_frame


## 40 Gegner ohne Helden: alle müssen die Feste erreichen, niemand steckt in einem Felsen fest.
func _no_stuck() -> void:
	var g := await _new_game()
	g.hero.die()
	g.hero.respawn_t = 9999.0
	g.lives = 9999
	for b in g.buildings:
		b.destroy()
	g.wave_time = -1e6
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
	var left_at: Array = []
	for e in g.enemies:
		left_at.append("%s %s s=%.0f %s" % [e.id, e.position, e.road_s, e.state])
	check(g.leaks == 40, "alle 40 Gegner erreichen die Feste (%d, %.0f s) %s" % [g.leaks, t, left_at])
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


func _items_data() -> void:
	var cfg = Database.load_json(HdShop.DATA)
	var ids := {}
	var tiers := {}
	for it in cfg.items:
		check(not ids.has(it.id), "Item %s nur einmal" % it.id)
		ids[it.id] = it
		tiers[int(it.tier)] = true
	for it in cfg.items:
		if it.has("recipe"):
			check(it.recipe.size() >= 2 and it.recipe.size() <= 4, "Rezept %s hat 2–4 Teile" % it.id)
			for c in it.recipe:
				check(ids.has(c), "Rezeptteil %s von %s existiert" % [c, it.id])
				if ids.has(c):
					check(int(ids[c].tier) <= int(it.tier), "Rezept %s nicht schwächer als Teil %s" % [it.id, c])
		else:
			check(str(it.get("shop", "")) in ["grund", "ruest", "trophae"], "Item %s ist im Laden zu kaufen" % it.id)
	check(tiers.size() == 5, "alle 5 Stufen kommen vor (%d)" % tiers.size())
	for st in cfg.wood.stats:
		check(not HdShop.stat_text(st.stats).is_empty(), "Holzwert %s hat Text" % st.id)


func _roads_gates() -> void:
	var g := await _new_game()
	check(g.roads.size() == 2 and g.road_by_id("nord") != null and g.road_by_id("sued") != null, "Einzelspieler: 2 Straßen (Nord, Süd)")
	check(g.buildings.size() == 4, "je Straße Vorwerk und Innentor (%d)" % g.buildings.size())
	var r: HdRoad = g.roads[0]
	var vw = r.gate("vorwerk")
	check(absf(r.speed_mult() - 1.0) < 0.001, "Torwerke stehen: normales Tempo")
	vw.destroy()
	check(absf(r.speed_mult() - float(vw.def.fast)) < 0.001, "Vorwerk gefallen: Gegner %.2f× schneller" % r.speed_mult())
	check(absf(g.roads[1].speed_mult() - 1.0) < 0.001, "andere Straße unberührt")
	# schneller laufen: Gegner auf der Straße mit gefallenem Vorwerk kommt weiter
	_park_hero(g)
	var a := g.spawn("sumpfling", null, 0.0, g.roads[0])
	var b := g.spawn("sumpfling", null, 0.0, g.roads[1])
	a.lane = 0.0
	b.lane = 0.0
	_run(g, 4.0)
	check(a.road_s > b.road_s * 1.15, "Gegner hinter gefallenem Vorwerk ist schneller (%.1f vs %.1f)" % [a.road_s, b.road_s])
	# Teleport-Stein: kurz draufstehen → vor das Vorwerk
	var st: Dictionary = g.stones[0]
	g.hero.position = st.pos
	g.hero.move_dir = Vector3.ZERO
	_run(g, 1.0)
	check(g.hero.position.distance_to(st.to) < 1.5, "Teleport-Stein bringt den Helden zur Straße")
	g.queue_free()
	await get_tree().process_frame
	# alle vier Straßen per Einstellung
	var keep: int = 0
	Session.skip_setup = true
	var g4: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g4.bot = true
	add_child(g4)
	await get_tree().process_frame
	g4.road_choice = 4
	g4._build_roads()
	check(g4.roads.size() == 4 and g4.buildings.size() == 8, "Einstellung: alle 4 Straßen (%d, %d Torwerke)" % [g4.roads.size(), g4.buildings.size()])
	g4.road_choice = keep
	g4.save_settings()
	g4.queue_free()
	await get_tree().process_frame


func _economy() -> void:
	var g := await _new_game()
	var sh: HdShop = g.shop
	var h := g.hero
	check(sh.gold == int(g.cfg.economy.start_gold), "Startgold %d" % sh.gold)
	h.position = g.hero_spawn()
	check(sh.in_fortress(), "Held startet in der Feste")
	check(sh.act({"kind": "buy", "id": "heiltrank"}) == "", "Heiltrank kaufen")
	check(sh.inv[0] != null and sh.inv[0].id == "heiltrank", "in der Feste: direkt ins Inventar")
	sh.act({"kind": "buy", "id": "heiltrank"})
	check(int(sh.inv[0].n) == 2 and sh.inv[1] == null, "Tränke stapeln sich (%d)" % int(sh.inv[0].n))
	# Fernkauf
	h.position = g.roads[0].point(20.0)
	sh.gold = 2000
	check(not sh.in_fortress(), "an der Straße: nicht in der Feste")
	check(sh.act({"kind": "buy", "id": "eisenklinge"}) == "", "Fernkauf Eisenklinge")
	check(sh.stash[0] != null and sh.stash[0].id == "eisenklinge", "Fernkauf landet im Lager")
	check(sh.act({"kind": "move", "from": "stash", "fi": 0, "to": "hero", "ti": 2}) != "", "Lager → Held nur in der Feste")
	# Rezept: Kraftring fehlt
	check(sh.missing("brecherklinge") == ["kraftring"], "Rezept zeigt fehlendes Teil (%s)" % [sh.missing("brecherklinge")])
	check(sh.can_craft("brecherklinge") != "", "ohne alle Teile kein Schmieden")
	var cost := sh.craft_cost("brecherklinge", true)
	check(cost == 300 + 160, "mit Teilen: Rezeptgold + Teilpreis (%d)" % cost)
	var g0 := sh.gold
	check(sh.act({"kind": "craft", "id": "brecherklinge", "buy_missing": true}) == "", "Brecherklinge schmieden (mit Kraftring)")
	check(sh.gold == g0 - cost and sh.owned_count("eisenklinge") == 0 and sh.owned_count("brecherklinge") == 1, "Teile verbraucht, Gold abgezogen")
	h.position = g.hero_spawn()
	var hp0 := h.max_hp
	var pw0 := h.power()
	var at := sh.stash.find(sh.stash.filter(func(x): return x != null)[0])
	check(sh.act({"kind": "move", "from": "stash", "fi": at, "to": "hero", "ti": 2}) == "", "in der Feste: Lager → Held")
	check(h.max_hp > hp0 + 170.0 and h.power() > pw0 * 1.2, "Werte am Helden (Leben %d → %d, Kraft %.2f → %.2f)" % [hp0, h.max_hp, pw0, h.power()])
	# mehrstufig: Schmiedesonne aus Brecherklinge + Glutkern
	check(sh.act({"kind": "craft", "id": "schmiedesonne", "buy_missing": true}) == "", "Schmiedesonne (Stufe Selten) schmieden")
	check(sh.inv[2] != null and sh.inv[2].id == "schmiedesonne", "Ergebnis am Platz des Bauteils")
	# Verkaufen
	g0 = sh.gold
	sh.act({"kind": "sell", "where": "hero", "i": 2})
	check(sh.gold == g0 + sh.sell_price("schmiedesonne") and sh.inv[2] == null, "Verkaufen gibt %d Gold" % sh.sell_price("schmiedesonne"))
	check(absf(h.max_hp - hp0) < 1.0, "verkauftes Item nimmt seine Werte mit")
	# Trank
	h.hp = 100.0
	check(sh.act({"kind": "use", "i": 0}) == "" and h.hp > 400.0 and int(sh.inv[0].n) == 1, "Heiltrank heilt und verbraucht eine Ladung")
	# Holz
	sh.wood = 10
	var p1 := sh.wood_price("schaerfe")
	sh.act({"kind": "wood", "id": "schaerfe"})
	sh.act({"kind": "wood", "id": "schaerfe"})
	var p3 := sh.wood_price("schaerfe")
	check(p3 > p1 and h.b("damage") > 0.06, "Holzwert wirkt, Preis steigt (%d → %d)" % [p1, p3])
	# Torwerk reparieren / neu bauen
	var gate = g.roads[0].gate("vorwerk")
	gate.hp = gate.max_hp * 0.5
	var e := g.spawn("sumpfling", gate.position + Vector3(2, 0, 0), 0.0, g.roads[0])
	check(sh.can_repair(gate) == tr("Gegner in der Nähe"), "nicht reparieren, solange Gegner nah sind")
	g._remove(e)
	g.enemies.clear()
	g0 = sh.gold
	var rc := sh.repair_cost(gate)
	check(sh.act({"kind": "repair", "gate": gate}) == "" and gate.hp >= gate.max_hp - 0.1 and sh.gold == g0 - rc, "Reparatur kostet %d Gold" % rc)
	g.damage_building(gate, 99999.0)
	check(gate.destroyed, "Vorwerk zerstört")
	check(sh.act({"kind": "repair", "gate": gate}) == "" and gate.alive(), "Vorwerk neu gebaut")
	# Kill-Gold
	g0 = sh.gold
	var k := g.spawn("sumpfling", null, 5.0, g.roads[1])
	g.hero_hit(k, 99999.0, "test")
	check(sh.gold > g0, "Kill gibt Gold (+%d)" % (sh.gold - g0))
	# Warnflächen-Farbe (Barrierefreiheit)
	var keep := HdTelegraph.palette
	HdTelegraph.palette = 3
	var t1 := HdTelegraph.circle(2.0)
	var t2 := HdTelegraph.circle(2.0, HdTelegraph.BLUE)
	check(t1.color == HdTelegraph.PALETTES[3].color, "Warnflächen nehmen die eingestellte Farbe")
	check(t2.color == HdTelegraph.BLUE, "Heldenflächen bleiben blau")
	t1.free()
	t2.free()
	HdTelegraph.palette = keep
	g.queue_free()
	await get_tree().process_frame


func _bot_run(diff: int, held := "torvik") -> void:
	Session.skip_setup = true
	Session.difficulty = diff
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.bot = true
	g.force_hero = held
	add_child(g)
	await get_tree().process_frame
	g.set_physics_process(false)
	g.wave_limit = 10
	var runs_before: int = Profile.data().get("runs", []).size() if Profile.data().has("runs") else -1
	_run(g, 900.0, true)
	var h := g.hero
	print("Bot %s %s: Welle %d, Feste %d/%d, Kills %d, Stufe %d, Tode %d, ausgewichen %d, Zeit %.0f s" % [
		held, g.cfg.difficulties[diff].name, g.wave, g.lives, g.max_lives, g.kills, h.level, h.deaths, h.dodges, g.play_time])
	check(g.state == "over", "Bot-Lauf endet (%s)" % g.state)
	check(g.wave >= 5, "Bot kommt mindestens bis Welle 5 (%d)" % g.wave)
	check(h.dodges > 0, "Bot weicht Warnflächen aus (%d)" % h.dodges)
	var stuck := 0
	for e in g.enemies:
		stuck += e.stuck_events
	check(not g.result_news.is_empty() or g.state == "over", "Run im Profil eingetragen")
	check(g.shop.gold_earned > 1000 and g.shop.crafted > 0, "Bot verdient Gold und schmiedet (%d Gold, %d Rezepte)" % [g.shop.gold_earned, g.shop.crafted])
	g.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- Etappe 3

func _stage3_data() -> void:
	var cfg: Dictionary = Database.load_json("res://data/heroes.json")
	var ids := {}
	for e in cfg.enemies:
		ids[str(e.id)] = e
		for a in e.abilities:
			check(cfg.abilities.has(a), "Fähigkeit %s von %s existiert" % [a, e.id])
		if e.has("faction"):
			check(cfg.factions.has(str(e.faction)), "Fraktion von %s existiert" % e.id)
		for ph in e.get("phases", []):
			for a in ph.get("add", []):
				check(cfg.abilities.has(a), "Phasen-Fähigkeit %s existiert" % a)
			if ph.has("summon"):
				check(ids.has(str(ph.summon.id)) or true, "Phasen-Beschwörung")
	for a in cfg.abilities.values():
		if str(a.kind) == "summon":
			check(ids.has(str(a.summon)), "Beschwörung %s existiert" % a.summon)
	var bosses: Array = []
	for i in cfg.waves.list.size():
		var w: Dictionary = cfg.waves.list[i]
		for g in w.groups:
			check(ids.has(str(g[0])), "Welle %d: Gegner %s existiert" % [i + 1, g[0]])
		if bool(w.get("boss", false)):
			bosses.append(i + 1)
	check(bosses == [10, 20, 30], "Kriegsherren in Welle 10/20/30, Welle 40 Großangriff (%s)" % [bosses])
	for z in ["arena", "hain", "schmiede", "pruefung"]:
		var found := false
		for x in cfg.zones.list:
			found = found or str(x.id) == z
		check(found, "Sonderzone %s" % z)
	var pool: Dictionary = Database.load_json("res://data/heroes_ereignisse.json")
	var ev_ids := {}
	var bad: Array = []
	for d in pool.list:
		ev_ids[str(d.id)] = true
		var kind := str(d.get("kind", ""))
		if not (kind in HdEventKinds.KINDS or kind in ["haendler", "karawane", "blutmond", "gefangener", "schrein"]):
			bad.append(d.id)
		for k in ["enemy", "guards", "mimic_enemy", "packs", "spawn"]:
			var base := str(d.get(k, {}).get("base", "")) if d.get(k) is Dictionary else ""
			if base != "" and not base.begins_with("wave_") and not _enemy_exists(cfg, base):
				bad.append("%s:%s" % [d.id, base])
	check(ev_ids.size() == pool.list.size() and ev_ids.size() >= 40, "Ereignis-Pool: mindestens 40 verschiedene (%d)" % ev_ids.size())
	check(bad.is_empty(), "Ereignis-Pool: bekannte Arten und Gegner %s" % [bad])


func _enemy_exists(cfg: Dictionary, id: String) -> bool:
	for e in cfg.enemies:
		if str(e.id) == id:
			return true
	return false


func _factions() -> void:
	var g := await _new_game()
	_park_hero(g)
	g.cfg.factions.knochen.chance = 1.0
	g.wave = 12
	# Knochenheer: steht einmal mit 40 % Leben wieder auf
	var e := _dummy(g, "knochenknecht", g.road_point(20.0))
	g.hero_hit(e, 99999.0, "test")
	_run(g, 2.5)
	var risen: HdEnemy = null
	for x in g.enemies:
		if x.id == "knochenknecht" and not x.dead:
			risen = x
	check(risen != null and risen.risen and absf(risen.hp - risen.max_hp) < 1.0 and risen.max_hp < e.max_hp * 0.5, "Knochenknecht steht mit 40 %% Leben wieder auf")
	if risen:
		g.hero_hit(risen, 99999.0, "test")
		_run(g, 2.5)
		var again := 0
		for x in g.enemies:
			if x.id == "knochenknecht" and not x.dead:
				again += 1
		check(again == 0, "Nur einmal wieder aufstehen")
	# Glutbrut: Todesexplosion mit Warnfläche trifft den Helden
	g.hero.position = g.road_point(30.0) + Vector3(0.5, 0, 0)
	var gl := _dummy(g, "glutling", g.road_point(30.0))
	var hp0 := g.hero.hp
	g.hero_hit(gl, 99999.0, "test")
	check(g.blasts.size() == 1, "Glutling hinterlässt eine Warnfläche")
	_run(g, 1.2)
	check(g.hero.hp < hp0, "Todesexplosion trifft den Helden in der Fläche")
	# Leere: Schild schluckt erst
	_park_hero(g)
	var l := _dummy(g, "leerling", g.road_point(25.0))
	check(l.shield > 0.0 and absf(l.shield - l.max_hp * 0.3) < 1.0, "Leerling hat 30 %% Schild")
	var hp1 := l.hp
	l.take(l.shield * 0.5)
	check(l.hp == hp1 and l.shield > 0.0, "Schaden geht zuerst auf den Schild")
	l.take(l.shield + 10.0)
	check(absf(l.hp - (hp1 - 10.0)) < 0.01, "Rest geht aufs Leben")
	g.queue_free()
	await get_tree().process_frame


func _flyer_elite() -> void:
	var g := await _new_game()
	_park_hero(g)
	g.wave = 12
	var f := g.spawn("knochengeier", null, 0.0, g.roads[0])
	f.max_hp = 1e7
	f.hp = f.max_hp
	check(f.fly and f.fly_road != null and f.fly_road.points.size() == 2, "Flieger nimmt die gerade Fluglinie")
	var lives0 := g.lives
	_run(g, 30.0)
	check(f.dead and g.lives < lives0, "Flieger erreicht die Feste über Felsen und Torwerke hinweg")
	# Teiler: zerfällt in zwei schwächere
	var t := _dummy(g, "glutling", g.road_point(20.0))
	for tr_ in g.cfg.elites.traits:
		if str(tr_.id) == "teiler":
			t.add_trait(tr_)
	g.hero_hit(t, 99999.0, "test")
	_run(g, 0.2)
	var parts := 0
	for x in g.enemies:
		if x.id == "glutling" and not x.dead and x.split_done:
			parts += 1
	check(parts == 2, "Teiler zerfällt in 2 (%d)" % parts)
	# Elite-Eigenschaften werden in Welle 12+ verteilt
	g.spawn_queue.clear()
	g.start_wave(15)
	var with_trait := 0
	for q in g.spawn_queue:
		if q.has("trait"):
			with_trait += 1
	check(with_trait == int(g.cfg.waves.list[14].elites), "Welle 15 hat %d Elite-Eigenschaften" % with_trait)
	g.queue_free()
	await get_tree().process_frame


func _bosses() -> void:
	var g := await _new_game()
	_park_hero(g)
	# Ansage 20 s vorher mit Straße
	g.start_wave(19)
	g.spawn_queue.clear()
	var road := g.boss_road
	check(road != null and g.roads.has(road), "Straße des Kriegsherrn steht in Welle 19 fest")
	g.wave_time = g.wave_len(19) - 19.0
	g.step(DT)
	check(g.boss_warned and g._boss_marker != null, "Kriegsherr wird 20 s vorher angesagt (Markierung)")
	g.wave_time = g.wave_len(19)
	g.step(DT)
	check(g.wave == 20, "Welle 20 startet")
	var vargul = null
	_run(g, 7.0)
	for e in g.enemies:
		if e.id == "vargul":
			vargul = e
	check(vargul != null and vargul.road == road, "Vargul kommt über die angesagte Straße")
	check(not g.can_call_early(), "Früher rufen gesperrt, solange der Kriegsherr lebt")
	if vargul:
		g.hero_hit(vargul, 9999999.0, "test")
	check(g.shop.trophies == 1, "Kriegsherr gibt eine Trophäe")
	_run(g, 1.0)
	check(g.rest_given and g.wave_len(20) - g.wave_time <= 45.1, "Rast: höchstens 45 s bis zur nächsten Welle")
	# Kriegsherren-Händler
	check(g.shop.act({"kind": "buy", "id": "moorkrone"}) == "" and g.shop.trophies == 0, "Trophäe kauft die Moorkrone")
	check(g.shop.can_buy("glutherz") != "", "Ohne Trophäe kein weiteres Trophäen-Item")
	# Welle 40: Großangriff ohne Endboss, danach Endgebiet (eigener Test _final_area)
	for e in g.enemies:
		g._remove(e)
	g.spawn_queue.clear()
	g.start_wave(40)
	var has_v := false
	for sq in g.spawn_queue:
		has_v = has_v or str(sq.id) == "verschlinger"
	check(not has_v and not g.is_boss_wave(40), "Welle 40 ist ein Großangriff ohne Verschlinger")
	g.queue_free()
	await get_tree().process_frame


func _zones() -> void:
	var g := await _new_game()
	var z := g.zones
	check(g.stones.filter(func(s): return s.has("zone")).size() == 8, "Je Sonderzone zwei Teleport-Steine")
	g.wave = 5
	check(not z.is_open("arena") and not z.is_open("schmiede"), "Arena/Schmiede anfangs zu")
	# Stein in der Feste bringt in die Schmiede (ab Welle 6)
	g.wave = 6
	for st in g.stones:
		if st.get("zone", "") == "schmiede" and st.out:
			g.hero.position = st.pos
	_run(g, 1.2)
	check(z.hero_zone() == "schmiede", "Teleport-Stein bringt in die Schmiede")
	# Schmiede: veredeln und Edelstein
	g.shop.gold = 5000
	g.shop.inv[0] = {"id": "eisenklinge", "n": 1}
	g.shop._changed()
	var dmg0 := g.hero.b("damage")
	check(g.shop.act({"kind": "upgrade", "where": "hero", "i": 0}) == "" and int(g.shop.inv[0].up) == 1, "Veredeln auf +1")
	check(g.hero.b("damage") > dmg0, "Veredeltes Item gibt mehr Schaden")
	check(g.shop.act({"kind": "socket", "where": "hero", "i": 0, "gem": "rubin"}) == "", "Rubin einsetzen")
	check(g.shop.act({"kind": "socket", "where": "hero", "i": 0, "gem": "topas"}) == "" and g.shop.inv[0].gems == ["topas"], "Voller Sockel: neuer Stein ersetzt den alten")
	check(g.hero.b("attack_speed") >= 0.06, "Topas gibt Angriffstempo")
	for k in 6:
		g.shop.act({"kind": "upgrade", "where": "hero", "i": 0})
	check(int(g.shop.inv[0].up) <= 5, "Höchstens +5")
	# Arena ab Welle 11
	g.wave = 11
	g.hero.position = z.center("arena") + Vector3(6, 0, 0)
	g.hero.move_dir = Vector3.ZERO
	check(g.shop.act({"kind": "arena"}) == "" and z.arena_fight != null, "Arena-Kampf beginnt")
	check(g.shop.act({"kind": "arena"}) != "", "Nur ein Wächter gleichzeitig")
	var wh0: float = z.arena_fight.max_hp
	var hp0 := g.hero.max_hp
	g.hero_hit(z.arena_fight, 9999999.0, "test")
	check(z.arena_wins == 1 and g.shop.marks == 1 and g.hero.max_hp > hp0, "Arena-Sieg: Marke und dauerhafte Werte")
	g.shop.act({"kind": "arena"})
	check(z.arena_fight.max_hp > wh0 * 1.3, "Nächster Wächter ist stärker")
	g.hero.position = g.hero_spawn()
	_run(g, 3.5)
	check(z.arena_fight == null, "Arena verlassen = Kampf verloren")
	# Holzhain: Geister geben Holz, Holzfäller arbeiten im Hain
	g.hero.position = z.center("hain")
	_run(g, 6.0)
	var spirit = null
	for e in g.enemies:
		if e.zone == "hain" and not e.dead:
			spirit = e
	check(spirit != null, "Hain-Geist erscheint")
	var w0 := g.shop.wood
	var gold0 := g.shop.gold
	if spirit:
		g.hero_hit(spirit, 99999.0, "test")
	check(g.shop.wood == w0 + 1 and g.shop.gold == gold0, "Hain-Geist gibt Holz statt Gold")
	check(g.shop.act({"kind": "lumberjack"}) == "" and z.lumberjacks == 1, "Holzfäller kaufen")
	w0 = g.shop.wood
	z._jack_t = 0.0
	for e in g.enemies:
		if e.zone == "hain":
			g._remove(e)
	g.hero.position = z.center("hain")
	g.hero.hp = g.hero.max_hp
	for k in int(16.0 / DT):
		g.hero.position = z.center("hain")
		g.step(DT)
	check(g.shop.wood > w0, "Holzfäller bringt Holz, solange der Held im Hain ist")
	# Prüfungen: Jagd
	g.wave = 13
	g.hero.position = z.center("pruefung")
	check(g.shop.act({"kind": "trial", "id": "jagd"}) == "", "Prüfung Jagd startet")
	var stash0 := g.shop.count_free("stash")
	var k := 0
	while not z.trial.is_empty() and k < 2000:
		g.hero.position = z.center("pruefung")
		for e in g.enemies:
			if e.zone == "pruefung" and not e.dead:
				g.hero_hit(e, 9999.0, "test")
				break
		g.step(DT)
		k += 1
	check(g.shop.count_free("stash") == stash0 - 1, "Jagd bestanden: seltenes Item im Lager")
	check(g.shop.act({"kind": "trial", "id": "jagd"}) != "", "Prüfung danach einige Wellen gesperrt")
	# Funkentanz: stehen bleiben = getroffen
	check(g.shop.act({"kind": "trial", "id": "tanz"}) == "", "Funkentanz startet")
	_run(g, 4.0)
	check(z.trial.is_empty(), "Funkentanz: Treffer beendet die Prüfung")
	g.queue_free()
	await get_tree().process_frame


func _events() -> void:
	var g := await _new_game()
	var ev = g.events
	_park_hero(g)
	g.wave = 4
	# Wanderhändler
	ev.start("haendler")
	check(g.shop.merchant.size() == 3, "Händler bietet 3 Items")
	g.shop.gold = 99999
	check(g.shop.act({"kind": "merchant", "i": 0}) == "" and g.shop.merchant[0].sold, "Händler-Item kaufen")
	_run(g, 61.0)
	check(g.shop.merchant.is_empty() and ev.active.is_empty(), "Händler zieht nach 60 s weiter")
	# Blutmond
	g.spawn_queue.clear()
	ev.start("blutmond")
	check(not ev.choice.is_empty(), "Blutmond fragt nach")
	check(g.shop.act({"kind": "event", "pick": 0}) == "" and g.blood_wave == g.wave + 1, "Ja: Blutmond auf der nächsten Welle")
	g.start_wave(g.wave + 1)
	var e := g.spawn("sumpfling", null, 0.0, g.roads[0])
	var plain := float(e.def.hp) * float(g.diff().hp) * float(g.scaling().hp) * (1.0 + float(g.cfg.waves.scale_hp) * (g.wave - 1))
	check(absf(e.max_hp - plain * 2.0) < 1.0 and e.reward == 2.0, "Blutmond: doppeltes Leben, doppelte Belohnung")
	for x in g.enemies:
		g._remove(x)
	g.spawn_queue.clear()
	# Schrein: Gold opfern → Segen
	ev.start("schrein")
	var dmg0 := g.hero.b("damage")
	check(g.shop.act({"kind": "event", "pick": 1}) == "" and g.hero.b("damage") > dmg0, "Schrein: Gold gegen Segen")
	g.start_wave(g.wave + 3)
	check(g.blessing.is_empty() and absf(g.hero.b("damage") - dmg0) < 0.001, "Segen endet nach 3 Wellen")
	# Schrein ohne Antwort = abgelehnt
	ev.start("schrein")
	_run(g, float(g.cfg.events.choose_time) + 0.5)
	check(ev.choice.is_empty() and g.blessing.is_empty(), "Ohne Antwort gilt Ablehnen")
	g.spawn_queue.clear()
	# Karawane
	ev.start("karawane")
	var c: HdAlly = ev.active.ally
	check(c != null and g.buildings.has(c), "Karawane zieht los")
	var gold0 := g.shop.gold
	c.position = c.route[c.route.size() - 1] + Vector3(0.3, 0, 0)
	c.leg = c.route.size() - 1
	_run(g, 1.0)
	check(ev.active.is_empty() and g.shop.gold > gold0, "Karawane am Ziel bringt Gold")
	# Gefangener (vorher alle Gegner weg: ein zufälliges Ereignis beim Wellenstart oben kann schon Wachen gesetzt haben)
	g.spawn_queue.clear()
	for x in g.enemies.duplicate():
		g._remove(x)
	ev.start("gefangener")
	check(ev.guards_left() == 3, "Gefangener mit 3 Wachen (%d)" % ev.guards_left())
	for x in g.enemies:
		if x.zone == "kerker":
			g.hero_hit(x, 999999.0, "test")
	for k in int(2.5 / DT):
		g.hero.position = ev.active.pos + Vector3(2.0, 0, 0)
		g.step(DT)
	check(ev.active.has("ally") and g.buildings.has(ev.active.ally), "Befreite kämpft mit")
	var ally: HdAlly = ev.active.ally
	for x in g.enemies:
		g._remove(x)
	g.spawn_queue.clear()
	g.hero.position = g.road_point(20.0)
	ally.position = g.hero.position + Vector3(1.5, 0, 0)
	var foe := _dummy(g, "sumpfling", g.road_point(22.0))
	foe.max_hp = 1e6
	foe.hp = 1e6
	var fhp := foe.hp
	_run(g, 4.0)
	check(foe.dead or foe.hp < fhp, "Befreite greift Gegner an")
	g.start_wave(g.wave + 3)
	check(ev.active.is_empty() and not is_instance_valid(ally) or ally.is_queued_for_deletion(), "Befreite zieht nach 2 Wellen weiter")
	g.queue_free()
	await get_tree().process_frame


## Ereignis-Uhr (System timed_events): alle 5 Minuten eins, nicht während ein Kriegsherr lebt; jedes Ereignis
## des Pools läuft einmal an und lässt sich abschließen; einige Arten mit Belohnung durchgespielt.
func _timed_events() -> void:
	var g := await _new_game()
	var clock = g.systems.get("timed_events")
	check(clock != null and clock.pool.size() >= 40 and is_equal_approx(clock.interval(), 300.0), "Ereignis-Uhr: Pool geladen, alle 300 s")
	_park_hero(g)
	g.wave = 4
	g.wave_time = 0.0
	clock.reset()
	g.wave_limit = 0
	var h0: int = clock.history.size()
	for k in int(299.0 / 0.5):
		clock.tick(0.5)
	check(clock.history.size() == h0, "vor 5 Minuten kein Ereignis")
	clock.tick(1.0)
	check(clock.history.size() == h0 + 1, "nach 5 Minuten ein Ereignis (%s)" % [clock.history])
	g.events.kinds.clear()
	g.events.choice = {}
	g.events.active = {}
	# alle Ereignisse einmal anstoßen
	var broken: Array = []
	for d in clock.pool:
		var id := str(d.id)
		if id in ["karawane", "gefangener", "haendler", "blutmond", "schrein"]:
			continue
		for x in g.enemies.duplicate():
			g._remove(x)
		g.spawn_queue.clear()
		g.hero.hp = g.hero.max_hp
		g.events.start(id)
		var started: bool = g.events.busy() or not g.event_buffs.is_empty() or not g.event_mods.is_empty()
		_run(g, 2.0)
		if not g.events.choice.is_empty():
			g.events._decide(g.events.choice.options.size() - 1)
		g.events.kinds.clear()
		g.event_buffs.clear()
		g.event_mods.clear()
		if not started or g.state != "play":
			broken.append(id)
	check(broken.is_empty(), "alle Ereignisse starten und enden sauber %s" % [broken])
	# Segen: Werte auf Zeit
	var as0 := g.hero.b("attack_speed")
	g.events.start("kriegstrommeln")
	check(g.hero.b("attack_speed") > as0 + 0.2, "Kriegstrommeln: Angriffstempo")
	_run(g, 91.0)
	check(absf(g.hero.b("attack_speed") - as0) < 0.001, "Segen endet nach seiner Zeit")
	# Jagd: Ziel besiegen → Item ins Lager
	for x in g.enemies.duplicate():
		g._remove(x)
	g.spawn_queue.clear()
	var free0 := g.shop.count_free("stash")
	g.events.start("kopfgeld")
	var tg: Array = g.events.kinds.event_enemies()
	check(tg.size() == 1 and tg[0].event_tag == "kopfgeld", "Kopfgeld: ein markierter Gegner")
	for e in tg:
		g.hero_hit(e, 1e9, "test")
	_run(g, 1.0)
	check(not g.events.kinds.busy() and g.shop.count_free("stash") == free0 - 1, "Kopfgeld: Item ins Lager")
	# Sammeln: über alle Lichter laufen
	var xp0 := g.hero.xp + g.hero.level * 1000.0
	g.events.start("sternsplitter")
	for o in g.events.kinds.task.orbs.duplicate():
		g.hero.position = o.node.position
		_run(g, 0.1)
	check(not g.events.kinds.busy() and g.hero.xp + g.hero.level * 1000.0 > xp0, "Sternsplitter: alle gesammelt, Erfahrung")
	# Halten: im Kreis stehen
	var lives0 := g.lives
	g.lives = g.max_lives - 5
	lives0 = g.lives
	g.events.start("altar")
	var at: Vector3 = g.events.kinds.task.pos
	for k in int(21.0 / DT):
		g.hero.position = at
		g.hero.hp = g.hero.max_hp
		g.step(DT)
	check(not g.events.kinds.busy() and g.lives == lives0 + 3, "Altar weihen: +3 Feste-Leben (%d → %d)" % [lives0, g.lives])
	# Wahl: Gaben der Ahnen
	var d0 := g.hero.b("damage")
	g.events.start("ahnengaben")
	check(g.shop.act({"kind": "event", "pick": 0}) == "" and g.hero.b("damage") > d0, "Gaben der Ahnen: Kraft dauerhaft")
	# Uhr steht, während ein Kriegsherr lebt
	for x in g.enemies.duplicate():
		g._remove(x)
	g.events.kinds.clear()
	g.start_wave(10)
	_run(g, 25.0)
	var c0: float = clock.clock
	_run(g, 5.0)
	check(not g.boss_alive() or is_equal_approx(clock.clock, c0), "Uhr steht, solange der Kriegsherr lebt")
	g.queue_free()
	await get_tree().process_frame


## Endgebiet „Der Schlund“: nach der letzten Welle hinüber, Challenges schaffen, Endboss geschwächt, Sieg.
func _final_area() -> void:
	var g := await _new_game()
	var ch = g.systems.get("challenges")
	check(ch != null and ch.list.size() >= 5, "Endgebiet: Challenges geladen")
	g.wave = 40
	g.wave_limit = 0
	g.spawn_queue.clear()
	for x in g.enemies.duplicate():
		g._remove(x)
	_run(g, 0.5)
	check(g.final.active and ch.open and g.hero.position.distance_to(g.final.start_pos()) < 3.0, "nach der letzten Welle ins Endgebiet")
	check(g.bounds() != g.cfg.arena.bounds, "eigenes Spielfeld im Endgebiet")
	# Wagnis: Station betreten → sofort Item ins Lager, Fluch für den Endkampf
	var free0 := g.shop.count_free("stash")
	for k in int(1.3 / DT):
		g.hero.position = g.final.station_pos("fluchschrein")
		g.step(DT)
	check(ch.state_of("fluchschrein") == "done" and g.shop.count_free("stash") == free0 - 1, "Fluchschrein: legendäres Item")
	# Siegel: in der Reihenfolge der Tafel
	g.hero.position = g.final.start_pos()
	check(g.final.begin("siegel") == "", "Siegelsteine beginnen")
	var run: Dictionary = g.final.run
	var order: Array = run.order.duplicate()
	for k in order:
		g.hero.position = run.stones[k].pos
		_run(g, 0.2)
		g.hero.position = g.final.start_pos()
		_run(g, 0.1)
	check(ch.state_of("siegel") == "done", "Siegelsteine in richtiger Reihenfolge gelöst")
	# Echos: alle Kriegsherren-Echos besiegen
	check(g.final.begin("echos") == "", "Echos beginnen")
	for k in 3:
		_run(g, 0.2)
		var cur = g.final.run.get("cur")
		if cur != null:
			g.hero_hit(cur, 1e9, "test")
	_run(g, 0.3)
	check(ch.state_of("echos") == "done", "Echos der Kriegsherren besiegt")
	check(g.shop.trophies == 0, "Echos geben keine Trophäen")
	# Endboss durch das Tor
	for k in int(1.8 / DT):
		g.hero.position = g.final.gate_pos()
		g.step(DT)
	check(ch.boss_started and g.final.boss != null, "Tor startet den Endkampf")
	var v: HdEnemy = g.final.boss
	check(not v.abilities().has("verschl_hagel"), "Siegel: Verschlinger ohne Leerenhagel")
	var plain := float(g.enemy_defs["verschlinger"].hp) * float(g.diff().hp) * float(g.scaling().hp) * (1.0 + float(g.cfg.waves.scale_hp) * 39)
	check(absf(v.max_hp - plain * 0.85) < 2.0, "Echos: Verschlinger −15 % Leben")
	check(g.hero.has_buff("endkampf"), "Fluch gilt im Endkampf")
	var lives0 := g.lives
	for k in int(9.0 / DT):
		g.hero.hp = g.hero.max_hp
		g.step(DT)
	check(g.lives == lives0, "Verschlinger belagert im Schlund keine Feste (%d → %d)" % [lives0, g.lives])
	v.shield = 0.0
	v.take(v.max_hp * 0.36)
	check(v.phase == 1 and g.spawn_queue.is_empty(), "Phase 2 ruft Gegner im Schlund, nicht über die Straßen")
	g.hero_hit(v, 1e10, "test")
	_run(g, 0.5)
	check(g.state == "over" and g.lives > 0, "Sieg nach dem Verschlinger")
	# Weckuhr: ohne Tor erwacht er von selbst
	var g2 := await _new_game()
	var ch2 = g2.systems.get("challenges")
	g2.final.enter()
	g2.hero.position = g2.final.start_pos()
	for k in int((float(ch2.cfg.awaken) + 1.0) / 1.0):
		ch2.tick(1.0)
	check(ch2.boss_started and ch2.boss_reason == "awaken", "Verschlinger erwacht nach %d s von selbst" % int(ch2.cfg.awaken))
	g.queue_free()
	g2.queue_free()
	await get_tree().process_frame
