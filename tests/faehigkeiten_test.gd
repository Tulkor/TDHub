extends Node
## Lauf: einzeln (Name faehigkeiten)
## Modi: eevetd, gemtd
## Fähigkeiten, die früher nur als Text in den Daten standen: eeveTD-Kopfgeld- und Erfahrungs-Auren
## (Minen, Weisheit), die Wellen-Eigenschaften Unverwundbar, Tempo-Bremse, Heiler und Fesselnd,
## und die Todesexplosion der GemTD-Geisterplatte. Alles im echten eeveTD-Spiel (game.gd ist die Basis).
## Start: godot --headless --path . res://tests/faehigkeiten_test.tscn (oder tools/run_tests.sh faehigkeiten)

var failures := 0
var game: Node


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile"
	await get_tree().process_frame
	Session.map_path = "res://data/maps/eeve.json"
	Session.map_override = null
	Session.skip_setup = true
	game = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	check(game.setup_done, "eeveTD gestartet")
	for id in ["eeve_gold_mine", "eeve_diamond_mine", "eeve_stone_of_wisdom", "eeve_ancient_fountain_of_wisdom"]:
		check(not Database.towers[id].get("eeve", {}).has("todo"), "%s: keine Fähigkeit mehr nur als Text" % id)
	_auras()
	_wraith()
	_props()
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)


## Tower bei (x, y) oder, falls dort kein Platz ist, im nächsten freien Feld der Zeile.
func _place(id: String, x: int, y := 60) -> Tower:
	for dx in 20:
		var a := Vector2i(x + dx, y)
		if game.debug_place(id, a):
			return game.towers.get(a, game.traps.get(a))
	return null


func _enemy(at: Vector2, props := []) -> Enemy:
	var g: Dictionary = (game.waves[0].groups[0] as Dictionary).duplicate()
	g["props"] = props
	var before: int = game.enemies.size()
	game._spawn_enemy(g, 0)
	var e: Enemy = game.enemies[before]
	e.pos = at
	e.max_hp = 100000.0
	e.hp = e.max_hp
	return e


func _clear_enemies() -> void:
	for e in game.enemies.duplicate():
		e.dead = true
		game._remove_enemy(e)


func _auras() -> void:
	var mine := _place("eeve_gold_mine", 10)
	var near := _place("eeve_earth_base_tower", 14)
	var far := _place("eeve_earth_base_tower", 10, 10)
	check(mine != null and near != null and far != null, "Goldmine und zwei Tower gesetzt")
	if mine == null or near == null or far == null:
		return
	check(is_equal_approx(mine.bounty_bonus, 0.33) and is_equal_approx(near.bounty_bonus, 0.33), "Goldmine: +33 %% Kopfgeld für sich und den Nachbarn (%.2f, %.2f)" % [mine.bounty_bonus, near.bounty_bonus])
	check(far.bounty_bonus == 0.0, "Tower außerhalb der Aura bekommt nichts")
	check(Abilities.describe(mine.ability("bounty_aura")).contains("33"), "Infotext der Aura: %s" % Abilities.describe(mine.ability("bounty_aura")))
	# Kopfgeld: Kill durch den Nachbarn bringt 33 % mehr als durch den Tower weit weg
	var gains := []
	for t in [near, far]:
		var e := _enemy(Vector2(0, 0))
		e.bounty = 300
		var before: int = game.gold
		e.last_hit_by = 0
		e.last_tower = t
		e.take_raw_damage(e.hp + 1.0)
		gains.append(game.gold - before)
	check(gains[1] > 0 and gains[0] == roundi(gains[1] * 1.33), "Kopfgeld mit Aura %d statt %d" % gains)

	var stone := _place("eeve_stone_of_wisdom", 18)
	check(stone != null and is_equal_approx(near.xp_bonus, 0.45) and is_equal_approx(stone.xp_bonus, 0.45), "Stein der Weisheit: +45 %% Erfahrung (%.2f)" % near.xp_bonus)
	check(far.xp_bonus == 0.0, "weit weg keine Erfahrungs-Aura")
	near.gain_ep(7)
	far.gain_ep(7)
	check(near.kill_bonus() > far.kill_bonus(), "mit Erfahrungs-Aura zählen die Kills mehr (%.2f > %.2f)" % [near.kill_bonus(), far.kill_bonus()])
	var fountain := _place("eeve_ancient_fountain_of_wisdom", 22)
	var diamond := _place("eeve_diamond_mine", 26)
	check(fountain != null and diamond != null and is_equal_approx(near.xp_bonus, 0.7) and is_equal_approx(near.bounty_bonus, 0.55),
			"stärkere Auren ersetzen die schwächeren, statt sich zu addieren (%.2f, %.2f)" % [near.xp_bonus, near.bounty_bonus])


func _wraith() -> void:
	var t := _place("wraith_slate", 30, 20)
	check(t != null and not t.ability("stacking_damage").is_empty(), "Geisterplatte gesetzt")
	if t == null:
		return
	_clear_enemies()
	var victim := _enemy(Vector2(0, 0))
	var close := _enemy(Vector2(3, 0))
	var outside := _enemy(Vector2(8, 0))
	t._hit(victim, 1.0)
	check(victim.stack_time > 0.0 and not victim.stack_boom.is_empty(), "Treffer setzt Stapel mit Todesexplosion")
	victim.hp = 1.0
	var kills_before := t.kills
	t._hit(victim, 10.0)
	check(victim.dead, "Opfer stirbt unter Incinerate")
	check(close.hp < close.max_hp - 100.0, "Gegner im Radius 750 nimmt Explosionsschaden (%d)" % roundi(close.max_hp - close.hp))
	check(outside.hp == outside.max_hp, "Gegner außerhalb bleibt heil")
	check(t.kills == kills_before + 1 and t.total_damage >= close.max_hp - close.hp, "Schaden der Explosion zählt für die Geisterplatte (%d)" % roundi(t.total_damage))
	# ohne Stapel keine Explosion
	var plain := _enemy(Vector2(0, 0))
	close.hp = close.max_hp
	plain.take_raw_damage(plain.hp + 1.0)
	check(close.hp == close.max_hp, "Tod ohne Incinerate explodiert nicht")
	# Kettenreaktion: wer mit Stapeln an der Explosion stirbt, explodiert auch
	_clear_enemies()
	var a := _enemy(Vector2(0, 0))
	var b := _enemy(Vector2(4, 0))
	var c := _enemy(Vector2(8, 0))
	t._hit(a, 1.0)
	t._hit(b, 1.0)
	a.hp = 1.0
	b.hp = 1.0
	a.take_raw_damage(5.0)
	check(b.dead and c.hp < c.max_hp, "Kettenreaktion: zweiter Gegner stirbt und explodiert weiter")
	_clear_enemies()


func _props() -> void:
	_clear_enemies()
	for id in ["invuln", "ar_aura", "heal", "entang"]:
		check(EeveWaves.prop(game.rules, id).get("enabled", true), "Eigenschaft %s ist eingeschaltet" % id)
	for id in ["evade", "dr_aura"]:
		check(not EeveWaves.prop(game.rules, id).get("enabled", true), "Eigenschaft %s bleibt aus" % id)

	# Unverwundbar: nach dem ersten Schaden 4,5 s ohne Schaden, danach 10 s Abklingzeit
	var e := _enemy(Vector2(-30, -30), ["invuln"])
	e.take_raw_damage(100.0)
	game._tick_props(0.1)
	check(e.invulnerable_time > 4.0, "Unverwundbar schützt sich nach Schaden")
	check(e.take_raw_damage(5000.0) == 0.0, "unverwundbar: kein Schaden")
	e._process(4.6)
	check(e.take_raw_damage(50.0) > 0.0, "nach 4,5 s wieder verwundbar")
	_clear_enemies()

	# Tempo-Bremse: Tower in 450 Reichweite greifen 45 % langsamer an
	var t := _place("eeve_earth_base_tower", 50, 20)
	check(t != null, "Tower für die Wellen-Eigenschaften")
	if t == null:
		return
	var cd: float = t.cooldown()
	var slow := _enemy(t.pos + Vector2(2, 0), ["ar_aura"])
	game._tick_props(0.1)
	check(is_equal_approx(t.speed_malus, 0.45) and t.cooldown() > cd * 1.8, "Tempo-Bremse: Abklingzeit %.2f statt %.2f" % [t.cooldown(), cd])
	slow.pos = t.pos + Vector2(10, 0)
	game._tick_props(0.1)
	check(t.speed_malus == 0.0, "außer Reichweite wieder normal")
	_clear_enemies()

	# Heiler: heilt verletzte Bodengegner in 700 um 225, dann 90 s Pause
	var healer := _enemy(Vector2(-30, -30), ["heal"])
	var hurt := _enemy(Vector2(-27, -30))
	hurt.hp -= 1000.0
	healer.hp -= 100.0
	game._tick_props(0.1)
	check(is_equal_approx(hurt.max_hp - hurt.hp, 775.0) and healer.hp == healer.max_hp, "Heiler heilt sich und Nachbarn (fehlen noch %d)" % roundi(hurt.max_hp - hurt.hp))
	game._tick_props(5.0)
	check(is_equal_approx(hurt.max_hp - hurt.hp, 775.0), "Heilung erst nach 90 s wieder")
	_clear_enemies()

	# Fesselnd: fesselt einen Tower, der ihn in Reichweite hat, 4 s lang
	var root := _enemy(t.pos + Vector2(1, 0), ["entang"])
	game._tick_props(0.1)
	check(t.rooted_time > 3.5, "Fesselnd fesselt den Tower in Reichweite")
	t.cooldown_left = 0.0
	root.hp = root.max_hp
	game.phase = game.Phase.WAVE
	t._process(0.1)
	check(root.hp == root.max_hp, "gefesselter Tower greift nicht an")
	game.phase = game.Phase.BUILD
	_clear_enemies()
