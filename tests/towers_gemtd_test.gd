extends "res://tests/lib/tower_probe.gd"
## Lauf: fest (Name towgemtd)
## Modi: gemtd
## GemTD: alle Gems (jede Qualität) und Spezial-Tower (jede Stufe) einzeln, Schaden und alle Fähigkeiten
## (tests/lib/tower_probe.gd). Start: tools/tower_pruefen.sh gemtd


func _start_game() -> void:
	mode = "gemtd"
	Session.game_kind = "gemtd"
	Session.map_path = Database.first_map().path
	Session.map_override = null
	Session.skip_setup = true
	game = load(Session.GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.lives = 1000000
	_ground_enemy = "greeny"
	_air_enemy = "bat"
	_helper_id = _plain_tower(Database.tower_ids())
	load("res://tests/towers_rg_test.gd")._pick_cells(game, self)


func _cases() -> Array:
	return _tier_cases(Database.tower_ids().filter(func(id): return str(Database.towers[id].get("category", "")) in ["gem", "special"]))
