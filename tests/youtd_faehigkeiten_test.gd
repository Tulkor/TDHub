extends Node
## Lauf: einzeln (Name ytfaehig)
## Modi: youtd
## YouTD Etappe 2: alle 690 Tower (214 Skripte aus YouTD 2) stehen in Gruppen am Weg, schießen auf Gegner mit allen
## 41 Wellen-Eigenschaften, steigen im Level auf, zaubern von Hand und werden aufgewertet. Godot-Fehler aus den
## Skripten zeigt run_tests.sh als ⚠. Start: godot --headless --path . res://tests/youtd_faehigkeiten_test.tscn

const BATCH := 36
const SECONDS := 8.0
const SIZES := ["normal", "champion", "air", "boss", "mass"]

var failures := 0
var game: Node


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	var expired := YtProjectile.new()
	var caster := YtUnit.new()
	expired._caster = caster
	caster.free()
	expired.update(0.01)
	check(expired._cleanup_done and expired.is_queued_for_deletion(), "Geschoss mit freigegebenem Schützen wird vor der Zielsuche bereinigt")
	RunHistory.path = "user://test_run_history.json"
	Profile.dir = "user://test_profile_youtd"
	Profile.reset_cache()
	Session.map_path = "res://data/maps/youtd.json"
	Session.map_override = null
	Session.skip_setup = false
	Session.game_kind = "youtd"
	game = load("res://scenes/youtd_game.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.submit({"type": "setup", "mode": 1, "length": 0, "difficulty": 1, "seed": 5, "wisdom": []})
	game.portal = 1000000.0
	await get_tree().process_frame
	await _all_towers()
	await _specials()
	await _upgrade()
	print("YTFAEHIG TEST ", "OK" if failures == 0 else "FAILED (%d)" % failures)
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


func _clear_towers() -> void:
	for t in game.all_towers().duplicate():
		game._unregister(t)
		t.remove_core()
		t.queue_free()


func _clear_creeps() -> void:
	for e in game.enemies.duplicate():
		game._remove_enemy(e)


func _spawn(level: int, specials: Array, tanky := false) -> void:
	var w: Dictionary = game._wave(level)
	w["specials"] = specials
	for s in SIZES:
		game._spawn_youtd(w, s)
		# zäh: die vorderen Tower sollen nicht alles wegschießen, bevor die hinteren dran sind
		if tanky:
			var e = game.enemies.back()
			e.core.set_base_health(1e9)
			e.core.set_health(1e9)
			# über den ganzen Weg verteilt, sonst sehen nur die Tower am Eingang Gegner
			var path: PackedVector2Array = e.path
			var i := randi_range(1, path.size() - 1)
			e.core.set_position_wc3_2d(path[i - 1].lerp(path[i], randf()) * YtWorld.WC3)


## Gegner laufen lassen, bis seconds Spielzeit um sind; jede Sekunde kommen neue.
func _run(seconds: float, level: int, specials: Array, tanky := false) -> void:
	Engine.time_scale = 6.0
	var t0: float = YtWorld.get_time()
	var next := 0.0
	while YtWorld.get_time() - t0 < seconds:
		if YtWorld.get_time() - t0 >= next:
			_spawn(level, specials, tanky)
			next += 1.0
		await get_tree().process_frame
	Engine.time_scale = 1.0


func _all_towers() -> void:
	var ids: Array = YoutdData.towers().keys()
	ids.sort_custom(func(a, b): return int(a) < int(b))
	var scripts := {}
	var dealt := 0
	var attackers := 0
	var casts := 0
	var manual := 0
	var with_script := 0
	var silent := []
	var restored := 0
	var lost := []
	for start in range(0, ids.size(), BATCH):
		var anchors := _anchors()
		var batch: Array = ids.slice(start, start + BATCH)
		var placed := []
		for id in batch:
			if anchors.is_empty():
				break
			var c: Vector2i = anchors.pop_front()
			if not game.debug_place(str(id), c):
				continue
			var t: YoutdTower = game.towers.get(c)
			placed.append(t)
			# Nachbarn des 2×2-Ankers fallen weg
			anchors = anchors.filter(func(a): return game.can_place(a))
		for t in placed:
			if t.core._tower_behavior.get_script() != null and t.core._tower_behavior.get_script().resource_path.contains("/towers/"):
				with_script += 1
				scripts[str(t.yt.get("script", ""))] = true
			t.core.add_exp(800.0)
		await _run(SECONDS, 20 + start / BATCH * 4, [], true)
		for t in placed:
			if not is_instance_valid(t) or t.core == null:
				continue
			if t.can_attack():
				attackers += 1
				if t.core.get_total_damage() > 0.0:
					dealt += 1
				else:
					silent.append(t.yid)
			for ac in t.core.get_autocast_list():
				if not ac.can_use_auto_mode():
					manual += 1
					t.core.set_mana(t.core.get_overall_mana())
					if ac.manual_cast():
						casts += 1
		await _run(1.0, 20, [])
		_clear_creeps()
		var st: Dictionary = YoutdSave.capture(game)
		_clear_towers()
		await get_tree().process_frame
		# Spielstand-Rundlauf: jeder Tower kommt mit seinen Zählern und dauerhaften Werten zurück
		var entries: Array = bytes_to_var(var_to_bytes(st)).towers
		for td in entries:
			YoutdSave._restore_tower(game, td)
			var t2: YoutdTower = game.towers.get(td.cell)
			if t2 == null or t2.core == null:
				continue
			restored += 1
			var again: Dictionary = YoutdSave.script_state(t2.core._tower_behavior)
			var same: bool = (td.script as Dictionary).keys().all(func(k): return str(again.get(k)) == str(td.script[k]))
			var mods_ok: bool = str(t2.yt.get("script", "")) in YoutdSave.MODS_SKIP or (td.mods as Dictionary).keys().all(func(k): return absf(float(t2.core._own_mods.get(k, 0.0)) - float(td.mods[k])) < 0.0001)
			if not same or not mods_ok:
				lost.append("%s %s" % [t2.yid, str(t2.yt.get("script", ""))])
		_clear_towers()
		await get_tree().process_frame
	check(restored >= 600 and lost.is_empty(), "Spielstand-Rundlauf: %d Tower geladen, abweichend: %s" % [restored, lost.slice(0, 10)])
	check(with_script >= 560 and scripts.size() >= 210, "Tower mit Skript: %d, verschiedene Skripte: %d" % [with_script, scripts.size()])
	check(dealt > attackers * 0.8, "angreifende Tower mit Schaden: %d von %d (ohne: %s)" % [dealt, attackers, silent.slice(0, 20)])
	check(manual > 0 and casts > manual / 3, "Zauber von Hand: %d von %d ausgelöst" % [casts, manual])


## Jede Wellen-Eigenschaft liegt als Buff auf den passenden Gegnern und läuft ein paar Sekunden mit Towern.
func _specials() -> void:
	var anchors := _anchors()
	for id in ["1", "41", "565", "49", "203"]:
		if not YoutdData.tower(id).is_empty() and not anchors.is_empty():
			game.debug_place(id, anchors.pop_front())
			anchors = anchors.filter(func(a): return game.can_place(a))
	var missing := []
	for sid in YoutdData.specials().keys():
		_spawn(30, [sid])
		var bt: YtBuffType = YtWaveSpecial.node.get_buff(int(sid))
		if bt == null:
			missing.append(sid)
			continue
		for e in game.enemies.slice(-SIZES.size()):
			if YoutdWaves.special_applies(sid, e.creep_size) and e.core.get_buff_of_type(bt) == null:
				missing.append(sid)
				break
		await _run(2.0, 30, [sid])
		_clear_creeps()
	check(missing.is_empty(), "alle 41 Eigenschaften als Buff auf den Gegnern (fehlen: %s)" % [missing])
	_clear_towers()


## Aufwerten: der neue Kern übernimmt Level und Erfahrung, das neue Skript läuft.
func _upgrade() -> void:
	game.gold = 100000
	game.mode_index = 1
	var anchors := _anchors()
	var ok := 0
	var tried := 0
	for id in ["1", "41", "203", "49"]:
		var up := YoutdData.upgrade_of(id)
		if up == "" or anchors.is_empty():
			continue
		var c: Vector2i = anchors.pop_front()
		game.debug_place(id, c)
		anchors = anchors.filter(func(a): return game.can_place(a))
		var t: YoutdTower = game.towers.get(c)
		t.core.add_exp(300.0)
		var lvl: int = t.level
		tried += 1
		t.set_youtd(up)
		await get_tree().process_frame
		if t.level == lvl and t.core.get_id() == int(up) and t.core.is_inside_tree():
			ok += 1
	await _run(3.0, 25, [])
	check(tried > 0 and ok == tried, "Aufwerten behält das Level: %d von %d" % [ok, tried])
	_clear_creeps()
	_clear_towers()

