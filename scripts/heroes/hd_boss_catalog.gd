class_name HdBossCatalog
extends RefCounted
## Ein Datenkatalog für alle Endgegner, gemeinsame Basis mit gezielten Boss-Overrides.

const DATA := "res://data/heroes_bosse.json"


static func install(cfg: Dictionary) -> void:
	var data: Dictionary = Database.load_json(DATA)
	cfg.abilities.merge(data.get("abilities", {}).duplicate(true), true)
	for add in data.get("adds", []):
		cfg.enemies.append(SystemHost.cascade(data.add_defaults, add))
	for boss in data.get("bosses", []):
		cfg.enemies.append(SystemHost.cascade(data.defaults, boss))
	cfg.waves.final_bosses = data.get("final_bosses", []).duplicate()


static func resolve(game: Node) -> String:
	if str(game.final_boss_id) != "":
		return str(game.final_boss_id)
	if str(game.force_final_boss) != "" and game.enemy_defs.has(str(game.force_final_boss)) and str(game.enemy_defs[str(game.force_final_boss)].get("rank", "")) == "boss":
		game.final_boss_id = str(game.force_final_boss)
	else:
		var pool: Array = game.cfg.waves.get("final_bosses", [])
		game.final_boss_id = str(pool[game.rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else "verschlinger"
	return str(game.final_boss_id)


static func groups(game: Node, wave: int) -> Array:
	var result: Array = game.cfg.waves.list[wave - 1].groups.duplicate(true)
	if wave == int(game.cfg.waves.count):
		for group in result:
			if str(game.enemy_defs[str(group[0])].get("rank", "")) == "boss":
				group[0] = resolve(game)
	return result
