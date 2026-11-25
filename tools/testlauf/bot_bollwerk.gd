extends "res://tools/testlauf/bot_basis.gd"
## Bollwerk-Bot (Hero Defense, Modus heroes) für Testläufe: nutzt den Bot des Spiels (HdGame.bot_turn: weicht
## Gefahren aus, kämpft gegen den nächsten Gegner, läuft zur Straße mit dem meisten Druck, kauft im Laden).
## Held mit --held=torvik|unrat|vesna|zix (Standard: je Seed ein anderer).
## Stufe 1: reagiert nur jede Sekunde, weicht nicht aus und läuft oft in eine zufällige Richtung.
## Stufe 2: reagiert alle 0,3 s, weicht nur jedes zweite Mal aus.
## Stufe 3/4: bot_turn alle 0,1 s (wie tools/heroes_sim.gd). Mit --skill wird jede Reaktion mit Wahrscheinlichkeit
## 1 − skill/100 die von Stufe 1 (bot_basis.wurf). Lukas' Regel: Läufe auf seinem PC ohne Fokus starten.

const HELDEN := ["torvik", "unrat", "vesna", "zix"]

var held := ""


func play(st: int, sd: int, tempo: float, args: Dictionary) -> Dictionary:
	stufe = st
	await start(sd, args)
	var g = game
	var k := 0
	var last_wave := 0
	var lives_start := int(g.max_lives)
	while g.state == "play" and g.play_time < 3600.0 * 3.0:
		var every: int = 3 if basis_stufe >= 3 else (9 if basis_stufe == 2 else 30)
		if k % every == 0:
			wurf()
			_turn()
		g.step(1.0 / 30.0)
		k += 1
		if g.wave != last_wave:
			last_wave = g.wave
			print("WELLE %d  Feste %d/%d  Held Stufe %d  Tode %d" % [g.wave, g.lives, g.max_lives, g.hero.level, g.hero.deaths])
		if k % 600 == 0:
			await get_tree().process_frame
	var leaks := []
	for w in g.wave_log:
		leaks.append(int(w.leaks))
	var gear := {}
	for x in g.shop.inv:
		if x != null:
			gear[str(x.id)] = int(gear.get(str(x.id), 0)) + 1
	return {"sieg": g.lives > 0 and g.state == "over" and g.wave >= g.wave_count(), "welle": mini(g.wave, g.wave_count()),
		"wellen": g.wave_count(), "leben_start": lives_start, "leben": g.lives, "verluste": leaks, "tower": gear,
		"gold": int(g.shop.gold), "held": held, "held_stufe": g.hero.level, "tode": g.hero.deaths}


func _turn() -> void:
	var g = game
	var h = g.hero
	if stufe >= 3:
		g.bot_turn()
		return
	if h.dead:
		return
	if stufe == 1 and randf() < 0.35:
		# ziellos: läuft in irgendeine Richtung und schlägt um sich
		var a := randf() * TAU
		h.move_dir = Vector3(cos(a), 0.0, sin(a))
		h.attack_held = true
		return
	# Ausweichen verpassen (Stufe 1 immer, Stufe 2 jedes zweite Mal): Abklingzeit kurz belegen, dann scheitert dodge()
	var miss := stufe == 1 or randf() < 0.5
	var cd: float = h.dodge_cd
	if miss and cd <= 0.0:
		h.dodge_cd = 0.001
	g.bot_turn()
	if miss and cd <= 0.0:
		h.dodge_cd = 0.0


func start(sd: int, args: Dictionary) -> void:
	Session.game_kind = "heroes"
	Session.skip_setup = true
	Session.difficulty = diff
	Profile.dir = "user://testlauf_profil"
	Profile.reset_cache()
	held = str(args.get("held", HELDEN[sd % HELDEN.size()]))
	game = load("res://scenes/heroes_game.tscn").instantiate()
	game.bot = true
	game.force_hero = held
	add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.rng.seed = 1000 + sd
