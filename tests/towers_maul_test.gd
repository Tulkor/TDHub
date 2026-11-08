extends "res://tests/lib/tower_probe.gd"
## Lauf: fest (Name towmaul)
## Modi: shoppingmaul
## Shopping Maul: jeder Tower aller Filialen einzeln, Schaden und alle Fähigkeiten (tests/lib/tower_probe.gd).
## Start: tools/tower_pruefen.sh maul


func _start_game() -> void:
	mode = "maul"
	Profile.dir = "user://test_maul_profil"
	game = load(Session.MAUL).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.start_game("hm", 1, "group", true)
	game.lives = 1000000
	_helper_id = ""
	var spots: Array = _spots(game.map.zones[0].rect)
	for a in spots:
		if game.build_problem("o000", a, 0) == "":
			_anchor = a
			break
	_trap_cell = _anchor


func _spots(zone: Rect2i) -> Array:
	var list := []
	for y in range(zone.position.y + 1, zone.end.y - 2, 4):
		for x in range(zone.position.x + 1, zone.end.x - 2, 4):
			list.append(Vector2i(x, y))
	var mid := Vector2(zone.get_center())
	list.sort_custom(func(a, b): return Vector2(a).distance_to(mid) < Vector2(b).distance_to(mid))
	return list


func _cases() -> Array:
	var ids: Array = MaulData.towers().keys()
	ids.sort()
	return ids.filter(func(id): return only.is_empty() or only.has(id)).map(func(id): return [id, 0])


func _new_tower_base() -> String:
	return "res://scripts/maul/maul_tower.gd"


func _stats(id: String, _tier: int) -> Dictionary:
	return MaulData.tower(id)


func _is_trap(_id: String) -> bool:
	return false


func _wave_running() -> void:
	game.phase = MaulGame.Phase.WAVE
	game.spawn_queue = []
	game.level = 10


func _set_wave(n: int) -> void:
	game.level = n


func _gold() -> int:
	return int(game.players[0].gold)


## Gärtnerei: Wasser voll, damit sie schießt.
func _prepare(t: Node) -> void:
	var p: Dictionary = t.plant()
	if not p.is_empty():
		t.water = float(p.water)


func _needs(t: Node, abilities: Array) -> Array:
	var out := super._needs(t, abilities)
	if not t.plant().is_empty():
		out.append("damage")
	return out


func _spawn(flying: bool, p: Vector2) -> Node:
	var e := MaulEnemy.new()
	e.net_id = game._next_enemy_id
	game._next_enemy_id += 1
	var def := {"id": str(game.level_def(3).get("unit", "")), "flying": flying, "boss": false, "color": "#ff0000"}
	var o := {"hp": 100.0, "speed": 2.0, "armor": 0.0, "bounty": 1.0, "armor_type": "medium", "size": 1.0}
	e.route = str(game.map.maul.routes.keys()[0])
	e.chose = true
	game.board.add_child(e)
	e.setup(game, def, o, PackedVector2Array([p, p + Vector2(500, 0)]))
	game.enemies.append(e)
	return e
