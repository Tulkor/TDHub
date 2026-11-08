extends Node
## Lauf: einzeln (Name sysbuild)
## Modi: system:build
## System build ohne Modus: Tempo ungedeckter Gegner aus balance.json, rules oder festem Wert (Kaskade), Deckung über
## den Haken cover_rule, Belegen mit und ohne Wegsperre (solid).
## Start: tools/run_tests.sh sysbuild

var failures := 0


class FakePath extends RefCounted:
	var solid := {}

	func set_solid_cells(cells: Array[Vector2i], on: bool) -> void:
		for c in cells:
			solid[c] = on


class FakeGame extends Node:
	var systems := {}
	var rules := {"empty_zone_speed": 2.5}
	var occupied := {}
	var pathfinder := FakePath.new()
	var covered := false

	func cover_rule(_e) -> bool:
		return covered


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _game(mode: String) -> FakeGame:
	var g := FakeGame.new()
	add_child(g)
	SystemHost.attach(g, mode, ["build"])
	return g


func _ready() -> void:
	await get_tree().process_frame
	var gm := _game("gemtd")
	check(is_equal_approx(gm.systems.build.idle_speed_factor(), maxf(float(Database.balance.get("idle_speed_factor", 1.0)), 1.0)),
		"GemTD: Tempo aus balance.json")
	var yt := _game("youtd")
	check(is_equal_approx(yt.systems.build.idle_speed_factor(), 1.0), "YouTD: fester Wert 1")
	var m := _game("shoppingmaul")
	check(is_equal_approx(m.systems.build.idle_speed_factor(), 2.5), "Maul: aus rules.empty_zone_speed")
	check(not m.systems.build.is_covered(null), "Maul: Deckung über Haken cover_rule")
	m.covered = true
	check(m.systems.build.is_covered(null), "Haken gibt gedeckt zurück")
	check(m.systems.build.free_stretch(null) == [-1.0, -1.0], "ohne Tower-Deckung keine freien Stücke")
	gm.systems.build.occupy(Vector2i(4, 4), true)
	check(gm.occupied.get(Vector2i(5, 5)) == Vector2i(4, 4) and gm.pathfinder.solid.get(Vector2i(5, 5), false), "belegt und sperrt")
	gm.systems.build.occupy(Vector2i(4, 4), false)
	check(gm.occupied.is_empty() and not gm.pathfinder.solid[Vector2i(4, 4)], "geräumt")
	yt.systems.build.occupy(Vector2i(2, 2), true)
	check(yt.occupied.size() == 4 and yt.pathfinder.solid.is_empty(), "YouTD: belegt, sperrt nicht (solid false)")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
