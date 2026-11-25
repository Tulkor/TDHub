extends "res://tools/testlauf/bot_basis.gd"
## Tower-Survivors-Bot für Testläufe: nutzt den Bot des Spiels (SvGame.bot_turn: kauft die teuerste passende Waffe,
## tauscht die schwächste gegen seltenere, öffnet Plätze, kauft das billigste Upgrade, nimmt den ersten Bonus).
## Stufe 1: schaut etwa jede Sekunde in den Laden, kauft eine zufällige bezahlbare Waffe, ab und zu ein zufälliges
##   Upgrade, nimmt einen zufälligen Bonus.
## Stufe 2: der Bot des Spiels (bot_turn) jede Sekunde.
## Stufe 3: bot_turn alle halbe Sekunde, danach geht alles übrige Gold sofort in das billigste Upgrade (bot_turn
##   allein spart zu viel: in Testläufen kam sogar Stufe 1 weiter).
## Stufe 4: wie 3, wählt das Upgrade aber nach Nutzen je Gold (Angriff gegen Verteidigung, je nachdem, wie viel
##   Hülle fehlt; Einkommen nur früh). Mit --skill ist jede Ladenrunde mit Wahrscheinlichkeit 1 − skill/100
## die von Stufe 1 (bot_basis.wurf). Kein Spielstand (Survivors hat noch keine Spielstände), keine Aufstiegsstufen.


func play(st: int, sd: int, tempo: float, args: Dictionary) -> Dictionary:
	stufe = st
	await start(sd, args)
	var g = game
	var k := 0
	var leaks := []
	var last_wave := 0
	var hp_at := float(g.hp)
	var every := 30 if stufe == 2 else 15
	while g.state != "over" and k < 30 * 60 * 40:
		g.step(1.0 / 30.0)
		k += 1
		if k % every == 0:
			wurf()
			if stufe == 1:
				_random_turn()
			else:
				if stufe >= 3:
					_buy_weapons()
					_spend()
				else:
					g.bot_turn()
		if g.wave != last_wave:
			if last_wave > 0:
				leaks.append(snappedf(maxf(hp_at - float(g.hp), 0.0), 0.1))
			hp_at = float(g.hp)
			last_wave = g.wave
			print("WELLE %d  Hülle %.0f/%.0f  Gold %d  DPS %d" % [g.wave, g.hp, g.max_hp(), g.gold, g.total_dps()])
		if k % 600 == 0:
			await get_tree().process_frame
	leaks.append(snappedf(maxf(hp_at - float(g.hp), 0.0), 0.1))
	var weapons := {}
	for w in g.weapons:
		if w != null:
			weapons[str(w.id)] = int(w.level)
	var count := int(g.cfg.waves.count)
	return {"sieg": g.hp > 0.0 and g.state == "over", "welle": mini(g.wave, count), "wellen": count,
		"leben_start": g.max_hp(), "leben": g.hp, "verluste": leaks, "tower": weapons, "gold": int(g.gold),
		"upgrades": g.upgrades.duplicate(), "kills": g.kills}


## Waffen kaufen: zuerst, was eine vorhandene Waffe eine Stufe hochbringt (gleiche Waffe nochmal), sonst die
## teuerste, die auf einen freien Platz passt. Volle Plätze: schwächste Waffe gegen eine seltenere tauschen (bot_turn).
func _buy_weapons() -> void:
	var g = game
	if g.state == "perk":
		g.choose_perk(0)
		return
	if g.state != "play":
		return
	for _pass in 4:
		var best := -1
		var best_v := -INF
		for i in g.offers.size():
			var id: String = g.offers[i]
			if id == "" or g.gold < g.price(id):
				continue
			var slot: int = g.target_slot(id)
			if slot < 0:
				continue
			var v := float(g.price(id))
			if g.weapons[slot] != null:
				v += 1000.0
			if v > best_v:
				best_v = v
				best = i
		if best < 0:
			break
		g.buy_offer(best)


## Übriges Gold in Upgrades stecken, bis nichts mehr bezahlbar ist.
func _spend() -> void:
	var g = game
	for _i in 12:
		if g.state != "play":
			return
		var ids: Array = ["damage", "rate", "hull", "armor", "repair", "thorns", "slot"]
		if g.wave <= 12:
			ids.append("income")
		var best := ""
		var best_s := -INF
		var dps := maxf(float(g.total_dps()), 1.0)
		var lost := 1.0 - float(g.hp) / maxf(float(g.max_hp()), 1.0)
		var defw := 0.6 + 3.0 * lost
		for id in ids:
			var p: int = g.upgrade_price(id)
			if p <= 0 or p > g.gold:
				continue
			var sc := -float(p)
			if stufe >= 4:
				var u: Dictionary = g.upgrade_defs[id]
				var v := 0.0
				match id:
					"damage", "rate":
						v = float(u.add) * 100.0
					"hull":
						v = float(u.add) / maxf(float(g.max_hp()), 1.0) * 100.0 * defw
					"armor":
						v = 2.5 * defw
					"thorns":
						v = 2.0 * defw
					"repair":
						v = float(u.add) * 20.0 / maxf(float(g.max_hp()), 1.0) * 100.0 * defw
					"income":
						v = float(u.add) * 30.0 * (13 - g.wave) / maxf(float(p), 1.0) * 4.0
					"slot":
						v = 40.0 if g.target_slot("__none__") < 0 else 0.0
				sc = v / float(p)
			if sc > best_s:
				best_s = sc
				best = id
		if best == "" or not g.buy_upgrade(best):
			return


## Gelegenheitsspieler: kauft, was bezahlbar ist, ohne zu vergleichen; nimmt irgendeinen Bonus.
func _random_turn() -> void:
	var g = game
	if g.state == "perk":
		g.choose_perk(randi() % maxi(g.perk_choice.size(), 1))
		return
	# schaut nur ab und zu in den Laden
	if g.state != "play" or randf() < 0.5:
		return
	var idx := range(g.offers.size())
	idx.shuffle()
	for i in idx:
		if g.offers[i] != "" and g.target_slot(g.offers[i]) >= 0 and g.gold >= g.price(g.offers[i]):
			g.buy_offer(i)
			break
	if randf() < 0.3:
		var ids: Array = ["damage", "rate", "hull", "armor", "repair", "thorns", "income", "slot"]
		g.buy_upgrade(ids[randi() % ids.size()])


func start(sd: int, _args: Dictionary) -> void:
	Session.game_kind = "survivors"
	Session.skip_setup = true
	Session.difficulty = diff
	Profile.dir = "user://testlauf_profil"
	game = load("res://scenes/survivors_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.set_physics_process(false)
	game.rng.seed = sd * 101
