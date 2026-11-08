class_name EeveItems
extends RefCounted
## Items und Marktplatz in eeveTD (Vorbild: eeve! TD v1.01). Werte in data/eeve_items.json.
##
## Jeder Spieler hat ein Lager (ep().items) und Marktplatz-Stufen (ep().market). Items fallen von Gegnern
## (ab Level 11 vielleicht beim ersten Kill eines Levels, Golems immer zwei) oder kommen vom Marktplatz.
## Tower ab Elementstufe 3 haben Item-Plätze (EeveTower.items); Items zieht man wie in WC3 zwischen Lager und
## Towern hin und her, auf ein anderes Item gezogen tauschen sie (move, Lukas 2026-11-01). Verbrauchs-Items ("use") wirken einmal auf einen Tower.
## Der Marktplatz ist ein Gebäude (Barrikade aufwerten), einer je Spieler: dort kauft und verkauft man Items
## und kauft die Upgrades für Schaden, Reichweite und Tempo aller eigenen Tower.
## Alles, was den Stand ändert, läuft als Befehl über eeve_game.gd (_execute) und rechnet im Koop der Host.

var game  # eeve_game.gd


func _init(g) -> void:
	game = g


static func data() -> Dictionary:
	return Database.eeve_items


static func item(id: String) -> Dictionary:
	return data().get("items", {}).get(id, {})


static func item_name(id: String) -> String:
	return TranslationServer.translate(str(item(id).get("name", id)))


## Verbrauchs-Items wirken einmal (Tränke, Phiole, Holz), alle anderen setzt man in einen Tower.
static func is_consumable(id: String) -> bool:
	return item(id).has("use")


static func sell_price(id: String) -> int:
	return floori(float(item(id).get("value", 0)) * float(data().get("sell_ratio", 0.5)))


## Was ein Item bewirkt, als kurze Zeilen fürs Lager und die Tooltips.
static func effect_text(id: String) -> String:
	var it := item(id)
	var lines := []
	if it.has("damage"):
		lines.append(TranslationServer.translate("+%d Schaden") % int(it.damage))
	if it.has("speed"):
		lines.append(TranslationServer.translate("+%d %% Angriffstempo") % roundi(float(it.speed) * 100.0))
	for ab in it.get("abilities", []):
		lines.append(Abilities.describe(ab))
	match str(it.get("use", "")):
		"xp":
			lines.append(TranslationServer.translate("+%d Kills für einen Tower") % int(it.amount))
		"vial":
			lines.append(TranslationServer.translate("zieht %d Kills aus einem Tower und wird zum Erfahrungstrank") % int(it.amount))
		"slot":
			lines.append(TranslationServer.translate("+1 Item-Platz (höchstens %d)") % int(data().get("max_slots", 6)))
		"lumber":
			lines.append(TranslationServer.translate("+1 Holz"))
	return "\n".join(lines)


## Grund-Plätze nach Art des Towers: ab Elementstufe 3 einer, je Stufe einer mehr; Dual-Tower 2;
## Barrikaden, Fallen und der Marktplatz keine.
static func base_slots(t: Tower) -> int:
	var e: Dictionary = t.def.get("eeve", {})
	if t.is_trap() or e.get("barricade", false) or e.get("market", false):
		return 0
	var s: Dictionary = data().get("slots", {})
	if e.has("elements") or e.get("dual_base", false):
		return int(s.get("dual", 2))
	return maxi(int(e.get("level", 0)) - int(s.get("from_level", 3)) + 1, 0)


static func slots(t: Tower) -> int:
	if not t is EeveTower or base_slots(t) <= 0:
		return 0
	return mini(base_slots(t) + t.extra_slots, int(data().get("max_slots", 6)))


static func market_level(st: Dictionary, kind: String) -> int:
	return int(st.get("market", {}).get(kind, 0))


## Boni eines Towers für Tower.set_rogue(): Items im Tower und die Marktplatz-Stufen seines Besitzers.
## Den festen Zusatzschaden setzt die Funktion direkt am Tower.
func apply_to(t: Tower) -> void:
	if not t is EeveTower:
		return
	var st: Dictionary = game.ep(t.owner_player)
	var ups: Dictionary = data().get("market", {}).get("upgrades", {})
	var b := {"damage": 0.0, "speed": 0.0, "range": 0.0, "abilities": []}
	var flat := 0.0
	for id in t.items:
		var it := item(id)
		flat += float(it.get("damage", 0))
		b.speed += float(it.get("speed", 0.0))
		for ab in it.get("abilities", []):
			var a: Dictionary = ab.duplicate()
			if it.has("color"):
				a.color = it.color
			b.abilities.append(a)
	if t.can_attack():
		b.damage += market_level(st, "damage") * float(ups.get("damage", {}).get("per_level", 0.0))
		b.speed += market_level(st, "speed") * float(ups.get("speed", {}).get("per_level", 0.0))
		var base_range := float(t.stats.get("range", 0.0))
		if base_range > 0.0:
			b.range = market_level(st, "range") * float(ups.get("range", {}).get("per_level", 0.0)) / base_range
	t.flat_damage = flat
	t.bonus_label = "Items und Marktplatz"
	if b.damage > 0.0 or b.speed > 0.0 or b.range > 0.0 or not b.abilities.is_empty():
		t.set_rogue(b)


func has_market(p: int) -> bool:
	return game.all_towers().any(func(t): return t.owner_player == p and t.def.get("eeve", {}).get("market", false))


func inventory(p: int) -> Array:
	return game.ep(p).items


## Item ins Lager von Spieler p. Holz zählt sofort, bei vollem Lager wird das Item zum halben Wert verkauft.
func give(p: int, id: String, why := "") -> void:
	if item(id).is_empty():
		return
	var st: Dictionary = game.ep(p)
	var pre := why + ": " if why != "" else ""
	if str(item(id).get("use", "")) == "lumber":
		st.lumber += 1
		game._note(pre + TranslationServer.translate("+1 Holz"), p)
		return
	if st.items.size() >= int(data().get("inventory_size", 8)):
		game.add_gold(sell_price(id), p)
		game._note(pre + TranslationServer.translate("%s verkauft (Lager voll, +%d Gold)") % [item_name(id), sell_price(id)], p)
		return
	st.items.append(id)
	game._note(pre + TranslationServer.translate("%s ins Lager") % item_name(id), p)


# --- Drops ----------------------------------------------------------------------------

## Gegnerstufe wie im Original: min(Level / 5,5 + 1, 10) - 1.
static func stage_for(level: int) -> int:
	return mini(int(level / 5.5) + 1, 10) - 1


static func pool(i: int) -> Array:
	var pools: Array = data().get("drops", {}).get("pools", [])
	return pools[clampi(i, 0, pools.size() - 1)] if not pools.is_empty() else []


static func _pick(list: Array, r: RandomNumberGenerator) -> String:
	return "" if list.is_empty() else str(list[r.randi() % list.size()])


## Zu Beginn eines Levels: würfeln, ob der erste Kill dieses Spielers ein Item bringt ("" = keins).
static func roll_level_drop(level: int, r: RandomNumberGenerator) -> String:
	var d: Dictionary = data().get("drops", {})
	var s := stage_for(level)
	if s < int(d.get("from_stage", 2)):
		return ""
	var roll := r.randi() % 100
	if roll < int(d.get("item_base", 25)) + int(d.get("item_step", 3)) * s:
		return _pick(pool(s / 2), r)
	if roll < int(d.get("consumable_base", 40)) + int(d.get("consumable_step", 4)) * s:
		return _pick(pool(0), r)
	return ""


## Golem besiegt: ein Verbrauchs-Item und ein Item aus Pool min(Stufe / 2 + 1, 4).
static func roll_challenge(level: int, r: RandomNumberGenerator) -> Array:
	var tier := mini((stage_for(level) + 1) / 2 + 1, 4)
	return [_pick(pool(0), r), _pick(pool(tier), r)].filter(func(id): return id != "")


func on_level_start(level: int) -> void:
	for p in game.players.size():
		game.ep(p).drop = roll_level_drop(level, game.rng)


func on_kill(e: Enemy) -> void:
	var p: int = e.last_hit_by
	if p < 0 or p >= game.players.size():
		return
	var def: Dictionary = Database.enemies.get(e.enemy_id, {})
	var level: int = game.wave_index + 1
	if str(def.get("eeve", {}).get("kind", "")) == "challenge":
		# Wie im Original nur die Golems bis Level 44, nicht die Challenges am Ende
		if level < 55:
			for id in roll_challenge(level, game.rng):
				give(p, id, TranslationServer.translate("Golem besiegt"))
		return
	var st: Dictionary = game.ep(p)
	var id := str(st.get("drop", ""))
	if id != "":
		st.drop = ""
		give(p, id, TranslationServer.translate("Fund"))


# --- Befehle (eeve_game.gd → _execute, acting = handelnder Spieler) -----------------------

## Warum Item index aus dem Lager nicht auf Tower t geht ("" = geht).
func use_reason(index: int, t: Tower) -> String:
	var inv := inventory(game.acting)
	if index < 0 or index >= inv.size():
		return TranslationServer.translate("kein Item gewählt")
	if t == null or not is_instance_valid(t) or not t is EeveTower or t.owner_player != game.acting:
		return TranslationServer.translate("eigenen Tower wählen")
	var id: String = inv[index]
	match str(item(id).get("use", "")):
		"":
			if slots(t) <= 0:
				return TranslationServer.translate("Tower hat keine Item-Plätze (ab Elementstufe 3)")
			if t.items.size() >= slots(t):
				return TranslationServer.translate("alle Item-Plätze belegt")
		"vial":
			if t.kills <= 0:
				return TranslationServer.translate("Tower hat noch keine Kills")
		"slot":
			if slots(t) <= 0:
				return TranslationServer.translate("nur für Tower mit Item-Plätzen")
			if slots(t) >= int(data().get("max_slots", 6)):
				return TranslationServer.translate("Tower hat schon %d Item-Plätze") % int(data().get("max_slots", 6))
		"xp":
			if not t.can_attack():
				return TranslationServer.translate("Tower greift nicht an")
	return ""


func use(index: int, t: Tower) -> bool:
	if use_reason(index, t) != "":
		return false
	var inv := inventory(game.acting)
	var id: String = inv[index]
	var it := item(id)
	match str(it.get("use", "")):
		"":
			t.items.append(id)
			inv.remove_at(index)
		"xp":
			# So viel Erfahrung wie die Kills (EP je Kill aus data/leveling.json, mit Marmor und Auren)
			t.kills += int(it.get("amount", 10))
			t.gain_ep(int(it.get("amount", 10)) * Leveling.kill_ep(t.level_profile(), null))
			inv.remove_at(index)
		"vial":
			var n := mini(int(it.get("amount", 10)), t.kills)
			t.kills -= n
			t.set_ep(t.ep - minf(int(it.get("amount", 10)) * Leveling.kill_ep(t.level_profile(), null) * t.xp_factor, t.ep))
			inv[index] = str(it.get("becomes", "xp_potion"))
		"slot":
			t.extra_slots += 1
			inv.remove_at(index)
		"lumber":
			game.lumber += 1
			inv.remove_at(index)
	game._update_auras()
	return true


## Ort im Inventar: {"stash": i} (i ab Lagergröße = freies Feld) oder {"tower": ref, "slot": k} (k über den belegten
## Plätzen oder -1 = freier Platz). Ergebnis {list, index, tower, id} oder {} wenn ungültig.
func _place(loc: Dictionary) -> Dictionary:
	if loc.has("stash"):
		var inv := inventory(game.acting)
		var i := int(loc.stash)
		if i < 0 or i >= int(data().get("inventory_size", 8)):
			return {}
		return {"list": inv, "index": i, "tower": null, "id": inv[i] if i < inv.size() else ""}
	var t: Tower = game.tower_from_ref(loc.get("tower", {}))
	if t == null or not t is EeveTower or t.owner_player != game.acting:
		return {}
	var k := int(loc.get("slot", -1))
	if k >= 0 and k >= slots(t):
		return {}
	return {"list": t.items, "index": k, "tower": t, "id": t.items[k] if k >= 0 and k < t.items.size() else ""}


## Warum das Item an from nicht nach to geht ("" = geht). Verbrauchs-Items wirken auf den Tower (use_reason).
func move_reason(from: Dictionary, to: Dictionary) -> String:
	var a := _place(from)
	var b := _place(to)
	if a.is_empty() or a.id == "":
		return TranslationServer.translate("kein Item gewählt")
	if b.is_empty():
		return TranslationServer.translate("eigenen Tower wählen") if to.has("tower") else TranslationServer.translate("kein Platz")
	if a.list == b.list and a.index == b.index:
		return TranslationServer.translate("liegt schon dort")
	if b.tower != null and is_consumable(a.id):
		return use_reason(a.index, b.tower) if a.tower == null else TranslationServer.translate("kein Platz")
	if b.tower != null and slots(b.tower) <= 0:
		return TranslationServer.translate("Tower hat keine Item-Plätze (ab Elementstufe 3)")
	if b.id != "":
		# Tausch: das andere Item muss an den alten Platz passen (Verbrauchs-Items nicht in Tower)
		return TranslationServer.translate("Verbrauchs-Items können nicht in einen Tower") if a.tower != null and is_consumable(b.id) else ""
	if b.tower != null and b.tower != a.tower and (b.list as Array).size() >= slots(b.tower):
		return TranslationServer.translate("Inventar voll")
	if b.tower == null and a.tower != null and (b.list as Array).size() >= int(data().get("inventory_size", 8)):
		return TranslationServer.translate("Lager voll")
	return ""


## Item verschieben wie in WC3: auf ein anderes Item = tauschen, auf einen freien Platz = verschieben,
## Verbrauchs-Items auf einen Tower = benutzen (werden verbraucht).
func move(from: Dictionary, to: Dictionary) -> bool:
	if move_reason(from, to) != "":
		return false
	var a := _place(from)
	var b := _place(to)
	if b.tower != null and is_consumable(a.id):
		return use(a.index, b.tower)
	game.systems.inventory.move(a.list, a.index, b.list, b.index if b.id != "" else -1)
	game._update_auras()
	return true


func sell(index: int) -> bool:
	var inv := inventory(game.acting)
	if index < 0 or index >= inv.size() or not has_market(game.acting):
		return false
	var id: String = inv[index]
	inv.remove_at(index)
	game.gold += sell_price(id)
	return true


## Angebot des Marktplatzes: [{item, price}].
static func shop() -> Array:
	return data().get("market", {}).get("shop", [])


static func shop_price(id: String) -> int:
	for s in shop():
		if str(s.item) == id:
			return int(s.price)
	return -1


func buy_reason(id: String) -> String:
	var price := shop_price(id)
	if price < 0:
		return "?"
	if not has_market(game.acting):
		return TranslationServer.translate("erst einen Marktplatz bauen")
	if game.gold < price:
		return TranslationServer.translate("zu wenig Gold")
	if str(item(id).get("use", "")) != "lumber" and inventory(game.acting).size() >= int(data().get("inventory_size", 8)):
		return TranslationServer.translate("Lager voll")
	return ""


func buy(id: String) -> bool:
	if buy_reason(id) != "":
		return false
	game.gold -= shop_price(id)
	if str(item(id).get("use", "")) == "lumber":
		game.lumber += 1
	else:
		inventory(game.acting).append(id)
	return true


static func upgrade(kind: String) -> Dictionary:
	return data().get("market", {}).get("upgrades", {}).get(kind, {})


## Kosten der nächsten Stufe {gold, lumber}, leer = schon alle Stufen.
func upgrade_cost(kind: String) -> Dictionary:
	var u := upgrade(kind)
	var costs: Array = u.get("costs", [])
	var lvl := market_level(game.ep(), kind)
	if lvl >= costs.size():
		return {}
	return {"gold": int(costs[lvl]), "lumber": int(u.get("lumber", 0))}


func upgrade_reason(kind: String) -> String:
	if upgrade(kind).is_empty():
		return "?"
	var c := upgrade_cost(kind)
	if c.is_empty():
		return TranslationServer.translate("höchste Stufe")
	if not has_market(game.acting):
		return TranslationServer.translate("erst einen Marktplatz bauen")
	if game.gold < int(c.gold):
		return TranslationServer.translate("zu wenig Gold")
	if game.lumber < int(c.lumber):
		return TranslationServer.translate("zu wenig Holz")
	return ""


func buy_upgrade(kind: String) -> bool:
	if upgrade_reason(kind) != "":
		return false
	var c := upgrade_cost(kind)
	game.gold -= int(c.gold)
	game.lumber -= int(c.lumber)
	var st: Dictionary = game.ep()
	if not st.has("market"):
		st.market = {}
	st.market[kind] = market_level(st, kind) + 1
	game._update_auras()
	return true
