extends RefCounted
## Itemzustand gehört zum Helden, nicht zum Inventarplatz. Der Host löst alle Effekte aus.


static func shop_for(hero):
	var shop = hero.game.shop
	if hero.game.coop:
		shop = hero.game.coop.slots.get(hero.game.hero_slot(hero), {}).get("shop", shop)
	return shop


static func has_scepter(hero) -> bool:
	var shop = shop_for(hero)
	if shop == null:
		return false
	for entry in shop.inv:
		if entry != null and bool(shop.item(str(entry.id)).get("scepter", false)):
			return true
	return false


static func passive_scripts(hero) -> Array:
	var result: Array = []
	if not str(hero.def.get("effect_script", "")).is_empty():
		result.append(str(hero.def.effect_script))
	var shop = shop_for(hero)
	if shop == null:
		return result
	var groups := {}
	for entry in shop.inv:
		if entry == null:
			continue
		var item: Dictionary = shop.item(str(entry.id))
		if str(item.get("effect_script", "")).is_empty():
			continue
		var group := str(item.get("effect_group", item.id))
		if not groups.has(group) or int(item.tier) > int(groups[group].tier) or (int(item.tier) == int(groups[group].tier) and float(item.get("effect_priority", 0)) > float(groups[group].get("effect_priority", 0))):
			groups[group] = item
	for item in groups.values():
		result.append(str(item.effect_script))
	return result


static func mastery_values(hero, rating: float) -> Dictionary:
	var result := {}
	var profile: Dictionary = hero.def.get("mastery", {})
	# 100 Wertung ist die Obergrenze; Schaden/Heilung/Schilde wachsen mit der Heldenkraft.
	for key in profile.get("scales", {}):
		var value := minf(maxf(rating, 0), 100) * float(profile.scales[key])
		if key in ["damage", "heal", "shield"]:
			value *= hero.power()
		result[key] = value
	return result


static func mastery_script(hero, rating: float) -> String:
	var text := str(hero.def.get("mastery", {}).get("effect", ""))
	var values := mastery_values(hero, rating)
	for key in values:
		text = text.replace("{" + str(key) + "}", String.num(float(values[key]), 4))
	return text


static func mastery_text(hero, rating := -1.0) -> String:
	var profile: Dictionary = hero.def.get("mastery", {})
	if profile.is_empty():
		return ""
	if rating < 0:
		rating = hero.b("mastery")
	var description := TranslationServer.translate(str(profile.desc))
	var values := mastery_values(hero, rating)
	for key in values:
		var percent: bool = key in ["slow", "haste", "speed", "reduction"]
		var number := String.num(float(values[key]) * (100 if percent else 1), 1)
		description = description.replace("{" + str(key) + "}", number)
	return TranslationServer.translate("Meisterschaft: %s · %d Wertung (max. 100)") % [TranslationServer.translate(str(profile.name)), roundi(rating)] + "\n" + description


static func mastery_event(hero, target, event: String) -> void:
	var profile: Dictionary = hero.def.get("mastery", {})
	if profile.is_empty() or event != str(profile.event) or hero.b("mastery") <= 0:
		return
	if not hero.alive() or hero.game.play_time < hero.mastery_ready:
		return
	hero.mastery_ready = hero.game.play_time + float(profile.cooldown)
	hero.set_meta("item_effect_scope", "mastery:" + str(hero.def.id))
	var errors := EffectScript.trigger(hero, target, "hit", 0, [mastery_script(hero, hero.b("mastery"))])
	EffectScript.report_errors(hero, errors)
	hero.remove_meta("item_effect_scope")


static func upgrade_skill(hero, skill: Dictionary, slot: int) -> void:
	if not has_scepter(hero):
		return
	var upgrade: Dictionary = hero.def.get("scepter", {})
	if upgrade.is_empty() or int(upgrade.slot) != slot:
		return
	for key in upgrade.get("set", {}):
		skill[key] = upgrade.set[key]
	for key in upgrade.get("add", {}):
		var path := str(key).split(".")
		var target: Dictionary = skill
		for i in path.size() - 1:
			if not target.get(path[i]) is Dictionary:
				target[path[i]] = {}
			target = target[path[i]]
		target[path[-1]] = float(target.get(path[-1], 0)) + float(upgrade.add[key])


static func after_cast(hero, slot: int) -> void:
	if not has_scepter(hero):
		return
	var upgrade: Dictionary = hero.def.get("scepter", {})
	if upgrade.is_empty() or int(upgrade.slot) != slot or str(upgrade.get("effect", "")) == "":
		return
	# Dasselbe Rekursionsverbot wie bei passiven Items: kein Proc erzeugt weitere Procs.
	hero.set_meta("item_effect_busy", true)
	hero.set_meta("item_effect_scope", "scepter:" + str(hero.def.id))
	var errors := EffectScript.trigger(hero, hero, "hit", 0, [str(upgrade.effect)])
	EffectScript.report_errors(hero, errors)
	hero.remove_meta("item_effect_scope")
	hero.set_meta("item_effect_busy", false)


static func active_left(hero, item: Dictionary) -> float:
	var active: Dictionary = item.get("active", {})
	return maxf(0, float(hero.item_ready.get(str(active.get("group", item.get("id", ""))), 0)) - hero.game.play_time)


static func activate(hero, item: Dictionary) -> String:
	var game = hero.game
	if game.coop and not game.coop.host:
		return TranslationServer.translate("Nur der Host löst Itemeffekte aus")
	if not hero.alive():
		return TranslationServer.translate("Der Held ist gefallen")
	if game.paused or hero.dodging() or hero.cc.stunned(game.play_time):
		return TranslationServer.translate("Jetzt nicht einsetzbar")
	var active: Dictionary = item.active
	var left := active_left(hero, item)
	if left > 0:
		return TranslationServer.translate("Item-Abklingzeit: %d s") % ceili(left)
	var distance := float(active.get("distance", 0))
	if distance > 0 and game.play_time < float(hero.get_meta("root_until", -1)):
		return TranslationServer.translate("Bewegung ist verwurzelt")
	if distance > 0:
		var start: Vector3 = hero.position
		var direction: Vector3 = hero.facing.normalized()
		for k in ceili(distance / .25):
			game.move_unit(hero, direction, 1, minf(.25, distance - k * .25), true)
		if start.distance_to(hero.position) < .05:
			return TranslationServer.translate("Weg blockiert")
		game.fx.dash_trail(start, hero.position - start)
	if bool(active.get("cleanse", false)):
		hero.cc._slows.clear()
		hero.set_meta("root_until", -1.0)
	hero.item_ready[str(active.get("group", item.id))] = game.play_time + float(active.cooldown)
	if str(active.get("effect", "")) != "":
		hero.set_meta("item_effect_busy", true)
		hero.set_meta("item_effect_scope", "active:" + str(active.get("group", item.id)))
		var errors := EffectScript.trigger(hero, hero, "hit", 0, [str(active.effect)])
		EffectScript.report_errors(hero, errors)
		hero.remove_meta("item_effect_scope")
		hero.set_meta("item_effect_busy", false)
	return ""
