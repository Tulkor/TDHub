class_name HdReward
extends RefCounted
## Belohnungen aus Ereignissen und Endgebiet-Challenges (Daten data/heroes_ereignisse.json,
## data/heroes_endgebiet.json). Ein reward-Dictionary kann enthalten:
##   gold    Zahl oder [Basis, je Welle]        wood   Holz           xp   Zahl oder [Basis, je Welle]
##   item    Stufe → zufälliges Item ins Lager   lives  Feste-Leben    heal Anteil des Heldenlebens
##   repair  alle Torwerke heil/neu              perma  {Wert: +x} dauerhaft (game.perma)
##   buff    {stats, time} auf Zeit (game.event_buffs)   upgrade  Stufen auf ein Item am Helden
##   ally    {time, hp, damage} Söldner auf Zeit (HdAlly)


static func amount(game, v) -> int:
	if v is Array:
		return roundi(float(v[0]) + float(v[1]) * game.wave)
	return roundi(float(v))


## Belohnung geben, gibt die Kurzbeschreibung zurück („+120 Gold · +2 Holz“).
static func grant(game, r: Dictionary, where = null) -> String:
	var shop = game.shop
	var out: Array = []
	if r.has("gold"):
		var g := amount(game, r.gold)
		shop.add_gold(g)
		out.append(TranslationServer.translate("+%d Gold") % g)
	if r.has("wood"):
		shop.add_wood(int(r.wood))
		out.append(TranslationServer.translate("+%d Holz") % int(r.wood))
	if r.has("xp"):
		var x := amount(game, r.xp)
		game.hero.add_xp(float(x))
		out.append(TranslationServer.translate("+%d EP") % x)
	if r.has("lives"):
		game.lives = mini(game.max_lives, game.lives + int(r.lives))
		out.append(TranslationServer.translate("+%d Feste-Leben") % int(r.lives))
	if r.has("heal") and game.hero.alive():
		game.hero.heal(game.hero.max_hp * float(r.heal), true)
		out.append(TranslationServer.translate("Geheilt"))
	if bool(r.get("repair", false)):
		for rd in game.roads:
			for gt in rd.gates:
				if gt.destroyed:
					gt.rebuild(float(game.cfg.arena.repair.rebuild_hp))
				else:
					gt.hp = gt.max_hp
		out.append(TranslationServer.translate("Torwerke repariert"))
	if r.has("perma"):
		for k in r.perma:
			game.perma[k] = float(game.perma.get(k, 0.0)) + float(r.perma[k])
		out.append(HdShop.stat_text(r.perma) + " " + TranslationServer.translate("(dauerhaft)"))
	if r.has("buff"):
		game.add_event_buff(r.buff.get("name", ""), r.buff.stats, float(r.buff.time))
		out.append(TranslationServer.translate("%s für %d s") % [HdShop.stat_text(r.buff.stats), roundi(float(r.buff.time))])
	if r.has("item"):
		out.append(give_item(game, int(r.item)))
	if r.has("upgrade"):
		out.append(upgrade(game, int(r.upgrade)))
	if r.has("ally"):
		spawn_ally(game, r.ally, where if where != null else game.hero.position)
		out.append(TranslationServer.translate("Söldner für %d s") % roundi(float(r.ally.time)))
	shop._changed()
	return " · ".join(out)


## Zufälliges Item der Stufe ins Lager (voll → 4 Holz).
static func give_item(game, tier: int) -> String:
	var shop = game.shop
	var pool: Array = []
	for it in shop.cfg.items:
		if int(it.get("tier", 1)) == tier and not it.has("trophy") and not it.has("marks") and not it.has("use"):
			pool.append(str(it.id))
	if pool.is_empty() or shop.count_free("stash") <= 0:
		shop.add_wood(4)
		return TranslationServer.translate("Lager voll: +4 Holz")
	var id: String = pool[game.rng.randi() % pool.size()]
	shop.stash[shop._free("stash")] = {"id": id, "n": 1}
	return TranslationServer.translate("%s ins Lager") % TranslationServer.translate(str(shop.item(id).name))


## Ein zufälliges Item am Helden um n Stufen veredeln (höchstens +5).
static func upgrade(game, n: int) -> String:
	var shop = game.shop
	var can: Array = []
	for x in shop.inv:
		if x != null and int(x.get("up", 0)) < 5 and not shop.item(str(x.id)).has("use"):
			can.append(x)
	if can.is_empty():
		shop.add_wood(2)
		return TranslationServer.translate("Nichts zu veredeln: +2 Holz")
	var x: Dictionary = can[game.rng.randi() % can.size()]
	x.up = mini(5, int(x.get("up", 0)) + n)
	return TranslationServer.translate("%s jetzt +%d") % [TranslationServer.translate(str(shop.item(str(x.id)).name)), int(x.up)]


static func spawn_ally(game, d: Dictionary, at: Vector3) -> void:
	var a := HdAlly.new()
	var f = 1.0 + 0.06 * game.wave
	a.setup_ally(game, {"name": "Söldner", "hp": float(d.get("hp", 1200)) * f, "armor": 4, "radius": 0.6, "speed": 6.5,
		"range": float(d.get("range", 7.0)), "damage": float(d.get("damage", 35)) * f, "interval": 0.9}, "fighter", game.free_point(at + Vector3(2, 0, 2), 1.0))
	a.until_time = game.play_time + float(d.get("time", 120.0))
	game.add_child(a)
	game.buildings.append(a)


## Kurzer Text ohne zu geben (Vorschau in Karten).
static func text(game, r: Dictionary) -> String:
	var out: Array = []
	if r.has("gold"):
		out.append(TranslationServer.translate("+%d Gold") % amount(game, r.gold))
	if r.has("wood"):
		out.append(TranslationServer.translate("+%d Holz") % int(r.wood))
	if r.has("xp"):
		out.append(TranslationServer.translate("+%d EP") % amount(game, r.xp))
	if r.has("lives"):
		out.append(TranslationServer.translate("+%d Feste-Leben") % int(r.lives))
	if r.has("heal"):
		out.append(TranslationServer.translate("Heilung"))
	if bool(r.get("repair", false)):
		out.append(TranslationServer.translate("Torwerke repariert"))
	if r.has("perma"):
		out.append(HdShop.stat_text(r.perma) + " " + TranslationServer.translate("(dauerhaft)"))
	if r.has("buff"):
		out.append(TranslationServer.translate("%s für %d s") % [HdShop.stat_text(r.buff.stats), roundi(float(r.buff.time))])
	if r.has("item"):
		out.append(TranslationServer.translate("Item Stufe %d") % int(r.item))
	if r.has("upgrade"):
		out.append(TranslationServer.translate("Item veredeln +%d") % int(r.upgrade))
	if r.has("ally"):
		out.append(TranslationServer.translate("Söldner für %d s") % roundi(float(r.ally.time)))
	return " · ".join(out)
