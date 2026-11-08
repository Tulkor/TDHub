extends Node
## Lauf: fest
## Modi: gemtd
## Balance-Check: kann ein einzelner Gem jeder Sorte Welle 1 halten?
## Start: godot --headless --fixed-fps 60 --path . res://tests/balance_test.tscn -- [--tier=0] [--wave=1] [--gem=ruby]
## Auf der klassischen Map steht der behaltene Gem direkt am Laufweg, einmal an der ersten Ecke
## (Checkpoint 1) und einmal mitten auf der ersten Geraden. Die übrigen vier Gems der Runde
## werden abseits des Wegs zu Steinen, es gibt also kein Labyrinth.

const GEMS := ["amethyst", "aquamarine", "diamond", "emerald", "opal", "ruby", "sapphire", "topaz"]
const RUNS := 10
const POSITIONS := {"Ecke": Vector2i(13, 25), "Gerade": Vector2i(12, 18)}
const ROCKS_AT := [Vector2i(15, 35), Vector2i(18, 35), Vector2i(15, 38), Vector2i(18, 38)]


func _ready() -> void:
	await get_tree().process_frame
	var tier := 0
	var wave := 1
	var gems := GEMS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tier="):
			tier = int(arg.substr(7))
		elif arg.begins_with("--wave="):
			wave = int(arg.substr(7))
		elif arg.begins_with("--gem="):
			gems = [arg.substr(6)]
	for gem in gems:
		var line := "%-11s Stufe %d, Welle %d:" % [gem, tier, wave]
		for pos_name in POSITIONS:
			var leaks := []
			for run in RUNS:
				leaks.append(await _run(gem, tier, wave, POSITIONS[pos_name]))
			line += "  %s %s" % [pos_name, leaks]
		print(line, "  (durchgekommen von 10)")
	Engine.time_scale = 1.0
	get_tree().quit()


func _run(gem: String, tier: int, wave: int, keep_at: Vector2i) -> int:
	Session.map_path = "res://data/maps/classic.json"
	var game: Node = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.wave_index = wave - 1
	game.debug_tower = "%s:%d" % [gem, tier]
	game.place_gem(keep_at)
	for a in ROCKS_AT:
		game.place_gem(a)
	game._select(game.round_towers[0])
	game._on_option_chosen(0)
	var lives_before: int = game.lives
	Engine.time_scale = 4.0
	while game.phase == game.Phase.WAVE:
		await get_tree().process_frame
	var leaked: int = lives_before - game.lives
	game.queue_free()
	await get_tree().process_frame
	return leaked
