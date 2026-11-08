extends Node
## Lauf: einzeln (Name lebensbalken)
## Modi: kern
## Lebensbalken der Gegner (enemy.gd → bar_visible): Bosse immer, Massenwellen nie, alle anderen erst auf
## dem letzten Stück des Wegs (balance.json → health_bar_last), danach bleibt der Balken an.

var failures := 0


class FakeGame:
	extends RefCounted

	func on_enemy_killed(_e) -> void:
		pass

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


func _make(def: Dictionary, o: Dictionary, path: PackedVector2Array) -> Enemy:
	var e := Enemy.new()
	add_child(e)
	var d := {"id": "x", "hp": 100}
	d.merge(def)
	e.setup(FakeGame.new(), d, o, path)
	return e


func _shown(e: Enemy) -> bool:
	return e._bar_fg.visible and e._bar_bg.visible


func _ready() -> void:
	var last := float(Database.balance.get("health_bar_last", 0.1))
	check(is_equal_approx(last, 0.1), "Schwelle 10 % in balance.json")
	# Weg mit Knick, 100 Towerbreiten lang
	var path := PackedVector2Array([Vector2.ZERO, Vector2(60, 0), Vector2(60, 40)])

	var normal := _make({}, {}, path)
	normal.place_on_path(10.0)
	check(not _shown(normal), "Normaler Gegner am Anfang ohne Balken")
	normal.place_on_path(85.0)
	check(not _shown(normal), "Normaler Gegner bei 85 % ohne Balken")
	normal.place_on_path(91.0)
	check(_shown(normal), "Normaler Gegner auf den letzten 10 % mit Balken")
	normal.place_on_path(50.0)
	check(_shown(normal), "Einmal eingeblendet bleibt der Balken")

	var boss := _make({"boss": true}, {}, path)
	boss._update_visual()
	check(_shown(boss), "Boss zeigt den Balken von Anfang an")

	var mass := _make({}, {"shape": "pyramid"}, path)
	mass.place_on_path(99.0)
	check(not _shown(mass), "Massenwelle zeigt nie einen Balken")
	var mass_air := _make({"flying": true, "shape": "pyramid"}, {}, path)
	mass_air.place_on_path(99.0)
	check(not _shown(mass_air), "Massenflieger zeigt nie einen Balken")

	var flyer := _make({"flying": true}, {}, path)
	flyer.place_on_path(95.0)
	check(_shown(flyer), "Flieger am Ende mit Balken")
	_finish()


func _finish() -> void:
	print("FERTIG ", "OK" if failures == 0 else "%d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
