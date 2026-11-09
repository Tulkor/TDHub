extends Node
## Lauf: einzeln (Name syschallenges)
## Modi: system:challenges
## System challenges (challenges) ohne Modus: an einem leeren Spiel-Knoten angelegt und geprüft.
## Start: tools/run_tests.sh syschallenges

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	await get_tree().process_frame
	var game := Node.new()
	add_child(game)
	var got := SystemHost.attach(game, "", ["challenges"])
	check(got.has("challenges"), "challenges lässt sich ohne Modus anlegen")
	var ch = got.challenges
	ch.list = [{"id": "x", "reward": {"boss": {"hp": -0.1, "remove": ["a"]}, "hero": {"speed": 0.2}}},
		{"id": "y", "reward": {"boss": {"hp": -0.05, "remove": ["b"]}}}]
	ch.cfg = {"awaken": 30.0, "retry": false}
	ch.enter()
	check(ch.open and ch.state_of("x") == "open", "Gebiet betreten: alles offen")
	check(ch.begin("x") == "" and ch.begin("y") != "", "nur eine Challenge gleichzeitig")
	ch.finish("x", true)
	check(ch.state_of("x") == "done" and ch.begin("x") != "", "geschafft bleibt geschafft")
	ch.begin("y")
	ch.finish("y", false)
	check(ch.state_of("y") == "failed" and ch.begin("y") != "", "retry false: gescheitert bleibt gescheitert")
	var m: Dictionary = ch.boss_mods()
	check(is_equal_approx(float(m.hp), -0.1) and m.remove == ["a"], "nur geschaffte Belohnungen zählen")
	ch.tick(31.0)
	check(ch.boss_started and ch.boss_reason == "awaken", "Endboss erwacht nach awaken")
	print("\n%s: %d Fehler" % ["BESTANDEN" if failures == 0 else "FEHLGESCHLAGEN", failures])
	get_tree().quit(1 if failures > 0 else 0)
