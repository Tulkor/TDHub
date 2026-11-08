extends Node
## Lauf: einzeln (Name geschosse)
## Modi: kern
## Geschosse wie in Path of Exile: Durchbohren, Gabeln, Verketten und ihre Reihenfolge (tower.gd → _projectile).
## Ein Tower bei (0, 0) schießt nach rechts auf einen Gegner bei (2, 0), ohne Spielfeld und Wellen.

var failures := 0
var enemies := []
var beams := 0


class FakeGame:
	extends RefCounted
	var test

	func enemies_in_radius(p: Vector2, radius: float) -> Array:
		return test.enemies.filter(func(e): return not e.dead and e.pos.distance_to(p) <= radius)

	func add_beam(_from: Vector3, _to: Vector3, _col: Color, _fx: String = "") -> void:
		test.beams += 1

	func on_enemy_killed(_e) -> void:
		pass

	func current_wave() -> int:
		return 1

	func add_gold(_g: int, _p: int) -> void:
		pass


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


## Schießt einmal auf den ersten Gegner und gibt den Schaden je Gegner zurück.
func shoot(abilities: Array, spots: Array) -> Array:
	var game := FakeGame.new()
	game.test = self
	for e in enemies:
		e.free()
	enemies.clear()
	beams = 0
	for p in spots:
		var e := Enemy.new()
		e.game = game
		e.max_hp = 1000.0
		e.hp = 1000.0
		e.pos = p
		enemies.append(e)
	var t := Tower.new()
	t.game = game
	t.stats = {"damage": [10, 10], "range": 5.0, "cooldown": 1.0, "abilities": abilities}
	t._attack(enemies[0])
	t.free()
	return enemies.map(func(e): return roundi(1000.0 - e.hp))


func _ready() -> void:
	var line := [Vector2(2, 0), Vector2(3, 0), Vector2(4, 0), Vector2(5, 0)]
	var got := shoot([], line)
	check(got == [10, 0, 0, 0], "ohne Fähigkeit nur das Ziel getroffen: %s" % [got])
	got = shoot([{"type": "pierce", "count": 2}], line)
	check(got == [10, 10, 10, 0], "Durchbohren 2: Ziel und zwei dahinter: %s" % [got])
	got = shoot([{"type": "pierce", "count": 5}], [Vector2(2, 0), Vector2(3, 0.2), Vector2(4, 1.0), Vector2(-1, 0)])
	check(got == [10, 10, 0, 0], "Durchbohren trifft nur auf der Flugbahn, nicht daneben oder dahinter: %s" % [got])

	# Gabeln: zwei Geschosse unter ±30°, das gegabelte Ziel wird nicht noch einmal getroffen
	var up := Vector2(2, 0) + Vector2.RIGHT.rotated(deg_to_rad(30)) * 2.0
	var down := Vector2(2, 0) + Vector2.RIGHT.rotated(deg_to_rad(-30)) * 2.0
	got = shoot([{"type": "fork", "count": 1, "angle": 30.0, "reach": 3.0}], [Vector2(2, 0), up, down, Vector2(4, 0)])
	check(got == [10, 10, 10, 0], "Gabeln: beide Äste treffen, geradeaus nichts: %s" % [got])
	check(beams == 3, "Gabeln: ein Strahl zum Ziel und zwei Äste (%d)" % beams)

	# Reihenfolge wie in PoE: erst durchbohren, dann gabeln
	var up2 := Vector2(3, 0) + Vector2.RIGHT.rotated(deg_to_rad(30)) * 2.0
	var down2 := Vector2(3, 0) + Vector2.RIGHT.rotated(deg_to_rad(-30)) * 2.0
	got = shoot([{"type": "fork", "count": 1, "angle": 30.0, "reach": 3.0}, {"type": "pierce", "count": 1}],
			[Vector2(2, 0), Vector2(3, 0), up2, down2, up, down])
	check(got == [10, 10, 10, 10, 0, 0], "Durchbohren vor Gabeln: gegabelt wird erst am zweiten Gegner: %s" % [got])

	# Verketten: springt zum nächsten Gegner, nie zurück
	got = shoot([{"type": "chain", "count": 2, "radius": 2.5, "factor": 0.5}], [Vector2(2, 0), Vector2(2, 2), Vector2(2, 4), Vector2(2, 6)])
	check(got == [10, 5, 3, 0], "Verketten 2: zwei Sprünge mit halbem Schaden je Sprung: %s" % [got])

	# Reihenfolge wie in PoE: erst gabeln, dann verketten. Jeder Ast ist ein eigenes Geschoss und springt
	# für sich: der obere Ast springt zum unteren Gegner (den nur der untere Ast schon getroffen hat),
	# der untere Ast zum Nachbarn des Ziels.
	var near := Vector2(2, -1.0)
	got = shoot([{"type": "chain", "count": 1, "radius": 2.5}, {"type": "fork", "count": 1, "angle": 30.0, "reach": 3.0}],
			[Vector2(2, 0), up, down, near])
	check(got == [10, 10, 20, 10], "Gabeln vor Verketten: beide Äste treffen und springen danach je einmal: %s" % [got])
	check(beams == 5, "Gabeln vor Verketten: Ziel, zwei Äste, zwei Sprünge (%d Strahlen)" % beams)

	# Alle drei: durchbohren → gabeln → verketten
	var side := up2 + Vector2(0, 1.5)
	got = shoot([{"type": "chain", "count": 1, "radius": 1.8}, {"type": "fork", "count": 1, "angle": 30.0, "reach": 3.0}, {"type": "pierce", "count": 1}],
			[Vector2(2, 0), Vector2(3, 0), up2, down2, side])
	check(got == [10, 10, 10, 10, 10], "Durchbohren, Gabeln, Verketten nacheinander: %s" % [got])

	# Obergrenze: viele Gabelungen schaukeln sich nicht endlos auf
	var crowd := [Vector2(2, 0)]
	for i in 200:
		crowd.append(Vector2(2 + randf_range(-3, 3), randf_range(-3, 3)))
	got = shoot([{"type": "fork", "count": 8, "angle": 20.0, "reach": 3.0}, {"type": "chain", "count": 5, "radius": 3.0}], crowd)
	var hit := got.filter(func(d): return d > 0).size()
	check(hit <= Tower.SHOT_MAX_HITS, "Obergrenze: %d Treffer bei 8 Gabelungen" % hit)

	# Texte fürs Infofenster
	check(Abilities.describe(Abilities.default_for("pierce")) == "Geschoss durchbohrt 2 Gegner", Abilities.describe(Abilities.default_for("pierce")))
	check("50%" in Abilities.describe({"type": "chain", "count": 3, "radius": 2.0, "factor": 0.5}), Abilities.describe({"type": "chain", "count": 3, "radius": 2.0, "factor": 0.5}))
	for e in enemies:
		e.free()
	print("Fertig: %d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
