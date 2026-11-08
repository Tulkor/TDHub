extends Node
## Lauf: fest (Name spaet)
## Modi: gemtd
## Balance-Check späte Wellen: wie viel Prozent der Gesamt-HP einer Welle schafft ein einzelner Tower?
## Start: godot --headless --fixed-fps 60 --path . res://tests/late_balance_test.tscn -- [--tower=gold:1] [--waves=30,35]
##        [--scenarios=normal,mass,boss] [--absolute] [--trap-passes=3]
## Szenarien mit gleicher Gesamt-HP wie die Welle: normal (wie in der Wellendatei),
## mass (30 Gegner dicht hintereinander) und boss (ein einzelner Gegner mit der ganzen HP).
## Der Tower steht allein an der ersten Ecke der klassischen Map. Fallen liegen auf dem Weg, und der Weg
## führt hin und zurück, sodass die Welle trap_passes-mal darüberläuft (Platten sind für mehrere
## Durchgänge im Labyrinth gedacht; nur ungerade Zahlen, damit die Gegner danach weiterlaufen).
## die übrigen vier Gems der Runde werden abseits zu Steinen. Leben sind unbegrenzt, jede Welle
## läuft also komplett durch. Ausgabe pro Zeile: Tower, dann Prozent der Wellen-HP je Welle.
## Auren für andere Tower (Schaden, Tempo) und Verlangsamung zählen hier nicht mit.

## Spezial-Tower in jeder Stufe, Grund-Gems als Vergleich in den Stufen 4 und 5 (Perfekt, Groß)
const GEM_TIERS := [4, 5]
const WAVES := [30, 31, 32, 33, 34, 35, 39, 42, 43, 48, 50]
const TOWER_AT := Vector2i(13, 25)
const MASS_COUNT := 30
const MASS_INTERVAL := 0.25
const ROCKS_AT := [Vector2i(15, 35), Vector2i(18, 35), Vector2i(15, 38), Vector2i(18, 38)]

var absolute := false
var trap_passes := 1


func _ready() -> void:
	await get_tree().process_frame
	var configs := []
	var waves := WAVES
	var scenarios := ["normal"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tower="):
			var p := arg.substr(8).split(":")
			configs.append([p[0], int(p[1]) if p.size() > 1 else 0])
		elif arg.begins_with("--waves="):
			waves = Array(arg.substr(8).split(",")).map(func(s): return int(s))
		elif arg.begins_with("--trap-passes="):
			trap_passes = int(arg.substr(14))
		elif arg == "--absolute":
			absolute = true
		elif arg.begins_with("--scenarios="):
			scenarios = Array(arg.substr(12).split(","))
	if configs.is_empty():
		for id in Database.tower_ids():
			if Database.towers[id].get("category", "gem") == "gem":
				for t in GEM_TIERS:
					configs.append([id, t])
			else:
				for t in Database.tier_count(id):
					configs.append([id, t])
	var header := "%-28s" % "Tower"
	for w in waves:
		for sc in scenarios:
			var col := "W%d%s" % [w, "L" if _is_air(w) else ""]
			if scenarios.size() > 1:
				col += sc.substr(0, 1).to_upper()
			header += " %6s" % col
	print(header)
	for c in configs:
		var line := "%-28s" % ("%s:%d" % c)
		for w in waves:
			for sc in scenarios:
				line += (" %6.2f" if absolute else " %6.1f") % (await _run(c[0], c[1], w, sc))
		print(line)
	Engine.time_scale = 1.0
	get_tree().quit()


func _is_air(wave: int) -> bool:
	var g: Dictionary = Database.wave_sets.get("classic", {}).get("waves", [])[wave - 1].groups[0]
	return Database.enemies.get(str(g.enemy), {}).get("flying", false)


func _nearest_index(path: PackedVector2Array, p: Vector2) -> int:
	var best := 0
	for i in path.size():
		if path[i].distance_to(p) < path[best].distance_to(p):
			best = i
	return best


## Weg, der um die Falle bei Index k hin- und herführt, sodass sie passes-mal überquert wird.
func _detour(path: PackedVector2Array, k: int, passes: int) -> PackedVector2Array:
	const MARGIN := 6  ## Felder vor und hinter der Falle, weit genug aus ihrer Reichweite
	var a := maxi(k - MARGIN, 0)
	var b := mini(k + MARGIN, path.size() - 1)
	var forward := path.slice(a, b + 1)
	var back := forward.duplicate()
	back.reverse()
	var out := path.slice(0, b + 1)
	for i in (passes - 1) / 2:
		out.append_array(back)
		out.append_array(forward)
	out.append_array(path.slice(b + 1))
	return out


## Gruppen der Welle im gewünschten Szenario, Gesamt-HP bleibt gleich.
func _groups(wave: int, scenario: String) -> Array:
	var groups: Array = Database.wave_sets.get("classic", {}).get("waves", [])[wave - 1].groups
	if scenario == "normal":
		return groups
	var g: Dictionary = groups[0]
	var total := 0.0
	for o in groups:
		total += float(o.get("hp", Database.enemies[str(o.enemy)].hp)) * int(o.count)
	var count := MASS_COUNT if scenario == "mass" else 1
	return [{"enemy": g.enemy, "count": count, "interval": MASS_INTERVAL, "hp": total / count}]


## Prozent der Gesamt-HP der Welle (mit --absolute: Schaden in Tausend), die der Tower verursacht hat.
func _run(id: String, tier: int, wave: int, scenario := "normal") -> float:
	Session.map_path = "res://data/maps/classic.json"
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.wave_index = wave - 1
	game.waves = game.waves.duplicate()
	game.waves[wave - 1] = {"groups": _groups(wave, scenario)}
	game.lives = 1000000
	var at := TOWER_AT
	var trap_index := -1
	if str(Database.towers[id].get("kind", "tower")) == "trap":
		var path: Array = game.pathfinder.compute_path()
		trap_index = path.size() / 8
		at = path[trap_index]
	game.debug_tower = "%s:%d" % [id, tier]
	var t: Tower = game.place_gem(at)
	game.debug_tower = "topaz:0"
	for a in ROCKS_AT:
		game.place_gem(a)
	game._select(t)
	game._on_option_chosen(0)
	if trap_index >= 0 and trap_passes > 1:
		game.ground_path = _detour(game.ground_path, _nearest_index(game.ground_path, t.pos), trap_passes)
	var total_hp := 0.0
	for g in game.waves[wave - 1].groups:
		total_hp += float(g.get("hp", Database.enemies[str(g.enemy)].hp)) * int(g.count)
	Engine.time_scale = 4.0
	while game.phase == game.Phase.WAVE:
		await get_tree().process_frame
	var share := t.total_damage / 1000.0 if absolute else 100.0 * t.total_damage / total_hp
	game.queue_free()
	await get_tree().process_frame
	return share
