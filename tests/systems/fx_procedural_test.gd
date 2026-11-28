extends Node3D
## Lauf: einzeln (Name fxprocedural)
## Modi: kern
## Flugbahn, begrenzte Batches, Lebensende, Grafikstufen und dauerhafte Tower.

const PROC := preload("res://scripts/game/fx_procedural.gd")
const TOWERS := preload("res://scripts/game/tower_element_fx.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func _ready() -> void:
	Sfx.audible = false
	var saved := Display.quality
	var a := Vector3.ZERO
	var b := Vector3(2, 0, 0)
	check(PROC.position_at(a, b, 0.0, 0.8).is_equal_approx(a), "Bogen startet am Abschuss")
	check(PROC.position_at(a, b, 1.0, 0.8).is_equal_approx(b), "Bogen endet genau am Ziel")
	check(is_equal_approx(PROC.position_at(a, b, 0.5, 0.8).y, Board3D.CELL * 0.8), "Bogenhöhe relativ zu CELL")
	for quality in [Display.HIGH, Display.LOW]:
		Display.quality = quality
		var fx := FxPlayer.new()
		add_child(fx)
		fx.set_process(false)
		for id in ["stone_arc", "arrow", "cannonball", "frost_bolt", "poison_glob", "water_jet", "chain_lightning"]:
			fx.play_shot({"id": id}, a, b)
		fx._process(0.18)
		check(fx._sprites.size() == 7, "Sieben aktive Geschosse")
		var proc: RefCounted = fx._procedural
		check(proc != null and proc.batches.size() <= 12, "Material-Batches begrenzt")
		var count: int = proc.batches.trail.items.size()
		check(count == (12 if quality == Display.LOW else 24), "Halbe Spurpartikel auf Niedrig: %d" % count)
		check(proc.batches.lightning.items.size() == (6 if quality == Display.LOW else 12), "Blitzsegmente halbiert")
		var segments: Array = proc.batches.lightning.items
		for i in range(1, segments.size()):
			var previous: Transform3D = segments[i - 1][0]
			var current: Transform3D = segments[i][0]
			check((previous.origin + previous.basis.y * 0.5).is_equal_approx(current.origin - current.basis.y * 0.5), "Blitzsegmente ohne Lücken")
		var shaft: Transform3D = proc.batches.shaft.items[0][0]
		check(shaft.basis.y.normalized().is_equal_approx((b - a).normalized()), "Pfeilschaft in Flugrichtung")
		for id in ["acid_cloud", "frost_ring", "stone_dust"]:
			fx.play_hit({"id": id}, b)
		fx._process(0.02)
		for e in fx._effects:
			var alive := 0
			for state in e.state:
				alive += state.alive
			check(alive <= (12 if quality == Display.LOW else 24), "Trefferbudget eingehalten")
		check(fx.lights_active() == 0, "Neue Effekte ohne Zusatzlicht")
		fx._process(3.0)
		fx._process(0.01)
		check(fx._sprites.is_empty() and fx._effects.is_empty(), "Geschosse und Treffer abgelaufen")
		for batch in proc.batches.values():
			check(batch.node.multimesh.visible_instance_count == 0, "Abgelaufene Batches unsichtbar")
		fx.free()
		for id in TOWERS.KINDS:
			var look := TowerModels.look("eeve", id)
			check(look.get("effect_tower", "") == id and look.get("model", "x") == "", "Effekt statt Ersatzkristall: " + id)
			var node := TOWERS.make(id)
			add_child(node)
			check(node.get_child_count() > 0, "Tower-Geometrie: " + id)
			for child in node.get_children():
				check(not child is Light3D, "Kein Tower-Zusatzlicht")
				if child is GPUParticles3D:
					check(child.amount == (4 if quality == Display.LOW else 8), "Tower-Partikel halbiert")
					Display.quality = Display.LOW
					Display.quality_changed.emit()
					check(child.amount == 4, "Grafikwechsel aktualisiert vorhandene Tower")
					Display.quality = quality
					Display.quality_changed.emit()
			node.free()
	Display.quality = saved
	print("FERTIG: %d Fehler" % failures)
	get_tree().quit(1 if failures else 0)
