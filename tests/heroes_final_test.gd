extends Node
## Lauf: einzeln (Name heroesfinal)
## Modi: heroes
## Sechs echte Challenge-Arme, begehbare Verbindungen und Felsgrenzen im Schlund.

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)


func _ready() -> void:
	Session.skip_setup = true
	var game: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	game.force_hero = "torvik"
	game.force_final_boss = "varkhun"
	game.persist_settings = false
	add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.spawn_queue.clear()
	var hour_before := game.time_of_day()
	game.final.enter()
	check(is_equal_approx(game.time_of_day(), hour_before), "Dunkles Gebietslicht verändert nicht die Gameplay-Tageszeit")
	var final := game.final
	var layout := final.layout
	check(final.data.list.size() == 6 and final.data.area.layout.arms.size() == 6, "Sechs Stationen mit sechs eigenen Armen")
	var reached := _reachable(layout, final.start_pos())
	for room in layout.rooms():
		var cell := Vector2i(roundi(room.pos.x / 2), roundi(room.pos.z / 2))
		check(reached.has(cell), "Vom Ankunftspunkt erreichbar: " + str(room.id))
	var rock := final.center + Vector3(32, 0, -72)
	check(not layout.inside(rock), "Zwischen Plattformen liegen unpassierbare Felsbereiche")
	game.hero.position = rock
	game._resolve(game.hero)
	check(layout.inside(game.hero.position, -game.hero.radius + 0.01), "Bewegungsgrenze hält Helden auf den tatsächlichen Plattformen")
	for room in layout.rooms():
		if str(room.id) != "boss":
			check(layout.rooms().any(func(other): return other.pos.is_equal_approx(Vector3(-room.pos.x, 0, room.pos.z))), "Arm hat symmetrisches Gegenstück: " + str(room.id))
	game.hero.position = final.station_pos("glutpfad")
	check(final.begin("glutpfad") == "", "Glutpfad startet")
	check(layout.inside(final.run.to, -1), "Glutpfad-Altar liegt auf seinem Arm statt im Fels")
	final._end_run(false, "test")
	game.hero.position = final.station_pos("leuchtfeuer")
	final.begin("leuchtfeuer")
	final.step(2)
	check(game.enemies.filter(func(e): return not e.dead and e.zone == "final_run").all(func(e): return layout.inside(e.position, -e.radius + 0.01)), "Leuchtfeuer-Gegner erscheinen innerhalb der Plattform")
	final._end_run(false, "test")
	game.hero.position = final.station_pos("jagd")
	check(final.begin("jagd") == "" and final.run.targets.size() == 12, "Sechste Challenge erzeugt eine echte Schattenschar")
	check(final.run.targets.all(func(e): return layout.inside(e.position, -e.radius)), "Schatten erscheinen auf der Challengeplattform")
	final.step(45.1)
	check(final.sys().state_of("jagd") == "failed", "Nicht besiegte Schattenschar scheitert am Zeitlimit")
	check(final.begin("jagd") == "", "Gescheiterte Jagd kann erneut versucht werden")
	for enemy in final.run.targets.duplicate():
		game.hero_hit(enemy, enemy.max_hp * 2, "physical", true)
	final.step(0)
	check(final.sys().state_of("jagd") == "done", "Besiegte Schattenschar schließt sechste Challenge ab")
	check(float(final.sys().boss_mods().get("hp", 0)) <= -0.1, "Sechste Challenge schwächt den Endboss tatsächlich")
	game.queue_free()
	await get_tree().process_frame
	print("Schlund: %d Prüfungen, %d Fehler" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _reachable(layout: HdFinalLayout, start: Vector3) -> Dictionary:
	var local := start - layout.center
	var first := Vector2i(roundi(local.x / 2), roundi(local.z / 2))
	var queue: Array[Vector2i] = [first]
	var seen := {first:true}
	var result := {first:true}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if seen.has(next) or absi(next.x) > 50 or absi(next.y) > 55:
				continue
			seen[next] = true
			if layout.inside(layout.center + Vector3(next.x * 2, 0, next.y * 2), -1):
				result[next] = true
				queue.append(next)
	return result
