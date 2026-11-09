extends Node
## Lauf: fest --runs=1 (Name tempo)
## Modi: gemtd
## Tempo-Test: macht jeder Tower bei 1×, 2× und 4× gleich viel Schaden in einer Welle?
## Start: godot --headless --fixed-fps 60 --path . res://tests/speed_test.tscn -- [--tower=ruby] [--runs=3]
## --fixed-fps legt die Bildrate fest (60 = typischer Monitor), das Spieltempo vervielfacht dann die Schrittweite.
## Ein Tower (höchste Stufe) steht an der ersten Ecke, Fallen liegen auf dem Weg. Die Gegner einer Boden- bzw.
## Flugwelle bekommen riesige Leben, damit keiner stirbt: gemessen wird reiner Schaden über die gleiche Strecke.

const SPEEDS := [1.0, 2.0, 4.0]
const CORNER := Vector2i(13, 25)
const TOLERANCE := 0.05

var failures := 0
var verbose := false


func _ready() -> void:
	await get_tree().process_frame
	var only := ""
	var runs := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tower="):
			only = arg.substr(8)
		elif arg == "--verbose":
			verbose = true
		elif arg.begins_with("--runs="):
			runs = int(arg.substr(7))
	Session.debug_immortal = true
	print("%d Läufe je Tempo" % runs)
	for id in Database.tower_ids():
		if only != "" and id != only:
			continue
		var tier: int = (Database.towers[id].get("tiers", []) as Array).size() - 1
		# Zufall (Krit, Nova mit Chance) läuft bei anderem Tempo anders ab: ein Lauf allein schwankt um ±10 %
		var n := runs
		if (Database.tower_tier(id, tier).get("abilities", []) as Array).any(func(ab): return ab.has("chance")):
			n = maxi(runs, 4)
		var dmg := []
		for s in SPEEDS:
			var total := 0.0
			for r in n:
				total += await _run(id, tier, s, r)
			dmg.append(total / n)
		var line := "%-20s" % id
		var worst := 0.0
		for i in SPEEDS.size():
			line += "  %d×: %9.0f" % [int(SPEEDS[i]), dmg[i]]
			if i > 0 and dmg[0] > 0.0:
				var dev: float = dmg[i] / dmg[0] - 1.0
				line += " (%+.1f%%)" % (dev * 100.0)
				worst = maxf(worst, absf(dev))
		if dmg[0] <= 0.0:
			line += "  (kein Schaden, z. B. nur Aura)"
		elif worst > TOLERANCE:
			line += "  ABWEICHUNG"
			failures += 1
		print(line)
	print("FERTIG, Tower mit über %d %% Abweichung: %d" % [int(TOLERANCE * 100), failures])
	Session.debug_immortal = false
	Engine.time_scale = 1.0
	get_tree().quit(1 if failures > 0 else 0)


func _run(id: String, tier: int, speed: float, run: int) -> float:
	seed(1000 + run)
	Session.map_path = "res://data/maps/classic.json"
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	var t := Tower.new()
	t.is_new = false
	game.board.add_child(t)
	var trap: bool = str(Database.towers[id].get("kind", "")) == "trap"
	var cell := CORNER
	if trap:
		var p: Vector2 = game.ground_path[mini(6, game.ground_path.size() - 1)]
		cell = Vector2i(p / Board3D.CELL) - Vector2i(1, 1)
	t.setup(game, cell, id, tier)
	game._register(t)
	game._update_paths()
	game._update_auras()
	# Welle 3 (Boden) oder 4 (Flieger), Gegner unsterblich
	game.waves = game.waves.duplicate(true)
	game.wave_index = 3 if t.target_mode() == "air" else 2
	for g in game.waves[game.wave_index].groups:
		g.hp = 1.0e9
	game._start_wave()
	Engine.time_scale = speed
	var frames := 0
	while game.phase == game.Phase.WAVE:
		await get_tree().process_frame
		frames += 1
	Engine.time_scale = 1.0
	if verbose:
		print("    %s %d×: %d Bilder, %d Angriffe" % [id, int(speed), frames, t.get_meta("shots", 0)])
	var d: float = t.total_damage
	game.queue_free()
	await get_tree().process_frame
	return d
