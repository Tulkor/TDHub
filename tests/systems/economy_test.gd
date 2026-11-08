extends Node
## Lauf: einzeln (Name syseconomy)
## Modi: system:economy
## System economy ohne Modus: Einkommens-Faktor fest, mit Anstieg und aus data/balance.json (Kaskade),
## Bruchteile sammeln, Gold ohne Besitzer verteilen oder dem handelnden Spieler geben, direkt gutschreiben.
## Start: tools/run_tests.sh syseconomy

var failures := 0
var wave := 1


class Pl extends RefCounted:
	var gold := 0
	var gold_frac := 0.0


class PlNoFrac extends RefCounted:
	var gold := 0


class FakeGame extends Node:
	var systems := {}
	var players: Array = []
	var acting := 0
	var wave := 1

	func current_wave() -> int:
		return wave


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
	g.players = [Pl.new(), Pl.new()]
	SystemHost.attach(g, "eevetd", ["economy"])
	var ec = g.systems.economy
	check(is_equal_approx(ec.income_factor(30), 1.0), "eeveTD: volles Gold (Basiswert)")
	ec.earn(3.0)
	check(g.players[0].gold == 1 and is_equal_approx(g.players[0].gold_frac, 0.5), "ohne Besitzer verteilt, Bruchteil bleibt")
	ec.earn(0.5, 0)
	check(g.players[0].gold == 2 and is_equal_approx(g.players[0].gold_frac, 0.0), "Bruchteile werden zu Gold")
	ec.cfg = SystemHost.cascade(ec.cfg, {"income": 0.5, "ramp": {"from_wave": 10, "to_wave": 20, "to_factor": 1.0}})
	check(is_equal_approx(ec.income_factor(5), 0.5) and is_equal_approx(ec.income_factor(15), 0.75)
		and is_equal_approx(ec.income_factor(40), 1.0), "Faktor steigt linear")
	var gm := FakeGame.new()
	add_child(gm)
	SystemHost.attach(gm, "gemtd", ["economy"])
	check(is_equal_approx(gm.systems.economy.income_factor(1), float(Database.balance.get("gold_income_factor", 1.0))),
		"gemtd: Faktor aus balance.json (Kaskade)")
	var m := FakeGame.new()
	add_child(m)
	m.players = [PlNoFrac.new(), PlNoFrac.new()]
	m.acting = 1
	SystemHost.attach(m, "shoppingmaul", ["economy"])
	m.systems.economy.earn(4.0)
	check(m.players[1].gold == 4 and m.players[0].gold == 0, "maul: Gold ohne Besitzer an den handelnden Spieler")
	m.systems.economy.add(7, 0)
	check(m.players[0].gold == 7, "direkt gutschreiben")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
