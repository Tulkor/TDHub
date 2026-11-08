extends Node
## Lauf: einzeln (Name syscoop)
## Modi: system:coop
## System coop ohne Modus: erlaubte Befehle (Basis + Modus), Modus-Stand aus system_cfg.coop.fields hin und zurück
## (ganze Sekunden, Schlüsselliste, leere Liste behält den Stand), Tower-Metadaten, Haken, Weggehen.
## Start: tools/run_tests.sh syscoop

var failures := 0


class Pl extends RefCounted:
	var away := false


class FakeTower extends RefCounted:
	var cell := Vector2i(2, 4)

	func is_trap() -> bool:
		return false


class FakeGame extends Node:
	var systems := {}
	var players: Array = []
	var difficulty := 1
	var level_pause := 0.0
	var ready_players := {}
	var rg_players: Array = []
	var towers: Array = []
	var away_calls: Array = []
	var applied: Array = []

	func all_towers() -> Array:
		return towers

	func coop_extra() -> Dictionary:
		return {"x": 7}

	func coop_applied(d: Dictionary, changed: Array) -> void:
		applied = [d.get("x"), changed]

	func on_player_away(p: int, away: bool) -> void:
		away_calls.append([p, away])


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	var host := FakeGame.new()
	add_child(host)
	SystemHost.attach(host, "eevetd", ["coop"])
	var co = host.systems.coop
	check(co.commands().has("place") and co.commands().has("market_buy"), "Befehle: Basis + eeveTD")
	var gm := FakeGame.new()
	add_child(gm)
	SystemHost.attach(gm, "gemtd", ["coop"])
	check(not gm.systems.coop.commands().has("market_buy"), "GemTD ohne eeveTD-Befehle")
	host.difficulty = 2
	host.level_pause = 3.2
	host.ready_players = {1: true}
	var t := FakeTower.new()
	t.set_meta("spent", 40)
	host.towers = [t]
	var s: Dictionary = JSON.parse_string(JSON.stringify(co.snapshot()))  # wie übers Netz
	check(int(s.pause) == 4, "Pause in ganzen Sekunden")
	check(s.x == 7, "Haken coop_extra kommt dazu")
	var mate := FakeGame.new()
	add_child(mate)
	SystemHost.attach(mate, "eevetd", ["coop"])
	var t2 := FakeTower.new()
	mate.towers = [t2]
	mate.ready_players = {0: true, 3: true}
	mate.systems.coop.apply(s)
	check(mate.difficulty == 2 and typeof(mate.difficulty) == TYPE_INT, "Zahl übernommen und bleibt int")
	check(is_equal_approx(mate.level_pause, 4.0), "Pause übernommen")
	check(mate.ready_players.keys() == [1], "Schlüsselliste wird Wörterbuch mit int")
	check(int(t2.get_meta("spent", 0)) == 40, "Tower-Metadaten")
	check(mate.applied[0] == 7 and mate.applied[1].has("difficulty") and mate.applied[1].has("pause"), "coop_applied mit geänderten Feldern")
	var rg := FakeGame.new()
	add_child(rg)
	SystemHost.attach(rg, "randgruppen", ["coop"])
	rg.rg_players = [{"race": "a"}]
	rg.systems.coop.apply({"players": []})
	check(rg.rg_players.size() == 1, "leere Liste behält den Stand")
	host.players = [Pl.new(), Pl.new()]
	co.set_away(1, true)
	co.set_away(1, true)
	co.set_away(5, true)
	check(host.players[1].away and host.away_calls == [[1, true]], "Weggehen: einmal, Haken on_player_away")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
