extends Node
## Druckkurve ohne Simulation: legt das Spiel eines Modus wie ein Testlauf-Bot an (Schwierigkeit, Aufstieg),
## erzeugt die Gegner jeder Welle über die Spawn-Funktionen des Modus selbst und misst ihre effektiven Leben
## (Leben / Rüstungsfaktor). Dauert Sekunden statt Minuten, rechnet aber nur die Gegnerseite.
## Start: godot --headless --path . res://tools/testlauf/druck.tscn -- --modus=gemtd [--schwierigkeit=schwer]
##   [--aufstieg=5] [--seed=1]  → eine Zeile „DRUCK {json}“. Besser: tools/druckkurve.sh.
## Shopping Maul passt die Level an die Spielleistung an (Jahresergebnis); hier mit neutralem Ergebnis gerechnet.

const Messung := preload("res://tools/testlauf/messung.gd")
const Testlauf := preload("res://tools/testlauf/testlauf.gd")


func _ready() -> void:
	if get_tree().current_scene != self:
		return
	await get_tree().process_frame
	var args := {"modus": "gemtd", "schwierigkeit": "mittel", "aufstieg": "0", "seed": "1"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var res: Dictionary = await messen(str(args.modus), Testlauf.schwierigkeit(str(args.schwierigkeit)),
			int(args.aufstieg), int(args.seed), args)
	print("DRUCK ", JSON.stringify(res))
	get_tree().quit()
	await get_tree().create_timer(10.0, true, false, true).timeout
	OS.kill(OS.get_process_id())


## Druck je Welle für modus (Schlüssel wie testlauf.gd BOTS), diff 0..2, Aufstieg (nur auf Schwer).
## Ergebnis: {modus, schwierigkeit, aufstieg, leben_start, wellen: [{ehp, hp, n, luft, art}], summe_ehp, druck_pro_leben}
## art: Wellenart des Modus (GemTD/eeve/Randgruppen wave_type, YouTD Größe, Maul Level-Art), für den Trendvergleich.
func messen(modus: String, diff: int, aufstieg: int, sd := 1, args := {}) -> Dictionary:
	seed(sd)
	var bot: Node = load(Testlauf.BOTS[modus]).new()
	bot.diff = diff
	bot.aufstieg = aufstieg if diff == 2 else 0
	add_child(bot)
	await bot.start(sd, args)
	var game = bot.game
	var lives := Messung.leben_von(game)
	var wellen: Array
	match modus:
		"youtd":
			wellen = _youtd(game)
		"shoppingmaul":
			wellen = _maul(game)
		_:
			wellen = _gruppen(game)
	var total := 0.0
	for w in wellen:
		total += float(w.ehp)
	var res := {
		"modus": modus, "schwierigkeit": Testlauf.SCHWIERIGKEITEN[diff], "aufstieg": bot.aufstieg,
		"leben_start": lives, "wellen": wellen, "summe_ehp": roundi(total),
		"druck_pro_leben": roundi(total / maxf(lives, 1.0)),
	}
	bot.queue_free()
	await get_tree().process_frame
	return res


## GemTD, eeveTD, Randgruppen: Gruppen der Welle über game._spawn_enemy (mit Schwierigkeit und Aufstieg).
func _gruppen(game) -> Array:
	var out := []
	for i in game.waves.size():
		game.wave_index = i
		var w := {"ehp": 0.0, "hp": 0.0, "n": 0, "luft": 0, "art": str(game.wave_type(game.waves[i]))}
		for g in game.waves[i].get("groups", []):
			for q in game.group_queue(g):
				var before: int = game.enemies.size()
				game._spawn_enemy(q)
				_take(game, before, w)
		out.append(_round(w))
	game.wave_index = 0
	return out


## YouTD: jeder Gegner der Welle über _spawn_youtd (Aufstieg, Größe, Eigenschaften).
func _youtd(game) -> Array:
	var out := []
	for i in game.max_wave():
		var wd: Dictionary = game.waves[i]
		var w := {"ehp": 0.0, "hp": 0.0, "n": 0, "luft": 0, "art": str(wd.get("size", ""))}
		for c in wd.creeps:
			var before: int = game.enemies.size()
			game._spawn_youtd(wd, str(c), 0)
			_take(game, before, w)
		out.append(_round(w))
	return out


## Shopping Maul: Budget je Level (Leben aller Gegner) mit Aufstieg, Jahresergebnis neutral.
func _maul(game) -> Array:
	var out := []
	var asc: Dictionary = game.systems.difficulty.ascension_mods()
	var hp_f: float = float(asc.get("hp", 1.0))
	game.prev_budget = 0.0
	for n in range(1, game.levels.size() + 1):
		var b: float = game.level_budget(n)
		game.prev_budget = b
		var kind := str(game.level_def(n).get("kind", "ground"))
		var count: int = game.per_spawn(kind) * game.spawn_count()
		var hp := b * hp_f + float(asc.get("hp_add", 0.0)) * count
		out.append({"ehp": roundi(hp), "hp": roundi(hp), "n": count, "luft": count if kind == "air" else 0,
				"art": kind})
	return out


func _take(game, before: int, w: Dictionary) -> void:
	while game.enemies.size() > before:
		var e = game.enemies.pop_back()
		w.ehp += Messung.ehp(e)
		w.hp += maxf(float(e.max_hp), 0.0)
		w.n += 1
		if e.flying:
			w.luft += 1
		e.queue_free()


func _round(w: Dictionary) -> Dictionary:
	w.ehp = roundi(w.ehp)
	w.hp = roundi(w.hp)
	return w
