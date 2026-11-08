extends Node
## Lauf: einzeln (Name ytitems)
## Modi: youtd
## YouTD Etappe 3: alle 315 Items (135 mit Skript aus YouTD 2) liegen in Towern am Weg, während Gegner laufen; Zauber
## der Items werden von Hand ausgelöst, Items wieder herausgenommen, Öle verbraucht, Verbrauchsgegenstände benutzt.
## Dazu die 7 Rezepte des Horadrischen Würfels, die 21 Baumeister und Items beim Aufwerten. Godot-Fehler aus den
## Skripten zeigt run_tests.sh als ⚠. Start: godot --headless --path . res://tests/youtd_items_test.tscn

const SIZES := ["normal", "champion", "air", "boss", "mass"]
## Tower mit vielen Item-Plätzen und Angriff (verschiedene Elemente)
const CARRIERS := 10

var failures := 0
var game: Node


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile_youtd_items"
	Profile.reset_cache()
	Session.map_path = "res://data/maps/youtd.json"
	Session.map_override = null
	Session.skip_setup = false
	Session.game_kind = "youtd"
	game = load("res://scenes/youtd_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.submit({"type": "setup", "mode": 1, "length": 0, "difficulty": 1, "seed": 7, "wisdom": [], "builder": "backpacker", "level": 300})
	game.portal = 1000000.0
	await get_tree().process_frame
	check(game.yp().builder_id == "backpacker", "Baumeister im Startbefehl gewählt")
	await _items()
	await _cube()
	await _store()
	await _builders()
	await _upgrade()
	print("YTITEMS TEST ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	get_tree().quit(1 if failures > 0 else 0)


## Bauplätze nah am Weg (Anker für 2×2-Tower), nächste zuerst.
func _anchors() -> Array:
	var path: PackedVector2Array = game.lane_paths[0].ground
	var list := []
	for y in game.map.height:
		for x in game.map.width:
			var c := Vector2i(x, y)
			if not game.can_place(c):
				continue
			var p := Board3D.footprint_center(c, 2)
			var d := INF
			for q in path:
				d = minf(d, p.distance_to(q))
			list.append([d, c])
	list.sort_custom(func(a, b): return a[0] < b[0])
	return list.map(func(a): return a[1])


func _place(ids: Array) -> Array:
	var anchors := _anchors()
	var out := []
	for id in ids:
		if anchors.is_empty():
			break
		var c: Vector2i = anchors.pop_front()
		if game.debug_place(str(id), c):
			out.append(game.towers.get(c))
		anchors = anchors.filter(func(a): return game.can_place(a))
	return out


func _clear() -> void:
	for e in game.enemies.duplicate():
		game._remove_enemy(e)
	for t in game.all_towers().duplicate():
		for it in t.items.duplicate() + t.oils.duplicate():
			it.drop()
			it.queue_free()
		game._unregister(t)
		t.remove_core()
		t.queue_free()


func _spawn(level: int) -> void:
	var w: Dictionary = game._wave(level)
	w["specials"] = []
	for s in SIZES:
		game._spawn_youtd(w, s)
		var e = game.enemies.back()
		e.core.set_base_health(1e8)
		e.core.set_health(1e8)
		var path: PackedVector2Array = e.path
		var i := randi_range(1, path.size() - 1)
		e.core.set_position_wc3_2d(path[i - 1].lerp(path[i], randf()) * YtWorld.WC3)


func _run(seconds: float, level: int) -> void:
	Engine.time_scale = 6.0
	var t0: float = YtWorld.get_time()
	var next := 0.0
	while YtWorld.get_time() - t0 < seconds:
		if YtWorld.get_time() - t0 >= next:
			_spawn(level)
			next += 1.0
		await get_tree().process_frame
	Engine.time_scale = 1.0


## Angreifende Tower mit den meisten Item-Plätzen, je Element einer zuerst.
func _carrier_ids() -> Array:
	var all := YoutdData.towers()
	var ids: Array = all.keys().filter(func(id): return bool(all[id].get("attack", true)) and str(all[id].get("rarity", "")) == "unique")
	ids.sort_custom(func(a, b): return YoutdData.item_slots(a) > YoutdData.item_slots(b))
	var out := []
	var seen := {}
	for id in ids:
		var el := str(all[id].element)
		if not seen.has(el):
			seen[el] = true
			out.append(id)
	for id in ids:
		if out.size() >= CARRIERS:
			break
		if not out.has(id):
			out.append(id)
	return out


func _items() -> void:
	var all := YoutdData.items()
	var regular: Array = all.keys().filter(func(id): return all[id].type == "regular")
	var p: YtPlayer = game.yp()
	var put := 0
	var scripted := 0
	var casts := 0
	var tried_casts := 0
	var with_script := {}
	# Backpacker: Tower tragen nur Items ihrer Seltenheit oder einzigartige; deshalb ohne Baumeister testen
	p.set_builder("")
	for start in range(0, regular.size(), 40):
		var towers := _place(_carrier_ids())
		for t in towers:
			t.core.add_exp(2000.0)
		var batch: Array = regular.slice(start, start + 40)
		var k := 0
		for id in batch:
			var it := YtItem.make(int(id), p)
			game.stash_add(it)
			var placed := false
			for _n in towers.size():
				var t: YoutdTower = towers[k % towers.size()]
				k += 1
				if game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": it.get_uid()}):
					placed = true
					break
			if placed:
				put += 1
				if all[id].has("script"):
					scripted += 1
					with_script[str(all[id].script)] = true
			else:
				game.stash_remove(it)
				it.queue_free()
		await _run(6.0, 30 + start / 10)
		for t in towers:
			if not is_instance_valid(t):
				continue
			for ac in t.autocasts():
				if ac.is_item_autocast() and not ac.can_use_auto_mode():
					tried_casts += 1
					t.core.set_mana(t.core.get_overall_mana())
					if ac.manual_cast():
						casts += 1
			# Werte der Item-Skripte lesen (on_tower_details)
			t.ability_lines()
			t.core.get_item_tower_details()
		await _run(2.0, 30)
		# alles wieder ins Lager und hinaus
		for t in towers:
			if not is_instance_valid(t):
				continue
			while not t.items.is_empty():
				game.take_item(t, 0)
		for it in game.item_stash.duplicate():
			game.stash_remove(it)
			it.queue_free()
		_clear()
		await get_tree().process_frame
	check(put >= 280, "normale Items eingelegt: %d von %d" % [put, regular.size()])
	check(with_script.size() >= 115, "Items mit Skript liefen: %d (verschiedene Skripte %d)" % [scripted, with_script.size()])
	check(tried_casts == 0 or casts > 0, "Item-Zauber von Hand: %d von %d" % [casts, tried_casts])

	# Öle: wirken dauerhaft ohne Platz
	var towers := _place(_carrier_ids().slice(0, 2))
	var oils: Array = all.keys().filter(func(id): return all[id].type == "oil")
	var applied := 0
	for id in oils:
		var it := YtItem.make(int(id), p)
		game.stash_add(it)
		if game.submit({"type": "item_put", "tower": game.tower_ref(towers[0]), "uid": it.get_uid()}):
			applied += 1
	check(applied == oils.size() and towers[0].oils.size() == oils.size() and towers[0].items.is_empty(), "alle %d Öle eingelegt, ohne Platz" % oils.size())
	await _run(3.0, 20)

	# Verbrauchsgegenstände
	var cons: Array = all.keys().filter(func(id): return all[id].type == "consumable")
	var tomes_before: int = p.tomes
	var used := 0
	for id in cons:
		var it := YtItem.make(int(id), p)
		game.stash_add(it)
		check(not game.submit({"type": "item_put", "tower": game.tower_ref(towers[0]), "uid": it.get_uid()}), "%s lässt sich nicht einlegen" % it.get_display_name())
		if game.submit({"type": "item_use", "uid": it.get_uid()}):
			used += 1
	check(used == cons.size() and not game.item_stash.any(func(i): return cons.has(str(i.get_id()))), "alle %d Verbrauchsgegenstände benutzt" % cons.size())
	check(p.tomes > tomes_before, "Verbrauchsgegenstände geben Bücher (%d → %d)" % [tomes_before, p.tomes])
	await _run(2.0, 20)

	# Verkaufen: Items ins Lager, Öle weg
	var t: YoutdTower = towers[0]
	var claws := YtItem.make(2, p)
	game.stash_add(claws)
	game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": claws.get_uid()})
	var opts: Array = game.tower_options(t)
	var si: int = opts.map(func(o): return o.action).find("sell")
	game.submit({"type": "option", "tower": game.tower_ref(t), "index": si, "action": "sell", "id": t.yid})
	await get_tree().process_frame
	check(game.item_stash.has(claws) and claws.get_carrier() == null, "Verkaufen legt das Item ins Lager")
	for it in game.item_stash.duplicate():
		game.stash_remove(it)
		it.queue_free()
	_clear()
	await get_tree().process_frame


## Horadrischer Würfel: jedes Rezept einmal mit passenden Items.
func _cube() -> void:
	var p: YtPlayer = game.yp()
	p.set_builder("backpacker")
	var all := YoutdData.items()
	var done := []
	for r in YoutdCube.recipes():
		for it in game.item_stash.duplicate():
			game.stash_remove(it)
			it.queue_free()
		# Zutaten: gewöhnliche (bzw. für "liquefy" seltene) Items und Öle
		var rarity := "rare" if int(r.rarity_change) < 0 else "common"
		var regular: Array = all.keys().filter(func(id): return all[id].type == "regular" and all[id].rarity == rarity)
		var usable: Array = all.keys().filter(func(id): return all[id].type in ["oil", "consumable"] and all[id].rarity == rarity)
		for i in int(r.permanent):
			game.stash_add(YtItem.make(int(regular[i * 3 % regular.size()]), p))
		for i in int(r.usable):
			game.stash_add(YtItem.make(int(usable[i % usable.size()]), p))
		var fill := YoutdCube.autofill(r, game.item_stash)
		var match_r := YoutdCube.current_recipe(p, fill)
		var before: int = game.item_stash.size()
		var ok: bool = game.submit({"type": "transmute", "uids": fill.map(func(it): return it.get_uid())})
		if ok and str(match_r.get("id", "")) == str(r.id) and game.item_stash.size() == before - fill.size() + int(r.count):
			done.append(r.id)
		else:
			printerr("Rezept %s: ok %s, erkannt %s, Lager %d → %d" % [r.id, ok, match_r.get("id", ""), before, game.item_stash.size()])
	check(done.size() == YoutdCube.recipes().size(), "alle Würfel-Rezepte verwandeln: %s" % [done])
	# Sperre: gesperrte Items füllt der Würfel nicht ein
	for it in game.item_stash.duplicate():
		game.stash_remove(it)
		it.queue_free()
	for i in 3:
		game.stash_add(YtItem.make(2, p))
	game.submit({"type": "item_lock", "uid": game.item_stash[0].get_uid()})
	check(YoutdCube.autofill(YoutdCube.recipe("reassemble"), game.item_stash).is_empty(), "gesperrtes Item kommt nicht in den Würfel")
	p.set_builder("")
	check(YoutdCube.current_recipe(p, game.item_stash.slice(0, 2) + game.item_stash.slice(0, 0)).is_empty(), "zwei Items sind kein Rezept")
	for it in game.item_stash.duplicate():
		game.stash_remove(it)
		it.queue_free()


## Lager unten links: Icons, „Öle kombinieren“, Herausnehmen per Befehl, „6 → 1“ im Zufallsmodus.
func _store() -> void:
	var p: YtPlayer = game.yp()
	var all := YoutdData.items()
	check(all.keys().all(func(id): return YoutdData.item_icon(str(id)) != null), "jedes Item hat ein Icon")
	check(YoutdData.towers().keys().all(func(id): return YoutdData.tower_icon(str(id)) != null), "jeder Tower hat ein Icon")
	var with_ab: Array = YoutdData.towers().keys().filter(func(id): return not (YoutdData.tower(id).get("abilities", []) as Array).is_empty())
	check(with_ab.all(func(id): return YoutdData.description("abilities", str(YoutdData.tower(id).abilities[0])) != ""),
			"jede Tower-Fähigkeit hat eine Beschreibung")
	# 9 gewöhnliche Öle: 2× destillieren (8 → 2 ungewöhnliche), 1 bleibt
	var oils: Array = all.keys().filter(func(id): return all[id].type == "oil" and all[id].rarity == "common")
	for i in 9:
		game.stash_add(YtItem.make(int(oils[i % oils.size()]), p))
	check(game.can_merge_oils(), "Öle kombinieren möglich")
	check(game.submit({"type": "oil_merge"}), "Öle kombinieren")
	var left: Array = game.item_stash.filter(func(it): return it.get_type_name() == "oil" and YoutdData.item(str(it.get_id())).rarity == "common")
	check(left.size() == 1 and game.item_stash.size() == 3, "9 gewöhnliche Öle → 1 übrig + 2 höhere (Lager %d)" % game.item_stash.size())
	check(not game.can_merge_oils(), "danach nichts mehr zu kombinieren")
	await get_tree().process_frame
	check(game.youtd_store._items.get_child_count() >= game.item_stash.size(), "Item-Lager zeigt Felder")
	# Fenster „Rezepte“ in der Mitte: ein freies Feld führt das Rezept sofort aus; Elemente schließt es wieder
	for i in 2:
		game.stash_add(YtItem.make(int(oils[i % oils.size()]), p))
	var panel: YoutdPanel = game.youtd_panel
	panel.open_window("recipes")
	var cells: Array = panel._rec_grid.get_children().filter(func(c): return c is Button and not c.disabled)
	check(panel.is_open("recipes") and cells.size() == 2, "Rezepte: Neu brauen gewöhnlich und ungewöhnlich ausführbar (%d)" % cells.size())
	var before: int = game.item_stash.size()
	if not cells.is_empty():
		(cells[0] as Button).pressed.emit()
	check(game.item_stash.size() == before - 1, "Rezept „Neu brauen“ per Klick: 2 Öle → 1 (Lager %d → %d)" % [before, game.item_stash.size()])
	panel.open_window("elements")
	check(panel.is_open("elements") and not panel.is_open("recipes"), "neues Fenster in der Mitte schließt das alte")
	panel.close_windows()
	for it in game.item_stash.duplicate():
		game.stash_remove(it)
		it.queue_free()
	# Herausnehmen per Befehl (Ziehen von der Auswahlkarte ins Lager)
	var t: YoutdTower = _place([_carrier_ids()[0]])[0]
	game.stash_add(YtItem.make(2, p))
	check(game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": game.item_stash[0].get_uid()}), "Item in Tower legen")
	check(game.submit({"type": "item_take", "tower": game.tower_ref(t), "index": 0}), "Item herausnehmen")
	await get_tree().create_timer(1.0).timeout
	check(t.items.is_empty() and game.item_stash.size() == 1, "Item wieder im Lager")
	await _inventory(t)
	for it in game.item_stash.duplicate():
		game.stash_remove(it)
		it.queue_free()
	# 6 → 1 im Zufallsmodus
	var mode: int = game.mode_index
	game.mode_index = 0
	var commons: Array = YoutdData.towers().keys().filter(func(id): return YoutdData.tower(id).rarity == "common" and int(YoutdData.tower(id).tier) == 1)
	game.stash = commons.slice(0, 7)
	check(game.merge_option().get("from", "") == "common", "6 → 1 angeboten")
	check(game.submit({"type": "tower_merge", "rarity": "common"}), "6 → 1")
	var st: Array = game.stash
	check(st.size() == 2 and st[0] == commons[6] and YoutdData.tower(st[1]).rarity == "uncommon", "6 gewöhnliche → 1 ungewöhnlicher: %s" % [st])
	check(not game.submit({"type": "tower_merge", "rarity": "common"}), "mit 1 gewöhnlichem kein 6 → 1")
	game.stash = []
	game.mode_index = mode
	_clear()


## Baumeister: Wirkung auf den Spieler und auf Tower.
## WC3-Inventar: Tauschen per Ziehen (item_move), Öle werden verbraucht, volles Inventar nimmt nichts.
func _inventory(t: YoutdTower) -> void:
	var p: YtPlayer = game.yp()
	var all := YoutdData.items()
	for it in game.item_stash.duplicate():
		game.stash_remove(it)
		it.queue_free()
	var regular: Array = all.keys().filter(func(id): return all[id].type == "regular" and all[id].rarity == "common")
	var a := YtItem.make(int(regular[0]), p)
	var b := YtItem.make(int(regular[1]), p)
	var c := YtItem.make(int(regular[2]), p)
	for it in [a, b, c]:
		game.stash_add(it)
	var ref: Dictionary = game.tower_ref(t)
	check(game.submit({"type": "item_move", "from": {"stash": c.get_uid()}, "to": {"stash": a.get_uid()}}) and game.item_stash == [c, b, a],
			"Lager: Item auf Item gezogen tauscht die Plätze")
	check(game.submit({"type": "item_move", "from": {"stash": a.get_uid()}, "to": {"tower": ref, "slot": 0}}) and t.items == [a],
			"Lager → freier Tower-Platz")
	check(game.submit({"type": "item_move", "from": {"stash": b.get_uid()}, "to": {"tower": ref, "slot": 0}}) and t.items == [b]
			and game.item_stash == [c, a], "Lager-Item auf Tower-Item: getauscht, altes Item auf dem Platz des neuen (%s)" % [game.item_stash])
	check(game.submit({"type": "item_move", "from": {"tower": ref, "slot": 0}, "to": {"stash": c.get_uid()}}) and t.items == [c]
			and game.item_stash == [b, a], "Tower-Item auf Lager-Item: getauscht")
	var t2: YoutdTower = _place([_carrier_ids()[1]])[0]
	var ref2: Dictionary = game.tower_ref(t2)
	check(game.submit({"type": "item_move", "from": {"stash": a.get_uid()}, "to": {"tower": ref2, "slot": -1}}) and t2.items == [a], "Item auf zweiten Tower")
	check(game.submit({"type": "item_move", "from": {"tower": ref, "slot": 0}, "to": {"tower": ref2, "slot": 0}}) and t.items == [a] and t2.items == [c],
			"Tower ↔ Tower getauscht")
	check(c.get_carrier() == t2.core and a.get_carrier() == t.core, "Wirkung wandert mit (Träger)")
	# Öl: wird beim Anwenden verbraucht, braucht keinen Platz; Verbrauchsgegenstände gehen nicht in Tower
	var oil_id: String = all.keys().filter(func(id): return all[id].type == "oil")[0]
	var oil := YtItem.make(int(oil_id), p)
	game.stash_add(oil)
	var data := {"inv": true, "from": {"stash": oil.get_uid()}}
	check(game.inv_drop_reason(t, data) == "", "Öl auf Tower in der Welt erlaubt")
	game.systems.inventory.drop(t, data)
	check(t.oils.has(oil) and not game.item_stash.has(oil), "Öl verbraucht: nicht mehr im Lager, wirkt im Tower")
	game._select(t)
	await get_tree().process_frame
	check(not (game.oil_rows(t) as Array).is_empty() and game.hud.info_oils.visible, "▲ Öle neben dem Namen mit Werten im Tooltip (%s)" % [game.oil_rows(t)])
	# volles Inventar
	for _n in 6:
		if t.items.size() >= t.slots():
			break
		var f := YtItem.make(int(regular[3 + t.items.size()]), p)
		game.stash_add(f)
		game.submit({"type": "item_move", "from": {"stash": f.get_uid()}, "to": {"tower": ref, "slot": -1}})
	game.stash_add(YtItem.make(int(regular[2]), p))
	var last: YtItem = game.item_stash[-1]
	check(game.inv_drop_reason(t, {"inv": true, "from": {"stash": last.get_uid()}}) == tr("Inventar voll"), "voller Tower: „Inventar voll“")
	check(not game.submit({"type": "item_move", "from": {"stash": last.get_uid()}, "to": {"tower": ref, "slot": -1}}), "voller Tower nimmt nichts")
	check(game.submit({"type": "item_move", "from": {"stash": last.get_uid()}, "to": {"tower": ref, "slot": 1}}) and t.items[1] == last,
			"auf ein Item im vollen Tower ziehen tauscht trotzdem")
	game._select(null)
	for it in t.items.duplicate() + t2.items.duplicate():
		it.drop()
		it.fly_to_stash(0.0)
	for it in game.item_stash.duplicate():
		game.stash_remove(it)
		it.queue_free()


func _builders() -> void:
	var ok := []
	for b in YoutdData.builders():
		var p := YtPlayer.new(0)
		var before: float = game.portal
		game._apply_player(p, {"builder": str(b.id), "level": 300, "wisdom": []})
		if p.builder_id == str(b.id) and p.builder != null:
			ok.append(b.id)
		match str(b.id):
			"elementalist":
				check(p.tomes == 90 + 65, "Elementalist: +65 Bücher (%d)" % p.tomes)
			"iron_maiden":
				check(is_equal_approx(game.portal, before + 50.0), "Iron Maiden: Portal +50")
			"fender":
				check(p.builder_wisdom_multiplier == 1.25 and p.income_rate < 1.0, "Feeble Fender: Weisheit ×1,25, weniger Einkommen")
			"goblin":
				check(p.interest_rate > 0.06, "Goblin Alchemist: mehr Zinsen")
		p.builder.queue_free()
	check(ok.size() == 21, "alle 21 Baumeister setzbar: %d" % ok.size())
	game._apply_player(game.yp(), {"builder": "blademaster", "level": 300, "wisdom": []})
	var t: YoutdTower = _place(["1"])[0]
	check(t.mod("MOD_ATK_CRIT_CHANCE") >= 0.079, "Blademaster gibt Towern +8 %% Krit (%s)" % t.mod("MOD_ATK_CRIT_CHANCE"))
	_clear()
	game._apply_player(game.yp(), {"builder": "master", "level": 300, "wisdom": []})
	t = _place(["1"])[0]
	check(t.level == 5, "Master of Encyclopedic Wisdom: Tower starten auf Level 5 (%d)" % t.level)
	_clear()
	game._apply_player(game.yp(), {"builder": "backpacker", "level": 300, "wisdom": []})
	t = _place(["1"])[0]
	check(t.slots() == YoutdData.item_slots("1") + 2, "Backpacker: zwei Item-Plätze mehr")
	_clear()
	game._apply_player(game.yp(), {"builder": "maverick", "level": 300, "wisdom": []})
	var a: Vector2i = _anchors()[0]
	game.debug_place("1", a)
	check(not game.can_place(a + Vector2i(2, 0)) and not game.can_place(a + Vector2i(0, 2)), "Maverick: keine Tower direkt nebeneinander")
	_clear()
	game._apply_player(game.yp(), {"builder": "", "level": 300, "wisdom": []})
	await get_tree().process_frame


## Aufwerten: Items und Öle wandern auf den neuen Kern und wirken weiter.
func _upgrade() -> void:
	var p: YtPlayer = game.yp()
	var t: YoutdTower = _place(["1"])[0]
	var claws := YtItem.make(2, p)
	var oil := YtItem.make(1001, p)
	game.stash_add(claws)
	game.stash_add(oil)
	game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": claws.get_uid()})
	game.submit({"type": "item_put", "tower": game.tower_ref(t), "uid": oil.get_uid()})
	var up := YoutdData.upgrade_of("1")
	t.set_youtd(up)
	await get_tree().process_frame
	check(t.items == [claws] and t.oils == [oil] and claws.get_carrier() == t.core and t.mod("MOD_DAMAGE_ADD_PERC") >= 0.25,
			"Aufwerten: Item und Öl wirken am neuen Kern")
	await _run(2.0, 20)
	_clear()
