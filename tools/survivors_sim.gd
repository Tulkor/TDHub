extends Node
## Balance-Lauf für Tower Survivors ohne Bild: der Bot (SvGame.bot_turn) spielt je Schwierigkeit
## --laeufe=N Partien, Ausgabe je Lauf Welle, Leben, Waffen, Boni und Gold/DPS an Wellen 5/10/20/30.
##   godot --headless --path . tools/survivors_sim.tscn -- [--laeufe=3] [--stufen=0,1,2]

func _ready() -> void:
	var opts := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Profile.dir = "user://sim_survivors_profile"
	await get_tree().process_frame
	var runs := int(opts.get("laeufe", "2"))
	for d in String(opts.get("stufen", "0,1,2")).split(","):
		for r in runs:
			await _run(int(d), r + 1)
	get_tree().quit()


func _run(diff: int, seed_: int) -> void:
	Session.skip_setup = true
	Session.difficulty = diff
	var g: SvGame = load("res://scenes/survivors_game.tscn").instantiate()
	add_child(g)
	g.set_physics_process(false)
	g.rng.seed = seed_ * 101
	seed(seed_ * 77)
	var k := 0
	var marks := []
	var last_wave := 0
	while g.state != "over" and k < 30 * 60 * 30:
		g.step(1.0 / 30.0)
		k += 1
		if k % 15 == 0:
			g.bot_turn()
		if g.wave != last_wave:
			last_wave = g.wave
			if g.wave in [5, 10, 15, 20, 25, 30]:
				marks.append("W%d: %dG %dDPS %dHP" % [g.wave, g.gold, g.total_dps(), g.max_hp()])
	print("%s #%d: Welle %d %s, Kills %d | %s | %s | %s" % [g.cfg.difficulties[diff].name, seed_, g.wave,
		"SIEG" if g.hp > 0 else "tot", g.kills, " ".join(marks),
		",".join(g.weapons.filter(func(w): return w != null).map(func(w): return "%s%d" % [w.id, w.level])),
		",".join(g.upgrades.keys().map(func(u): return "%s%d" % [u, g.upgrades[u]]))])
	g.queue_free()
	await get_tree().process_frame
