extends Node
## Lauf: einzeln (Name treffer)
## Modi: kern
## Treffer-Effekte: Wahl nach Farbe (Feuer nur für warme Tower), Treffer erst beim Einschlag des Geschosses,
## Treffer-Lichter in der Schussfarbe mit fester Obergrenze (fx_data.gd, fx_player.gd, effects.gd).

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK   ", msg)
	else:
		failures += 1
		printerr("FAIL ", msg)


func _ready() -> void:
	# Splash: Rubin (rot) explodiert, Silber (blass) und Wasser-Grundturm (blau) spritzen ohne Feuer
	var ruby := FxData.for_tower("ruby", 2)
	check(ruby.hit.id == "bk_explosion" and ruby.shot.id == "fire_orb", "Rubin: Feuer %s" % [ruby])
	for id in ["silver", "eeve_water_base_tower"]:
		var f := FxData.for_tower(id, 0)
		check(f.hit.id == "kb_splash" and f.shot.id == "energy_orb", "%s: kein Feuer %s" % [id, f])

	var effects := Effects.new()
	add_child(effects)
	var fx := effects.fx
	# Geschoss: Treffer und Licht erst nach der Flugzeit
	var fly := float(FxData.shot("energy_orb").length)
	effects.add_beam(Vector3.ZERO, Vector3(3, 0.3, 0), Color.CYAN, "t:eeve_water_base_tower:0")
	fx._process(fly * 0.5)
	check(fx.lights_active() == 0, "vor dem Einschlag kein Licht")
	fx._process(fly * 0.6)
	check(fx.lights_active() == 1, "beim Einschlag ein Licht")
	var light: OmniLight3D = fx._lights[0].node
	check(light.light_color.b > light.light_color.r, "Licht in Schussfarbe (blau): %s" % light.light_color)

	# Viele Treffer gleichzeitig: nahe Treffer teilen sich ein Licht, insgesamt höchstens MAX_LIGHTS
	fx.clear()
	effects.add_beam(Vector3.ZERO, Vector3(5, 0.3, 5), Color.RED, "t:ruby:2")
	effects.add_beam(Vector3.ZERO, Vector3(5.2, 0.3, 5), Color.RED, "t:ruby:2")
	fx._process(1.0 / 60.0 + float(FxData.shot("fire_orb").length))
	check(fx.lights_active() == 1, "zwei Treffer nebeneinander = ein Licht (%d)" % fx.lights_active())
	for i in 40:
		effects.add_beam(Vector3.ZERO, Vector3(i * 2.0, 0.3, 0), Color.RED, "t:ruby:2")
	fx._process(0.3)
	check(fx._lights.size() <= FxPlayer.MAX_LIGHTS and fx.lights_active() > 0, "40 Treffer: %d Lichter" % fx._lights.size())
	fx._process(1.0)
	fx._process(1.0)
	check(fx.lights_active() == 0, "Lichter gehen wieder aus")

	FxPlayer.lights_enabled = false
	effects.add_beam(Vector3.ZERO, Vector3(3, 0.3, 0), Color.RED, "t:ruby:2")
	fx._process(1.0)
	check(fx.lights_active() == 0, "Lichter ausgeschaltet")
	FxPlayer.lights_enabled = true

	print("Fertig: %d Fehler" % failures)
	get_tree().quit(1 if failures > 0 else 0)
