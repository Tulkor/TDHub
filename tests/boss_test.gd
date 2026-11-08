extends Node
## Lauf: einzeln (Name boss)
## Modi: kern
## Boss-Modell (enemy.gd → BOSS_MODEL): Bosse ohne eigenes Modell bekommen den animierten "Little Man",
## laufen mit "walk", stehen betäubt mit "idle", zucken bei großen Treffern und hinterlassen beim Tod
## kurz eine Leiche mit "death", die sich selbst wieder entfernt.

var failures := 0
var killed := 0


class FakeGame:
	extends RefCounted
	var test

	func on_enemy_killed(_e) -> void:
		test.killed += 1

	func is_covered(_e) -> bool:
		return true

	func on_enemy_leaked(_e) -> void:
		pass


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	var game := FakeGame.new()
	game.test = self
	var path := PackedVector2Array([Vector2.ZERO, Vector2(50, 0)])

	var normal := Enemy.new()
	add_child(normal)
	normal.setup(game, {"id": "w", "hp": 100}, {}, path)
	check(normal._anim != null and not normal._body.visible and normal._model_path.ends_with("skeleton.glb"),
			"Bodengegner ist ein animiertes Skelett")
	for c in [[{"flying": true}, {}, "dragon.glb"], [{"flying": true}, {"shape": "pyramid"}, "bat.glb"],
			[{}, {"shape": "pyramid"}, "slime.glb"]]:
		var e := Enemy.new()
		add_child(e)
		var def: Dictionary = {"id": "m", "hp": 100, "color": "#ff0000"}
		def.merge(c[0])
		e.setup(game, def, c[1], path)
		check(e._anim != null and e._model_path.ends_with(c[2]) and e._anim.has_animation("death"),
				"Gegner %s %s ist %s mit Animationen" % [c[0], c[1], c[2]])
		var tinted := false
		for m in e._model.find_children("*", "MeshInstance3D", true, false):
			for i in m.get_surface_override_material_count():
				var mat = m.get_surface_override_material(i)
				tinted = tinted or (mat is BaseMaterial3D and mat.albedo_color.r > mat.albedo_color.g + 0.3)
		check(tinted, "%s trägt die Gegnerfarbe" % c[2])
	var own := Enemy.new()
	add_child(own)
	own.setup(game, {"id": "o", "hp": 100, "model": "res://gibt/es/nicht.glb"}, {}, path)
	check(own._model == null and own._body.visible, "eigenes, fehlendes Modell bleibt die einfache Form")

	var boss := Enemy.new()
	add_child(boss)
	boss.setup(game, {"id": "b", "hp": 1000, "boss": true}, {}, path)
	check(boss._model != null and not boss._body.visible, "Boss bekommt das Modell statt des Quaders")
	check(boss._anim != null, "Boss-Modell hat einen AnimationPlayer")
	if boss._anim == null:
		_finish()
		return
	for a in ["walk", "idle", "hit", "death"]:
		check(boss._anim.has_animation(a), "Animation " + a + " vorhanden")
	check(boss._anim.current_animation == "walk", "Boss läuft mit walk")
	var box := ModelLoader.aabb(boss._model, Transform3D())
	check(absf(box.size.y - Enemy.BOSS_MODEL_HEIGHT) < 0.05, "Modell %.2f hoch" % box.size.y)
	check(boss._bar_fg.position.y > box.end.y, "Lebensbalken über dem Kopf")

	boss.apply_stun(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(boss._anim.current_animation == "idle", "betäubt: idle")
	boss.stun_time = 0.0
	boss.take_raw_damage(100.0)
	await get_tree().process_frame
	check(boss._anim.current_animation == "hit", "großer Treffer: hit")

	var before := get_child_count()
	boss.take_raw_damage(5000.0)
	check(killed == 1 and boss.dead, "Boss getötet")
	check(get_child_count() == before + 1, "Leiche liegt auf dem Feld")
	var corpse: Node = get_child(get_child_count() - 1)
	var players := corpse.find_children("*", "AnimationPlayer", true, false)
	check(not players.is_empty() and players[0].current_animation == "death", "Leiche spielt death")
	boss.queue_free()
	var t := 0.0
	while is_instance_valid(corpse) and t < 4.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(not is_instance_valid(corpse), "Leiche verschwindet wieder")
	_finish()


func _finish() -> void:
	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
