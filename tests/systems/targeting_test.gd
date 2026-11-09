extends Node
## Lauf: einzeln (Name systargeting)
## Modi: system:targeting
## System targeting ohne Modus: Tower-Ziele (am weitesten gelaufen zuerst), eigene Reichweite, Gegner im Kreis
## und nächster Gegner, mit Vector2-Gegnern (pos) und 3D-Gegnern mit Ausdehnung (Kaskade aus modes.json).
## Start: tools/run_tests.sh systargeting

var failures := 0


class FakeGame extends Node:
	var systems := {}
	var enemies: Array = []


class E2 extends RefCounted:
	var pos := Vector2.ZERO
	var traveled := 0.0
	var dead := false
	var air := false


class E3 extends Node3D:
	var radius := 0.0
	var dead := false


class FakeTower extends RefCounted:
	var pos := Vector2.ZERO
	var range := 100.0

	func can_target(e) -> bool:
		return not e.air

	func in_range(e) -> bool:
		return e.pos.distance_to(pos) <= range


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _e2(x: float, traveled: float, air := false, dead := false) -> E2:
	var e := E2.new()
	e.pos = Vector2(x, 0)
	e.traveled = traveled
	e.air = air
	e.dead = dead
	return e


func _ready() -> void:
	await get_tree().process_frame
	var g := FakeGame.new()
	add_child(g)
	SystemHost.attach(g, "gemtd", ["targeting"])
	var tg = g.systems.targeting
	var near := _e2(10, 5)
	var far := _e2(50, 30)
	var out := _e2(500, 99)
	var flyer := _e2(20, 80, true)
	var dead := _e2(5, 90, false, true)
	g.enemies = [near, far, out, flyer, dead]
	var t := FakeTower.new()
	check(tg.find_targets(t, 1) == [far], "ein Ziel: am weitesten gelaufen, in Reichweite, angreifbar, lebend")
	check(tg.find_targets(t, 3) == [far, near], "mehrere Ziele nach Weg sortiert")
	check(tg.find_targets_in(t, 20.0, 2) == [near], "eigene Reichweite statt in_range")
	check(tg.enemies_in_radius(Vector2.ZERO, 20.0).size() == 2, "Kreis: lebende Gegner, auch Flieger")
	check(tg.nearest(Vector2(45, 0), 100.0) == far, "nächster Gegner")
	check(tg.nearest(Vector2(45, 0), 100.0, [far]) == flyer, "nächster ohne die übersprungenen")
	# Bollwerk: 3D-Gegner mit Radius
	var h := FakeGame.new()
	add_child(h)
	SystemHost.attach(h, "heroes", ["targeting"])
	var a := E3.new()
	a.position = Vector3(3, 0, 4)
	a.radius = 1.0
	h.add_child(a)
	h.enemies = [a]
	check(str(h.systems.targeting.cfg.position) == "xz", "heroes: Bodenpunkt aus position (Kaskade)")
	check(h.systems.targeting.nearest(Vector2.ZERO, 4.0) == a, "Ausdehnung zählt zur Reichweite (5 - 1 <= 4)")
	check(h.systems.targeting.nearest(Vector2.ZERO, 3.9) == null, "knapp außerhalb: keiner")
	check(h.systems.targeting.enemies_in_radius(Vector2.ZERO, 4.0) == [a], "Kreis mit Ausdehnung")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
