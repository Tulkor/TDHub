extends "res://tests/lib/tower_probe.gd"
## Lauf: fest (Name towrg)
## Modi: randgruppen
## Randgruppen TD: jeder Tower aller Rassen einzeln, Schaden und alle Fähigkeiten (tests/lib/tower_probe.gd).
## Start: tools/tower_pruefen.sh rg


func _start_game() -> void:
	mode = "rg"
	Session.game_kind = "randgruppen"
	Session.map_path = "res://data/maps/randgruppen.json"
	Session.map_override = null
	Session.skip_setup = false
	Session.rg_choice = {}
	game = load("res://scenes/rg_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.submit({"type": "setup", "race": "kleingarten", "difficulty": 0})
	await get_tree().process_frame
	game.lives = 1000000
	var levels: Array = Database.randgruppen.levels
	_ground_enemy = str(levels.filter(func(lv): return not Database.enemies[str(lv.enemy)].get("flying", false))[0].enemy)
	_air_enemy = str(levels.filter(func(lv): return Database.enemies[str(lv.enemy)].get("flying", false))[0].enemy)
	game.foreign_build = true
	_helper_id = _plain_tower(_cases().map(func(c): return c[0]))
	_pick_cells(game, self)


func _cases() -> Array:
	return _tier_cases(Database.tower_ids().filter(func(id): return str(Database.towers[id].get("category", "")) == "randgruppen"))


## Bauplatz nahe der Mitte von Bahn 0 mit freiem Platz links daneben für den Helfer (auch von GemTD genutzt).
static func _pick_cells(g: Node, probe: Node) -> void:
	var path: PackedVector2Array = g.lane_paths[0].ground
	var c0 := Vector2i(path[path.size() / 2] / Board3D.CELL)
	probe._trap_cell = c0
	for r in range(2, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var a := c0 + Vector2i(dx, dy)
				if g.can_place(a) and g.can_place(a - Vector2i(2, 0)):
					probe._anchor = a
					probe._helper_cell = a - Vector2i(2, 0)
					return
	probe.check(false, "kein Bauplatz gefunden")
