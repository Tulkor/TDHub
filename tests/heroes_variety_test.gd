extends Node
## Lauf: einzeln (Name heroesvariety)
## Modi: heroes
## Alle Rezeptketten wirklich schmieden/verkaufen; Gegnerfähigkeiten vollständig ausführen.

var checks := 0
var failures := 0
const ICONS = preload("res://scripts/heroes/hd_item_icons.gd")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func recipe_valid(id: String, items: Dictionary, ancestors: Array) -> bool:
	if id in ancestors or not items.has(id):
		return false
	var next := ancestors.duplicate()
	next.append(id)
	for part in items[id].get("recipe", []):
		if not recipe_valid(str(part), items, next):
			return false
	return true


func craft_tree(shop: HdShop, id: String) -> void:
	for part in shop.item(id).get("recipe", []):
		craft_tree(shop, str(part))
	if shop.item(id).has("recipe"):
		check(shop.craft(id, false) == "", "Rezept mit echten Teilen: " + id)
	else:
		check(shop.buy(id) == "", "Bauteil kaufen: " + id)


func _ready() -> void:
	Sfx.audible = false
	Session.skip_setup = true
	Session.coop = {}
	Session.difficulty = 0
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.bot = true
	g.persist_settings = false
	g.force_hero = "torvik"
	add_child(g)
	await get_tree().process_frame
	g.set_process(false)
	g.set_physics_process(false)
	g.hud.set_process(false)
	g.spawn_queue.clear()
	for e in g.enemies:
		g._remove(e)
	g.enemies.clear()
	var english: Dictionary = Database.load_json(Loc.SOURCE)
	var shop: HdShop = g.shop
	g.perma.clear()
	g.blessing.clear()
	g.event_buffs.clear()
	shop.wood_bought.clear()
	var base_bonus := shop.bonus()
	g.hero.set_bonus(base_bonus)
	var base_power := g.hero.power()
	var base_hp := g.hero.max_hp
	for id in shop.items:
		var it: Dictionary = shop.item(id)
		check(recipe_valid(id, shop.items, []), "Rezept erreichbar und ohne Zyklus: " + id)
		check(ICONS.texture(id) != null, "Item hat ladbares Symbol: " + id)
		for key in ["name", "desc"]:
			check(english.has(str(it.get(key, ""))), "Item übersetzt: %s.%s" % [id, key])
		if not it.has("recipe"):
			continue
		shop.inv.fill(null)
		shop.stash.fill(null)
		shop.gold = 1000000
		g.hero.position = g.hero_spawn()
		g.hero.set_bonus(shop.bonus())
		var before := shop.gold
		craft_tree(shop, id)
		check(before - shop.gold == shop.total_cost(id), "Rezeptbaum berechnet jeden Goldpreis: " + id)
		check(shop.owned_count(id) == 1 and shop.count_free("hero") == shop.inv.size() - 1 and shop.count_free("stash") == shop.stash.size(), "Rezept verbraucht sämtliche Teile: " + id)
		var expected := base_bonus.duplicate()
		for stat in it.stats:
			expected[stat] = float(expected.get(stat, 0)) + float(it.stats[stat])
		check(shop.bonus() == expected, "Nur Endprodukt gibt Werte: " + id)
		var slot := -1
		for i in shop.inv.size():
			if shop.inv[i] != null:
				slot = i
		if slot >= 0:
			var entry: Dictionary = shop.inv[slot]
			entry.up = 1
			check(shop.tooltip(id, entry).contains(tr(str(it.desc))), "Veredelung erhält Rollenbeschreibung: " + id)
			check(shop.sell("hero", slot) == "", "Verkauf: " + id)
			check(shop.bonus() == base_bonus and is_equal_approx(g.hero.power(), base_power) and is_equal_approx(g.hero.max_hp, base_hp), "Verkauf entfernt Itemwerte: " + id)
	# Fernschmieden und gemischte Bauteilorte laufen über dieselben neuen Rezepte.
	shop.inv.fill(null)
	shop.stash.fill(null)
	g.hero.position = g.roads[0].point(30)
	shop.gold = 100000
	check(shop.craft("himmelsarchiv", true) == "" and shop.stash[0].id == "himmelsarchiv", "Legendäres Fernrezept landet im Lager")
	check(shop.bonus() == base_bonus, "Lageritem verstärkt den Helden nicht")
	g.hero.position = g.hero_spawn()
	check(shop.move("stash", 0, "hero", 0) == "" and g.hero.b("mana") == 900, "Zauber-Endprodukt gibt Mana erst nach Abholung")
	shop.inv.fill(null)
	shop.stash.fill(null)
	g.hero.set_bonus(shop.bonus())
	var used := {}
	for id in g.enemy_defs:
		var definition: Dictionary = g.enemy_defs[id]
		for key in ["role", "hint"]:
			check(english.has(str(definition.get(key, ""))), "Gegner hat übersetzte Rolle/Konter: %s.%s" % [id, key])
		if str(definition.rank) == "boss":
			continue  # Bossrotationen separat in heroesboss.
		var enemy: HdEnemy = g.spawn(id, g.hero_spawn() + Vector3(0, 0, -5))
		for aid in definition.get("abilities", []):
			if used.has(aid):
				continue
			used[aid] = true
			g.hero.hp = g.hero.max_hp
			g.hero.dead = false
			enemy.target = g.hero
			enemy.start_cast(str(aid), g.play_time)
			check(enemy.casting() and not enemy.cast.tele.is_empty(), "Fähigkeit erzeugt Warnfläche: " + str(aid))
			var ticks := 0
			while enemy.casting() and ticks < 600:
				g.play_time += 1.0 / 30.0
				enemy._step_cast(1.0 / 30.0, g.play_time)
				ticks += 1
			check(not enemy.casting(), "Alle Phasen der Fähigkeit enden: " + str(aid))
			enemy.cancel_cast(true)
		g._remove(enemy)
		g.enemies.erase(enemy)
	check(used.size() >= 40, "Unterschiedliche Spezialistenmuster werden ausgeführt")
	g.set_paused(true)
	g.hud.show_bestiary()
	await get_tree().process_frame
	check(g.hud._overlay != null and g.paused, "Gegnerkunde öffnet während Pause")
	if "--bilder" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://export/screens")
		get_viewport().get_texture().get_image().save_png("res://export/screens/bollwerk-gegnerkunde.png")
	for faction in ["sumpf", "knochen", "glut", "leere", "zone"]:
		g.hud.show_bestiary(faction)
		await get_tree().process_frame
		check(g.hud._overlay != null and g.paused, "Gegnerkunde filtert: " + faction)
	g.hud._close_overlay()
	g.queue_free()
	await get_tree().process_frame
	print("FERTIG heroesvariety: %d Prüfungen, Fehler: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
