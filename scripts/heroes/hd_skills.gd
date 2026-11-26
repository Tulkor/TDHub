class_name HdSkills
extends RefCounted
## Rangwerte, Tags und bedingte Powerups. Alle Ausführungen und Tooltip-Vergleiche lesen dieselbe Kopie.

const DATA := "res://data/heroes_progression.json"
var hero: HdHero
var cfg: Dictionary
var ranks: Array[int] = [1, 1, 1, 1]
var points := 0
var modifiers: Array = []
var _cache := {}
var _cache_key := 0


func _init(owner_hero: HdHero) -> void:
	hero = owner_hero
	cfg = Database.load_json(DATA)


func can_upgrade(slot: int) -> bool:
	return slot >= 0 and slot < 4 and points > 0 and ranks[slot] < int(cfg.max_rank) and hero.unlocked(slot)


func upgrade(slot: int) -> bool:
	if hero.game.coop and not hero.game.coop.host:
		hero.game.coop.command({"kind":"skill", "slot":slot})
		return true
	if not can_upgrade(slot):
		return false
	ranks[slot] += 1
	points -= 1
	refresh_constructs()
	hero.game.changed.emit()
	return true


## Tags werden ALLE verlangt: [projectile, lightning] verstärkt nur Blitzprojektile.
func add_modifier(id: String, tags: Array, mods: Dictionary) -> void:
	modifiers = modifiers.filter(func(m): return str(m.id) != id)
	modifiers.append({"id": id, "tags": tags.duplicate(), "mods": mods.duplicate(true)})
	refresh_constructs()


func refresh_constructs() -> void:
	if hero is HdHeroRoster:
		for p in hero.servants:
			if not is_instance_valid(p) or not p.alive():
				continue
			var source := hero.ability(int(p.def.source_slot))
			var ratio: float = p.hp / maxf(p.max_hp, 1)
			p.def.damage = float(source.get("damage", 30)) * hero.power()
			p.max_hp = float(source.get("hp", 350))
			p.hp = p.max_hp * ratio
		return
	if not hero is HdHeroZix:
		return
	for gadget in hero.gadgets:
		if not is_instance_valid(gadget) or gadget.destroyed:
			continue
		for slot in 3:
			var a := hero.ability(slot)
			if str(a.gadget) != gadget.kind:
				continue
			var ratio: float = gadget.hp / maxf(gadget.max_hp, 1)
			gadget.def = a.gadget_stats
			gadget.max_hp = float(gadget.def.hp) * (1.0 + 0.1 * (hero.level - 1))
			gadget.hp = gadget.max_hp * ratio


func resolve(source: Dictionary, slot: int, extra_rank := 0) -> Dictionary:
	var signature := hash([ranks, modifiers, hero.game.imprints, hero.game.zix_kit, hero.ITEM_EFFECTS.has_scepter(hero)])
	if signature != _cache_key:
		_cache.clear()
		_cache_key = signature
	var key := str(slot) + ":" + str(extra_rank) + ":" + str(hash(source))
	if _cache.has(key):
		return _cache[key]
	var out := source.duplicate(true)
	var steps := ranks[slot] - 1 + extra_rank
	var factors := {}
	for stat in cfg.per_rank:
		factors[stat] = maxf(0.4, 1.0 + float(cfg.per_rank[stat]) * steps)
	factors.protection = factors.get("damage", 1.0)
	for m in modifiers + hero.own_imprints():
		if (m.tags as Array).all(func(t): return (out.get("tags", []) as Array).has(t)):
			for stat in m.mods:
				factors[stat] = maxf(0.3, float(factors.get(stat, 1.0)) + float(m.mods[stat]))
				if stat == "damage" and not m.has("hero"):
					factors.protection += float(m.mods[stat])
	_scale(out, factors)
	for imprint in hero.own_imprints():
		for change in imprint.get("skill_changes", []):
			if int(change.slot) == slot:
				var path := str(change.field).split(".")
				var target: Dictionary = out
				for k in path.size() - 1:
					if not target.get(path[k]) is Dictionary:
						target[path[k]] = {}
					target = target[path[k]]
				var field := str(path[-1])
				target[field] = float(target.get(field, 0)) + float(change.add)
	hero.ITEM_EFFECTS.upgrade_skill(hero, out, slot)
	_cache[key] = out
	return out


func _scale(data: Dictionary, factors: Dictionary, nested := false) -> void:
	for key in data.keys():
		var value = data[key]
		if value is Dictionary:
			_scale(value, factors, true)
			continue
		var group := ""
		if key in ["heal", "end_heal", "shield", "dmg_in", "reflect"] and factors.has("protection"):
			group = "protection"
		elif key in cfg.damage_fields:
			group = "damage"
		elif key in cfg.duration_fields:
			group = "duration"
		elif key in cfg.range_fields and not (nested and key == "radius"):
			group = "range"
		elif key in ["cooldown", "interval"]:
			group = "cooldown"
		if group == "":
			continue
		var factor := float(factors.get(group, 1.0))
		if value is Array:
			data[key] = value.map(func(v): return float(v) * factor)
		elif typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			data[key] = float(value) * factor


func tag_text(a: Dictionary) -> String:
	var names := PackedStringArray()
	for tag in a.get("tags", []):
		names.append(tr(str(cfg.tags.get(tag, tag))))
	return " · ".join(names)


func metrics(a: Dictionary) -> Dictionary:
	var result := {}
	for key in ["damage", "dps", "burn", "bite", "heal", "end_heal", "shield", "dmg_out", "dmg_in", "slow", "reflect", "range", "radius", "reach", "cooldown", "duration", "time", "stun", "burn_time", "slow_time", "shield_time", "attack_range", "mana"]:
		if not a.has(key):
			continue
		var value = a[key]
		var number := 0.0
		if value is Array:
			for n in value:
				number += float(n)
		else:
			number = float(value)
		if key in ["damage", "dps", "burn", "bite"]:
			number *= hero.power() * hero.out_mult()
		if key == "cooldown":
			number *= maxf(0.1, 1.0 - hero.b("cdr"))
		result[key] = number
	if a.has("plague"):
		result.plague_time = float(a.plague.time)
	if a.has("gadget_stats"):
		for key in ["damage", "reach", "interval", "hp"]:
			if a.gadget_stats.has(key):
				result[key] = float(a.gadget_stats[key])
				if key == "damage":
					result[key] *= hero.power() * hero.out_mult()
				if key == "hp":
					result[key] *= 1.0 + 0.1 * (hero.level - 1)
		if a.gadget_stats.has("heal"):
			result.gadget_heal = float(a.gadget_stats.heal) * hero.power() * hero.out_mult()
		if a.gadget_stats.has("burn"):
			result.burn = float(a.gadget_stats.burn) * hero.power() * hero.out_mult()
	return result


func tooltip(slot: int, upgrade_preview := false) -> String:
	var a := hero.ability(slot)
	var lines: Array[String] = [tr(str(a.name)) + " · " + tr("Rang %d") % ranks[slot], tag_text(a), tr(str(a.get("summary", a.get("desc", ""))))]
	var current := metrics(a)
	var scepter: Dictionary = hero.def.get("scepter", {})
	if not scepter.is_empty() and int(scepter.slot) == slot:
		lines.append(tr("Szepter: %s") % tr(str(scepter.desc)))
		if hero.ITEM_EFFECTS.has_scepter(hero):
			lines.append(tr("Szepter-Aufwertung aktiv"))
	var next := metrics(hero.ability_at_rank(slot, 1)) if upgrade_preview else {}
	for key in current:
		var value := _format(key, float(current[key]))
		if next.has(key) and not is_equal_approx(float(next[key]), float(current[key])):
			value += " → " + _format(key, float(next[key]))
		lines.append(stat_label(key) + ": " + value)
	if upgrade_preview:
		lines.append(tr("Kostet 1 Fähigkeitspunkt"))
	return "\n".join(lines)


## Übersetzte Bezeichnung eines Kennwerts (Tooltip, Rangtabelle).
func stat_label(key: String) -> String:
	var labels := {"damage":"Schaden", "dps":"Schaden/s", "burn":"Brandschaden/s", "bite":"Bissschaden/s", "heal":"Heilung", "end_heal":"Abschlussheilung", "shield":"Schild", "dmg_out":"Zusatzschaden", "dmg_in":"Schadensreduktion", "slow":"Verlangsamung", "reflect":"Reflexionschance", "range":"Reichweite", "radius":"Radius", "reach":"Gebäudereichweite", "cooldown":"Abklingzeit", "duration":"Dauer", "time":"Dauer", "stun":"Kontrolldauer", "burn_time":"Branddauer", "slow_time":"Verlangsamungsdauer", "shield_time":"Schilddauer", "plague_time":"Seuchendauer", "mana":"Mana", "interval":"Angriffsintervall", "hp":"Gebäudeleben"}
	labels.gadget_heal = "Heilung/s"
	labels.attack_range = "Angriffsreichweite"
	return tr(str(labels.get(key, key)))


## Werte einer Fähigkeit über alle Ränge (MOBA-Tooltip): [{key, label, values: [String], unit, varies}].
## Mana steht im Kopf des Tooltips und fehlt hier.
func rank_table(slot: int) -> Array:
	var top := int(cfg.max_rank)
	var rows := {}
	var order: Array = []
	for r in range(1, top + 1):
		var m := metrics(hero.ability_at_rank(slot, r - ranks[slot]))
		for key in m:
			if key == "mana":
				continue
			if not rows.has(key):
				rows[key] = []
				order.append(key)
			rows[key].append(float(m[key]))
	var out: Array = []
	for key in order:
		var values: Array = rows[key]
		if values.size() != top:
			continue
		var varies := false
		for v in values:
			if not is_equal_approx(float(v), float(values[0])):
				varies = true
		out.append({"key": key, "label": stat_label(key), "values": values.map(func(v): return _short(key, float(v))), "unit": _unit(key), "varies": varies})
	return out


func _unit(key: String) -> String:
	if key in ["heal", "end_heal", "shield", "dmg_out", "dmg_in", "slow", "reflect"]:
		return "%"
	if key in cfg.duration_fields or key in ["cooldown", "interval", "plague_time"]:
		return "s"
	if key in ["range", "radius", "reach", "attack_range"]:
		return "m"
	return ""


func _short(key: String, number: float) -> String:
	if _unit(key) == "%":
		return str(roundi(number * 100.0))
	if absf(number) >= 20.0:
		return str(roundi(number))
	return str(snappedf(number, 0.1 if absf(number) >= 2.0 else 0.01))


func _format(key: String, number: float) -> String:
	if key in ["heal", "end_heal", "shield", "dmg_out", "dmg_in", "slow", "reflect"]:
		return str(snappedf(number * 100, 0.1)) + " %"
	var seconds: bool = key in cfg.duration_fields or key in ["cooldown", "interval", "plague_time"]
	return str(snappedf(number, 0.01)) + (" s" if seconds else "")
