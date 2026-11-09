extends Node
## Lauf: einzeln (Name visuals)
## Modi: kern, system:visuals
## Kaskade, gleichzeitige Gegnerzustände, Zuschauerflags, Qualitätswechsel und Effekt-Obergrenzen.

var failures := 0


class VisibilityGame:
	extends RefCounted
	var detected := false

	func is_detected(_enemy) -> bool:
		return detected


func check(ok: bool, message: String) -> void:
	if ok:
		print("OK   ", message)
	else:
		failures += 1
		printerr("FAIL ", message)


func _ready() -> void:
	await get_tree().process_frame
	var saved_quality: int = Display.quality
	var mode: Dictionary = Database.modes[0]
	var original: Dictionary = mode.get("system_cfg", {}).duplicate(true)
	mode["system_cfg"] = SystemHost.cascade(original, {"visuals": {"range": {"fill": 0.09}, "wind": {"enabled": false}}})
	VisualFx._configs.clear()
	var game: Node = load("res://scripts/game/game.gd").new()
	var cfg := VisualFx.config(game)
	check(is_equal_approx(float(cfg.range.fill), 0.09) and not cfg.wind.enabled, "Modus überschreibt gezielt die visuelle Basis")
	check(cfg.status.enabled and is_equal_approx(float(cfg.range.motion), 0.12), "nicht überschriebene Basiswerte bleiben erhalten")
	mode["system_cfg"] = original
	VisualFx._configs.clear()
	game.free()

	var enemy := Enemy.new()
	add_child(enemy)
	enemy.set_process(false)
	enemy._body = MeshInstance3D.new()
	enemy._body.mesh = BoxMesh.new()
	enemy.add_child(enemy._body)
	enemy.hp = 100.0
	enemy.max_hp = 100.0
	enemy._setup_status()
	check(enemy._body.material_overlay == enemy._overlay, "auch Platzhalter ohne Animation bekommen Zustandsmuster")
	enemy.slow_time = 2.0
	enemy.poison_time = 2.0
	enemy.stun_time = 2.0
	enemy.armor_reduction_time = 2.0
	enemy.invulnerable_time = 2.0
	enemy.burn_visual_time = 2.0
	enemy._update_status()
	for parameter in ["frost", "poison", "stun", "armor_break", "invulnerable", "burning"]:
		check(enemy._overlay.get_shader_parameter(parameter) == 1.0, "gleichzeitiger Zustand: " + parameter)
	var packet := enemy.net_state()
	check(int(packet[6]) == 63, "alle visuellen Zustände passen in das bestehende Flag-Feld")
	var remote := Enemy.new()
	remote.apply_net_state(packet)
	check(remote.armor_reduction_time > 0.0 and remote.invulnerable_time > 0.0 and remote.burn_visual_time > 0.0, "Zuschauer erhalten auch Rüstungsbruch, Schutz und Feuer")
	remote.free()
	var hidden := MaulEnemy.new()
	var vision := VisibilityGame.new()
	hidden.game = vision
	hidden.invisible = true
	check(not hidden.status_visible(), "Maul: Unsichtbarkeit hat Vorrang vor neuer Sichtbarkeit")
	vision.detected = true
	check(hidden.status_visible(), "Maul: erst enttarnte Gegner bekommen Zusatzdarstellung")
	hidden.free()

	Display.quality = Display.LOW
	Display.apply_quality()
	var xray: ShaderMaterial = enemy._overlay.get_meta("occlusion_material")
	check(enemy._overlay.next_pass == null, "Niedrig: kein verdeckter Konturpass aktiv")
	var gem := VisualFx.gem_material(null, true)
	gem.set_shader_parameter("color", Color.RED)
	check(gem.shader == VisualFx.GEM, "Niedrig: Gem ohne Bildschirmtextur")
	var base := StandardMaterial3D.new()
	base.albedo_color = Color(0.2, 0.6, 0.3)
	var wind := VisualFx.wind_material(base, AABB(Vector3.ZERO, Vector3.ONE), self)
	check(is_zero_approx(float(wind.get_shader_parameter("wind_strength"))), "Niedrig: Wind steht still")
	Display.quality = Display.HIGH
	Display.apply_quality()
	check(gem.shader == VisualFx.GEM_HIGH and gem.get_shader_parameter("color") == Color.RED, "Hoch: Brechung aktiviert, Towerfarbe bleibt erhalten")
	check(xray.get_shader_parameter("enabled") and float(wind.get_shader_parameter("wind_strength")) > 0.0, "Qualitätswechsel aktiviert vorhandene Konturen und Wind")
	enemy.free()

	var root := Node3D.new()
	add_child(root)
	for i in 40:
		VisualFx.pulse(root, Vector3.ZERO, 2.0, Color.CYAN, 1.0, 0.05)
		VisualFx.shockwave(root, Vector3.ZERO, 2.0)
	check(get_tree().get_nodes_in_group("visual_transient").size() == VisualFx.MAX_TRANSIENTS, "Bodenpulse sind begrenzt")
	check(get_tree().get_nodes_in_group("visual_shockwave").size() == 3, "höchstens drei Druckwellen gleichzeitig")
	await get_tree().create_timer(0.7).timeout
	check(get_tree().get_nodes_in_group("visual_transient").is_empty() and get_tree().get_nodes_in_group("visual_shockwave").is_empty(), "kurzlebige Effekte geben ihre Knoten frei")
	root.queue_free()
	Display.quality = saved_quality
	Display.apply_quality()
	print("Visuals: %d Fehler" % failures)
	get_tree().quit(1 if failures else 0)
