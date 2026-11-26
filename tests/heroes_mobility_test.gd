extends Node
## Lauf: einzeln (Name heroesmobility)
## Modi: heroes
## Kampfpause, Laufbonus aller Helden, echte Bewegung und unverändertes Ausweichen.

var checks := 0
var failures := 0


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", text)


func _ready() -> void:
	Session.skip_setup = true
	Session.coop = {}
	Session.difficulty = 0
	var g: HdGame = load("res://scenes/heroes_game.tscn").instantiate()
	g.bot = true
	g.force_hero = "torvik"
	g.persist_settings = false
	add_child(g)
	g.set_physics_process(false)
	g.set_process(false)
	g.spawn_queue.clear()
	for id in ["torvik", "unrat", "vesna", "zix"]:
		g.set_hero(id)
		var h: HdHero = g.hero
		h.auto_attack = false
		h.attack_held = false
		h.order = {}
		g.play_time = 10.0
		h.mark_combat()
		g.play_time = 14.999
		check(not h.out_of_combat() and is_equal_approx(h.run_bonus(), 1.0), id + ": vor fünf Sekunden kein Bonus")
		g.play_time = 15.0
		check(h.out_of_combat() and is_equal_approx(h.run_bonus(), 1.7), id + ": nach fünf Sekunden 70 % Laufbonus")
		var interval: float = h.attack_interval()
		var dodge_distance: float = h.def.dodge.distance
		var origin := Vector3(-10, 0, 0)
		h.position = origin
		h.move_dir = Vector3.LEFT
		h.mark_combat()
		h.step(0.1, g.play_time)
		var combat_distance: float = origin.distance_to(h.position)
		g.play_time += 5.0
		h.position = origin
		h.step(0.1, g.play_time)
		check(is_equal_approx(origin.distance_to(h.position), combat_distance * 1.7), id + ": tatsächliche WASD-Bewegung ist 70 % schneller")
		check(is_equal_approx(interval, h.attack_interval()) and is_equal_approx(dodge_distance, float(h.def.dodge.distance)), id + ": Angriffstempo und Ausweichdistanz bleiben gleich")
		h.move_dir = Vector3.ZERO
		h.attack_cd = 0.0
		h.attack_held = true
		h.aim = h.position + Vector3.LEFT * 10
		h.step(0.01, g.play_time)
		check(not h.out_of_combat() and is_equal_approx(h.combat_until, g.play_time + 5.0), id + ": Luftangriff beendet Laufbonus")
		h.attack_held = false
		g.play_time += 5.0
		h.add_shield(100, 20)
		var hurt: float = h.incoming(10)
		check(is_zero_approx(hurt) and not h.out_of_combat(), id + ": vollständig absorbierter Treffer zählt als Kampf")
		g.play_time += 5.0
		h.incoming(0)
		check(h.out_of_combat(), id + ": Nullschaden startet keine neue Kampfpause")
		h.die()
		g.play_time += 10.0
		check(not h.out_of_combat(), id + ": kein Laufbonus während Tod")
		h._respawn()
		check(not h.out_of_combat() and is_equal_approx(h.combat_until, g.play_time + 5.0), id + ": Respawn beginnt mit neuer Fünfsekundenfrist")
	g.set_hero("torvik")
	g.hero.auto_attack = false
	g.play_time += 6.0
	g.hero.cd[0] = 0
	check(g.hero.cast(0, g.hero.position + Vector3.LEFT * 3) and not g.hero.out_of_combat(), "Offensiver Fähigkeitswurf ohne Gegner beendet Laufbonus")
	g.set_hero("unrat")
	g.hero.auto_attack = false
	g.play_time += 6.0
	g.hero.cd[2] = 0
	check(g.hero.cast(2, g.hero.position) and g.hero.out_of_combat(), "Reine Schildfähigkeit unterbricht Erkundungstempo nicht")
	g.queue_free()
	await get_tree().process_frame
	print("FERTIG, %d Prüfungen, Fehler: %d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
