extends Node
## Balance-Probe für Bollwerk (Modus heroes): der Bot spielt Läufe ohne Bild.
##   godot --headless --path . tools/heroes_sim.tscn -- --laeufe=3 --stufen=0,1,2 [--helden=torvik,unrat,vesna,zix] [--wellen=N --zeit=S]
## Ausgabe je Lauf: erreichte Welle, Feste-Leben, Stufe, Tode, Durchbrüche je Welle, Gold/Holz/Inventar.

func _ready() -> void:
	var opts := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Profile.dir = "user://sim_heroes_profile"
	Profile.reset_cache()
	var runs := int(opts.get("laeufe", "2"))
	var jobs: Array = []
	for held in str(opts.get("helden", "torvik")).split(","):
		for st in str(opts.get("stufen", "0,1,2")).split(","):
			for r in runs:
				jobs.append([held, int(st), r])
	for j in jobs:
		Session.skip_setup = true
		Session.difficulty = j[1]
		var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
		g.bot = true
		g.force_hero = j[0]
		add_child(g)
		await get_tree().process_frame
		g.set_physics_process(false)
		g.rng.seed = 1000 + j[2]
		if opts.has("wellen"):
			g.wave_limit = int(opts.wellen)
		var k := 0
		while g.state == "play" and g.play_time < float(opts.get("zeit", "3600")):
			if k % 3 == 0:
				g.bot_turn()
			g.step(1.0 / 30.0)
			k += 1
		var leaks: Array = []
		for w in g.wave_log:
			leaks.append(int(w.leaks))
		print("%s Stufe %d Lauf %d: %s Welle %d, Feste %d/%d, Held Stufe %d, Tode %d, ausgewichen %d, Schaden %d, Heilung %d, Durchbrüche %s" % [
			j[0], j[1], j[2], "SIEG" if g.lives > 0 and g.state == "over" else "verloren", g.wave, g.lives, g.max_lives,
			g.hero.level, g.hero.deaths, g.hero.dodges, roundi(g.hero.damage_done), roundi(g.hero.healing_done), leaks])
		var gear: Array = []
		for x in g.shop.inv:
			if x != null:
				gear.append(x.id)
		var fallen := 0
		for b in g.buildings:
			if b.destroyed and b.road != null:
				fallen += 1
		print("    Gold verdient %d, übrig %d, Holz %d/%d, Torwerke gefallen %d, Inventar %s" % [
			g.shop.gold_earned, g.shop.gold, g.shop.wood, g.shop.wood_earned, fallen, gear])
		g.queue_free()
		await get_tree().process_frame
	get_tree().quit()
