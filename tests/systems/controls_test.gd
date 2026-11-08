extends Node
## Lauf: einzeln (Name syscontrols)
## Modi: system:controls
## System controls ohne Modus: Auswahlrahmen je Modus (Kaskade), nur erlaubte Spieltempi, Tempo gemerkt nur solo.
## Start: tools/run_tests.sh syscontrols

var failures := 0


class FakeGame extends Node:
	var systems := {}
	var alone := true

	func solo() -> bool:
		return alone


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	var g := FakeGame.new()
	add_child(g)
	SystemHost.attach(g, "gemtd", ["controls"])
	var e := FakeGame.new()
	add_child(e)
	SystemHost.attach(e, "eevetd", ["controls"])
	check(g.systems.controls.box_select() and not e.systems.controls.box_select(), "Auswahlrahmen nur GemTD")
	var before := Session.speed
	check(not g.systems.controls.set_speed(3.0), "3× nicht erlaubt")
	check(g.systems.controls.set_speed(2.0) and Engine.time_scale == 2.0 and Session.speed == 2.0, "2× solo, gemerkt")
	g.alone = false
	Session.speed = 1.0
	check(g.systems.controls.set_speed(4.0) and Engine.time_scale == 4.0 and Session.speed == 1.0, "4× im Mehrspieler, nicht gemerkt")
	Engine.time_scale = 1.0
	Session.speed = before
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
