extends Node
## Balance-Probe für Bollwerk (Modus heroes): der Bot spielt Läufe ohne Bild.
##   godot --headless --path . tools/heroes_sim.tscn -- --laeufe=3 --stufen=0,1,2
## Ausgabe je Lauf: erreichte Welle, Feste-Leben, Stufe, Tode, Durchbrüche je Welle.

func _ready() -> void:
	var opts := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Profile.dir = "user://sim_heroes_profile"
	Profile.reset_cache()
	var runs := int(opts.get("laeufe", "2"))
	for st in str(opts.get("stufen", "0,1,2")).split(","):
		for r in runs:
			Session.skip_setup = true
			Session.difficulty = int(st)
			var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
			g.bot = true
			add_child(g)
			await get_tree().process_frame
			g.set_physics_process(false)
			g.rng.seed = 1000 + r
			var k := 0
			while g.state == "play" and g.play_time < 900.0:
				if k % 3 == 0:
					g.bot_turn()
				g.step(1.0 / 30.0)
				k += 1
			var leaks: Array = []
			for w in g.wave_log:
				leaks.append(int(w.leaks))
			print("Stufe %s Lauf %d: %s Welle %d, Feste %d/%d, Held Stufe %d, Tode %d, ausgewichen %d, Durchbrüche %s" % [
				st, r, "SIEG" if g.lives > 0 and g.state == "over" else "verloren", g.wave, g.lives, g.max_lives,
				g.hero.level, g.hero.deaths, g.hero.dodges, leaks])
			g.queue_free()
			await get_tree().process_frame
	get_tree().quit()
