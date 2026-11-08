extends "res://tests/lib/tower_probe.gd"
## Lauf: fest (Name toweeve)
## Modi: eevetd
## eeveTD: jeder Tower und jede Falle einzeln, Schaden und alle Fähigkeiten (tests/lib/tower_probe.gd).
## Start: tools/tower_pruefen.sh eeve


func _start_game() -> void:
	mode = "eeve"
	Session.map_path = "res://data/maps/eeve.json"
	Session.map_override = null
	Session.skip_setup = true
	game = load(Session.EEVE_GAME).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.lives = 1000000
	_ground_enemy = EeveWaves.enemy_for(3, "ground")
	_air_enemy = EeveWaves.enemy_for(3, "air")
	_helper_id = _plain_tower(_ids())
	_pick_cells()


func _ids() -> Array:
	return Database.tower_ids().filter(func(id): return str(Database.towers[id].get("category", "")) == "eeve")


func _cases() -> Array:
	return _tier_cases(_ids())


func _missing(id: String) -> Array:
	return Database.towers[id].eeve.get("todo", [])


func _new_tower_base() -> String:
	return "res://scripts/game/eeve_tower.gd"


func _pick_cells() -> void:
	var path: PackedVector2Array = game.lane_paths[0].ground
	var mid: Vector2 = path[path.size() / 2]
	var c0 := Vector2i(mid / Board3D.CELL)
	_trap_cell = c0 - Vector2i(1, 1)
	for r in range(2, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var a := c0 + Vector2i(dx, dy)
				if game.can_place(a) and game.can_place(a - Vector2i(2, 0)):
					_anchor = a
					_helper_cell = a - Vector2i(2, 0)
					return
