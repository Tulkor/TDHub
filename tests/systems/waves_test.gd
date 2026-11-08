extends Node
## Lauf: einzeln (Name syswaves)
## Modi: system:waves
## System waves ohne Modus: Spawn-Warteschlange mit Abständen und Nachlaufen verspäteter Gegner,
## Auto-Welle laut Kaskade (eeveTD: Bauphase ab Welle 2, Befehl start_level; YouTD: Haken des Modus).
## Start: tools/run_tests.sh syswaves

var failures := 0


class FakeEnemy extends RefCounted:
	var ran := 0.0

	func _process(d: float) -> void:
		ran += d


class FakeGame extends Node:
	var systems := {}
	var phase := 0
	var wave_index := 0
	var sent: Array = []
	var rule := false

	func submit(cmd: Dictionary) -> bool:
		sent.append(cmd)
		return true

	func auto_wave_rule() -> bool:
		return rule


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
	SystemHost.attach(g, "eevetd", ["waves"])
	var w = g.systems.waves
	var made: Array = []
	var spawn := func(entry): var e := FakeEnemy.new(); made.append(e); return [e]
	var gap := func(entry): return float(entry.interval)
	var queue := [{"interval": 1.0}, {"interval": 1.0}, {"interval": 1.0}]
	var t: float = w.drain(queue, 0.5, 0.25, spawn, gap)
	check(made.is_empty() and is_equal_approx(t, 0.25), "noch nicht fällig: nichts gespawnt")
	t = w.drain(queue, t, 1.5, spawn, gap)
	check(made.size() == 2 and queue.size() == 1, "zwei fällig in einem langen Bild")
	check(is_equal_approx(made[0].ran, 1.25) and is_equal_approx(made[1].ran, 0.25), "verspätete Gegner laufen nach")
	check(is_equal_approx(t, 0.75), "Timer zählt vom fälligen Zeitpunkt weiter")
	check(w.has_auto(), "eeveTD hat Auto (Kaskade)")
	g.phase = 0
	g.wave_index = 0
	check(not w.auto_due(), "vor Welle 1 kein Auto")
	g.wave_index = 3
	check(w.auto_due(), "Bauphase ab Welle 2: Auto fällig")
	g.phase = 2
	check(not w.auto_due(), "während der Welle nicht")
	w.next_now()
	check(g.sent == [{"type": "start_level"}], "nächste Welle per Befehl start_level")
	var y := FakeGame.new()
	add_child(y)
	SystemHost.attach(y, "youtd", ["waves"])
	y.rule = true
	check(y.systems.waves.auto_due(), "YouTD: Haken auto_wave_rule entscheidet")
	var m := FakeGame.new()
	add_child(m)
	SystemHost.attach(m, "gemtd", ["waves"])
	check(not m.systems.waves.has_auto(), "GemTD: kein Auto (Basiswert)")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
