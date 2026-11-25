extends Node
## Lauf: einzeln (Name schwierigkeit)
## Modi: system:difficulty
## Schwierigkeitsleiter aller Modi ohne Simulation (tools/testlauf/druck.gd): je Modus muss jede Stufe mehr Druck
## pro Startleben haben als die davor (Einfach < Mittel < Schwer < Schwer +3). Dazu die Messung der Testläufe
## (effektive Leben mit Rüstung, Welle und Leben je Modus) und das Lesen der Schwierigkeit aus der Befehlszeile.

const Druck := preload("res://tools/testlauf/druck.gd")
const Messung := preload("res://tools/testlauf/messung.gd")
const Testlauf := preload("res://tools/testlauf/testlauf.gd")
const MODI := ["gemtd", "eevetd", "shoppingmaul", "randgruppen", "youtd"]

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	Profile.dir = "user://test_schwierigkeit"
	Profile.reset_cache()
	await get_tree().process_frame

	# Schwierigkeit aus der Befehlszeile: Namen oder 0..2, Unbekanntes = Mittel
	check(Testlauf.schwierigkeit("einfach") == 0 and Testlauf.schwierigkeit("Schwer") == 2, "Namen der Schwierigkeit")
	check(Testlauf.schwierigkeit("2") == 2 and Testlauf.schwierigkeit("7") == 2, "Zahl, auf 0..2 begrenzt")
	check(Testlauf.schwierigkeit("quatsch") == 1, "Unbekanntes = Mittel")

	# Effektive Leben wie Enemy.take_damage: Rüstung 5 → 23,1 % weniger Schaden, negative Rüstung mehr
	var e := Enemy.new()
	e.max_hp = 100.0
	check(is_equal_approx(Messung.ehp(e), 100.0), "ohne Rüstung: effektive = echte Leben")
	e.armor = 5.0
	check(absf(Messung.ehp(e) - 100.0 / (1.0 - 0.3 / 1.3)) < 0.01, "Rüstung 5: WC3-Formel")
	e.armor = -3.0
	check(Messung.ehp(e) < 100.0, "negative Rüstung: weniger effektive Leben")
	e.free()
	check(Messung.welle_von({"level": 4}) == 3 and Messung.welle_von({"wave_index": 2, "level": 9}) == 2,
		"Welle: wave_index, sonst Maul-Level ab 1")
	check(Messung.leben_von({"portal": 80.0, "lives": 3}) == 80.0 and Messung.gold_von({"players": [{"gold": 12}]}) == 12,
		"YouTD-Portal und Maul-Gold je Spieler")

	# Leiter je Modus
	var druck: Node = Druck.new()
	add_child(druck)
	for m in MODI:
		var stufen := [[0, 0], [1, 0], [2, 0], [2, 3]]
		var prev := {}
		for st in stufen:
			var r: Dictionary = await druck.messen(m, st[0], st[1])
			var name := "%s %s%s" % [m, r.schwierigkeit, " +%d" % r.aufstieg if r.aufstieg > 0 else ""]
			check(r.wellen.size() > 10 and int(r.summe_ehp) > 0, "%s: %d Wellen mit Gegnern" % [name, r.wellen.size()])
			if not prev.is_empty():
				check(int(r.druck_pro_leben) > int(prev.druck_pro_leben), "%s schwerer als die Stufe davor (%d > %d)" % [
						name, r.druck_pro_leben, prev.druck_pro_leben])
			prev = r
		check(prev.aufstieg == 3, "%s: Aufstieg auf Schwer übernommen" % m)

	print("FERTIG" if failures == 0 else "FEHLER: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
